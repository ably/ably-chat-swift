import Ably

/**
 * This interface is used to interact with messages in a chat room: subscribing
 * to new messages, fetching history, or sending messages.
 *
 * Get an instance via ``Room/messages``.
 */
@MainActor
public protocol Messages: AnyObject, Sendable {
    /// The type of the message reactions handler.
    associatedtype Reactions: MessageReactions
    /// The type of the subscription response.
    associatedtype SubscribeResponse: MessageSubscriptionResponse
    /// The type of the paginated history result.
    associatedtype HistoryResult: PaginatedResult<Message>

    /**
     * Subscribe to new messages in this chat room.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing room `ChatMessageEvent` events.
     *
     * - Returns: A subscription that can be used to unsubscribe from `ChatMessageEvent` events.
     */
    func subscribe(_ callback: @escaping @MainActor (ChatMessageEvent) -> Void) -> SubscribeResponse

    /**
     * Get messages that have been previously sent to the chat room, based on the provided options.
     *
     * - Parameters:
     *   - params: Parameters for the query.
     *
     * - Returns: A paginated result object that can be used to fetch more messages if available.
     */
    func history(withParams params: HistoryParams) async throws(ErrorInfo) -> HistoryResult

    /**
     * Send a message in the chat room.
     *
     * This method uses the Ably Chat API endpoint for sending messages.
     *
     * - Parameters:
     *   - params: An object containing `text`, `headers` and `metadata` for the message.
     *
     * - Returns: The published message, with the action of the message set as `.messageCreate`.
     *
     * - Note: It is possible to receive your own message via the messages subscription before this method returns.
     */
    func send(withParams params: SendMessageParams) async throws(ErrorInfo) -> Message

    /**
     * Update a message in the chat room.
     *
     * Note that this method may return before OR after the updated message is
     * received from the realtime channel. This means you may see the update that
     * was just sent in a callback to `subscribe` before this method returns.
     *
     * NOTE: The Message instance returned by this method is the state of the message as a result of the update operation.
     * If you have a subscription to message events via `subscribe`, you should discard the message instance returned by
     * this method and use the event payloads from the subscription instead.
     *
     * This method uses PUT-like semantics: if headers and metadata are omitted from the updateParams, then
     * the existing headers and metadata are replaced with the empty objects.
     *
     * - Parameters:
     *   - serial: The serial of the message to update.
     *   - updateParams: The parameters for updating the message.
     *   - details: Optional details to record about the update action.
     *
     * - Returns: The updated message.
     */
    func update(withSerial serial: String, params: UpdateMessageParams, details: OperationDetails?) async throws(ErrorInfo) -> Message

    /**
     * Delete a message in the chat room.
     *
     * This method uses the Ably Chat API REST endpoint for deleting messages.
     * It performs a `soft` delete, meaning the message is marked as deleted.
     *
     * Note that this method may return before OR after the message is deleted
     * from the realtime channel. This means you may see the message that was just
     * deleted in a callback to `subscribe` before this method returns.
     *
     * NOTE: The Message instance returned by this method is the state of the message as a result of the delete operation.
     * If you have a subscription to message events via `subscribe`, you should discard the message instance returned by
     * this method and use the event payloads from the subscription instead.
     *
     * Should you wish to restore a deleted message, and providing you have the appropriate permissions,
     * you can simply send an update to the original message.
     * Note: This is subject to change in future versions, whereby a new permissions model will be introduced
     * and a deleted message may not be restorable in this way.
     *
     * - Parameters:
     *   - serial: The serial of the message to delete.
     *   - details: Optional details to record about the delete action.
     *
     * - Returns: The deleted message.
     */
    func delete(withSerial serial: String, details: OperationDetails?) async throws(ErrorInfo) -> Message

    /**
     * Get a message by its serial.
     *
     * - Parameters:
     *   - serial: The serial of the message to get.
     *
     * - Returns: The message with the specified serial.
     */
    func get(withSerial serial: String) async throws(ErrorInfo) -> Message

    /**
     * Add, delete, and subscribe to message reactions.
     */
    var reactions: Reactions { get }
}

/// Extension providing `AsyncSequence`-based convenience methods for subscribing to messages.
public extension Messages {
    /**
     * Subscribe to new messages in this chat room.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription ``MessageSubscription`` that can be used to iterate through new messages.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> MessageSubscriptionResponseAsyncSequence<SubscribeResponse.HistoryResult> {
        var emitEvent: ((ChatMessageEvent) -> Void)?
        let subscription = subscribe { event in
            emitEvent?(event)
        }

        let subscriptionAsyncSequence = MessageSubscriptionResponseAsyncSequence(
            bufferingPolicy: bufferingPolicy,
            historyBeforeSubscribe: subscription.historyBeforeSubscribe,
        )
        emitEvent = { [weak subscriptionAsyncSequence] event in
            subscriptionAsyncSequence?.emit(event)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe() -> MessageSubscriptionResponseAsyncSequence<SubscribeResponse.HistoryResult> {
        subscribe(bufferingPolicy: .unbounded)
    }
}

/**
 * Params for sending a text message. Only `text` is mandatory.
 */
public struct SendMessageParams: Sendable {
    /**
     * The text of the message.
     */
    public var text: String

