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
     *    - params: Options for the history query.
     *
     * - Returns: A paginated result of messages, in newest-to-oldest order.
     */
    func historyBeforeSubscribe(_ params: QueryOptions) async throws(ARTErrorInfo) -> HistoryResult
}

internal struct DefaultSubscription: SubscriptionProtocol, Sendable {
    private let _unsubscribe: () -> Void

    internal func unsubscribe() {
        _unsubscribe()
    }

    internal init(unsubscribe: @MainActor @Sendable @escaping () -> Void) {
        _unsubscribe = unsubscribe
    }
}

internal struct DefaultStatusSubscription: StatusSubscriptionProtocol, Sendable {
    private let _off: () -> Void

    internal func off() {
        _off()
    }

    internal init(off: @MainActor @Sendable @escaping () -> Void) {
        _off = off
    }
}

internal struct DefaultMessageSubscriptionResponse: MessageSubscriptionResponseProtocol, Sendable {
    private let chatAPI: ChatAPI
    private let roomName: String
    private let subscriptionStartSerial: @MainActor @Sendable () async throws(InternalError) -> String
    private let _unsubscribe: () -> Void

    internal func unsubscribe() {
        _unsubscribe()
    }

    internal func historyBeforeSubscribe(_ params: QueryOptions) async throws(ARTErrorInfo) -> some PaginatedResult<Message> {
        do {
            let fromSerial = try await subscriptionStartSerial()

            // (CHA-M5f) This method must accept any of the standard history query options, except for direction, which must always be backwards.
            var queryOptions = params
            queryOptions.orderBy = .newestFirst // newestFirst is equivalent to backwards

            // (CHA-M5g) The subscribers subscription point must be additionally specified (internally, by us) in the fromSerial query parameter.
            queryOptions.fromSerial = fromSerial

            return try await chatAPI.getMessages(roomName: roomName, params: queryOptions)
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    internal init(
        chatAPI: ChatAPI,
        roomName: String,
        subscriptionStartSerial: @MainActor @escaping @Sendable () async throws(InternalError) -> String,
        unsubscribe: @MainActor @Sendable @escaping () -> Void,
    ) {
        self.chatAPI = chatAPI
        self.roomName = roomName
        self.subscriptionStartSerial = subscriptionStartSerial
        _unsubscribe = unsubscribe
    }
}
