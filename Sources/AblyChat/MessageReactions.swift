import Ably

/**
 * Send, delete, and subscribe to message reactions.
 *
 * Get an instance via ``Room/messages/reactions``.
 */
@MainActor
public protocol MessageReactions: AnyObject, Sendable {
    /// The subscription type for message reaction event listeners.
    associatedtype Subscription: AblyChat.Subscription

    /**
     * Sends a reaction to a specific chat message.
     *
     * - Note:
     *   - The behavior depends on the reaction type configured for the room.
     *   - This method uses the Ably Chat REST API and so does not require the room
     *     to be attached to be called.
     *
     * - Parameters:
     *   - messageSerial: The unique identifier of the message to react to.
     *   - params: The reaction parameters.
     *
     * - Throws: ``ErrorInfo`` with code 40400 if the message does not exist.
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get(named: "sports-chat")
     *
     * let messageSerial = "01726585978590-001@abcdefghij:001"
     *
     * // Send a simple reaction to a message
     * do {
     *     try await room.messages.reactions.send(
     *         forMessageWithSerial: messageSerial,
     *         params: .init(
     *             name: "👍"
     *         )
     *     )
     *     print("Reaction sent successfully")
     * } catch {
     *     print("Failed to send reaction: \(error)")
     * }
     *
     * // Send a distinct type reaction (can react with multiple different emojis)
     * try await room.messages.reactions.send(
     *     forMessageWithSerial: messageSerial,
     *     params: .init(
     *         name: "❤️",
     *         type: .distinct
     *     )
     * )
     *
     * // Send a multiple type reaction with count (for vote-style reactions)
     * try await room.messages.reactions.send(
     *     forMessageWithSerial: messageSerial,
     *     params: .init(
     *         name: "option-a",
     *         type: .multiple,
     *         count: 3 // User votes 3 times for option-a
     *     )
     * )
     * ```
     */
    func send(forMessageWithSerial messageSerial: String, params: SendMessageReactionParams) async throws(ErrorInfo)

    /**
     * Deletes a previously sent reaction from a chat message.
     *
     * The deletion behavior depends on the reaction type:
     * - **Unique**: Removes the client's single reaction (name not required)
     * - **Distinct**: Removes a specific reaction by name
     * - **Multiple**: Removes all instances of a reaction by name
     *
     * - Note: This method uses the Ably Chat REST API and so does not require the room
     * to be attached to be called.
     *
     * - Parameters:
     *   - messageSerial: The unique identifier of the message to remove the reaction from
     *   - params: Optional deletion parameters
     *
     * - Throws:
     *   - ``ErrorInfo`` with code 40400 if the message does not exist.
     *   - ``ErrorInfo`` with code ``InternalError/ErrorCode/invalidArgument`` if trying to delete a non-Unique reaction without a name.
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get(named: "team-chat")
     *
     * let messageSerial = "01726585978590-001@abcdefghij:001"
     *
     * // Delete a distinct reaction (specific emoji)
     * do {
     *     try await room.messages.reactions.delete(
     *         fromMessageWithSerial: messageSerial,
     *         params: .init(
     *             name: "👍",
     *             type: .distinct
     *         )
     *     )
     *     print("Thumbs up reaction removed")
     * } catch {
     *     print("Failed to delete reaction: \(error)")
     * }
     *
     * // Delete a unique reaction (only one per user, name not needed)
     * try await room.messages.reactions.delete(
     *     fromMessageWithSerial: messageSerial,
     *     params: .init(
     *         type: .unique
     *     )
     * )
     *
     * // Delete all instances of a multiple reaction
     * try await room.messages.reactions.delete(
     *     fromMessageWithSerial: messageSerial,
     *     params: .init(
     *         name: "option-b",
     *         type: .multiple
     *     )
     * )
     * ```
     */
    func delete(fromMessageWithSerial messageSerial: String, params: DeleteMessageReactionParams) async throws(ErrorInfo)

