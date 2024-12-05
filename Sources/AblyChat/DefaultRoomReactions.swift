import Ably

// TODO: This class errors with "Task-isolated value of type '() async throws -> ()' passed as a strongly transferred parameter; later accesses could race". Adding @MainActor fixes this, revisit as part of https://github.com/ably-labs/ably-chat-swift/issues/83
@MainActor
internal final class DefaultRoomReactions: RoomReactions, EmitsDiscontinuities {
    private let roomID: String
    public let featureChannel: FeatureChannel
    private let logger: InternalLogger
    private let clientID: String

    internal nonisolated var channel: any RealtimeChannelProtocol {
        featureChannel.channel
    }

    internal init(featureChannel: FeatureChannel, clientID: String, roomID: String, logger: InternalLogger) {
        self.roomID = roomID
        self.featureChannel = featureChannel
        self.logger = logger
        self.clientID = clientID
    }

    // (CHA-ER3) Ephemeral room reactions are sent to Ably via the Realtime connection via a send method.
    // (CHA-ER3a) Reactions are sent on the channel using a message in a particular format - see spec for format.
    internal func send(params: SendReactionParams) async throws {
        logger.log(message: "Sending reaction with params: \(params)", level: .debug)
        let extras = ["headers": params.headers ?? [:]] as ARTJsonCompatible
        channel.publish(RoomReactionEvents.reaction.rawValue, data: params.asJSONObject(), extras: extras)
    }

    // (CHA-ER4) A user may subscribe to reaction events in Realtime.
    // (CHA-ER4a) A user may provide a listener to subscribe to reaction events. This operation must have no side-effects in relation to room or underlying status. When a realtime message with name roomReaction is received, this message is converted into a reaction object and emitted to subscribers.
    internal func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<Reaction> {
        logger.log(message: "Subscribing to reaction events", level: .debug)
        let subscription = Subscription<Reaction>(bufferingPolicy: bufferingPolicy)

        // (CHA-ER4c) Realtime events with an unknown name shall be silently discarded.
        channel.subscribe(RoomReactionEvents.reaction.rawValue) { [clientID, logger] message in
            logger.log(message: "Received roomReaction message: \(message)", level: .debug)
            Task {
                do {
                    guard let data = message.data as? [String: Any],
                          let reactionType = data["type"] as? String
                    else {
                        throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without data or text")
                    }

                    guard let messageClientID = message.clientId else {
                        throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without clientId")
                    }

                    guard let timestamp = message.timestamp else {
                        throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without timestamp")
                    }

                    guard let extras = try message.extras?.toJSON() else {
                        throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without extras")
                    }

                    let metadata = data["metadata"] as? Metadata
                    let headers = extras["headers"] as? Headers

                    // (CHA-ER4d) Realtime events that are malformed (unknown fields should be ignored) shall not be emitted to listeners.
                    let reaction = Reaction(
                        type: reactionType,
                        metadata: metadata ?? .init(),
                        headers: headers ?? .init(),
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
        }

        return subscription
    }

    // (CHA-ER5) Users may subscribe to discontinuity events to know when there’s been a break in reactions that they need to resolve. Their listener will be called when a discontinuity event is triggered from the room lifecycle.
    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent> {
        await featureChannel.onDiscontinuity(bufferingPolicy: bufferingPolicy)
    }

    private enum RoomReactionsError: Error {
        case noReferenceToSelf
    }
}
