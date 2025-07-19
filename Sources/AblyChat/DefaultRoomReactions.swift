import Ably

internal final class DefaultRoomReactions: RoomReactions {
    private let implementation: Implementation

    internal init(channel: any InternalRealtimeChannelProtocol, clientID: String, roomName: String, logger: InternalLogger) {
        implementation = .init(channel: channel, clientID: clientID, roomName: roomName, logger: logger)
    }

    internal func send(params: SendReactionParams) async throws(ARTErrorInfo) {
        try await implementation.send(params: params)
    }

    @discardableResult
    internal func subscribe(_ callback: @escaping @MainActor (RoomReactionEvent) -> Void) -> SubscriptionProtocol {
        implementation.subscribe(callback)
    }

    /// This class exists to make sure that the internals of the SDK only access ably-cocoa via the `InternalRealtimeChannelProtocol` interface. It does this by removing access to the `channel` property that exists as part of the public API of the `RoomReactions` protocol, making it unlikely that we accidentally try to call the `ARTRealtimeChannelProtocol` interface. We can remove this `Implementation` class when we remove the feature-level `channel` property in https://github.com/ably/ably-chat-swift/issues/242.
    @MainActor
    private final class Implementation: Sendable {
        private let channel: any InternalRealtimeChannelProtocol
        private let roomName: String
        private let logger: InternalLogger
        private let clientID: String

        internal init(channel: any InternalRealtimeChannelProtocol, clientID: String, roomName: String, logger: InternalLogger) {
            self.roomName = roomName
            self.channel = channel
            self.logger = logger
            self.clientID = clientID
        }

        // (CHA-ER3) Ephemeral room reactions are sent to Ably via the Realtime connection via a send method.
        // (CHA-ER3d) Reactions are sent on the channel using a message in a particular format - see spec for format.
        internal func send(params: SendReactionParams) async throws(ARTErrorInfo) {
            do {
                logger.log(message: "Sending reaction with params: \(params)", level: .debug)

                let dto = RoomReactionDTO(name: params.name, metadata: params.metadata, headers: params.headers)

                try await channel.publish(
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
        @discardableResult
        internal func subscribe(_ callback: @escaping @MainActor (RoomReactionEvent) -> Void) -> SubscriptionProtocol {
            logger.log(message: "Subscribing to reaction events", level: .debug)

            // (CHA-ER4c) Realtime events with an unknown name shall be silently discarded.
            let eventListener = channel.subscribe(RoomReactionEvents.reaction.rawValue) { [clientID, logger] message in
                logger.log(message: "Received roomReaction message: \(message)", level: .debug)

                let ablyCocoaData = message.data ?? [:] // CHA-ER4e2

                let extras = if let ablyCocoaExtras = message.extras {
                    JSONValue.objectFromAblyCocoaExtras(ablyCocoaExtras)
                } else {
                    [String: JSONValue]() // CHA-ER4e2
                }

                let dto = try? RoomReactionDTO(
                    data: .init(jsonValue: .init(ablyCocoaData: ablyCocoaData)),
                    extras: .init(jsonObject: extras)
                )

                let messageClientID = message.clientId ?? "" // CHA-ER4e3

                let reaction = RoomReaction(
                    name: dto?.name ?? "", // CHA-ER4e1
                    metadata: dto?.metadata ?? [:],
                    headers: dto?.headers ?? [:],
                    createdAt: message.timestamp ?? Date(), // CHA-ER4e4
                    clientID: messageClientID,
                    isSelf: messageClientID == clientID
                )

                let event = RoomReactionEvent(type: .reaction, reaction: reaction)
                logger.log(message: "Emitting room reaction: \(reaction)", level: .debug)
                callback(event)
            }

            return Subscription { [weak self] in
                self?.channel.unsubscribe(eventListener)
            }
        }

        private enum RoomReactionsError: Error {
            case noReferenceToSelf
        }
    }
}
