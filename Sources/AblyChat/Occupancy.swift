import Ably

public protocol Occupancy: AnyObject, Sendable, EmitsDiscontinuities {
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<OccupancyEvent>
    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy.unbounded``.
    ///
    /// The `Occupancy` protocol provides a default implementation of this method.
    func subscribe() async -> Subscription<OccupancyEvent>
    func get() async throws -> OccupancyEvent
    var channel: RealtimeChannelProtocol { get }
}

public extension Occupancy {
    func subscribe() async -> Subscription<OccupancyEvent> {
        await subscribe(bufferingPolicy: .unbounded)
    }
}

// (CHA-O2) The occupancy event format is shown here (https://sdk.ably.com/builds/ably/specification/main/chat-features/#chat-structs-occupancy-event)
public struct OccupancyEvent: Sendable, Encodable, Decodable {
    public var connections: Int
    public var presenceMembers: Int

    public init(connections: Int, presenceMembers: Int) {
        self.connections = connections
        self.presenceMembers = presenceMembers
    }
}
