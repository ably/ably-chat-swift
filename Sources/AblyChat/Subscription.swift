import Ably

/**
 * Represents a subscription that can be unsubscribed from.
 * This interface provides a way to clean up and remove subscriptions when they
 * are no longer needed.
 */
@MainActor
public protocol SubscriptionProtocol: Sendable {
    /**
     * This method should be called when the subscription is no longer needed,
     * it will make sure no further events will be sent to the subscriber and
     * that references to the subscriber are cleaned up.
     */
    func unsubscribe()
}

/**
 * Represents a subscription to status change events that can be unsubscribed from. This
 * interface provides a way to clean up and remove subscriptions when they are no longer needed.
 */
@MainActor
public protocol StatusSubscriptionProtocol: Sendable {
    /**
     * Unsubscribes from the status change events. It will ensure that no
     * further status change events will be sent to the subscriber and
     * that references to the subscriber are cleaned up.
     */
    func off()
}

/**
 * A response object that allows you to control a message subscription.
 */
@MainActor
public protocol MessageSubscriptionResponseProtocol: SubscriptionProtocol, Sendable {
    /**
     * Get the previous messages that were sent to the room before the listener was subscribed.
     *
     * If the client experiences a discontinuity event (i.e. the connection was lost and could not be resumed), the starting point of
     * historyBeforeSubscribe will be reset.
     *
     * Calls to historyBeforeSubscribe will wait for continuity to be restored before resolving.
     *
     * Once continuity is restored, the subscription point will be set to the beginning of this new period of continuity. To
     * ensure that no messages are missed, you should call historyBeforeSubscribe after any period of discontinuity to
     * fill any gaps in the message history.
     *
     * - Parameters:
     *    - params: Options for the history query.
     *
     * - Returns: A paginated result of messages, in newest-to-oldest order.
     */
    func historyBeforeSubscribe(_ params: QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>
}

public struct Subscription: SubscriptionProtocol, Sendable {
    private let _unsubscribe: () -> Void

    public func unsubscribe() {
        _unsubscribe()
    }

    public init(unsubscribe: @MainActor @Sendable @escaping () -> Void) {
        _unsubscribe = unsubscribe
    }
}

public struct StatusSubscription: StatusSubscriptionProtocol, Sendable {
    private let _off: () -> Void

    public func off() {
        _off()
    }

    public init(off: @MainActor @Sendable @escaping () -> Void) {
        _off = off
    }
}

public struct MessageSubscriptionResponse: MessageSubscriptionResponseProtocol, Sendable {
    private let _unsubscribe: () -> Void
    private let _historyBeforeSubscribe: @Sendable (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>

    public func unsubscribe() {
        _unsubscribe()
    }

    public func historyBeforeSubscribe(_ params: QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message> {
        try await _historyBeforeSubscribe(params)
    }

    public init(
        unsubscribe: @MainActor @Sendable @escaping () -> Void,
        historyBeforeSubscribe: @MainActor @Sendable @escaping (QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message>
    ) {
        _unsubscribe = unsubscribe
        _historyBeforeSubscribe = historyBeforeSubscribe
    }
}
