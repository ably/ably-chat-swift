import Ably

/**
 * Add, delete, and subscribe to message reactions.
 *
 * Get an instance via ``Room/messages/reactions``.
 */
@MainActor
public protocol MessageReactions: AnyObject, Sendable {
    associatedtype Subscription: AblyChat.Subscription

    /**
     * Add a message reaction.
     *
     * - Parameters:
     *   - messageSerial: A serial of the message to react to.
     *   - params: Describe the reaction to add.
     *
     * - Note: It is possible to receive your own reaction via the reactions subscription before this method returns.
     */
    func send(to messageSerial: String, params: SendMessageReactionParams) async throws(ARTErrorInfo)

    /**
     * Delete a message reaction.
     *
     * - Parameters:
     *   - messageSerial: A serial of the message to remove the reaction from.
     *   - params: The type of reaction annotation and the specific reaction to remove. The reaction to remove is required for all types except ``MessageReactionType/unique``.
     */
    func delete(from messageSerial: String, params: DeleteMessageReactionParams) async throws(ARTErrorInfo)

    /**
     * Subscribe to message reaction summaries. Use this to keep message reaction counts up to date efficiently in the UI.
     *
     * - Parameters:
     *   - callback: A callback to call when a message reaction summary is received.
     *
     * - Returns: A subscription handle object that should be used to unsubscribe.
     */
    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (MessageReactionSummaryEvent) -> Void) -> Subscription

    /**
     * Subscribe to individual reaction events.
     *
     * - Parameters:
     *   - callback: A callback to call when a message reaction event is received.
     *
     * - Returns: A subscription handle object that should be used to unsubscribe.
     *
     * - Note: If you only need to keep track of reaction counts and clients, use ``subscribe(_:)`` instead.
     */
    @discardableResult
    func subscribeRaw(_ callback: @escaping @MainActor (MessageReactionRawEvent) -> Void) -> Subscription
}

/// `AsyncSequence` variant of receiving message reactions events.
public extension MessageReactions {
    /**
     * Subscribes a given listener to message reactions summary events.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``MessageReactionSummaryEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<MessageReactionSummaryEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<MessageReactionSummaryEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribe { summaryEvent in
            subscriptionAsyncSequence.emit(summaryEvent)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe() -> SubscriptionAsyncSequence<MessageReactionSummaryEvent> {
        subscribe(bufferingPolicy: .unbounded)
    }

    /**
     * Subscribes a given listener to message reactions events.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``MessageReactionRawEvent`` events.
     */
    func subscribeRaw(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<MessageReactionRawEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<MessageReactionRawEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribeRaw { reaction in
            subscriptionAsyncSequence.emit(reaction)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribeRaw() -> SubscriptionAsyncSequence<MessageReactionRawEvent> {
        subscribeRaw(bufferingPolicy: .unbounded)
    }
}

/**
 * Parameters for adding a message reaction.
 */
public struct SendMessageReactionParams: Sendable {
    /**
     * The type of reaction, must be one of ``MessageReactionType``.
     * If not set, the default type will be used which is configured in the ``MessagesOptions/defaultMessageReactionType`` of the room.
     */
    public var type: MessageReactionType?

    /**
     * The reaction to add; ie. the emoji.
     */
    public var name: String

    /**
     * The count of the reaction for type ``MessageReactionType/multiple``.
     * Defaults to 1 if not set. Not supported for other reaction types.
     */
    public var count: Int?

    public init(name: String, type: MessageReactionType? = nil, count: Int? = nil) {
        self.name = name
        self.type = type
        self.count = count
    }
}

/**
 * Parameters for deleting a message reaction.
 */
public struct DeleteMessageReactionParams: Sendable {
    /**
     * The type of reaction, must be one of ``MessageReactionType``.
     */
    public var type: MessageReactionType?

    /**
     * The reaction to remove, ie. the emoji name. Required for all reaction types
     * except ``MessageReactionType/unique``.
     */
    public var name: String?

    public init(name: String? = nil, type: MessageReactionType? = nil) {
        self.name = name
        self.type = type
    }
}
