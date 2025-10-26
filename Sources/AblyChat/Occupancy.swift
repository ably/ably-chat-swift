import Ably

/**
 * This interface is used to interact with occupancy in a chat room: subscribing to occupancy updates and
 * fetching the current room occupancy metrics.
 *
 * Get an instance via ``Room/occupancy``.
 */
@MainActor
public protocol Occupancy: AnyObject, Sendable {
    // swiftlint:disable:next missing_docs
    associatedtype Subscription: AblyChat.Subscription

    /**
     * Subscribes a given listener to occupancy updates of the chat room.
     *
     * Note that it is a programmer error to call this method if occupancy events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's occupancy options to use this feature.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing room ``OccupancyEvent`` events.
     *
     * - Returns: A subscription that can be used to unsubscribe from ``OccupancyEvent`` events.
     */
    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (OccupancyEvent) -> Void) -> Subscription

    /**
     * Get the current occupancy of the chat room.
     *
     * - Returns: A current occupancy of the chat room.
     */
    func get() async throws(ErrorInfo) -> OccupancyData

    /**
     * Get the latest occupancy data received from realtime events.
     *
     * Note that it is a programmer error to read this property if occupancy events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's occupancy options to use this feature.
     *
     * - Returns: The latest occupancy data, or nil if no realtime events have been received yet.
     */
    var current: OccupancyData? { get }
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
    func subscribe(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<OccupancyEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<OccupancyEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribe { occupancyEvent in
            subscriptionAsyncSequence.emit(occupancyEvent)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe() -> SubscriptionAsyncSequence<OccupancyEvent> {
        subscribe(bufferingPolicy: .unbounded)
    }
}

/**
 * Represents the occupancy of a chat room.
 */
public struct OccupancyData: Sendable {
    /**
     * The number of connections to the chat room.
     */
    public var connections: Int

    /**
     * The number of presence members in the chat room - members who have entered presence.
     */
    public var presenceMembers: Int

    /// Memberwise initializer to create a `OccupancyData`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(connections: Int, presenceMembers: Int) {
        self.connections = connections
        self.presenceMembers = presenceMembers
    }
}

/// Enum representing occupancy events.
public enum OccupancyEventType: Sendable {
    /// Event triggered when occupancy is updated.
    case updated
}

/// Represents an occupancy event.
public struct OccupancyEvent: Sendable {
    /// The type of the occupancy event.
    public var type: OccupancyEventType
    /// The occupancy data.
    public var occupancy: OccupancyData

    /// Memberwise initializer to create a `OccupancyEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: OccupancyEventType, occupancy: OccupancyData) {
        self.type = type
        self.occupancy = occupancy
    }
}

extension OccupancyData: JSONObjectDecodable {
    internal init(jsonObject: [String: JSONValue]) throws(ErrorInfo) {
        try self.init(
            connections: Int(jsonObject.numberValueForKey("connections")),
            presenceMembers: Int(jsonObject.numberValueForKey("presenceMembers")),
        )
    }
}