    /**
     * Subscribes to chat message reaction summary events.
     *
     * Summary events provide aggregated reaction counts. Each summary event contains counts and
     * client lists for all reaction types on a message.
     *
     * - Note:
     *   - The room must be attached to receive reaction events.
     *   - When there are many reacting clients, the client list may be clipped. Check the ``MessageReactionSummary/ClientIDCounts/clipped`` flag and use ``MessageReactions/clientReactions(forMessageWithSerial:clientID:)`` for complete client information when needed.
     *   - When the rate of reactions is very high, multiple summaries may be rolled up into a single summary event, meaning the delta between sequential summaries is not guaranteed to be a single reaction change.
     *
     * - Parameters:
     *   - callback: Callback invoked when reaction summaries are updated
     *
     * - Returns: Subscription object with an unsubscribe method
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get(named: "product-reviews")
     *
     * // Subscribe to reaction summaries
     * let subscription = room.messages.reactions.subscribe { event in
     *     let reactions = event.reactions
     *     // Handle distinct reactions
     *     for (reaction, data) in reactions.distinct {
     *         print("\(reaction): \(data.total) reactions from \(data.clientIDs.count) users")
     *     }
     *     // Handle unique reactions
     *     for (reaction, data) in reactions.unique {
     *         print("\(reaction): \(data.total) users reacted")
     *     }
     *     // Handle multiple reactions
     *     for (reaction, data) in reactions.multiple {
     *         print("\(reaction): \(data.total) total votes")
     *     }
     * }
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     *
     * // Later, unsubscribe when done
     * subscription.unsubscribe()
     * ```
     */
    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (MessageReactionSummaryEvent) -> Void) -> Subscription

    /**
     * Subscribes to individual chat message reaction events.
     *
     * Raw reaction events provide the individual updates for each reaction
     * added or removed. This is most useful for analytics, but is not recommended
     * for driving UI due to the high volume of events.
     *
     * - Note:
     *   - Requires ``MessagesOptions/rawMessageReactions`` to be enabled in room options. It's a programmer error otherwise.
     *
     * - Parameters:
     *   - callback: Callback invoked for each individual reaction event
     *
     * - Returns: Subscription object with an unsubscribe method
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Enable raw reactions in room options
     * let room = try await chatClient.rooms.get(named: "live-stream", options: RoomOptions(
     *     messages: MessagesOptions(
     *         rawMessageReactions: true
     *     )
     * ))
     *
     * // Subscribe to raw reaction events for analytics
     * let subscription = room.messages.reactions.subscribeRaw { event in
     *     let reaction = event.reaction
     *
     *     switch event.type {
     *     case .create:
     *         print("[\(event.timestamp)] \(reaction.clientID) added \(reaction.name) to message \(reaction.messageSerial)")
     *
     *     case .delete:
     *         print("[\(event.timestamp)] \(reaction.clientID) removed \(reaction.name) from message \(reaction.messageSerial)")
     *     }
     *
     *     // Handle multiple type reactions with counts
     *     if let count = reaction.count {
     *         print("Reaction has count: \(count)")
     *     }
     * }
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     *
     * // Later, unsubscribe when done
     * subscription.unsubscribe()
     * ```
     */
    @discardableResult
    func subscribeRaw(_ callback: @escaping @MainActor (MessageReactionRawEvent) -> Void) -> Subscription

    /**
     * Retrieves reaction information for a specific client on a message.
     *
     * Use this method when reaction summaries are clipped (too many reacting clients)
     * and you need to check if a specific client has reacted. This is particularly
     * useful for determining if the current user has reacted when they're not in
     * the summary's client list.
     *
     * - Note: This method uses the Ably Chat REST API and so does not require the room to be attached to be called.
     *
     * - Parameters:
     *   - messageSerial: The unique identifier of the message
     *   - clientID: The client ID to check (defaults to current client)
     *
     * - Returns: Reaction data for the specified client.
     *
     * - Throws: ``ErrorInfo`` with code 40400 if the message does not exist.
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     * let room = try await chatClient.rooms.get(named: "large-event")
     *
     * let messageSerial = "01726585978590-001@abcdefghij:001"
     *
     * do {
     *     // Get reactions for the current client
     *     let myReactions = try await room.messages.reactions.clientReactions(
     *         forMessageWithSerial: messageSerial,
     *         clientID: nil
     *     )
     *     if myReactions.unique["👍"] != nil {
     *         print("I have reacted with 👍")
     *     }
     *     if myReactions.distinct["❤️"] != nil {
     *         print("I have reacted with ❤️")
     *     }
     *     if let voteCount = myReactions.multiple["vote-option-a"]?.clientIDs[myClientID] {
     *         print("I voted for option A: \(voteCount) times")
     *     }
     *
     *     // Check reactions for a specific client
     *     let specificClientReactions = try await room.messages.reactions.clientReactions(
     *         forMessageWithSerial: messageSerial,
     *         clientID: "specific-client-id"
     *     )
     *     print("Specific client reactions: \(specificClientReactions)")
     * } catch {
     *     print("Failed to get client reactions: \(error)")
     * }
     * ```
     */
    func clientReactions(forMessageWithSerial messageSerial: String, clientID: String?) async throws(ErrorInfo) -> MessageReactionSummary
}

