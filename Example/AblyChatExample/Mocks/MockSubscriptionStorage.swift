import Ably
@testable import AblyChat

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

@MainActor
class MockSubscriptionHandleStorage<Element: Sendable> {
    @MainActor
    private struct Subscription {
        let handle: SubscriptionHandle
        let callback: (Element) -> Void

        init(randomElement: @escaping @Sendable () -> Element, interval: Double, callback: @escaping @MainActor (Element) -> Void, onTerminate: @escaping () -> Void) {
            self.callback = callback

            var needNext = true
            periodic(with: interval) {
                if needNext {
                    callback(randomElement())
                }
                return needNext
            }
            handle = SubscriptionHandle {
                needNext = false
                onTerminate()
            }
        }
    }

    private var subscriptions: [UUID: Subscription] = [:]

    func create(
        randomElement: @escaping @Sendable () -> Element,
        interval: Double,
        callback: @escaping @MainActor (Element) -> Void
    ) -> SubscriptionHandle {
        let id = UUID()
        let subscription = Subscription(randomElement: randomElement, interval: interval, callback: callback) { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }
        subscriptions[id] = subscription
        return subscription.handle
    }

    private func subscriptionDidTerminate(id: UUID) {
        _ = subscriptions.removeValue(forKey: id)
    }

    func emit(_ element: Element) {
        for subscription in subscriptions.values {
            subscription.callback(element)
        }
    }
}

@MainActor
class MockMessageSubscriptionHandleStorage<Element: Sendable> {
    @MainActor
    private struct Subscription {
        let handle: MessageSubscriptionHandle
        let callback: (Element) -> Void

        init(
            randomElement: @escaping @Sendable () -> Element,
            previousMessages: @escaping @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>,
            interval: Double,
            callback: @escaping @MainActor (Element) -> Void,
            onTerminate: @escaping () -> Void
        ) {
            self.callback = callback

            var needNext = true
            periodic(with: interval) {
                if needNext {
                    callback(randomElement())
                }
                return needNext
            }
            handle = MessageSubscriptionHandle(unsubscribe: {
                needNext = false
                onTerminate()
            }, getPreviousMessages: previousMessages)
        }
    }

    private var subscriptions: [UUID: Subscription] = [:]

    func create(
        randomElement: @escaping @Sendable () -> Element,
        previousMessages: @escaping @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>,
        interval: Double,
        callback: @escaping @MainActor (Element) -> Void
    ) -> MessageSubscriptionHandle {
        let id = UUID()
        let subscription = Subscription(
            randomElement: randomElement,
            previousMessages: previousMessages,
            interval: interval,
            callback: callback
        ) { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }
        subscriptions[id] = subscription
        return subscription.handle
    }

    private func subscriptionDidTerminate(id: UUID) {
        _ = subscriptions.removeValue(forKey: id)
    }

    func emit(_ element: Element) {
        for subscription in subscriptions.values {
            subscription.callback(element)
        }
    }
}
