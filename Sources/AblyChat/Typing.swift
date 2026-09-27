import Ably

/**
 * Represents a user in the set of currently typing users, with associated metadata.
 */
public struct TypingMember: Sendable {
    /// The client ID of the typing user.
    public var clientID: String

    /// The user claim attached to this user's typing event, if any.
    public var userClaim: String?

    /// Memberwise initializer to create a `TypingMember`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(clientID: String, userClaim: String? = nil) {
        self.clientID = clientID
        self.userClaim = userClaim
    }
}

/**
 * This interface is used to interact with typing in a chat room including subscribing to typing events and
 * fetching the current set of typing clients.
 *
 * Get an instance via ``Room/typing``.
 */
@MainActor
public protocol Typing: AnyObject, Sendable {
    // swiftlint:disable:next missing_docs
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

    // @spec CHA-T16
    /**
     * Get the current typers, a set of clientIds.
     *
     * Deprecated per CHA-T16; use ``currentTypers`` (CHA-T18) instead.
     *
     * - Returns: A set of clientIds that are currently typing.
     */
    var current: Set<String> { get }

    // @spec CHA-T18
    /**
     * Gets the current set of users who are typing, with associated metadata.
     *
     * - Returns: An array of ``TypingMember`` for users currently typing.
     */
    var currentTypers: [TypingMember] { get }

    /**
     * Keystroke indicates that the current user is typing. This will emit a ``TypingEvent`` event to inform listening clients and begin a timer,
     * once the timer expires, another ``TypingEvent`` event will be emitted. In both cases ``TypingEvent/currentlyTyping``
     * contains a list of userIds who are currently typing.
     *
     * The heartbeat throttle interval is configurable through the ``TypingOptions/heartbeatThrottle`` parameter.
     * It will show the current user as typing for the duration of the throttle, plus an internally defined timeout.
     * Any keystrokes within the throttle period will be ignored, with no new events being sent.
     *
     * - Throws: An `ErrorInfo`.
     */
    func keystroke() async throws(ErrorInfo)

    /**
     * Stop indicates that the current user has stopped typing. This will emit a ``TypingEvent`` event to inform listening clients,
     * and immediately clear the typing timeout timer.
     *
     * - Throws: An `ErrorInfo`.
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
 * Represents a typing event.
 */
public struct TypingSetEvent: Sendable {
    // swiftlint:disable:next missing_docs
    public var type: TypingSetEventType

    /**
     * Get a set of clientIds that are currently typing.
     */
    public var currentlyTyping: Set<String>

    // @spec CHA-T6d
    /**
     * The set of users currently typing, with associated metadata.
     */
    public var currentTypers: [TypingMember]

    /**
     * Get the details of the operation that modified the typing event.
      */
    public var change: Change

    /// Memberwise initializer to create a `TypingSetEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: TypingSetEventType, currentlyTyping: Set<String>, currentTypers: [TypingMember], change: Change) {
        self.type = type
        self.currentlyTyping = currentlyTyping
        self.currentTypers = currentTypers
        self.change = change
    }

    // swiftlint:disable:next missing_docs
    public struct Change: Sendable {
        // swiftlint:disable:next missing_docs
        public var clientID: String
        // swiftlint:disable:next missing_docs
        public var type: TypingEventType

        // @spec CHA-T13a1
        /**
         * The user claim attached to this typing event by the server.
         *
         * Set automatically by the Ably server when a JWT contains a matching
         * `ably.room.<roomName>` claim. This is a read-only, server-provided value.
         *
         * The `userClaim` must persist across heartbeat events and inactivity timeouts
         * for a given `clientId`.
         */
        public var userClaim: String?

        /// Memberwise initializer to create a `Change`.
        ///
        /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
        public init(clientID: String, type: TypingEventType, userClaim: String? = nil) {
            self.clientID = clientID
            self.type = type
            self.userClaim = userClaim
        }
    }
}
