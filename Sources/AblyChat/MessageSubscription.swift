import Foundation

/// A concrete type for message subscriptions that can be used for type annotations and passed to functions.
///
/// This type provides the same functionality as the underlying `MessageSubscriptionResponseAsyncSequence`
/// but without generic parameters, making it easy to store, pass around, and use as a property type.
///
/// This mirrors the `MessageSubscriptionResponse` interface in JavaScript and `MessagesSubscription` in Kotlin,
/// providing Swift developers with a simple, explicit type for message subscriptions.
///
/// Example usage:
/// ```swift
/// class ChatManager {
///     var subscription: MessageSubscription?
///
///     func setup(room: some Room) async {
///         subscription = MessageSubscription(room.messages.subscribe())
///     }
///
///     func processMessages(_ subscription: MessageSubscription) async {
///         let history = try? await subscription.historyBeforeSubscribe(withParams: .init())
///         for await event in subscription {
///             print(event.message.text)
///         }
///     }
/// }
/// ```
public final class MessageSubscription: Sendable, AsyncSequence {
    // swiftlint:disable:next missing_docs
    public typealias Element = ChatMessageEvent

    private let box: any MessageSubscriptionBox

    /// Creates a `MessageSubscription` by wrapping a `MessageSubscriptionResponseAsyncSequence`.
    ///
    /// This initializer type-erases the generic `HistoryResult` parameter, allowing
    /// the resulting `MessageSubscription` to be used as a concrete type.
    ///
    /// - Parameter underlying: The `MessageSubscriptionResponseAsyncSequence` to wrap.
    public init(_ underlying: MessageSubscriptionResponseAsyncSequence<some PaginatedResult<Message>>) {
        box = ConcreteMessageSubscriptionBox(underlying)
    }

    /// Creates a `MessageSubscription` for testing/mocking purposes.
    ///
    /// - Parameters:
    ///   - mockAsyncSequence: An `AsyncSequence` that provides the events.
    ///   - mockHistoryBeforeSubscribe: A closure that returns paginated history results.
    public init<Underlying: AsyncSequence & Sendable>(
        mockAsyncSequence: Underlying,
        mockHistoryBeforeSubscribe: @escaping @Sendable (HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> any PaginatedResult<Message>,
    ) where Underlying.Element == Element {
        box = MockMessageSubscriptionBox(
            asyncSequence: mockAsyncSequence,
            historyBeforeSubscribe: mockHistoryBeforeSubscribe,
        )
    }

    /// Get the previous messages that were sent to the room before the listener was subscribed.
    ///
    /// If the client experiences a discontinuity event (i.e. the connection was lost and could not be resumed),
    /// the starting point of historyBeforeSubscribe will be reset.
    ///
    /// Calls to historyBeforeSubscribe will wait for continuity to be restored before resolving.
    ///
    /// Once continuity is restored, the subscription point will be set to the beginning of this new period
    /// of continuity. To ensure that no messages are missed, you should call historyBeforeSubscribe after
    /// any period of discontinuity to fill any gaps in the message history.
    ///
    /// - Parameter params: Parameters for the history query.
    /// - Returns: A paginated result of messages, in newest-to-oldest order.
    public func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> any PaginatedResult<Message> {
        switch box {
        case let wrapped as ConcreteMessageSubscriptionBox:
            try await wrapped.historyBeforeSubscribe(withParams: params)
        case let mock as MockMessageSubscriptionBox:
            try await mock.historyBeforeSubscribe(withParams: params)
        default:
            fatalError("Unknown box type")
        }
    }

    // MARK: - AsyncSequence conformance

    // swiftlint:disable:next missing_docs
    public struct AsyncIterator: AsyncIteratorProtocol {
        fileprivate var underlying: any MessageSubscriptionIteratorBox

        // swiftlint:disable:next missing_docs
        public mutating func next() async -> Element? {
            await underlying.next()
        }
    }

    // swiftlint:disable:next missing_docs
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(underlying: box.makeIterator())
    }
}

// MARK: - Internal protocols for type erasure

/// Protocol for type-erased message subscription box.
private protocol MessageSubscriptionBox: Sendable {
    func makeIterator() -> any MessageSubscriptionIteratorBox
}

