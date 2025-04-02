@testable import AblyChat
import Testing

@MainActor
struct SubscriptionStorageTests {
    @Test
    func emit() async throws {
        let storage = SubscriptionStorage<String>()
        let subscriptions = (0 ..< 10).map { _ in storage.create(bufferingPolicy: .unbounded) }
        storage.emit("hello")

        var emittedElements: [String] = []
        for subscription in subscriptions {
            try emittedElements.append(#require(await subscription.first { @Sendable _ in true }))
        }

        #expect(emittedElements == Array(repeating: "hello", count: 10))
    }

    @Test
    func removesSubscriptionOnTermination() async throws {
        let storage = SubscriptionStorage<String>()
        let subscriptionTerminatedSignal = AsyncStream<Void>.makeStream()

        ({
            let subscription = storage.create(bufferingPolicy: .unbounded)
            subscription.addTerminationHandler {
                subscriptionTerminatedSignal.continuation.yield()
            }

            withExtendedLifetime(subscription) {
                #expect(storage.testsOnly_subscriptionCount == 1)
            }

            // Now there are no more references to `subscription`.
        })()

        await subscriptionTerminatedSignal.stream.first { @Sendable _ in true }
        #expect(storage.testsOnly_subscriptionCount == 0)
    }
}
