import Ably

internal final class DefaultOccupancy: Occupancy, EmitsDiscontinuities {
    private let chatAPI: ChatAPI
    private let roomID: String
    private let logger: InternalLogger
    public nonisolated let featureChannel: FeatureChannel

    internal nonisolated var channel: any RealtimeChannelProtocol {
        featureChannel.channel
    }

    internal init(featureChannel: FeatureChannel, chatAPI: ChatAPI, roomID: String, logger: InternalLogger) {
        self.featureChannel = featureChannel
        self.chatAPI = chatAPI
        self.roomID = roomID
        self.logger = logger
    }

    // (CHA-04a) Users may register a listener that receives occupancy events in realtime.
    // (CHA-04c) When a regular occupancy event is received on the channel (a standard PubSub occupancy event per the docs), the SDK will convert it into occupancy event format and broadcast it to subscribers.
    // (CHA-04d) If an invalid occupancy event is received on the channel, it shall be dropped.
    internal func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<OccupancyEvent> {
        logger.log(message: "Subscribing to occupancy events", level: .debug)

        let subscription = Subscription<OccupancyEvent>(bufferingPolicy: bufferingPolicy)

        let eventListener = channel.subscribe(OccupancyEvents.meta.rawValue) { [logger] message in
            logger.log(message: "Received occupancy message: \(message)", level: .debug)
            guard let data = message.data as? [String: Any],
                  let metrics = data["metrics"] as? [String: Any]
            else {
                let error = ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without data or metrics")
                logger.log(message: "Error parsing occupancy message: \(error)", level: .error)
                return // (CHA-04d) implies we don't throw an error
            }

            let connections = metrics["connections"] as? Int ?? 0
            let presenceMembers = metrics["presenceMembers"] as? Int ?? 0

            let occupancyEvent = OccupancyEvent(connections: connections, presenceMembers: presenceMembers)
            logger.log(message: "Emitting occupancy event: \(occupancyEvent)", level: .debug)
            subscription.emit(occupancyEvent)
        }

        subscription.addTerminationHandler { [weak self] in
            if let eventListener {
                self?.channel.off(eventListener)
            }
        }

        return subscription
    }

    // (CHA-O3) Users can request an instantaneous occupancy check via the REST API. The request is detailed here (https://sdk.ably.com/builds/ably/specification/main/chat-features/#rest-occupancy-request), with the response format being a simple occupancy event
    internal func get() async throws -> OccupancyEvent {
        logger.log(message: "Getting occupancy for room: \(roomID)", level: .debug)
        return try await chatAPI.getOccupancy(roomId: roomID)
    }

    // (CHA-O5) Users may subscribe to discontinuity events to know when there’s been a break in occupancy. Their listener will be called when a discontinuity event is triggered from the room lifecycle. For occupancy, there shouldn’t need to be user action as most channels will send occupancy updates regularly as clients churn.
    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent> {
        await featureChannel.onDiscontinuity(bufferingPolicy: bufferingPolicy)
    }
}
