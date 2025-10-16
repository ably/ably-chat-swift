import Ably

internal final class DefaultOccupancy: Occupancy {
    private let channel: any InternalRealtimeChannelProtocol
    private let chatAPI: ChatAPI
    private let roomName: String
    private let logger: any InternalLogger
    private let options: OccupancyOptions

    private var lastOccupancyData: OccupancyData?

    internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI, roomName: String, logger: any InternalLogger, options: OccupancyOptions) {
        self.channel = channel
        self.chatAPI = chatAPI
        self.roomName = roomName
        self.logger = logger
        self.options = options
    }

    @discardableResult
    internal func subscribe(_ callback: @escaping @MainActor (OccupancyEvent) -> Void) -> some Subscription {
        // CHA-O4e (we use a fatalError for this programmer error, which is the idiomatic thing to do for Swift)
        guard options.enableEvents else {
            fatalError("In order to be able to subscribe to occupancy events, please set enableEvents to true in the room's occupancy options.")
        }

        logger.log(message: "Subscribing to occupancy events", level: .debug)

        let eventListener = channel.subscribe(OccupancyEvents.meta.rawValue) { [weak self] message in
            guard let self else {
                return
            }
            logger.log(message: "Received occupancy message: \(message)", level: .debug)

            var metrics = [String: Any]()
            if let data = message.data as? [String: Any] {
                metrics = data["metrics"] as? [String: Any] ?? [:]
            }

            let connections = metrics["connections"] as? Int ?? 0 // CHA-O4g
            let presenceMembers = metrics["presenceMembers"] as? Int ?? 0 // CHA-O4g

            let occupancyData = OccupancyData(connections: connections, presenceMembers: presenceMembers)
            let occupancyEvent = OccupancyEvent(type: .updated, occupancy: occupancyData)

            lastOccupancyData = occupancyData

            logger.log(message: "Emitting occupancy event: \(occupancyEvent)", level: .debug)
            callback(occupancyEvent)
        }

        return DefaultSubscription {
            guard let eventListener else {
                return
            }
            self.channel.off(eventListener)
        }
    }

    // (CHA-O3) Users can request an instantaneous occupancy check via the REST API. The request is detailed here (https://sdk.ably.com/builds/ably/specification/main/chat-features/#rest-occupancy-request), with the response format being a simple occupancy data
    internal func get() async throws(ErrorInfo) -> OccupancyData {
        do {
            logger.log(message: "Getting occupancy for room: \(roomName)", level: .debug)
            return try await chatAPI.getOccupancy(roomName: roomName)
        } catch {
            throw error.toErrorInfo()
        }
    }

    // (CHA-O7a) The current method should return the latest occupancy numbers received over the realtime connection in a [meta]occupancy event.
    internal var current: OccupancyData? {
        // CHA-O7c (we use a fatalError for this programmer error, which is the idiomatic thing to do for Swift)
        guard options.enableEvents else {
            fatalError("In order to be able to fetch the last received occupancy event, please set enableEvents to true in the room's occupancy options.")
        }

        // CHA-07a
        // CHA-07b
        return lastOccupancyData
    }
}
