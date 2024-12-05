import Ably

public protocol RoomReactions: AnyObject, Sendable, EmitsDiscontinuities {
    func send(params: SendReactionParams) async throws
    var channel: RealtimeChannelProtocol { get }
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<Reaction>
    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy.unbounded``.
    ///
    /// The `RoomReactions` protocol provides a default implementation of this method.
    func subscribe() async -> Subscription<Reaction>
}

public extension RoomReactions {
    func subscribe() async -> Subscription<Reaction> {
        await subscribe(bufferingPolicy: .unbounded)
    }
}

public struct SendReactionParams: Sendable {
    public var type: String
    public var metadata: ReactionMetadata?
    public var headers: ReactionHeaders?

    public init(type: String, metadata: ReactionMetadata? = nil, headers: ReactionHeaders? = nil) {
        self.type = type
        self.metadata = metadata
        self.headers = headers
    }
}

internal extension SendReactionParams {
    /// Returns a dictionary that `JSONSerialization` can serialize to a JSON "object" value.
    ///
    /// Suitable to pass as the `data` argument of an ably-cocoa publish operation.
    func asJSONObject() -> [String: String] {
        var dict: [String: String] = [:]
        dict["type"] = "\(type)"
        dict["metadata"] = "\(metadata ?? [:])"
        return dict
    }
}
