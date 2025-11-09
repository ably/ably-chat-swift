import Ably

/**
 * This interface is used to interact with room-level reactions in a chat room: subscribing to reactions and sending them.
 *
 * Get an instance via ``Room/reactions``.
 */
@MainActor
public protocol RoomReactions: AnyObject, Sendable {
    // swiftlint:disable:next missing_docs
    associatedtype Subscription: AblyChat.Subscription

    /**
     * Sends a room-level reaction.
     *
     * Room reactions are ephemeral events that are not associated with specific messages.
     * They're commonly used for live interactions like floating emojis, applause, or other
     * real-time feedback in chat rooms. Unlike message reactions, room reactions are not
     * persisted and are only visible to users currently connected to the room.
     *
     * - Note:
     *   - The room should be attached to send room reactions.
     *   - It is possible (though unlikely) to receive your own reaction via subscription before this method returns.
     *
     * - Parameters:
     *   - params: The reaction parameters
     *
     * - Throws:
     *   - ``ErrorInfo`` with code ``InternalError/ErrorCode/invalidArgument`` if name is not provided
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get(named: "live-event")
     *
     * // Attach to the room to send room reactions
     * try await room.attach()
     *
     * // Send a simple room reaction
     * do {
     *     try await room.reactions.send(withParams: .init(
     *         name: "❤️"
     *     ))
     *     print("Heart reaction sent to room")
     * } catch {
     *     print("Failed to send reaction: \(error)")
     * }
     * ```
     */
    func send(withParams params: SendReactionParams) async throws(ErrorInfo)

    /**
     * Subscribes to room-level reaction events.
     *
     * Receives all room reactions sent by any user in the room. This is useful for
     * displaying floating reactions, triggering animations, or showing live audience
     * engagement in real-time. Room reactions are ephemeral and not persisted.
     *
     * - Note: The room should be attached to receive reaction events.
     *
     * - Parameters:
     *   - callback: Callback invoked when a room reaction is received
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
     * let room = try await chatClient.rooms.get(named: "webinar-room")
     *
     * // Subscribe to room reactions for live animations
     * let subscription = room.reactions.subscribe { event in
     *     let reaction = event.reaction
     *
     *     print("\(reaction.clientID) sent \(reaction.name)")
     *     print("Sent at: \(reaction.createdAt)")
     *
     *     // Handle different reaction types
     *     switch reaction.name {
     *     case "❤️":
     *         // Show floating heart animation
     *         showFloatingHeart(reaction.isSelf ? "own" : "other")
     *     case "👏":
     *         // Show applause indicator
     *         showApplauseAnimation(reaction.clientID)
     *     default:
     *         // Handle generic reactions
     *         showGenericReaction(reaction.name)
     *     }
     *
     *     // Check if reaction is from current user
     *     if reaction.isSelf {
     *         print("You sent a reaction: \(reaction.name)")
     *     }
     * }
     *
     * // Attach to the room to start receiving reactions
     * try await room.attach()
     *
     * // Later, unsubscribe when done
     * subscription.unsubscribe()
     * ```
     */
    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (RoomReactionEvent) -> Void) -> Subscription
}

/// `AsyncSequence` variant of receiving room reactions.
public extension RoomReactions {
    /**
     * Subscribes a given listener to receive room-level reactions.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through `RoomReactionEvent` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<RoomReactionEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<RoomReactionEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribe { event in
            subscriptionAsyncSequence.emit(event)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe() -> SubscriptionAsyncSequence<RoomReactionEvent> {
        subscribe(bufferingPolicy: .unbounded)
    }
}

/**
 * Params for sending a room-level reactions. Only `name` is mandatory.
 */
public struct SendReactionParams: Sendable {
    /**
     * The name of the reaction, for example an emoji or a short string (e.g., "❤️", "👏", "confetti", "applause").
     *
     * It is the only mandatory parameter to send a room-level reaction.
     */
    public var name: String

    /**
     * Optional metadata of the reaction.
     *
     * The metadata is a map of extra information that can be attached to the
     * room reaction. It is not used by Ably and is sent as part of the realtime
     * message payload. Example use cases are custom animations or other effects.
     *
     * Do not use metadata for authoritative information. There is no server-side
     * validation. When reading the metadata treat it like user input.
     */
    public var metadata: RoomReactionMetadata?

    /**
     * Optional headers of the room reaction.
     *
     * The headers are a flat key-value map and are sent as part of the realtime
     * message's `extras` inside the `headers` property. They can serve similar
     * purposes as the metadata but they are read by Ably and can be used for
     * features such as
     * [subscription filters](https://faqs.ably.com/subscription-filters).
     *
     * Do not use the headers for authoritative information. There is no
     * server-side validation. When reading the headers treat them like user
     * input.
     */
    public var headers: RoomReactionHeaders?

    /// Creates an instance with the given property values.
    public init(name: String, metadata: RoomReactionMetadata? = nil, headers: RoomReactionHeaders? = nil) {
        self.name = name
        self.metadata = metadata
        self.headers = headers
    }
}

/**
 * The type of room reaction events.
 */
public enum RoomReactionEventType: Sendable {
    /**
     * Event triggered when a room reaction was received.
     */
    case reaction
}

/**
 * Event that is emitted when a room reaction is received.
 */
public struct RoomReactionEvent: Sendable {
    /**
     * The type of the event.
     */
    public var type: RoomReactionEventType

    /**
     * The reaction that was received.
     */
    public var reaction: RoomReaction

    /// Memberwise initializer to create a `RoomReactionEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: RoomReactionEventType = .reaction, reaction: RoomReaction) {
        self.type = type
        self.reaction = reaction
    }
}
