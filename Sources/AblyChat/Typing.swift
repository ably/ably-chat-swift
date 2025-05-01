import Ably

/**
 * This interface is used to interact with typing in a chat room including subscribing to typing events and
 * fetching the current set of typing clients.
 *
 * Get an instance via ``Room/typing``.
 */
@MainActor
public protocol Typing: AnyObject, Sendable {
    /**
     * Subscribes a given listener to all typing events from users in the chat room.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``TypingEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<TypingEvent>

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Typing` protocol provides a default implementation of this method.
    func subscribe() -> Subscription<TypingEvent>

    /**
     * Get the current typers, a set of clientIds.
     *
     * - Returns: A set of clientIds that are currently typing.
     */
    func get() async throws(ARTErrorInfo) -> Set<String>

    /**
     * Keystroke indicates that the current user is typing. This will emit a ``TypingEvent`` event to inform listening clients and begin a timer,
     * once the timer expires, another ``TypingEvent`` event will be emitted. In both cases ``TypingEvent/currentlyTyping``
     * contains a list of userIds who are currently typing.
     *
     * The heartbeat throttle interval is configurable through the ``TypingOptions/heartbeatThrottle`` parameter.
     * It will show the current user as typing for the duration of the throttle, plus an internally defined timeout.
     * Any keystrokes within the throttle period will be ignored, with no new events being sent.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func keystroke() async throws(ARTErrorInfo)

    /**
     * Stop indicates that the current user has stopped typing. This will emit a ``TypingEvent`` event to inform listening clients,
     * and immediately clear the typing timeout timer.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func stop() async throws(ARTErrorInfo)
}

public extension Typing {
    func subscribe() -> Subscription<TypingEvent> {
        subscribe(bufferingPolicy: .unbounded)
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

    /**
     * Get the details of the operation that modified the typing event.
      */
    public var change: Change

    public init(currentlyTyping: Set<String>, change: Change) {
        self.currentlyTyping = currentlyTyping
        self.change = change
    }

    public struct Change: Sendable {
        public var clientId: String
        public var type: TypingEvents

        public init(clientId: String, type: TypingEvents) {
            self.clientId = clientId
            self.type = type
        }
    }
}
