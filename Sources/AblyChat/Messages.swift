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
     * Subscribe to chat message events in this room.
     *
     * This method allows you to listen for chat message events and provides access to
     * historical messages that occurred before the subscription was established.
     *
     * - Note: The room must be attached for the listener to receive new message events.
     *
     * - Parameters:
     *   - callback: A callback function that will be invoked when chat message events occur.
     *
     * - Returns: A ``MessageSubscriptionResponse`` object that provides:
     *   - `unsubscribe()`: Method to stop listening for message events
     *   - `historyBeforeSubscribe()`: Method to retrieve messages sent before subscription
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room and subscribe to messages
     * let room = try await chatClient.rooms.get("general-chat")
     *
     * let subscription = room.messages.subscribe { event in
     *     print("Message \(event.type): \(event.message.text)")
     *     print("From: \(event.message.clientID)")
     *     print("At: \(event.message.timestamp)")
     *     // Handle different event types
     * }
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     *
     * // Later, unsubscribe when done
     * subscription.unsubscribe()
     * ```
     */
    func subscribe(_ callback: @escaping @MainActor (ChatMessageEvent) -> Void) -> SubscribeResponse

    /**
     * Get messages that have been previously sent to the chat room.
     *
     * This method retrieves historical messages based on the provided query options,
     * allowing you to paginate through message history, filter by time ranges,
     * and control the order of results.
     *
     * - Note: This method uses the Ably Chat REST API and so does not require the room
     * to be attached to be called.
     *
     * - Parameters:
     *   - params: Query parameters to filter and control the message retrieval
     *
     * - Returns: A ``PaginatedResult`` containing an array of ``Message`` objects
     *   and methods for pagination control
     *
     * - Throws: ``ErrorInfo`` with code 40003 (invalid argument) when the query fails due to invalid parameters
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get("project-updates")
     *
     * // Retrieve message history with pagination
     * do {
     *     var result = try await room.messages.history(withParams: HistoryParams(
     *         limit: 50,
     *         orderBy: .newestFirst
     *     ))
     *
     *     print("Retrieved \(result.items.count) messages")
     *     for message in result.items {
     *         print("\(message.clientID): \(message.text)")
     *     }
     *
     *     // Paginate through additional pages if available
     *     while result.hasNext {
     *         if let nextPage = try await result.next() {
     *             print("Next page has \(nextPage.items.count) messages")
     *             for message in nextPage.items {
     *                 print("\(message.clientID): \(message.text)")
     *             }
     *             result = nextPage
     *         } else {
     *             break // No more pages
     *         }
     *     }
     *     print("All message history retrieved")
     * } catch {
     *     print("Failed to retrieve message history: \(error)")
     * }
     * ```
     */
    func history(withParams params: HistoryParams) async throws(ErrorInfo) -> HistoryResult

    /**
     * Send a message to the chat room.
     *
     * This method publishes a new message to the chat room using the Ably Chat API.
     * The message will be delivered to all subscribers in real-time.
     *
     * - Important: The function can return before OR after the message is received
     * from the realtime channel. This means subscribers may see the message before
     * the send operation completes.
     *
     * - Note: This method uses the Ably Chat REST API and so does not require the room
     * to be attached to be called.
     *
     * - Parameters:
     *   - params: Message parameters containing the text and optional metadata/headers
     *
     * - Returns: The sent ``Message`` object
     *
     * - Throws: ``ErrorInfo`` when the message fails to send due to network issues, authentication problems, or rate limiting
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get("general-chat")
     *
     * // Send a message with metadata and headers
     * do {
     *     let message = try await room.messages.send(withParams: .init(
     *         text: "Hello, everyone! 👋",
     *         metadata: ["priority": "high", "category": "greeting"],
     *         headers: ["content-type": "text", "language": "en"]
     *     ))
     *
     *     print("Message sent successfully: \(message.serial)")
     * } catch {
     *     print("Failed to send message: \(error)")
     * }
     * ```
     */
    func send(withParams params: SendMessageParams) async throws(ErrorInfo) -> Message

    /**
     * Update a message in the chat room.
     *
     * This method modifies an existing message's content, metadata, or headers.
     * The update creates a new version of the message while preserving the original
     * serial identifier. Subscribers will receive an update event in real-time.
     *
     * - Important: The function can return before OR after the update event is received
     * from the realtime channel. Subscribers may see the update event before this method
     * completes.
     *
     * - Note:
     *   - This method uses PUT-like semantics. If metadata or headers are omitted
     *     from updateParams, they will be replaced with empty objects, not merged with existing values.
     *   - The returned Message instance represents the state after the update. If you
     *     have active subscriptions, use the event payloads from those subscriptions instead
     *     of the returned instance for consistency.
     *   - This method uses the Ably Chat REST API and so does not require the room
     *     to be attached to be called.
     *
     * - Parameters:
     *   - serial: The unique identifier of the message to update.
     *   - params: The new message content and properties.
     *   - details: Optional details to record about the update action.
     *
     * - Returns: The updated ``Message`` object with `isUpdated` set to true and update metadata populated
     *
     * - Throws: ``ErrorInfo`` when the message is not found, user lacks permissions, or network/server errors occur
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get("team-updates")
     *
     * // Update a message with corrected text and tracking
     * let messageSerial = "01726585978590-001@abcdefghij:001"
     *
     * do {
     *     let updatedMessage = try await room.messages.update(
     *         withSerial: messageSerial,
     *         params: .init(
     *             text: "Meeting is scheduled for 3 PM (corrected time)"
     *         ),
     *         details: .init(
     *             description: "Corrected meeting time",
     *             metadata: ["editTimestamp": "\(Date())"]
     *         )
     *     )
     *
     *     print("Updated text: \(updatedMessage.text)")
     * } catch let error where error.code == 40400 {
     *     print("Message not found: \(messageSerial)")
     * } catch let error where error.code == 40300 {
     *     print("Permission denied: Cannot update this message")
     * } catch {
     *     print("Failed to update message: \(error)")
     * }
     * ```
     */
    func update(withSerial serial: String, params: UpdateMessageParams, details: OperationDetails?) async throws(ErrorInfo) -> Message

    /**
     * Delete a message in the chat room.
     *
     * This method performs a "soft delete" on a message, marking it as deleted rather
     * than permanently removing it. The deleted message will still be visible in message
     * history but will be flagged as deleted. Subscribers will receive a deletion event
     * in real-time.
     *
     * - Important: The function can return before OR after the deletion event is received
     * from the realtime channel. Subscribers may see the deletion event before this method
     * completes.
     *
     * - Note:
     *   - The returned Message instance represents the state after deletion. If you
     *     have active subscriptions, use the event payloads from those subscriptions instead
     *     of the returned instance for consistency.
     *   - This method uses the Ably Chat REST API and so does not require the room
     *     to be attached to be called.
     *
     * - Parameters:
     *   - serial: The unique identifier of the message to delete.
     *   - details: Optional details to record about the delete action.
     *
     * - Returns: The deleted ``Message`` object with `isDeleted` set to true and deletion metadata populated
     *
     * - Throws: ``ErrorInfo`` when the message is not found, user lacks permissions, or network/server errors occur
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get("public-chat")
     *
     * // Serial of the message to delete
     * let messageSerial = "01726585978590-001@abcdefghij:001"
     *
     * do {
     *     let deletedMessage = try await room.messages.delete(
     *         withSerial: messageSerial,
     *         details: .init(
     *             description: "Inappropriate content removed by moderator",
     *             metadata: [
     *                 "reason": "policy-violation",
     *                 "timestamp": "\(Date())"
     *             ]
     *         )
     *     )
     *
     *     print("Deleted message: \(deletedMessage.text)")
     * } catch let error where error.code == 40400 {
     *     print("Message not found: \(messageSerial)")
     * } catch let error where error.code == 40300 {
     *     print("Permission denied: Cannot delete this message")
     * } catch {
     *     print("Failed to delete message: \(error)")
     * }
     * ```
     */
    func delete(withSerial serial: String, details: OperationDetails?) async throws(ErrorInfo) -> Message

    /**
     * Get a specific message by its unique serial identifier.
     *
     * This method retrieves a single message using its serial, which is a unique
     * identifier assigned to each message when it's created.
     *
     * - Note: This method uses the Ably Chat REST API and so does not require the room
     * to be attached to be called.
     *
     * - Parameters:
     *   - serial: The unique serial identifier of the message to retrieve.
     *
     * - Returns: The ``Message`` object
     *
     * - Throws: ``ErrorInfo`` when the message is not found or network/server errors occur
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get("customer-support")
     *
     * // Get a specific message by its serial
     * let messageSerial = "01726585978590-001@abcdefghij:001"
     *
     * do {
     *     let message = try await room.messages.get(withSerial: messageSerial)
     *
     *     print("Serial: \(message.serial)")
     *     print("From: \(message.clientID)")
     *     print("Text: \(message.text)")
     *
     * } catch let error where error.statusCode == 404 {
     *     print("Message not found: \(messageSerial)")
     * } catch {
     *     print("Failed to retrieve message: \(error)")
     * }
     * ```
     */
    func get(withSerial serial: String) async throws(ErrorInfo) -> Message

    /**
     * Send, delete, and subscribe to message reactions.
     *
     * This property provides access to the message reactions functionality, allowing you to
     * add reactions to specific messages, remove reactions, and subscribe to reaction events
     * in real-time.
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

    // swiftlint:disable:next missing_docs
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

    // swiftlint:disable:next missing_docs
    public init(description: String? = nil, metadata: MessageOperationMetadata? = nil) {
        self.description = description
        self.metadata = metadata
    }
}

/**
 * Parameters for querying messages in a chat room.
 */
public struct HistoryParams: Sendable {
    /**
     * The order in which results should be returned when performing a paginated query (e.g. message history).
     */
    public enum OrderBy: Sendable {
        /**
         * Return results in ascending order (oldest first).
         */
        case oldestFirst
        /**
         * Return results in descending order (newest first).
         */
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

    // swiftlint:disable:next missing_docs
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

/**
 * All chat message events.
 */
public enum ChatMessageEventType: Sendable {
    /**
     * Fires when a new chat message is received.
     */
    case created

    /**
     * Fires when a chat message is updated.
     */
    case updated

    /**
     * Fires when a chat message is deleted.
     */
    case deleted
}

/**
 * Payload for a message event.
 */
public struct ChatMessageEvent: Sendable {
    /**
     * The type of the message event.
     */
    public var type: ChatMessageEventType

    /**
     * The message that was received.
     */
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
    // swiftlint:disable:next missing_docs
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

    // used for testing
    // swiftlint:disable:next missing_docs
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

    // swiftlint:disable:next missing_docs
    public func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> HistoryResult {
        try await historyBeforeSubscribe(params)
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
