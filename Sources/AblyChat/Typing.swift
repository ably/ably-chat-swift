import Ably

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
     * Subscribes to typing events from users in the chat room.
     *
     * Receives updates whenever a user starts or stops typing, providing real-time
     * feedback about who is currently composing messages. The subscription emits
     * events containing the current set of typing users and details about what changed.
     *
     * - Note: The room must be attached to receive typing events.
     *
     * - Parameters:
     *   - callback: Callback invoked when the typing state changes
     *
     * - Returns: Subscription object with an unsubscribe method
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options
     * let room = try await chatClient.rooms.get(named: "team-chat")
     *
     * // Subscribe to typing events
     * let subscription = room.typing.subscribe { event in
     *     let currentlyTyping = event.currentlyTyping
     *
     *     // Display who is currently typing
     *     if currentlyTyping.isEmpty {
     *         hideTypingIndicator()
     *     } else if currentlyTyping.count == 1 {
     *         showTypingIndicator("\(currentlyTyping[0]) is typing...")
     *     } else if currentlyTyping.count == 2 {
     *         showTypingIndicator("\(currentlyTyping[0]) and \(currentlyTyping[1]) are typing...")
     *     } else {
     *         showTypingIndicator("\(currentlyTyping.count) people are typing...")
     *     }
     * }
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     *
     * // Later, unsubscribe when done
     * subscription.unsubscribe()
     * ```
     */
    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (TypingSetEvent) -> Void) -> Subscription

    /**
     * Gets the current set of users who are typing.
     *
     * Returns a Set containing the client IDs of all users currently typing in the room.
     * This provides a snapshot of the typing state at the time of the call.
     *
     * - Returns: Set of client IDs currently typing
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options
     * let room = try await chatClient.rooms.get(named: "support-chat")
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     *
     * // Fetch the current cached set of typing users
     * let typingUsers = room.typing.current
     *
     * print("\(typingUsers.count) users are typing")
     *
     * if typingUsers.contains("agent-001") {
     *     print("Support agent is typing a response...")
     * }
     * ```
     */
    var current: Set<String> { get }

    /**
     * Sends a typing started event to notify other users that the current user is typing.
     *
     * Events are throttled according to the `heartbeatThrottleMs` room option to prevent
     * excessive network traffic. If called within the throttle interval, the operation
     * becomes a no-op. Multiple rapid calls are serialized to maintain consistency.
     *
     * - Note:
     *   - The connection must be in the `connected` state.
     *   - Calls to `keystroke()` and `stop()` are serialized and resolve in order.
     *   - The most recent operation always determines the final typing state.
     *   - The room must be attached to send typing events.
     *
     * - Throws: ``ErrorInfo`` if the operation fails to send the event
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options and attach to it
     * let room = try await chatClient.rooms.get(named: "project-discussion", options: RoomOptions())
     * try await room.attach()
     *
     * do {
     *     try await room.typing.keystroke()
     * } catch {
     *     print("Typing indicator error: \(error)")
     * }
     * ```
     */
    func keystroke() async throws(ErrorInfo)

    /**
     * Sends a typing stopped event to notify other users that the current user has stopped typing.
     *
     * If the user is not currently typing, this operation is a no-op. Multiple rapid calls
     * are serialized to maintain consistency, with the most recent operation determining
     * the final state.
     *
     * - Note:
     *   - The connection must be in the `connected` state.
     *   - Calls to `keystroke()` and `stop()` are serialized and resolve in order.
     *   - The room must be attached to send typing events.
     *
     * - Throws: ``ErrorInfo`` if the operation fails to send the event
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options and attach to it
     * let room = try await chatClient.rooms.get(named: "customer-support")
     * try await room.attach()
     *
     * // Start typing in the room
     * try await room.typing.keystroke()
     *
     * // User sends a message, or deletes their draft, etc.
     * try await room.typing.stop()
     * ```
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

    /**
     * Represents the change that resulted in the new set of typers.
     */
    public struct Change: Sendable {
        /**
         * The client ID of the user who stopped/started typing.
         */
        public var clientID: String

        /**
         * Type of the change.
         */
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
