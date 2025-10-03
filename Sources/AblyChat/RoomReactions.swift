import Ably

/**
 * This interface is used to interact with room-level reactions in a chat room: subscribing to reactions and sending them.
 *
 * Get an instance via ``Room/reactions``.
 */
@MainActor
public protocol RoomReactions: AnyObject, Sendable {
    associatedtype Subscription: SubscriptionProtocol

    /**
     * Send a reaction to the room including some metadata.
     *
     * - Parameters:
     *   - params: An object containing `type` and optional `headers` with `metadata`.
     *
     * - Note: It is possible to receive your own reaction via the reactions subscription before this method returns.
     */
    func send(params: SendReactionParams) async throws(ARTErrorInfo)

    /**
     * Subscribes a given listener to the room reactions.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing room `RoomReactionEvent`.
     *
     * - Returns: A subscription that can be used to unsubscribe from `RoomReactionEvent` events.
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
     * The name of the reaction, for example an emoji or a short string such as "like".
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
    public var metadata: ReactionMetadata?

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
    public var headers: ReactionHeaders?

    public init(name: String, metadata: ReactionMetadata? = nil, headers: ReactionHeaders? = nil) {
        self.name = name
        self.metadata = metadata
        self.headers = headers
    }
}

/// Event type for room reaction subscription.
public enum RoomReactionEventType: String, Sendable {
    case reaction
}

/// Event emitted by room reaction subscriptions, containing the type and the reaction.
public struct RoomReactionEvent: Sendable {
    public let type: RoomReactionEventType
    public let reaction: RoomReaction
    public init(type: RoomReactionEventType = .reaction, reaction: RoomReaction) {
        self.type = type
        self.reaction = reaction
    }
}
