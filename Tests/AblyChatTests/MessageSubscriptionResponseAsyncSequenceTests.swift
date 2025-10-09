@testable import AblyChat
import AsyncAlgorithms
import Foundation
import Testing

private final class MockPaginatedResult<Item: Equatable>: PaginatedResult, @MainActor Equatable {
    var items: [Item] { fatalError("Not implemented") }

    var hasNext: Bool { fatalError("Not implemented") }

    var isLast: Bool { fatalError("Not implemented") }

    var next: MockPaginatedResult<Item>? { fatalError("Not implemented") }

    var first: MockPaginatedResult<Item> { fatalError("Not implemented") }

    var current: MockPaginatedResult<Item> { fatalError("Not implemented") }

    init() {}

    static func == (lhs: MockPaginatedResult<Item>, rhs: MockPaginatedResult<Item>) -> Bool {
        lhs.items == rhs.items &&
            lhs.hasNext == rhs.hasNext &&
            lhs.isLast == rhs.isLast
    }
}

struct MessageSubscriptionResponseAsyncSequenceTests {
    let messages = ["First", "Second"].map { text in
        Message(serial: "", action: .messageCreate, clientID: "", text: text, metadata: [:], headers: [:], version: .init(serial: "", timestamp: Date()), timestamp: Date())
    }

    @Test
    func withMockAsyncSequence() async {
        let events = messages.map { ChatMessageEvent(message: $0) }
        let subscription = MessageSubscriptionResponseAsyncSequence<MockPaginatedResult>(mockAsyncSequence: events.async) { _ in fatalError("Not implemented") }
        #expect(await Array(subscription.prefix(2)).map(\.message.text) == ["First", "Second"])
    }

    @Test
    func emit() async {
        let subscription = MessageSubscriptionResponseAsyncSequence<MockPaginatedResult>(bufferingPolicy: .unbounded) { _ in fatalError("Not implemented") }
        async let emittedElements = Array(subscription.prefix(2))
        subscription.emit(ChatMessageEvent(message: messages[0]))
        subscription.emit(ChatMessageEvent(message: messages[1]))
        #expect(await emittedElements.map(\.message.text) == ["First", "Second"])
    }

    @Test
    @MainActor
    func mockGetPreviousMessages() async throws {
        let mockPaginatedResult = MockPaginatedResult<Message>()
        let subscription = MessageSubscriptionResponseAsyncSequence(mockAsyncSequence: [].async) { _ in mockPaginatedResult }

        let result = try await subscription.historyBeforeSubscribe(withParams: .init())
        #expect(result === mockPaginatedResult)
    }
}
