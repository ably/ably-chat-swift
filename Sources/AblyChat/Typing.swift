import Ably

/**
 * This interface is used to interact with typing in a chat room including subscribing to typing events and
 * fetching the current set of typing clients.
 *
 * Get an instance via ``Room/typing``.
 */
public protocol Typing: AnyObject, Sendable, EmitsDiscontinuities {
    /**
     * Subscribes a given listener to all typing events from users in the chat room.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``TypingEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<TypingEvent>

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Typing` protocol provides a default implementation of this method.
    func subscribe() async -> Subscription<TypingEvent>

    /**
     * Get the current typers, a set of clientIds.
     *
     * - Returns: A set of clientIds that are currently typing.
     */
    func get() async throws -> Set<String>

    /**
     * Start indicates that the current user is typing. This will emit a ``TypingEvent`` event to inform listening clients and begin a timer,
     * once the timer expires, another ``TypingEvent`` event will be emitted. In both cases ``TypingEvent/currentlyTyping``
     * contains a list of userIds who are currently typing.
     *
     * The timeout is configurable through the ``TypingOptions/timeout`` parameter.
     * If the current user is already typing, it will reset the timer and begin counting down again without emitting a new event.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func start() async throws

    /**
     * Stop indicates that the current user has stopped typing. This will emit a ``TypingEvent`` event to inform listening clients,
     * and immediately clear the typing timeout timer.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func stop() async throws

    /**
     * Get the Ably realtime channel underpinning typing events.
     *
     * - Returns: The Ably realtime channel.
     */
    var channel: any RealtimeChannelProtocol { get }
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
