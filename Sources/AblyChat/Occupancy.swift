import Ably

/**
 * This interface is used to interact with occupancy in a chat room: subscribing to occupancy updates and
 * fetching the current room occupancy metrics.
 *
 * Get an instance via ``Room/occupancy``.
 */
public protocol Occupancy: AnyObject, Sendable, EmitsDiscontinuities {
    /**
     * Subscribes a given listener to occupancy updates of the chat room.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``OccupancyEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<OccupancyEvent>

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Occupancy` protocol provides a default implementation of this method.
    func subscribe() async -> Subscription<OccupancyEvent>

    /**
     * Get the current occupancy of the chat room.
     *
     * - Returns: A current occupancy of the chat room.
     */
    func get() async throws -> OccupancyEvent

    /**
     * Get underlying Ably channel for occupancy events.
     *
     * - Returns: The underlying Ably channel for occupancy events.
     */
    var channel: RealtimeChannelProtocol { get }
}

public extension Occupancy {
    func subscribe() async -> Subscription<OccupancyEvent> {
        await subscribe(bufferingPolicy: .unbounded)
    }
}

// (CHA-O2) The occupancy event format is shown here (https://sdk.ably.com/builds/ably/specification/main/chat-features/#chat-structs-occupancy-event)

/**
 * Represents the occupancy of a chat room.
 */
public struct OccupancyEvent: Sendable, Encodable, Decodable {
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
