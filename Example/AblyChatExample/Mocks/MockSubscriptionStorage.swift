import Ably
import AblyChat

// This is copied from ably-chat’s internal class `SubscriptionStorage`.
@MainActor
class MockSubscriptionStorage<Element: Sendable> {
    @MainActor
    private struct SubscriptionItem {
        let subscription: SubscriptionProtocol
        let callback: (Element) -> Void

        init(
            randomElement: @escaping @MainActor @Sendable () -> Element?,
            interval: @escaping @MainActor @Sendable () -> Double,
            callback: @escaping @MainActor (Element) -> Void,
            onTerminate: @escaping @MainActor () -> Void,
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
            subscription = MockSubscription {
                needNext = false
                onTerminate()
            }
        }
    }

    private var subscriptions: [UUID: SubscriptionItem] = [:]

    func create(
        randomElement: @escaping @MainActor @Sendable () -> Element?,
        interval: @autoclosure @escaping @MainActor @Sendable () -> Double,
        callback: @escaping @MainActor (Element) -> Void,
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
        let subscription: StatusSubscriptionProtocol
        let callback: (Element) -> Void

        init(
            randomElement: @escaping @MainActor @Sendable () -> Element?,
            interval: @escaping @MainActor @Sendable () -> Double,
            callback: @escaping @MainActor (Element) -> Void,
            onTerminate: @escaping @MainActor () -> Void,
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
            subscription = MockStatusSubscription {
                needNext = false
                onTerminate()
            }
        }
    }

    private var subscriptions: [UUID: SubscriptionItem] = [:]

    func create(
        randomElement: @escaping @MainActor @Sendable () -> Element?,
        interval: @autoclosure @escaping @MainActor @Sendable () -> Double,
        callback: @escaping @MainActor (Element) -> Void,
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
        let subscription: MessageSubscriptionResponseProtocol
        let callback: (Element) -> Void

        init(
            randomElement: @escaping @MainActor @Sendable () -> Element,
            previousMessages: @escaping @MainActor @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>,
            interval: @escaping @MainActor @Sendable () -> Double,
            callback: @escaping @MainActor (Element) -> Void,
            onTerminate: @escaping () -> Void,
        ) {
            self.callback = callback

            var needNext = true
            periodic(with: interval) {
                if needNext {
                    callback(randomElement())
                }
                return needNext
            }
            subscription = MockMessageSubscriptionResponse(previousMessages: previousMessages) {
                needNext = false
                onTerminate()
            }
        }
    }

    private var subscriptions: [UUID: SubscriptionItem] = [:]

    func create(
        randomElement: @escaping @MainActor @Sendable () -> Element,
        previousMessages: @escaping @MainActor @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>,
        interval: @autoclosure @escaping @MainActor @Sendable () -> Double,
        callback: @escaping @MainActor (Element) -> Void,
    ) -> MessageSubscriptionResponseProtocol {
        let id = UUID()
        let subscriptionItem = SubscriptionItem(
            randomElement: randomElement,
            previousMessages: previousMessages,
            interval: interval,
            callback: callback,
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

struct MockSubscription: SubscriptionProtocol {
    private let _unsubscribe: () -> Void

    func unsubscribe() {
        _unsubscribe()
    }

    init(unsubscribe: @MainActor @Sendable @escaping () -> Void) {
        _unsubscribe = unsubscribe
    }
}

struct MockStatusSubscription: StatusSubscriptionProtocol {
    private let _off: () -> Void

    func off() {
        _off()
    }

    init(off: @MainActor @Sendable @escaping () -> Void) {
        _off = off
    }
}

struct MockMessageSubscriptionResponse: MessageSubscriptionResponseProtocol {
    private let _unsubscribe: () -> Void
    private let previousMessages: @MainActor @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>

    func historyBeforeSubscribe(_ params: QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message> {
        try await previousMessages(params)
    }

    func unsubscribe() {
        _unsubscribe()
    }

    init(
        previousMessages: @escaping @MainActor @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>,
        unsubscribe: @MainActor @Sendable @escaping () -> Void,
    ) {
        self.previousMessages = previousMessages
        _unsubscribe = unsubscribe
    }
}
