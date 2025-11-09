import Ably

/**
 * Represents a subscription that can be unsubscribed from.
 * This interface provides a way to clean up and remove subscriptions when they
 * are no longer needed.
 */
@MainActor
public protocol Subscription: Sendable {
    /**
     * Unsubscribes from the subscription.
     *
     * This method should be called when the subscription is no longer needed.
     * It ensures that no further events will be sent to the subscriber and
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
     * Get the previous messages that were sent to the room before the listener was subscribed. This can be used to populate
     * a room on initial subscription or to refresh local state after a discontinuity event.
     *
     * - Note:
     *   - If the client experiences a discontinuity event (i.e. the connection was lost and could not be resumed), the starting point of
     *     `historyBeforeSubscribe` will be reset.
     *   - Calls to `historyBeforeSubscribe` will then wait for continuity to be restored before resolving.
     *   - Once continuity is restored, the subscription point will be set to the beginning of this new period of continuity. To
     *     ensure that no messages are missed (or updates/deletes), you should call `historyBeforeSubscribe` after any period of discontinuity to
     *     re-populate your local state.
     *
     * - Parameters:
     *    - params: Parameters for the history query.
     *
     * - Returns: A paginated result of messages, in newest-to-oldest order.
     *
     * - Throws: ``ErrorInfo``
     *
     * ## Example - Populating messages on initial subscription
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     * let room = try await chatClient.rooms.get("general-chat")
     *
     * // Local message state
     * var localMessages: [Message] = []
     *
     * func updateLocalMessageState(messages: inout [Message], message: Message) {
     *     // Find existing message in local state
     *     if let existingIndex = messages.firstIndex(where: { $0.serial == message.serial }) {
     *         // Existing message, update local state
     *         messages[existingIndex] = messages[existingIndex].with(message)
     *     } else {
     *         // New message, add to local state
     *         messages.append(message)
     *     }
     *     // Messages should be ordered by serial
     *     messages.sort { $0.serial < $1.serial }
     * }
     *
     * // Subscribe a listener to message events
     * let subscription = room.messages.subscribe { event in
     *     print("Message \(event.type): \(event.message.text)")
     *     updateLocalMessageState(messages: &localMessages, message: event.message)
     * }
     *
     * // Attach to the room to start receiving message events
     * try await room.attach()
     *
     * // Get historical messages before subscription
     * do {
     *     let history = try await subscription.historyBeforeSubscribe(withParams: .init(limit: 50))
     *     print("Retrieved \(history.items.count) historical messages")
     *
     *     // Process historical messages
     *     for message in history.items {
     *         print("Historical: \(message.text) from \(message.clientID)")
     *         updateLocalMessageState(messages: &localMessages, message: message)
     *     }
     * } catch {
     *     print("Failed to retrieve message history: \(error)")
     * }
     * ```
     *
     * ## Example - Handling discontinuities to refresh local state
     *
     * ```swift
     * // Subscribe a listener to message events as before
     * let subscription = room.messages.subscribe { event in
     *     print("Message \(event.type): \(event.message.text)")
     *     updateLocalMessageState(messages: &localMessages, message: event.message)
     * }
     *
     * // Subscribe to discontinuity events on the room
     * room.onDiscontinuity { reason in
     *     print("Discontinuity detected: \(reason)")
     *     // Clear local state and re-fetch messages
     *     localMessages = []
     *     Task {
     *         do {
     *             // Fetch messages before the new subscription point
     *             let history = try await subscription.historyBeforeSubscribe(withParams: .init(limit: 100))
     *
     *             // Merge each message into local state
     *             for message in history.items {
     *                 updateLocalMessageState(messages: &localMessages, message: message)
     *             }
     *
     *             print("Refreshed local state with \(localMessages.count) messages")
     *         } catch {
     *             print("Failed to refresh messages after discontinuity: \(error)")
     *         }
     *     }
     * }
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     * ```
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

internal struct DefaultMessageSubscriptionResponse<Realtime: InternalRealtimeClientProtocol>: MessageSubscriptionResponse, Sendable {
    private let chatAPI: ChatAPI<Realtime>
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
        chatAPI: ChatAPI<Realtime>,
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
