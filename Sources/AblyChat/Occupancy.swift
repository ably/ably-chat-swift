import Ably

public protocol Occupancy: AnyObject, Sendable, EmitsDiscontinuities {
    func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<OccupancyEvent>
    func get() async throws -> OccupancyEvent
    var channel: ARTRealtimeChannelProtocol { get }
}

public struct OccupancyEvent {
    public var connections: Int
    public var presenceMembers: Int

    public init(connections: Int, presenceMembers: Int) {
        self.connections = connections
        self.presenceMembers = presenceMembers
    }
}
