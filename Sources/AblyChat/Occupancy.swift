import Ably

public protocol Occupancy: AnyObject, Sendable, EmitsDiscontinuities {
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<OccupancyEvent>
    func get() async throws -> OccupancyEvent
    var channel: RealtimeChannelProtocol { get }
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
