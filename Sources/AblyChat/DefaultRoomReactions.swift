import Ably

internal final class DefaultRoomReactions: RoomReactions {
    private let realtime: any InternalRealtimeClientProtocol
    private let channel: any InternalRealtimeChannelProtocol
    private let roomName: String
    private let logger: any InternalLogger

    internal init(realtime: any InternalRealtimeClientProtocol, channel: any InternalRealtimeChannelProtocol, roomName: String, logger: any InternalLogger) {
        self.realtime = realtime
        self.channel = channel
        self.roomName = roomName
        self.logger = logger
    }

    // (CHA-ER3) Ephemeral room reactions are sent to Ably via the Realtime connection via a send method.
    // (CHA-ER3d) Reactions are sent on the channel using a message in a particular format - see spec for format.
    internal func send(withParams params: SendReactionParams) async throws(ErrorInfo) {
        logger.log(message: "Sending reaction with params: \(params)", level: .debug)

        let dto = RoomReactionDTO(name: params.name, metadata: params.metadata, headers: params.headers)

        try await channel.publish(
            RoomReactionEvents.reaction.rawValue,
            data: dto.data.toJSONValue,
            extras: dto.extras.toJSONObject,
        )
    }

    // (CHA-ER4) A user may subscribe to reaction events in Realtime.
    // (CHA-ER4a) A user may provide a listener to subscribe to reaction events. This operation must have no side-effects in relation to room or underlying status. When a realtime message with name roomReaction is received, this message is converted into a reaction object and emitted to subscribers.
    @discardableResult
    internal func subscribe(_ callback: @escaping @MainActor (RoomReactionEvent) -> Void) -> some Subscription {
        logger.log(message: "Subscribing to reaction events", level: .debug)

        // (CHA-ER4c) Realtime events with an unknown name shall be silently discarded.
        let eventListener = channel.subscribe(RoomReactionEvents.reaction.rawValue) { [weak self] message in
            guard let self else {
                return
            }
            logger.log(message: "Received roomReaction message: \(message)", level: .debug)

            let ablyCocoaData = message.data ?? [:] // CHA-ER4e2

            let extras = if let ablyCocoaExtras = message.extras {
                JSONValue.objectFromAblyCocoaExtras(ablyCocoaExtras)
            } else {
                [String: JSONValue]() // CHA-ER4e2
            }

            let dto = try? RoomReactionDTO(
                data: .init(jsonValue: .init(ablyCocoaData: ablyCocoaData)),
                extras: .init(jsonObject: extras),
            )

            let messageClientID = message.clientId ?? "" // CHA-ER4e3

            let reaction = RoomReaction(
                name: dto?.name ?? "", // CHA-ER4e1
                metadata: dto?.metadata ?? [:],
                headers: dto?.headers ?? [:],
                createdAt: message.timestamp ?? Date(), // CHA-ER4e4
                clientID: messageClientID,
                isSelf: messageClientID == realtime.clientId,
            )

            let event = RoomReactionEvent(type: .reaction, reaction: reaction)
            logger.log(message: "Emitting room reaction: \(reaction)", level: .debug)
            callback(event)
        }

        return DefaultSubscription { [weak self] in
            self?.channel.unsubscribe(eventListener)
        }
    }
}
