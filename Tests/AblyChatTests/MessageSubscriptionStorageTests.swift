@testable import AblyChat
import AsyncAlgorithms
import Foundation
import Testing

/// Tests proving that MessageSubscriptionResponseAsyncSequence can be stored as a property
/// without needing to specify generic parameters - the original goal of this change.
struct MessageSubscriptionStorageTests {
    // MARK: - Using Protocol Existential (Recommended - consistent with SDK style)

    @Test
    func canStoreSubscriptionAsProtocolExistential() async {
        final class ChatManager {
            var subscription: (any MessageSubscriptionResponseAsyncSequenceProtocol)?

            func setSubscription(_ sub: any MessageSubscriptionResponseAsyncSequenceProtocol) {
                subscription = sub
            }

            func clearSubscription() {
                subscription = nil
            }
        }

        let manager = ChatManager()
        let mockSubscription = MessageSubscriptionResponseAsyncSequence(
            mockAsyncSequence: [].async
        ) { _ in
            fatalError("Not implemented")
        }

        // Can assign
        manager.setSubscription(mockSubscription)
        #expect(manager.subscription != nil)

        // Can clear
        manager.clearSubscription()
        #expect(manager.subscription == nil)
    }

    // MARK: - Using Concrete Type (Also works)

    @Test
    func canStoreSubscriptionAsConcreteType() async {
        final class ChatManager {
            var subscription: MessageSubscriptionResponseAsyncSequence?

            func setSubscription(_ sub: MessageSubscriptionResponseAsyncSequence) {
                subscription = sub
            }

            func clearSubscription() {
                subscription = nil
            }
        }

        let manager = ChatManager()
        let mockSubscription = MessageSubscriptionResponseAsyncSequence(
            mockAsyncSequence: [].async
        ) { _ in
            fatalError("Not implemented")
        }

        // Can assign
        manager.setSubscription(mockSubscription)
        #expect(manager.subscription != nil)

        // Can clear
        manager.clearSubscription()
        #expect(manager.subscription == nil)
    }

    // MARK: - Iterating over concrete type (no try required)

    /// This test proves that users can iterate over a stored concrete subscription WITHOUT using `try`.
    @Test
    func canIterateOverConcreteTypeWithoutTry() async {
        final class ChatManager {
            var subscription: MessageSubscriptionResponseAsyncSequence?

            // ✅ This method is `async` not `async throws`
            // It would fail to compile if `try` was needed to iterate
            func processMessages() async -> [String] {
                guard let subscription else { return [] }

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
            mockAsyncSequence: events.async
        ) { _ in
            fatalError("Not implemented")
        }

        let receivedTexts = await manager.processMessages()
        #expect(receivedTexts == ["Hello", "World"])
    }

    // MARK: - Iterating over protocol existential (requires try)

    /// This test shows that iterating over the protocol existential requires `try`.
    /// This is because Swift can't guarantee non-throwing without `Failure == Never` (requires macOS 15+/iOS 18+).
    @Test
    func iteratingOverProtocolExistentialRequiresTry() async throws {
        final class ChatManager {
            var subscription: (any MessageSubscriptionResponseAsyncSequenceProtocol)?

            // ⚠️ This method must be `async throws` because iterating over the protocol existential requires `try`
            // Also note: the event type becomes `Any` so we need to cast it
            func processMessages() async throws -> [String] {
                guard let subscription else { return [] }

                var receivedTexts: [String] = []
                for try await event in subscription {
                    let chatEvent = event as! ChatMessageEvent
                    receivedTexts.append(chatEvent.message.text)
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
            mockAsyncSequence: events.async
        ) { _ in
            fatalError("Not implemented")
        }

        let receivedTexts = try await manager.processMessages()
        #expect(receivedTexts == ["Hello", "World"])
    }
}
