import Ably

/**
 * This interface is used to interact with occupancy in a chat room: subscribing to occupancy updates and
 * fetching the current room occupancy metrics.
 *
 * Get an instance via ``Room/occupancy``.
 */
@MainActor
public protocol Occupancy: AnyObject, Sendable {
    /**
     * Subscribes a given listener to occupancy updates of the chat room.
     *
     * Note that it is a programmer error to call this method if occupancy events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's occupancy options to use this feature.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing room ``OccupancyEvent`` events.
     *
     * - Returns: A subscription handle that can be used to unsubscribe from ``OccupancyEvent`` events.
     */
    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (OccupancyEvent) -> Void) -> SubscriptionHandle

    /**
     * Get the current occupancy of the chat room.
     *
     * - Returns: A current occupancy of the chat room.
     */
    func get() async throws(ARTErrorInfo) -> OccupancyEvent
}

/// `AsyncSequence` variant of receiving room occupancy events.
public extension Occupancy {
    /**
     * Subscribes a given listener to occupancy updates of the chat room.
     *
     * Note that it is a programmer error to call this method if occupancy events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's occupancy options to use this feature.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``OccupancyEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<OccupancyEvent> {
        let subscription = Subscription<OccupancyEvent>(bufferingPolicy: bufferingPolicy)

        let subscriptionHandle = subscribe { occupancy in
            subscription.emit(occupancy)
        }

        subscription.addTerminationHandler {
            Task { @MainActor in
                subscriptionHandle.unsubscribe()
            }
        }

        return subscription
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Occupancy` protocol provides a default implementation of this method.
    func subscribe() -> Subscription<OccupancyEvent> {
        subscribe(bufferingPolicy: .unbounded)
    }
}

// (CHA-O2) The occupancy event format is shown here (https://sdk.ably.com/builds/ably/specification/main/chat-features/#chat-structs-occupancy-event)

/**
 * Represents the occupancy of a chat room.
 */
public struct OccupancyEvent: Sendable {
    /**
     * The number of connections to the chat room.
     */
    public var connections: Int

    /**
     * The number of presence members in the chat room - members who have entered presence.
     */
    public var presenceMembers: Int

    public init(connections: Int, presenceMembers: Int) {
        self.connections = connections
        self.presenceMembers = presenceMembers
    }
}

extension OccupancyEvent: JSONObjectDecodable {
    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        try self.init(
            connections: Int(jsonObject.numberValueForKey("connections")),
            presenceMembers: Int(jsonObject.numberValueForKey("presenceMembers"))
        )
    }
}
