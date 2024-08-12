import Ably

public protocol Messages: AnyObject, Sendable, EmitsDiscontinuities {
    func subscribe(bufferingPolicy: BufferingPolicy) -> MessageSubscription
    func get(options: QueryOptions) async throws -> any PaginatedResult<Message>
    func send(params: SendMessageParams) async throws -> Message
    var channel: ARTRealtimeChannelProtocol { get }
}

public struct SendMessageParams: Sendable {
    public var text: String
    public var metadata: MessageMetadata?
    public var headers: MessageHeaders?

    public init(text: String, metadata: (any MessageMetadata)? = nil, headers: (any MessageHeaders)? = nil) {
        self.text = text
        self.metadata = metadata
        self.headers = headers
    }
}

public struct QueryOptions: Sendable {
    public enum Direction: Sendable {
        case forwards
        case backwards
    }

    public var start: Date?
    public var end: Date?
    public var limit: Int?
    public var direction: Direction?

    public init(start: Date? = nil, end: Date? = nil, limit: Int? = nil, direction: QueryOptions.Direction? = nil) {
        self.start = start
        self.end = end
        self.limit = limit
        self.direction = direction
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

// TODO: note this will start accumulating messages as soon as created
// TODO: note that I wanted this to instead inherit from Sequence protocol but that's not possible
public struct MessageSubscription: Sendable, AsyncSequence {
    public typealias Element = Message

    // TODO: explain, this is a workaround to allow us to write mocks
    public init<T: AsyncSequence>(mockAsyncSequence _: T) where T.Element == Element {
        fatalError("Not yet implemented")
    }

    public func getPreviousMessages(params _: QueryOptionsWithoutDirection) async throws -> any PaginatedResult<Message> {
        fatalError("Not yet implemented")
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        // note that I’ve removed the `throws` here and that means we don't need a `try` in the loop
        public mutating func next() async -> Element? {
            fatalError("Not implemented")
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        fatalError("Not implemented")
    }
}