    /**
     * Optional metadata of the message.
     *
     * The metadata is a map of extra information that can be attached to chat
     * messages. It is not used by Ably and is sent as part of the realtime
     * message payload. Example use cases are setting custom styling like
     * background or text colors or fonts, adding links to external images,
     * emojis, etc.
     *
     * Do not use metadata for authoritative information. There is no server-side
     * validation. When reading the metadata treat it like user input.
     *
     */
    public var metadata: MessageMetadata?

    /**
     * Optional headers of the message.
     *
     * The headers are a flat key-value map and are sent as part of the realtime
     * message's extras inside the `headers` property. They can serve similar
     * purposes as the metadata but they are read by Ably and can be used for
     * features such as
     * [subscription filters](https://faqs.ably.com/subscription-filters).
     *
     * Do not use the headers for authoritative information. There is no
     * server-side validation. When reading the headers treat them like user
     * input.
     *
     */
    public var headers: MessageHeaders?

    /**
     * Creates a new instance of ``SendMessageParams``.
     *
     * - Parameters:
     *   - text: The text of the message.
     *   - metadata: Optional metadata of the message.
     *   - headers: Optional headers of the message.
     */
    public init(text: String, metadata: MessageMetadata? = nil, headers: MessageHeaders? = nil) {
        self.text = text
        self.metadata = metadata
        self.headers = headers
    }
}

/// Parameters for updating a message.
public struct UpdateMessageParams: Sendable {
    /// The new text of the message.
    public var text: String

    /// Optional metadata of the message.
    public var metadata: MessageMetadata?

    /// Optional headers of the message.
    public var headers: MessageHeaders?

    /// Creates an instance with the given property values.
    public init(text: String, metadata: MessageMetadata? = nil, headers: MessageHeaders? = nil) {
        self.text = text
        self.metadata = metadata
        self.headers = headers
    }
}

/// The parameters supplied to a message action like delete or update.
public struct OperationDetails: Sendable {
    /// Optional description for the message action.
    public var description: String?

    /// Optional metadata that will be added to the action. Defaults to empty.
    public var metadata: MessageOperationMetadata?

    /**
     * Creates a new instance of ``OperationDetails``.
     *
     * - Parameters:
     *   - description: Optional description for the message action.
     *   - metadata: Optional metadata that will be added to the action.
     */
    public init(description: String? = nil, metadata: MessageOperationMetadata? = nil) {
        self.description = description
        self.metadata = metadata
    }
}

/**
 * Options for querying messages in a chat room.
 */
public struct HistoryParams: Sendable {
    /**
     * The order in which results should be returned when performing a paginated query.
     */
    public enum OrderBy: Sendable {
        /// Return results in ascending order (oldest first).
        case oldestFirst
        /// Return results in descending order (newest first).
        case newestFirst
    }

    /**
     * The start of the time window to query from. If provided, the response will include
     * messages with timestamps equal to or greater than this value.
     *
     * Defaults to the beginning of time.
     */
    public var start: Date?

    /**
     * The end of the time window to query from. If provided, the response will include
     * messages with timestamps less than this value.
     *
     * Defaults to the current time.
     */
    public var end: Date?

    /**
     * The maximum number of messages to return in the response.
     *
     * Defaults to 100.
     */
    public var limit: Int?

    /**
     * The direction to query messages in.
     * If ``OrderBy/oldestFirst``, the response will include messages from the start of the time window to the end.
     * If ``OrderBy/newestFirst``, the response will include messages from the end of the time window to the start.
     * If not provided, the default is ``OrderBy/newestFirst`.
     */
    public var orderBy: OrderBy?

    // (CHA-M5g) The subscribers subscription point must be additionally specified (internally, by us) in the fromSerial query parameter.
    internal var fromSerial: String?

    /**
     * Creates a new instance of ``HistoryParams``.
     *
     * - Parameters:
     *   - start: The start of the time window to query from.
     *   - end: The end of the time window to query from.
     *   - limit: The maximum number of messages to return.
     *   - orderBy: The direction to query messages in.
     */
    public init(start: Date? = nil, end: Date? = nil, limit: Int? = nil, orderBy: HistoryParams.OrderBy? = nil) {
        self.start = start
        self.end = end
        self.limit = limit
        self.orderBy = orderBy
    }
}

/**
 * Options for querying messages that were sent to a chat room before a listener was subscribed.
 *
 * This is the same as ``HistoryParams`` but without the `orderBy` property as the order is always newest-first.
 */
public struct HistoryBeforeSubscribeParams: Sendable {
    /**
     * The start of the time window to query from. If provided, the response will include
     * messages with timestamps equal to or greater than this value.
     *
     * Defaults to the beginning of time.
     */
    public var start: Date?

    /**
     * The end of the time window to query from. If provided, the response will include
     * messages with timestamps less than this value.
     *
     * Defaults to the current time.
     */
    public var end: Date?

