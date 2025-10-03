import Foundation

/// Maintains a list of `Subscription` objects, which can be used to unsubscribe from subscription events.
///
/// Offers the ability to create a new subscription (using ``create(_:)``) or to emit a value on all subscriptions (using ``emit(_:)``).
@MainActor
internal class SubscriptionStorage<Element: Sendable> {
    private struct SubscriptionItem {
        let callback: (Element) -> Void
        let subscription: Subscription
    }

    private var subscriptions: [UUID: SubscriptionItem] = [:]

    /// Creates a subscription and adds it to the list managed by this `SubscriptionStorage` instance.
    internal func create(_ callback: @escaping @MainActor (Element) -> Void) -> any SubscriptionProtocol {
        let id = UUID()
        let subscription = Subscription { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }
        let subscriptionItem = SubscriptionItem(callback: callback, subscription: subscription)
        subscriptions[id] = subscriptionItem
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
        for subscriptionItem in subscriptions.values {
            subscriptionItem.callback(element)
        }
    }
}

/// Maintains a list of `StatusSubscription` objects, which can be used to unsubscribe from subscription events.
///
/// Offers the ability to create a new subscription (using ``create(_:)``) or to emit a value on all subscriptions (using ``emit(_:)``).
@MainActor
internal class StatusSubscriptionStorage<Element: Sendable> {
    private struct SubscriptionItem {
        let callback: (Element) -> Void
        let subscription: StatusSubscription
    }

    private var subscriptions: [UUID: SubscriptionItem] = [:]

    /// Creates a subscription and adds it to the list managed by this `SubscriptionStorage` instance.
    internal func create(_ callback: @escaping @MainActor (Element) -> Void) -> any StatusSubscriptionProtocol {
        let id = UUID()
        let statusSubscription = StatusSubscription { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }
        let element = SubscriptionItem(callback: callback, subscription: statusSubscription)
        subscriptions[id] = element
        return statusSubscription
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
        for subscriptionItem in subscriptions.values {
            subscriptionItem.callback(element)
        }
    }
}