/// `AsyncSequence` variant of receiving message reactions events.
public extension MessageReactions {
    /**
     * Subscribes a given listener to message reactions summary events.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``MessageReactionSummaryEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<MessageReactionSummaryEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<MessageReactionSummaryEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribe { summaryEvent in
            subscriptionAsyncSequence.emit(summaryEvent)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe() -> SubscriptionAsyncSequence<MessageReactionSummaryEvent> {
        subscribe(bufferingPolicy: .unbounded)
    }

    /**
     * Subscribes a given listener to message reactions events.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``MessageReactionRawEvent`` events.
     */
    func subscribeRaw(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<MessageReactionRawEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<MessageReactionRawEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribeRaw { reaction in
            subscriptionAsyncSequence.emit(reaction)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribeRaw() -> SubscriptionAsyncSequence<MessageReactionRawEvent> {
        subscribeRaw(bufferingPolicy: .unbounded)
    }
}

/**
 * Parameters for sending a message reaction.
 */
public struct SendMessageReactionParams: Sendable {
    /**
     * The reaction name to send; (e.g., emoji like "👍", "❤️", or custom names).
     */
    public var name: String

    /**
     * The optional type of reaction, must be one of ``MessageReactionType`` if set.
     * If not set, the default type will be used which is configured in the ``MessagesOptions/defaultMessageReactionType`` of the room.
     */
    public var type: MessageReactionType?

    /**
     * The count of the reaction for type ``MessageReactionType/multiple``.
     * Defaults to 1 if not set. Not supported for other reaction types.
     */
    public var count: Int?

    /// Creates an instance with the given property values.
    public init(name: String, type: MessageReactionType? = nil, count: Int? = nil) {
        self.name = name
        self.type = type
        self.count = count
    }
}

/**
 * Parameters for deleting a message reaction.
 */
public struct DeleteMessageReactionParams: Sendable {
    /**
     * The type of reaction, must be one of ``MessageReactionType``.
     * If not set, the default type will be used which is configured in the ``MessagesOptions/defaultMessageReactionType`` of the room.
     */
    public var type: MessageReactionType?

    /**
     * The reaction name to delete; ie. the emoji. Required for all reaction types except ``MessageReactionType/unique``.
     */
    public var name: String?

    /// Creates an instance with the given property values.
    public init(name: String? = nil, type: MessageReactionType? = nil) {
        self.name = name
        self.type = type
    }
}
