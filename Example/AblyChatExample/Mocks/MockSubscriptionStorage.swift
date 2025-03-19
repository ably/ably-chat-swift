import Foundation

// This is copied from ably-chat’s internal class `SubscriptionStorage`.
class MockSubscriptionStorage<Element: Sendable>: @unchecked Sendable {
    // We hold a weak reference to the subscriptions that we create, so that the subscriptions’ termination handlers get called when the user releases their final reference to the subscription.
    private struct WeaklyHeldSubscription {
        weak var subscription: MockSubscription<Element>?
    }

    /// Access must be synchronised via ``lock``.
    private var subscriptions: [UUID: WeaklyHeldSubscription] = [:]
    private let lock = NSLock()

    // You must not call the `setOnTermination` method of a subscription returned by this function, as it will replace the termination handler set by this function.
    func create(randomElement: @escaping @Sendable () -> Element, interval: Double) -> MockSubscription<Element> {
        let subscription = MockSubscription<Element>(randomElement: randomElement, interval: interval)
        let id = UUID()

        lock.withLock {
            subscriptions[id] = .init(subscription: subscription)
        }

        subscription.setOnTermination { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }

        return subscription
    }

    private func subscriptionDidTerminate(id: UUID) {
        lock.withLock {
            _ = subscriptions.removeValue(forKey: id)
        }
    }

    func emit(_ element: Element) {
        for subscription in subscriptions.values {
            subscription.subscription?.emit(element)
        }
    }
}
