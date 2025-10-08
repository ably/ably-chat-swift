import Ably

/**
 * This interface is used to interact with messages in a chat room: subscribing
 * to new messages, fetching history, or sending messages.
 *
 * Get an instance via ``Room/messages``.
 */
@MainActor
public protocol Messages: AnyObject, Sendable {
    // swiftlint:disable:next missing_docs
    associatedtype Reactions: MessageReactions
    // swiftlint:disable:next missing_docs
    associatedtype SubscribeResponse: MessageSubscriptionResponse
    // swiftlint:disable:next missing_docs
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
     *   - options: Options for the query.
     *
     * - Returns: A paginated result object that can be used to fetch more messages if available.
     */
    func history(withOptions options: QueryOptions) async throws(ARTErrorInfo) -> HistoryResult

    /**
     * Send a message in the chat room.
     *
     * This method uses the Ably Chat API endpoint for sending messages.
     *
     * - Parameters:
     *   - params: An object containing `text`, `headers` and `metadata` for the message.
     *
     * - Returns: The published message, with the action of the message set as `.create`.
     *
     * - Note: It is possible to receive your own message via the messages subscription before this method returns.
     */
    func send(withParams params: SendMessageParams) async throws(ARTErrorInfo) -> Message

    /**
     * Updates a message in the chat room.
     *
     * This method uses the Ably Chat API endpoint for updating messages.
     *
     * - Parameters:
     *   - newMessage: A copy of the `Message` object with the intended edits applied. Use the provided `copy` method on the existing message.
     *   - description: Optional description of the update action.
     *   - metadata: Optional metadata of the update action. (The metadata of the message itself still resides within the newMessage object above).
     *
     * - Returns: The updated message, with the `action` of the message set as `.update`.
     *
     * - Note: It is possible to receive your own message via the messages subscription before this method returns.
     */
    func update(newMessage: Message, description: String?, metadata: OperationMetadata?) async throws(ARTErrorInfo) -> Message

    /**
     * Deletes a message in the chat room.
     *
     * This method uses the Ably Chat API endpoint for deleting messages.
     *
     * - Parameters:
     *   - message: The message you wish to delete.
     *   - params: Contains an optional description and metadata of the delete action.
     *
     * - Returns: The deleted message, with the action of the message set as `.delete`.
     *
     * - Note: It is possible to receive your own message via the messages subscription before this method returns.
     */
    func delete(message: Message, params: DeleteMessageParams) async throws(ARTErrorInfo) -> Message

    /**
     * Add, delete, and subscribe to message reactions.
     */
    var reactions: Reactions { get }
}

// swiftlint:disable:next missing_docs
public extension Messages {
    /**
     * Subscribe to new messages in this chat room.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription ``MessageSubscription`` that can be used to iterate through new messages.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> MessageSubscriptionAsyncSequence<SubscribeResponse.HistoryResult> {
        var emitEvent: ((ChatMessageEvent) -> Void)?
        let subscription = subscribe { event in
            emitEvent?(event)
        }

        let subscriptionAsyncSequence = MessageSubscriptionAsyncSequence(
            bufferingPolicy: bufferingPolicy,
            getPreviousMessages: subscription.historyBeforeSubscribe,
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
    func subscribe() -> MessageSubscriptionAsyncSequence<SubscribeResponse.HistoryResult> {
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

    // swiftlint:disable:next missing_docs
    public init(text: String, metadata: MessageMetadata? = nil, headers: MessageHeaders? = nil) {
        self.text = text
        self.metadata = metadata
        self.headers = headers
    }
}

/**
 * Params for updating a text message.  All fields are updated and, if omitted, they are set to empty.
 */
public struct UpdateMessageParams: Sendable {
    /**
     * The params to update including the text of the message.
     */
    public var message: SendMessageParams

    /**
     * Optional description of the update action.
     */
    public var description: String?

    /**
     * Optional metadata of the update action.
     *
     * The metadata is a map of extra information that can be attached to the update action.
     * It is not used by Ably and is sent as part of the realtime
     * message payload. Example use cases are setting custom styling like
     * background or text colors or fonts, adding links to external images,
     * emojis, etc.
     *
     * Do not use metadata for authoritative information. There is no server-side
     * validation. When reading the metadata treat it like user input.
     *
     */
    public var metadata: OperationMetadata?

