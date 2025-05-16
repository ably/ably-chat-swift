import Foundation

/// Maintains a list of `SubscriptionHandle` objects, which can be used to unsubscribe from subscription events.
///
/// Offers the ability to create a new subscription (using ``create(_:)``) or to emit a value on all subscriptions (using ``emit(_:)``).
@MainActor
internal class SubscriptionHandleStorage<Element: Sendable> {
    private struct SubscriptionElement {
        let callback: (Element) -> Void
        let handle: SubscriptionHandle
    }

    private var subscriptions: [UUID: SubscriptionElement] = [:]

    /// Creates a subscription and adds it to the list managed by this `SubscriptionStorage` instance.
    internal func create(_ callback: @escaping @MainActor (Element) -> Void) -> SubscriptionHandle {
        let id = UUID()
        let subscriptionHandle = SubscriptionHandle { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }
        let element = SubscriptionElement(callback: callback, handle: subscriptionHandle)
        subscriptions[id] = element
        return subscriptionHandle
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
            subscription.callback(element)
        }
    }
}
