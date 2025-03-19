import Foundation

/// Maintains a list of `Subscription` objects, from which it removes a subscription once the subscription is no longer in use.
///
/// Offers the ability to create a new subscription (using ``create(bufferingPolicy:)``) or to emit a value on all subscriptions (using ``emit(_:)``).
internal class SubscriptionStorage<Element: Sendable>: @unchecked Sendable {
    // A note about the use of `@unchecked Sendable` here: This is a type that updates its own state in response to external events (i.e. subscription termination), and I wasn’t sure how to perform this mutation in the context of some external actor that owns the mutable state held in this type. So instead I made this class own its mutable state and take responsibility for its synchronisation, and I decided to do perform this synchronisation manually instead of introducing _another_ layer of actors for something that really doesn’t seem like it should be an actor; it’s just meant to be a utility type. But we can revisit this decision.

    // We hold a weak reference to the subscriptions that we create, so that the subscriptions’ termination handlers get called when the user releases their final reference to the subscription.
    private struct WeaklyHeldSubscription {
        internal weak var subscription: Subscription<Element>?
    }

    /// Access must be synchronised via ``lock``.
    private var subscriptions: [UUID: WeaklyHeldSubscription] = [:]
    private let lock = NSLock()

    /// Creates a subscription and adds it to the list managed by this `SubscriptionStorage` instance.
    ///
    /// The `SubscriptionStorage` instance will remove this subscription from its list once the subscription “terminates” (meaning that there are no longer any references to it, or the task in which it was being iterated was cancelled).
    internal func create(bufferingPolicy: BufferingPolicy) -> Subscription<Element> {
        let subscription = Subscription<Element>(bufferingPolicy: bufferingPolicy)
        let id = UUID()

        lock.withLock {
            subscriptions[id] = .init(subscription: subscription)
        }

        subscription.addTerminationHandler { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }

        return subscription
    }

    #if DEBUG
        internal var testsOnly_subscriptionCount: Int {
            lock.withLock {
                subscriptions.count
            }
        }
    #endif

    private func subscriptionDidTerminate(id: UUID) {
        lock.withLock {
            _ = subscriptions.removeValue(forKey: id)
        }
    }

    /// Emits an element on all of the subscriptions in the reciever’s managed list.
    internal func emit(_ element: Element) {
        lock.withLock {
            for subscription in subscriptions.values {
                subscription.subscription?.emit(element)
            }
        }
    }
}