/// Protocol for type-erased async iterator box.
private protocol MessageSubscriptionIteratorBox {
    mutating func next() async -> ChatMessageEvent?
}

// MARK: - Concrete box implementation

/// Box that wraps a `MessageSubscriptionResponseAsyncSequence`.
private final class ConcreteMessageSubscriptionBox: MessageSubscriptionBox, @unchecked Sendable {
    private let underlying: any InternalMessageSubscriptionBox

    init(_ underlying: MessageSubscriptionResponseAsyncSequence<some PaginatedResult<Message>>) {
        self.underlying = TypedMessageSubscriptionBox(underlying)
    }

    func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> any PaginatedResult<Message> {
        try await underlying.historyBeforeSubscribe(withParams: params)
    }

    func makeIterator() -> any MessageSubscriptionIteratorBox {
        underlying.makeIterator()
    }
}

/// Internal protocol to hide generic parameter.
private protocol InternalMessageSubscriptionBox: Sendable {
    func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> any PaginatedResult<Message>
    func makeIterator() -> any MessageSubscriptionIteratorBox
}

/// Typed box that holds the actual `MessageSubscriptionResponseAsyncSequence`.
private final class TypedMessageSubscriptionBox<HistoryResult: PaginatedResult<Message>>: InternalMessageSubscriptionBox, @unchecked Sendable {
    private let underlying: MessageSubscriptionResponseAsyncSequence<HistoryResult>

    init(_ underlying: MessageSubscriptionResponseAsyncSequence<HistoryResult>) {
        self.underlying = underlying
    }

    func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> any PaginatedResult<Message> {
        try await underlying.historyBeforeSubscribe(withParams: params)
    }

    func makeIterator() -> any MessageSubscriptionIteratorBox {
        ConcreteIteratorBox(underlying.makeAsyncIterator())
    }

    /// Box that wraps the concrete iterator.
    private struct ConcreteIteratorBox: MessageSubscriptionIteratorBox {
        private var iterator: MessageSubscriptionResponseAsyncSequence<HistoryResult>.AsyncIterator

        init(_ iterator: MessageSubscriptionResponseAsyncSequence<HistoryResult>.AsyncIterator) {
            self.iterator = iterator
        }

        mutating func next() async -> ChatMessageEvent? {
            await iterator.next()
        }
    }
}

// MARK: - Mock box implementation

/// Box for mock subscriptions used in testing.
private final class MockMessageSubscriptionBox: MessageSubscriptionBox, @unchecked Sendable {
    private let asyncSequence: MockAsyncSequenceBox
    private let _historyBeforeSubscribe: @Sendable (HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> any PaginatedResult<Message>

    init<Underlying: AsyncSequence & Sendable>(
        asyncSequence: Underlying,
        historyBeforeSubscribe: @escaping @Sendable (HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> any PaginatedResult<Message>,
    ) where Underlying.Element == ChatMessageEvent {
        self.asyncSequence = MockAsyncSequenceBox(asyncSequence)
        _historyBeforeSubscribe = historyBeforeSubscribe
    }

    func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> any PaginatedResult<Message> {
        try await _historyBeforeSubscribe(params)
    }

    func makeIterator() -> any MessageSubscriptionIteratorBox {
        asyncSequence.makeIterator()
    }
}

/// Type-erased box for mock async sequences.
private final class MockAsyncSequenceBox: @unchecked Sendable {
    private let _makeIterator: () -> any MessageSubscriptionIteratorBox

    init<Underlying: AsyncSequence & Sendable>(_ sequence: Underlying) where Underlying.Element == ChatMessageEvent {
        _makeIterator = {
            MockIteratorBox(sequence.makeAsyncIterator())
        }
    }

    func makeIterator() -> any MessageSubscriptionIteratorBox {
        _makeIterator()
    }

    /// Box that wraps mock iterators.
    private struct MockIteratorBox<I: AsyncIteratorProtocol>: MessageSubscriptionIteratorBox where I.Element == ChatMessageEvent {
        private var iterator: I

        init(_ iterator: I) {
            self.iterator = iterator
        }

        mutating func next() async -> ChatMessageEvent? {
            do {
                return try await iterator.next()
            } catch {
                fatalError("The AsyncSequence passed to MessageSubscription.init(mockAsyncSequence:) threw an error: \(error). This is not supported.")
            }
        }
    }
}
