import Ably

/**
 * Represents a subscription that can be unsubscribed from.
 * This interface provides a way to clean up and remove subscriptions when they
 * are no longer needed.
 */
@MainActor
public protocol Subscription: Sendable {
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
public protocol StatusSubscription: Sendable {
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
public protocol MessageSubscriptionResponse: Subscription, Sendable {
    // swiftlint:disable:next missing_docs
    associatedtype HistoryResult: PaginatedResult<Message>

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
     *    - params: Parameters for the history query.
     *
     * - Returns: A paginated result of messages, in newest-to-oldest order.
     */
    func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> HistoryResult
}

internal struct DefaultSubscription: Subscription, Sendable {
    private let _unsubscribe: () -> Void

    internal func unsubscribe() {
        _unsubscribe()
    }

    internal init(unsubscribe: @MainActor @Sendable @escaping () -> Void) {
        _unsubscribe = unsubscribe
    }
}

internal struct DefaultStatusSubscription: StatusSubscription, Sendable {
    private let _off: () -> Void

    internal func off() {
        _off()
    }

    internal init(off: @MainActor @Sendable @escaping () -> Void) {
        _off = off
    }
}

internal struct DefaultMessageSubscriptionResponse: MessageSubscriptionResponse, Sendable {
    private let chatAPI: ChatAPI
    private let roomName: String
    private let subscriptionStartSerial: @MainActor @Sendable () async throws(ErrorInfo) -> String
    private let _unsubscribe: () -> Void

    internal func unsubscribe() {
        _unsubscribe()
    }

    internal func historyBeforeSubscribe(withParams params: HistoryBeforeSubscribeParams) async throws(ErrorInfo) -> some PaginatedResult<Message> {
        let fromSerial = try await subscriptionStartSerial()

        // (CHA-M5f) This method must accept any of the standard history query options, except for direction
        var queryOptions = params.toHistoryParams()

        // (CHA-M5g) The subscribers subscription point must be additionally specified (internally, by us) in the fromSerial query parameter.
        queryOptions.fromSerial = fromSerial

        return try await chatAPI.getMessages(roomName: roomName, params: queryOptions)
    }

    internal init(
        chatAPI: ChatAPI,
        roomName: String,
        subscriptionStartSerial: @MainActor @escaping @Sendable () async throws(ErrorInfo) -> String,
        unsubscribe: @MainActor @Sendable @escaping () -> Void,
    ) {
        self.chatAPI = chatAPI
        self.roomName = roomName
        self.subscriptionStartSerial = subscriptionStartSerial
        _unsubscribe = unsubscribe
    }
}
