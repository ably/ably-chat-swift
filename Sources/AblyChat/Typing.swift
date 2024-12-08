import Ably

/**
 * This interface is used to interact with typing in a chat room including subscribing to typing events and
 * fetching the current set of typing clients.
 *
 * Get an instance via {@link Room.typing}.
 */
public protocol Typing: AnyObject, Sendable, EmitsDiscontinuities {
    /**
     * Subscribe a given listener to all typing events from users in the chat room.
     *
     * @param listener A listener to be called when the typing state of a user in the room changes.
     * @returns A response object that allows you to control the subscription to typing events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<TypingEvent>

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy.unbounded``.
    ///
    /// The `Typing` protocol provides a default implementation of this method.
    func subscribe() async -> Subscription<TypingEvent>

    /**
     * Get the current typers, a set of clientIds.
     * @returns A Promise of a set of clientIds that are currently typing.
     */
    func get() async throws -> Set<String>

    /**
     * Start indicates that the current user is typing. This will emit a typingStarted event to inform listening clients and begin a timer,
     * once the timer expires, a typingStopped event will be emitted. The timeout is configurable through the typingTimeoutMs parameter.
     * If the current user is already typing, it will reset the timer and being counting down again without emitting a new event.
     *
     * @returns A promise which resolves upon success of the operation and rejects with an ErrorInfo object upon its failure.
     */
    func start() async throws

    /**
     * Stop indicates that the current user has stopped typing. This will emit a typingStopped event to inform listening clients,
     * and immediately clear the typing timeout timer.
     *
     * @returns A promise which resolves upon success of the operation and rejects with an ErrorInfo object upon its failure.
     */
    func stop() async throws

    /**
     * Get the Ably realtime channel underpinning typing events.
     * @returns The Ably realtime channel.
     */
    var channel: RealtimeChannelProtocol { get }
}

public extension Typing {
    func subscribe() async -> Subscription<TypingEvent> {
        await subscribe(bufferingPolicy: .unbounded)
    }
}

/**
 * Represents a typing event.
 */
public struct TypingEvent: Sendable {
    /**
     * Get a set of clientIds that are currently typing.
     */
    public var currentlyTyping: Set<String>

    public init(currentlyTyping: Set<String>) {
        self.currentlyTyping = currentlyTyping
    }
}
