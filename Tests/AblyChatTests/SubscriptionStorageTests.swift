@testable import AblyChat
import Testing

@MainActor
struct SubscriptionStorageTests {
    @Test
    func emit() async throws {
        var emittedElements: [String] = []

        let storage = SubscriptionStorage<String>()
        _ = (0 ..< 10).map { _ in
            storage.create { element in
                emittedElements.append(element)
            }
        }
        storage.emit("hello")

        #expect(emittedElements == Array(repeating: "hello", count: 10))
    }

    @Test
    func removesSubscriptionOnUnsubscribe() async throws {
        let storage = SubscriptionStorage<String>()
        let subscription = storage.create { _ in }
        #expect(storage.testsOnly_subscriptionCount == 1)
        subscription.unsubscribe()
        #expect(storage.testsOnly_subscriptionCount == 0)
    }
}
