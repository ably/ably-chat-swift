import Ably

public protocol RoomReactions: AnyObject, Sendable, EmitsDiscontinuities {
    func send(params: RoomReactionParams) async throws
    func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<Reaction>
    var channel: ARTRealtimeChannelProtocol { get }
}

public struct RoomReactionParams: Sendable {
    public init() {}
}
