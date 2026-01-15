@testable import AblyChat
import AsyncAlgorithms
import Foundation
import Testing

/// Tests proving that MessageSubscriptionResponseAsyncSequence can be stored as a property without needing to specify generic parameters.
struct MessageSubscriptionStorageTests {
    // MARK: - Can store as property

    @Test
    func canStoreSubscriptionAsProperty() async {
        final class ChatManager {
            var subscription: MessageSubscriptionResponseAsyncSequence?
        }

        let manager = ChatManager()
        let mockSubscription = MessageSubscriptionResponseAsyncSequence(
            mockAsyncSequence: [].async,
        ) { _ in
            fatalError("Not implemented")
        }

        // Can assign
        manager.subscription = mockSubscription
        #expect(manager.subscription != nil)

        // Can clear
        manager.subscription = nil
        #expect(manager.subscription == nil)
    }

    // MARK: - Can iterate without try

    /// This test proves that users can iterate over a stored subscription WITHOUT using `try`.
    @Test
    func canIterateWithoutTry() async {
        final class ChatManager {
            var subscription: MessageSubscriptionResponseAsyncSequence?

            // This method is `async` not `async throws`
            // It would fail to compile if `try` was needed to iterate
            func processMessages() async -> [String] {
                guard let subscription else {
                    return []
                }

                var receivedTexts: [String] = []
                for await event in subscription {
                    receivedTexts.append(event.message.text)
                }
                return receivedTexts
            }
        }

        let messages = [
            Message(serial: "1", action: .messageCreate, clientID: "user1", text: "Hello", metadata: [:], headers: [:], version: .init(serial: "1", timestamp: Date()), timestamp: Date(), reactions: .empty),
            Message(serial: "2", action: .messageCreate, clientID: "user2", text: "World", metadata: [:], headers: [:], version: .init(serial: "2", timestamp: Date()), timestamp: Date(), reactions: .empty),
        ]
        let events = messages.map { ChatMessageEvent(message: $0) }

        let manager = ChatManager()
        manager.subscription = MessageSubscriptionResponseAsyncSequence(
            mockAsyncSequence: events.async,
        ) { _ in
            fatalError("Not implemented")
        }

        let receivedTexts = await manager.processMessages()
        #expect(receivedTexts == ["Hello", "World"])
    }
}
