import Ably

public protocol Messages: AnyObject, Sendable, EmitsDiscontinuities {
    func subscribe(bufferingPolicy: BufferingPolicy) async -> MessageSubscription
    func get(options: QueryOptions) async throws -> any PaginatedResult<Message>
    func send(params: SendMessageParams) async throws -> Message
    var channel: RealtimeChannelProtocol { get }
}

public struct SendMessageParams: Sendable {
    public var text: String
    public var metadata: MessageMetadata?
    public var headers: MessageHeaders?

    public init(text: String, metadata: MessageMetadata? = nil, headers: MessageHeaders? = nil) {
        self.text = text
        self.metadata = metadata
        self.headers = headers
    }
}

public struct QueryOptions: Sendable {
    public enum ResultOrder: Sendable {
        case oldestFirst
        case newestFirst
    }

    public var start: Date?
    public var end: Date?
    public var limit: Int?
    public var orderBy: ResultOrder?

    public init(start: Date? = nil, end: Date? = nil, limit: Int? = nil, orderBy: QueryOptions.ResultOrder? = nil) {
        self.start = start
        self.end = end
        self.limit = limit
        self.orderBy = orderBy
    }
}

public struct QueryOptionsWithoutDirection: Sendable {
    public var start: Date?
    public var end: Date?
    public var limit: Int?

    public init(start: Date? = nil, end: Date? = nil, limit: Int? = nil) {
        self.start = start
        self.end = end
        self.limit = limit
    }
}

// Currently a copy-and-paste of `Subscription`; see notes on that one. For `MessageSubscription`, my intention is that the `BufferingPolicy` passed to `subscribe(bufferingPolicy:)` will also define what the `MessageSubscription` does with messages that are received _before_ the user starts iterating over the sequence (this buffering will allow us to implement the requirement that there be no discontinuity between the the last message returned by `getPreviousMessages` and the first element you get when you iterate).
public struct MessageSubscription: Sendable, AsyncSequence {
    public typealias Element = Message

    private var subscription: Subscription<Element>

    private var mockGetPreviousMessages: (@Sendable (QueryOptionsWithoutDirection) async throws -> any PaginatedResult<Message>)?

    internal init(bufferingPolicy: BufferingPolicy) {
        subscription = .init(bufferingPolicy: bufferingPolicy)
    }

    public init<T: AsyncSequence & Sendable>(mockAsyncSequence: T, mockGetPreviousMessages: @escaping @Sendable (QueryOptionsWithoutDirection) async throws -> any PaginatedResult<Message>) where T.Element == Element {
        subscription = .init(mockAsyncSequence: mockAsyncSequence)
        self.mockGetPreviousMessages = mockGetPreviousMessages
    }

    internal func emit(_ element: Element) {
        subscription.emit(element)
    }

    public func getPreviousMessages(params: QueryOptionsWithoutDirection) async throws -> any PaginatedResult<Message> {
        guard let mockImplementation = mockGetPreviousMessages else {
            fatalError("Not yet implemented")
        }
        return try await mockImplementation(params)
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
