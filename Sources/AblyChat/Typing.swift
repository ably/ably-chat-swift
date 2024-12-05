import Ably

public protocol Typing: AnyObject, Sendable, EmitsDiscontinuities {
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<TypingEvent>
    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy.unbounded``.
    ///
    /// The `Typing` protocol provides a default implementation of this method.
    func subscribe() async -> Subscription<TypingEvent>
    func get() async throws -> Set<String>
    func start() async throws
    func stop() async throws
    var channel: RealtimeChannelProtocol { get }
}

public extension Typing {
    func subscribe() async -> Subscription<TypingEvent> {
        await subscribe(bufferingPolicy: .unbounded)
    }
}

public struct TypingEvent: Sendable {
    public var currentlyTyping: Set<String>

    public init(currentlyTyping: Set<String>) {
        self.currentlyTyping = currentlyTyping
    }
}
