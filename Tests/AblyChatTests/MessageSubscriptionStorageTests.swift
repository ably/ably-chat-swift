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

    // MARK: - Can iterate using concrete type

    @Test
    func canIterateOverStoredConcreteSubscription() async {
        var subscription: MessageSubscriptionResponseAsyncSequence?

        let messages = [
            Message(serial: "1", action: .messageCreate, clientID: "user1", text: "Hello", metadata: [:], headers: [:], version: .init(serial: "1", timestamp: Date()), timestamp: Date(), reactions: .empty),
            Message(serial: "2", action: .messageCreate, clientID: "user2", text: "World", metadata: [:], headers: [:], version: .init(serial: "2", timestamp: Date()), timestamp: Date(), reactions: .empty),
        ]
        let events = messages.map { ChatMessageEvent(message: $0) }

        subscription = MessageSubscriptionResponseAsyncSequence(
            mockAsyncSequence: events.async
        ) { _ in
            fatalError("Not implemented")
        }

        // Can iterate over the stored subscription
        var receivedTexts: [String] = []
        for await event in subscription! {
            receivedTexts.append(event.message.text)
        }

        #expect(receivedTexts == ["Hello", "World"])
    }
}
