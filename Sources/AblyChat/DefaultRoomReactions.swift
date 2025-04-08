import Ably

internal final class DefaultRoomReactions: RoomReactions, EmitsDiscontinuities {
    public let featureChannel: FeatureChannel
    private let implementation: Implementation

    internal nonisolated var channel: any RealtimeChannelProtocol {
        featureChannel.channel.underlying
    }

    #if DEBUG
        internal nonisolated var testsOnly_internalChannel: any InternalRealtimeChannelProtocol {
            featureChannel.channel
        }
    #endif

    internal init(featureChannel: FeatureChannel, clientID: String, roomID: String, logger: InternalLogger) {
        self.featureChannel = featureChannel
        implementation = .init(featureChannel: featureChannel, clientID: clientID, roomID: roomID, logger: logger)
    }

    internal func send(params: SendReactionParams) async throws(ARTErrorInfo) {
        try await implementation.send(params: params)
    }

    internal func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<Reaction> {
        implementation.subscribe(bufferingPolicy: bufferingPolicy)
    }

    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        implementation.onDiscontinuity(bufferingPolicy: bufferingPolicy)
    }

    /// This class exists to make sure that the internals of the SDK only access ably-cocoa via the `InternalRealtimeChannelProtocol` interface. It does this by removing access to the `channel` property that exists as part of the public API of the `RoomReactions` protocol, making it unlikely that we accidentally try to call the `ARTRealtimeChannelProtocol` interface. We can remove this `Implementation` class when we remove the feature-level `channel` property in https://github.com/ably/ably-chat-swift/issues/242.
    @MainActor
    private final class Implementation: Sendable {
        public let featureChannel: FeatureChannel
        private let roomID: String
        private let logger: InternalLogger
        private let clientID: String

        internal init(featureChannel: FeatureChannel, clientID: String, roomID: String, logger: InternalLogger) {
            self.roomID = roomID
            self.featureChannel = featureChannel
            self.logger = logger
            self.clientID = clientID
        }

        // (CHA-ER3) Ephemeral room reactions are sent to Ably via the Realtime connection via a send method.
        // (CHA-ER3a) Reactions are sent on the channel using a message in a particular format - see spec for format.
        internal func send(params: SendReactionParams) async throws(ARTErrorInfo) {
            do {
                logger.log(message: "Sending reaction with params: \(params)", level: .debug)

                let dto = RoomReactionDTO(type: params.type, metadata: params.metadata, headers: params.headers)

                try await featureChannel.channel.publish(
                    RoomReactionEvents.reaction.rawValue,
                    data: dto.data.toJSONValue,
                    extras: dto.extras.toJSONObject
                )
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        // (CHA-ER4) A user may subscribe to reaction events in Realtime.
        // (CHA-ER4a) A user may provide a listener to subscribe to reaction events. This operation must have no side-effects in relation to room or underlying status. When a realtime message with name roomReaction is received, this message is converted into a reaction object and emitted to subscribers.
        internal func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<Reaction> {
            logger.log(message: "Subscribing to reaction events", level: .debug)
            let subscription = Subscription<Reaction>(bufferingPolicy: bufferingPolicy)

            // (CHA-ER4c) Realtime events with an unknown name shall be silently discarded.
            let eventListener = featureChannel.channel.subscribe(RoomReactionEvents.reaction.rawValue) { [clientID, logger] message in
                logger.log(message: "Received roomReaction message: \(message)", level: .debug)
                do {
                    guard let ablyCocoaData = message.data else {
                        throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without data")
                    }

                    guard let messageClientID = message.clientId else {
                        throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without clientId")
                    }

                    guard let timestamp = message.timestamp else {
                        throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without timestamp")
                    }

                    guard let ablyCocoaExtras = message.extras else {
                        throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without extras")
                    }

                    let dto = try RoomReactionDTO(
                        data: .init(jsonValue: .init(ablyCocoaData: ablyCocoaData)),
                        extras: .init(jsonObject: JSONValue.objectFromAblyCocoaExtras(ablyCocoaExtras))
                    )

                    // (CHA-ER4d) Realtime events that are malformed (unknown fields should be ignored) shall not be emitted to listeners.
                    let reaction = Reaction(
                        type: dto.type,
                        metadata: dto.metadata ?? [:],
                        headers: dto.headers ?? [:],
                        createdAt: timestamp,
                        clientID: messageClientID,
                        isSelf: messageClientID == clientID
                    )
                    logger.log(message: "Emitting reaction: \(reaction)", level: .debug)
                    subscription.emit(reaction)
                } catch {
                    logger.log(message: "Error processing incoming reaction message: \(error)", level: .error)
                }
            }

            subscription.addTerminationHandler { [weak self] in
                Task { @MainActor in
                    self?.featureChannel.channel.unsubscribe(eventListener)
                }
            }

            return subscription
        }

        // (CHA-ER5) Users may subscribe to discontinuity events to know when there’s been a break in reactions that they need to resolve. Their listener will be called when a discontinuity event is triggered from the room lifecycle.
        internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
            featureChannel.onDiscontinuity(bufferingPolicy: bufferingPolicy)
        }

        private enum RoomReactionsError: Error {
            case noReferenceToSelf
        }
    }
}
