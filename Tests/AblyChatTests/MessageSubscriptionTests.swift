import Ably
@testable import AblyChat
import AsyncAlgorithms
import Foundation
import Testing

private final class MockPaginatedResult: PaginatedResult, @unchecked Sendable {
    let items: [Message]
    let hasNext: Bool
    let isLast: Bool

    init(items: [Message] = [], hasNext: Bool = false) {
        self.items = items
        self.hasNext = hasNext
        isLast = !hasNext
    }

    func next() async throws(ErrorInfo) -> MockPaginatedResult? { nil }
    func first() async throws(ErrorInfo) -> MockPaginatedResult { self }
    func current() async throws(ErrorInfo) -> MockPaginatedResult { self }
}

struct MessageSubscriptionTests {
    let messages = ["First", "Second"].map { text in
        Message(serial: "", action: .messageCreate, clientID: "", text: text, metadata: [:], headers: [:], version: .init(serial: "", timestamp: Date()), timestamp: Date(), reactions: .empty)
    }

    // MARK: - Type annotation tests (the main purpose of MessageSubscription)

    @Test
    @MainActor
    func canBeUsedAsPropertyType() async {
        // This test verifies that MessageSubscription can be used as a concrete property type
        // without needing to specify generic parameters
        final class ChatManager: Sendable {
            let subscription: MessageSubscription

            init(subscription: MessageSubscription) {
                self.subscription = subscription
            }
        }

        let events = messages.map { ChatMessageEvent(message: $0) }
        let mockResult = MockPaginatedResult()
        let subscription = MessageSubscription(
            mockAsyncSequence: events.async,
        ) { _ in mockResult }
        let manager = ChatManager(subscription: subscription)
        #expect(manager.subscription === subscription)
    }

    @Test
    @MainActor
    func canBeUsedAsParameterType() async {
        // This test verifies that MessageSubscription can be used as a function parameter type
        func processSubscription(_ sub: MessageSubscription) async -> [String] {
            var texts: [String] = []
            for await event in sub.prefix(2) {
                texts.append(event.message.text)
            }
            return texts
        }

        let events = messages.map { ChatMessageEvent(message: $0) }
        let mockResult = MockPaginatedResult()
        let subscription = MessageSubscription(
            mockAsyncSequence: events.async,
        ) { _ in mockResult }
        let texts = await processSubscription(subscription)
        #expect(texts == ["First", "Second"])
    }

    @Test
    @MainActor
    func canBeUsedAsOptionalPropertyType() async {
        // This test verifies that MessageSubscription? can be used as a property type
        final class ChatManager: @unchecked Sendable {
            var subscription: MessageSubscription?

            func setSubscription(_ sub: MessageSubscription) {
                subscription = sub
            }
        }

        let events = messages.map { ChatMessageEvent(message: $0) }
        let mockResult = MockPaginatedResult()
        let subscription = MessageSubscription(
            mockAsyncSequence: events.async,
        ) { _ in mockResult }
        let manager = ChatManager()
        #expect(manager.subscription == nil)
        manager.setSubscription(subscription)
        #expect(manager.subscription != nil)
    }

    // MARK: - Functionality tests

    @Test
    @MainActor
    func iteratingThroughMessages() async {
        // Test that MessageSubscription properly provides messages via AsyncSequence
        let events = messages.map { ChatMessageEvent(message: $0) }
        let mockResult = MockPaginatedResult()
        let subscription = MessageSubscription(
            mockAsyncSequence: events.async,
        ) { _ in mockResult }
        #expect(await Array(subscription.prefix(2)).map(\.message.text) == ["First", "Second"])
    }

    @Test
    @MainActor
    func historyBeforeSubscribe() async throws {
        // Test that historyBeforeSubscribe returns the paginated result
        let historyMessages = messages
        let mockPaginatedResult = MockPaginatedResult(items: historyMessages)
        let subscription = MessageSubscription(
            mockAsyncSequence: [ChatMessageEvent]().async,
        ) { _ in mockPaginatedResult }
        let result = try await subscription.historyBeforeSubscribe(withParams: .init())
        #expect(result.items.count == 2)
        #expect(result.items[0].text == "First")
    }

    @Test
    @MainActor
    func wrappingMessageSubscriptionResponseAsyncSequence() async {
        // Test that MessageSubscription properly wraps MessageSubscriptionResponseAsyncSequence
        let events = messages.map { ChatMessageEvent(message: $0) }
        let mockResult = MockPaginatedResult()
        let underlying = MessageSubscriptionResponseAsyncSequence<MockPaginatedResult>(
            mockAsyncSequence: events.async,
        ) { _ in mockResult }
        let subscription = MessageSubscription(underlying)
        #expect(await Array(subscription.prefix(2)).map(\.message.text) == ["First", "Second"])
    }
}
