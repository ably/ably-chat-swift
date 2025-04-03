import Foundation

// This is copied from ably-chat’s internal class `SubscriptionStorage`.
@MainActor
class MockSubscriptionStorage<Element: Sendable> {
    // We hold a weak reference to the subscriptions that we create, so that the subscriptions’ termination handlers get called when the user releases their final reference to the subscription.
    private struct WeaklyHeldSubscription {
        weak var subscription: MockSubscription<Element>?
    }

    private var subscriptions: [UUID: WeaklyHeldSubscription] = [:]

    // You must not call the `setOnTermination` method of a subscription returned by this function, as it will replace the termination handler set by this function.
    func create(randomElement: @escaping @Sendable () -> Element, interval: Double) -> MockSubscription<Element> {
        let subscription = MockSubscription<Element>(randomElement: randomElement, interval: interval)
        let id = UUID()
        subscriptions[id] = .init(subscription: subscription)

        subscription.setOnTermination { [weak self] in
            Task { @MainActor in
                self?.subscriptionDidTerminate(id: id)
            }
        }

        return subscription
    }

    private func subscriptionDidTerminate(id: UUID) {
        _ = subscriptions.removeValue(forKey: id)
    }

    func emit(_ element: Element) {
        for subscription in subscriptions.values {
            subscription.subscription?.emit(element)
        }
    }
}
