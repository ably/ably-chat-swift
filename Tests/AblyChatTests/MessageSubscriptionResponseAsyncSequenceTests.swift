import Ably
@testable import AblyChat
import AsyncAlgorithms
import Foundation
import Testing

struct MessageSubscriptionResponseAsyncSequenceTests {
    let messages = ["First", "Second"].map { text in
        Message(serial: "", action: .messageCreate, clientID: "", text: text, metadata: [:], headers: [:], version: .init(serial: "", timestamp: Date()), timestamp: Date(), reactions: .empty)
    }

    @Test
    func withMockAsyncSequence() async {
        let events = messages.map { ChatMessageEvent(message: $0) }
        let subscription = MessageSubscription(mockAsyncSequence: events.async) { _ in
            PaginatedResult(items: [])
        }
        #expect(await Array(subscription.prefix(2)).map(\.message.text) == ["First", "Second"])
    }

    @Test
    @MainActor
    func emit() async {
        let subscription = MessageSubscription(
            bufferingPolicy: .unbounded,
        ) { _ in PaginatedResult(items: []) }
        async let emittedElements = Array(subscription.prefix(2))
        subscription.emit(ChatMessageEvent(message: messages[0]))
        subscription.emit(ChatMessageEvent(message: messages[1]))
        #expect(await emittedElements.map(\.message.text) == ["First", "Second"])
    }

    @Test
    @MainActor
    func mockGetPreviousMessages() async throws {
        let mockPaginatedResult = PaginatedResult<Message>(items: messages)
        let subscription = MessageSubscription(mockAsyncSequence: [].async) { _ in mockPaginatedResult }

        let result = try await subscription.historyBeforeSubscribe(withParams: .init())
        #expect(result == mockPaginatedResult)
    }
}
