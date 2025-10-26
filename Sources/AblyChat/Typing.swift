import Ably

/**
 * This interface is used to interact with typing in a chat room including subscribing to typing events and
 * fetching the current set of typing clients.
 *
 * Get an instance via ``Room/typing``.
 */
@MainActor
public protocol Typing: AnyObject, Sendable {
    /// The type of the subscription.
    associatedtype Subscription: AblyChat.Subscription

    /**
     * Subscribes a given listener to all typing events from users in the chat room.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing room ``TypingEvent`` events.
     *
     * - Returns: A subscription that can be used to unsubscribe from ``TypingEvent`` events.
     */
    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (TypingSetEvent) -> Void) -> Subscription

    /**
     * Get the current typers, a set of clientIds.
     *
     * - Returns: A set of clientIds that are currently typing.
     */
    var current: Set<String> { get }

    /**
     * This will send a `typing.started` event to the server.
     * Events are throttled according to the `heartbeatThrottle` room option.
     * If an event has been sent within the interval, this operation is no-op.
     *
     * Calls to `keystroke()` and `stop()` are serialized and will always resolve in the correct order.
     * - For example, if multiple `keystroke()` calls are made in quick succession before the first `keystroke()` call has
     * sent a `typing.started` event to the server, followed by one `stop()` call, the `stop()` call will execute
     * as soon as the first `keystroke()` call completes.
     * All intermediate `keystroke()` calls will be treated as no-ops.
     * - The most recent operation (`keystroke()` or `stop()`) will always determine the final state, ensuring operations
     * resolve to a consistent and correct state.
     *
     * - Throws: An `ErrorInfo` if the operation fails.
     */
    func keystroke() async throws(ErrorInfo)

    /**
     * This will send a `typing.stopped` event to the server.
     * If the user was not currently typing, this operation is no-op.
     *
     * Calls to `keystroke()` and `stop()` are serialized and will always resolve in the correct order.
     * - For example, if multiple `keystroke()` calls are made in quick succession before the first `keystroke()` call has
     * sent a `typing.started` event to the server, followed by one `stop()` call, the `stop()` call will execute
     * as soon as the first `keystroke()` call completes.
     * All intermediate `keystroke()` calls will be treated as no-ops.
     * - The most recent operation (`keystroke()` or `stop()`) will always determine the final state, ensuring operations
     * resolve to a consistent and correct state.
     *
     * - Throws: An `ErrorInfo` if the operation fails.
     */
    func stop() async throws(ErrorInfo)
}

/// `AsyncSequence` variant of receiving room typing events.
public extension Typing {
    /**
     * Subscribes a given listener to all typing events from users in the chat room.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``TypingSetEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<TypingSetEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<TypingSetEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribe { typingEvent in
            subscriptionAsyncSequence.emit(typingEvent)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe() -> SubscriptionAsyncSequence<TypingSetEvent> {
        subscribe(bufferingPolicy: .unbounded)
    }
}

/**
 * Represents a change in the state of current typers.
 */
public struct TypingSetEvent: Sendable {
    /**
     * The type of the event.
     */
    public var type: TypingSetEventType

    /**
     * The set of clientIds that are currently typing.
     */
    public var currentlyTyping: Set<String>

    /**
     * Represents the change that resulted in the new set of typers.
      */
    public var change: Change

    /// Memberwise initializer to create a `TypingSetEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: TypingSetEventType, currentlyTyping: Set<String>, change: Change) {
        self.type = type
        self.currentlyTyping = currentlyTyping
        self.change = change
    }

    /// Represents the change that resulted in the new set of typers.
    public struct Change: Sendable {
        /// The client ID of the user who stopped/started typing.
        public var clientID: String
        /// Type of the change.
        public var type: TypingEventType

        /// Memberwise initializer to create a `Change`.
        ///
        /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
        public init(clientID: String, type: TypingEventType) {
            self.clientID = clientID
            self.type = type
        }
    }
}