    /**
     * The maximum number of messages to return in the response.
     *
     * Defaults to 100.
     */
    public var limit: Int?

    /**
     * Creates a new instance of ``HistoryBeforeSubscribeParams``.
     *
     * - Parameters:
     *   - start: The start of the time window to query from.
     *   - end: The end of the time window to query from.
     *   - limit: The maximum number of messages to return.
     */
    public init(start: Date? = nil, end: Date? = nil, limit: Int? = nil) {
        self.start = start
        self.end = end
        self.limit = limit
    }

    /**
     * Converts this to a ``HistoryParams`` with orderBy set to newestFirst, per CHA-M5f.
     */
    internal func toHistoryParams() -> HistoryParams {
        HistoryParams(start: start, end: end, limit: limit, orderBy: .newestFirst)
    }
}

internal extension HistoryParams {
    // Same as `ARTDataQuery.asQueryItems` from ably-cocoa.
    func asQueryItems() -> [String: String] {
        var dict: [String: String] = [:]
        if let start {
            dict["start"] = "\(dateToMilliseconds(start))"
        }

        if let end {
            dict["end"] = "\(dateToMilliseconds(end))"
        }

        if let limit {
            dict["limit"] = "\(limit)"
        }

        if let orderBy {
            switch orderBy {
            case .oldestFirst:
                dict["direction"] = "forwards"
            case .newestFirst:
                dict["direction"] = "backwards"
            }
        }

        if let fromSerial {
            dict["fromSerial"] = fromSerial
        }

        return dict
    }
}

/// Event type for chat message subscription.
public enum ChatMessageEventType: Sendable {
    /// Fires when a new chat message is received.
    case created
    /// Fires when a chat message is updated.
    case updated
    /// Fires when a chat message is deleted.
    case deleted
}

/// Payload for a message event.
public struct ChatMessageEvent: Sendable {
    /// The type of the message event.
    public var type: ChatMessageEventType
    /// The message that was received.
    public var message: Message

    /// Memberwise initializer to create a `ChatMessageEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: ChatMessageEventType, message: Message) {
        self.type = type
        self.message = message
    }

    internal init(message: Message) {
        switch message.action {
        case .messageCreate:
            type = .created
        case .messageUpdate:
            type = .updated
        case .messageDelete:
            type = .deleted
        }
        self.message = message
    }
}

/// A non-throwing `AsyncSequence` whose element is ``ChatMessageEvent``. The Chat SDK uses this type as the return value of the `AsyncSequence` convenience variants of the ``Messages`` methods that allow you to find out about received chat messages.
///
/// You should only iterate over a given `MessageSubscriptionResponseAsyncSequence` once; the results of iterating more than once are undefined.
public final class MessageSubscriptionResponseAsyncSequence<HistoryResult: PaginatedResult<Message>>: Sendable, AsyncSequence {
    /// The type of element returned by this async sequence.
    public typealias Element = ChatMessageEvent

    private let subscription: SubscriptionAsyncSequence<Element>

    // can be set by either initialiser
    private let historyBeforeSubscribe: @Sendable (HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> HistoryResult

    // used internally
    internal init(
        bufferingPolicy: BufferingPolicy,
        historyBeforeSubscribe: @escaping @Sendable (HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> HistoryResult,
    ) {
        subscription = .init(bufferingPolicy: bufferingPolicy)
        self.historyBeforeSubscribe = historyBeforeSubscribe
    }

    /// Creates a mock instance for testing purposes.
    ///
    /// This initializer is provided for creating mock implementations in tests.
    public init<Underlying: AsyncSequence & Sendable>(mockAsyncSequence: Underlying, mockHistoryBeforeSubscribe: @escaping @Sendable (HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> HistoryResult) where Underlying.Element == Element {
        subscription = .init(mockAsyncSequence: mockAsyncSequence)
        historyBeforeSubscribe = mockHistoryBeforeSubscribe
    }

    internal func emit(_ element: Element) {
        subscription.emit(element)
    }

    @MainActor
    internal func addTerminationHandler(_ onTermination: @escaping (@Sendable () -> Void)) {
        subscription.addTerminationHandler(onTermination)
    }

    /// Gets previous messages that were sent to the room before the subscription was created.
    public func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> HistoryResult {
        try await historyBeforeSubscribe(params)
    }

    /// The iterator for this async sequence.
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var subscriptionIterator: SubscriptionAsyncSequence<Element>.AsyncIterator

        fileprivate init(subscriptionIterator: SubscriptionAsyncSequence<Element>.AsyncIterator) {
            self.subscriptionIterator = subscriptionIterator
        }

        /// Asynchronously advances to the next element and returns it, or `nil` if no next element exists.
        public mutating func next() async -> Element? {
            await subscriptionIterator.next()
        }
    }

    /// Creates an async iterator for this sequence.
    public func makeAsyncIterator() -> AsyncIterator {
        .init(subscriptionIterator: subscription.makeAsyncIterator())
    }
}
