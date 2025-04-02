import Foundation

/// Maintains a list of `Subscription` objects, from which it removes a subscription once the subscription is no longer in use.
///
/// Offers the ability to create a new subscription (using ``create(bufferingPolicy:)``) or to emit a value on all subscriptions (using ``emit(_:)``).
@MainActor
internal class SubscriptionStorage<Element: Sendable> {
    // We hold a weak reference to the subscriptions that we create, so that the subscriptions’ termination handlers get called when the user releases their final reference to the subscription.
    private struct WeaklyHeldSubscription {
        internal weak var subscription: Subscription<Element>?
    }

    private var subscriptions: [UUID: WeaklyHeldSubscription] = [:]

    /// Creates a subscription and adds it to the list managed by this `SubscriptionStorage` instance.
    ///
    /// The `SubscriptionStorage` instance will remove this subscription from its list once the subscription “terminates” (meaning that there are no longer any references to it, or the task in which it was being iterated was cancelled).
    internal func create(bufferingPolicy: BufferingPolicy) -> Subscription<Element> {
        let subscription = Subscription<Element>(bufferingPolicy: bufferingPolicy)
        let id = UUID()
        subscriptions[id] = .init(subscription: subscription)

        subscription.addTerminationHandler { [weak self] in
            Task { @MainActor in
                self?.subscriptionDidTerminate(id: id)
            }
        }

        return subscription
    }

    #if DEBUG
        internal var testsOnly_subscriptionCount: Int {
            subscriptions.count
        }
    #endif

    private func subscriptionDidTerminate(id: UUID) {
        _ = subscriptions.removeValue(forKey: id)
    }

    /// Emits an element on all of the subscriptions in the reciever’s managed list.
    internal func emit(_ element: Element) {
        for subscription in subscriptions.values {
            subscription.subscription?.emit(element)
        }
    }
}
