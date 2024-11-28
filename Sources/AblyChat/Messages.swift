import Ably

/**
 * This interface is used to interact with messages in a chat room: subscribing
 * to new messages, fetching history, or sending messages.
 *
 * Get an instance via {@link Room.messages}.
 */
public protocol Messages: AnyObject, Sendable, EmitsDiscontinuities {
    /**
     * Subscribe to new messages in this chat room.
     * @param listener callback that will be called
     * @returns A response object that allows you to control the subscription.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) async throws -> MessageSubscription

    /**
     * Get messages that have been previously sent to the chat room, based on the provided options.
     *
     * @param options Options for the query.
     * @returns A promise that resolves with the paginated result of messages. This paginated result can
     * be used to fetch more messages if available.
     */
    func get(options: QueryOptions) async throws -> any PaginatedResult<Message>

    /**
     * Send a message in the chat room.
     *
     * This method uses the Ably Chat API endpoint for sending messages.
     *
     * Note that the Promise may resolve before OR after the message is received
     * from the realtime channel. This means you may see the message that was just
     * sent in a callback to `subscribe` before the returned promise resolves.
     *
     * @param params an object containing {text, headers, metadata} for the message
     * to be sent. Text is required, metadata and headers are optional.
     * @returns A promise that resolves when the message was published.
     */
    func send(params: SendMessageParams) async throws -> Message

    /**
     * Get the underlying Ably realtime channel used for the messages in this chat room.
     *
     * @returns The realtime channel.
     */
    var channel: RealtimeChannelProtocol { get }
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

    public init(text: String, metadata: MessageMetadata? = nil, headers: MessageHeaders? = nil) {
        self.text = text
        self.metadata = metadata
        self.headers = headers
    }
}

/**
 * Options for querying messages in a chat room.
 */
public struct QueryOptions: Sendable {
    public enum ResultOrder: Sendable {
        case oldestFirst
        case newestFirst
    }

    /**
     * The start of the time window to query from. If provided, the response will include
     * messages with timestamps equal to or greater than this value.
     *
     * @defaultValue The beginning of time
     */
    public var start: Date?

    /**
     * The end of the time window to query from. If provided, the response will include
     * messages with timestamps less than this value.
     *
     * @defaultValue Now
     */
    public var end: Date?

    /**
     * The maximum number of messages to return in the response.
     *
     * @defaultValue 100
     */
    public var limit: Int?

    /**
     * The direction to query messages in.
     * If `forwards`, the response will include messages from the start of the time window to the end.
     * If `backwards`, the response will include messages from the end of the time window to the start.
     * If not provided, the default is `forwards`.
     *
     * @defaultValue forwards
     */
    public var orderBy: ResultOrder?

    // (CHA-M5g) The subscribers subscription point must be additionally specified (internally, by us) in the fromSerial query parameter.
    internal var fromSerial: String?

    public init(start: Date? = nil, end: Date? = nil, limit: Int? = nil, orderBy: QueryOptions.ResultOrder? = nil) {
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

// Currently a copy-and-paste of `Subscription`; see notes on that one. For `MessageSubscription`, my intention is that the `BufferingPolicy` passed to `subscribe(bufferingPolicy:)` will also define what the `MessageSubscription` does with messages that are received _before_ the user starts iterating over the sequence (this buffering will allow us to implement the requirement that there be no discontinuity between the the last message returned by `getPreviousMessages` and the first element you get when you iterate).
public struct MessageSubscription: Sendable, AsyncSequence {
    public typealias Element = Message

    private var subscription: Subscription<Element>

    // can be set by either initialiser
    private let getPreviousMessages: @Sendable (QueryOptions) async throws -> any PaginatedResult<Message>

    // used internally
    internal init(
        bufferingPolicy: BufferingPolicy,
        getPreviousMessages: @escaping @Sendable (QueryOptions) async throws -> any PaginatedResult<Message>
    ) {
        subscription = .init(bufferingPolicy: bufferingPolicy)
        self.getPreviousMessages = getPreviousMessages
    }

    // used for testing
    public init<T: AsyncSequence & Sendable>(mockAsyncSequence: T, mockGetPreviousMessages: @escaping @Sendable (QueryOptions) async throws -> any PaginatedResult<Message>) where T.Element == Element {
        subscription = .init(mockAsyncSequence: mockAsyncSequence)
        getPreviousMessages = mockGetPreviousMessages
    }

    internal func emit(_ element: Element) {
        subscription.emit(element)
    }

    public func getPreviousMessages(params: QueryOptions) async throws -> any PaginatedResult<Message> {
        try await getPreviousMessages(params)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var subscriptionIterator: Subscription<Element>.AsyncIterator

        fileprivate init(subscriptionIterator: Subscription<Element>.AsyncIterator) {
            self.subscriptionIterator = subscriptionIterator
        }

        public mutating func next() async -> Element? {
            await subscriptionIterator.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        .init(subscriptionIterator: subscription.makeAsyncIterator())
    }
}