    // swiftlint:disable:next missing_docs
    public init(message: SendMessageParams, description: String? = nil, metadata: OperationMetadata? = nil) {
        self.message = message
        self.description = description
        self.metadata = metadata
    }
}

/**
 * Params for deleting a message.
 */
public struct DeleteMessageParams: Sendable {
    // swiftlint:disable:next missing_docs
    public var description: String?

    // swiftlint:disable:next missing_docs
    public var metadata: OperationMetadata?

    // swiftlint:disable:next missing_docs
    public init(description: String? = nil, metadata: OperationMetadata? = nil) {
        self.description = description
        self.metadata = metadata
    }
}

/**
 * Options for querying messages in a chat room.
 */
public struct QueryOptions: Sendable {
    // swiftlint:disable:next missing_docs
    public enum OrderBy: Sendable {
        // swiftlint:disable:next missing_docs
        case oldestFirst
        // swiftlint:disable:next missing_docs
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

    // swiftlint:disable:next missing_docs
    public init(start: Date? = nil, end: Date? = nil, limit: Int? = nil, orderBy: QueryOptions.OrderBy? = nil) {
        self.start = start
        self.end = end
        self.limit = limit
        self.orderBy = orderBy
    }
}

internal extension QueryOptions {
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
    // swiftlint:disable:next missing_docs
    case created
    // swiftlint:disable:next missing_docs
    case updated
    // swiftlint:disable:next missing_docs
    case deleted
}

/// Event emitted by message subscriptions, containing the type and the message.
public struct ChatMessageEvent: Sendable {
    // swiftlint:disable:next missing_docs
    public var type: ChatMessageEventType
    // swiftlint:disable:next missing_docs
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
        case .create:
            type = .created
        case .update:
            type = .updated
        case .delete:
            type = .deleted
        }
        self.message = message
    }
}

/// A non-throwing `AsyncSequence` whose element is ``ChatMessageEvent``. The Chat SDK uses this type as the return value of the `AsyncSequence` convenience variants of the ``Messages`` methods that allow you to find out about received chat messages.
///
/// You should only iterate over a given `MessageSubscriptionAsyncSequence` once; the results of iterating more than once are undefined.
public final class MessageSubscriptionAsyncSequence<HistoryResult: PaginatedResult<Message>>: Sendable, AsyncSequence {
    // swiftlint:disable:next missing_docs
    public typealias Element = ChatMessageEvent

    private let subscription: SubscriptionAsyncSequence<Element>

    // can be set by either initialiser
    private let getPreviousMessages: @Sendable (QueryOptions) async throws(ARTErrorInfo) -> HistoryResult

    // used internally
    internal init(
        bufferingPolicy: BufferingPolicy,
        getPreviousMessages: @escaping @Sendable (QueryOptions) async throws(ARTErrorInfo) -> HistoryResult,
    ) {
        subscription = .init(bufferingPolicy: bufferingPolicy)
        self.getPreviousMessages = getPreviousMessages
    }

    // used for testing
    // swiftlint:disable:next missing_docs
    public init<Underlying: AsyncSequence & Sendable>(mockAsyncSequence: Underlying, mockGetPreviousMessages: @escaping @Sendable (QueryOptions) async throws(ARTErrorInfo) -> HistoryResult) where Underlying.Element == Element {
        subscription = .init(mockAsyncSequence: mockAsyncSequence)
        getPreviousMessages = mockGetPreviousMessages
    }

    internal func emit(_ element: Element) {
        subscription.emit(element)
    }

    @MainActor
    internal func addTerminationHandler(_ onTermination: @escaping (@Sendable () -> Void)) {
        subscription.addTerminationHandler(onTermination)
    }

    // swiftlint:disable:next missing_docs
    public func getPreviousMessages(withParams params: QueryOptions) async throws(ARTErrorInfo) -> HistoryResult {
        try await getPreviousMessages(params)
    }

    // swiftlint:disable:next missing_docs
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var subscriptionIterator: SubscriptionAsyncSequence<Element>.AsyncIterator

        fileprivate init(subscriptionIterator: SubscriptionAsyncSequence<Element>.AsyncIterator) {
            self.subscriptionIterator = subscriptionIterator
        }

        // swiftlint:disable:next missing_docs
        public mutating func next() async -> Element? {
            await subscriptionIterator.next()
        }
    }

    // swiftlint:disable:next missing_docs
    public func makeAsyncIterator() -> AsyncIterator {
        .init(subscriptionIterator: subscription.makeAsyncIterator())
    }
}
