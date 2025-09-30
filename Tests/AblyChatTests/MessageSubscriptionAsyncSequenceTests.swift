@testable import AblyChat
import AsyncAlgorithms
import Foundation
import Testing

private final class MockPaginatedResult<Item: Equatable>: PaginatedResult {
    var items: [Item] { fatalError("Not implemented") }

    var hasNext: Bool { fatalError("Not implemented") }

    var isLast: Bool { fatalError("Not implemented") }

    var next: (any AblyChat.PaginatedResult<Item>)? { fatalError("Not implemented") }

    var first: any AblyChat.PaginatedResult<Item> { fatalError("Not implemented") }

    var current: any AblyChat.PaginatedResult<Item> { fatalError("Not implemented") }

    init() {}

    static func == (lhs: MockPaginatedResult<Item>, rhs: MockPaginatedResult<Item>) -> Bool {
        lhs.items == rhs.items &&
            lhs.hasNext == rhs.hasNext &&
            lhs.isLast == rhs.isLast
    }
}

struct MessageSubscriptionAsyncSequenceTests {
    let messages = ["First", "Second"].map { text in
        Message(serial: "", action: .create, clientID: "", text: text, metadata: [:], headers: [:], version: .init(serial: "", timestamp: Date()), timestamp: Date())
    }

    @Test
    func withMockAsyncSequence() async {
        let events = messages.map { ChatMessageEvent(message: $0) }
        let subscription = MessageSubscriptionAsyncSequence(mockAsyncSequence: events.async) { _ in fatalError("Not implemented") }
        #expect(await Array(subscription.prefix(2)).map(\.message.text) == ["First", "Second"])
    }

    @Test
    func emit() async {
        let subscription = MessageSubscriptionAsyncSequence(bufferingPolicy: .unbounded) { _ in fatalError("Not implemented") }
        async let emittedElements = Array(subscription.prefix(2))
        subscription.emit(ChatMessageEvent(message: messages[0]))
        subscription.emit(ChatMessageEvent(message: messages[1]))
        #expect(await emittedElements.map(\.message.text) == ["First", "Second"])
    }

    @Test
    func mockGetPreviousMessages() async throws {
        let mockPaginatedResult = MockPaginatedResult<Message>()
        let subscription = MessageSubscriptionAsyncSequence(mockAsyncSequence: [].async) { _ in mockPaginatedResult }

        let result = try await subscription.getPreviousMessages(params: .init())
        // This dance is to avoid the compiler error "Runtime support for parameterized protocol types is only available in iOS 16.0.0 or newer" — casting back to a concrete type seems to avoid this
        let resultAsConcreteType = try #require(result as? MockPaginatedResult<Message>)
        #expect(resultAsConcreteType === mockPaginatedResult)
    }
}
