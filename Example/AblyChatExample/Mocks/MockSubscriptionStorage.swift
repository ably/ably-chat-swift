import Ably
import AblyChat

// This is copied from ably-chat’s internal class `SubscriptionStorage`.
@MainActor
class MockSubscriptionStorage<Element: Sendable> {
    @MainActor
    private struct SubscriptionItem {
        let subscription: Subscription
        let callback: (Element) -> Void

        init(
            randomElement: @escaping @MainActor @Sendable () -> Element?,
            interval: @escaping @MainActor @Sendable () -> Double,
            callback: @escaping @MainActor (Element) -> Void,
            onTerminate: @escaping @MainActor () -> Void
        ) {
            self.callback = callback

            var needNext = true
            periodic(with: interval) {
                if needNext {
                    if let randomElement = randomElement() {
                        callback(randomElement)
                    }
                }
                return needNext
            }
            subscription = Subscription {
                needNext = false
                onTerminate()
            }
        }
    }

    private var subscriptions: [UUID: SubscriptionItem] = [:]

    func create(
        randomElement: @escaping @MainActor @Sendable () -> Element?,
        interval: @autoclosure @escaping @MainActor @Sendable () -> Double,
        callback: @escaping @MainActor (Element) -> Void
    ) -> SubscriptionProtocol {
        let id = UUID()
        let subscriptionItem = SubscriptionItem(randomElement: randomElement, interval: interval, callback: callback) { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }
        subscriptions[id] = subscriptionItem
        return subscriptionItem.subscription
    }

    private func subscriptionDidTerminate(id: UUID) {
        _ = subscriptions.removeValue(forKey: id)
    }

    func emit(_ element: Element) {
        for subscriptionItem in subscriptions.values {
            subscriptionItem.callback(element)
        }
    }
}

// This is copied from ably-chat’s internal class `StatusSubscriptionStorage`.
@MainActor
class MockStatusSubscriptionStorage<Element: Sendable> {
    @MainActor
    private struct SubscriptionItem {
        let subscription: StatusSubscription
        let callback: (Element) -> Void

        init(
            randomElement: @escaping @MainActor @Sendable () -> Element?,
            interval: @escaping @MainActor @Sendable () -> Double,
            callback: @escaping @MainActor (Element) -> Void,
            onTerminate: @escaping @MainActor () -> Void
        ) {
            self.callback = callback

            var needNext = true
            periodic(with: interval) {
                if needNext {
                    if let randomElement = randomElement() {
                        callback(randomElement)
                    }
                }
                return needNext
            }
            subscription = StatusSubscription {
                needNext = false
                onTerminate()
            }
        }
    }

    private var subscriptions: [UUID: SubscriptionItem] = [:]

    func create(
        randomElement: @escaping @MainActor @Sendable () -> Element?,
        interval: @autoclosure @escaping @MainActor @Sendable () -> Double,
        callback: @escaping @MainActor (Element) -> Void
    ) -> StatusSubscriptionProtocol {
        let id = UUID()
        let subscriptionItem = SubscriptionItem(randomElement: randomElement, interval: interval, callback: callback) { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }
        subscriptions[id] = subscriptionItem
        return subscriptionItem.subscription
    }

    private func subscriptionDidTerminate(id: UUID) {
        _ = subscriptions.removeValue(forKey: id)
    }

    func emit(_ element: Element) {
        for subscriptionItem in subscriptions.values {
            subscriptionItem.callback(element)
        }
    }
}

// This is copied from `MockSubscriptionStorage`, but for `MessageSubscriptionResponse`.
@MainActor
class MockMessageSubscriptionStorage<Element: Sendable> {
    @MainActor
    private struct SubscriptionItem {
        let subscription: MessageSubscriptionResponse
        let callback: (Element) -> Void

        init(
            randomElement: @escaping @MainActor @Sendable () -> Element,
            previousMessages: @escaping @MainActor @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>,
            interval: @escaping @MainActor @Sendable () -> Double,
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
            subscription = MessageSubscriptionResponse(unsubscribe: {
                needNext = false
                onTerminate()
            }, historyBeforeSubscribe: previousMessages)
        }
    }

    private var subscriptions: [UUID: SubscriptionItem] = [:]

    func create(
        randomElement: @escaping @MainActor @Sendable () -> Element,
        previousMessages: @escaping @MainActor @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>,
        interval: @autoclosure @escaping @MainActor @Sendable () -> Double,
        callback: @escaping @MainActor (Element) -> Void
    ) -> MessageSubscriptionResponseProtocol {
        let id = UUID()
        let subscriptionItem = SubscriptionItem(
            randomElement: randomElement,
            previousMessages: previousMessages,
            interval: interval,
            callback: callback
        ) { [weak self] in
            self?.subscriptionDidTerminate(id: id)
        }
        subscriptions[id] = subscriptionItem
        return subscriptionItem.subscription
    }

    private func subscriptionDidTerminate(id: UUID) {
        _ = subscriptions.removeValue(forKey: id)
    }

    func emit(_ element: Element) {
        for subscriptionItem in subscriptions.values {
            subscriptionItem.callback(element)
        }
    }
}
