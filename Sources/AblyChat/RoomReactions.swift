import Ably

/**
 * This interface is used to interact with room-level reactions in a chat room: subscribing to reactions and sending them.
 *
 * Get an instance via ``Room/reactions``.
 */
public protocol RoomReactions: AnyObject, Sendable, EmitsDiscontinuities {
    /**
     * Send a reaction to the room including some metadata.
     *
     * - Parameters:
     *   - params: An object containing `type` and optional `headers` with `metadata`.
     *
     * - Note: It is possible to receive your own reaction via the reactions subscription before this method returns.
     */
    func send(params: SendReactionParams) async throws

    /**
     * Returns an instance of the Ably realtime channel used for room-level reactions.
     * Avoid using this directly unless special features that cannot otherwise be implemented are needed.
     *
     * - Returns: The realtime channel.
     */
    var channel: RealtimeChannelProtocol { get }

    /**
     * Subscribes a given listener to receive room-level reactions.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``Reaction`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<Reaction>

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `RoomReactions` protocol provides a default implementation of this method.
    func subscribe() async -> Subscription<Reaction>
}

public extension RoomReactions {
    func subscribe() async -> Subscription<Reaction> {
        await subscribe(bufferingPolicy: .unbounded)
    }
}

/**
 * Params for sending a room-level reactions. Only `type` is mandatory.
 */
public struct SendReactionParams: Sendable {
    /**
     * The type of the reaction, for example an emoji or a short string such as "like".
     * It is the only mandatory parameter to send a room-level reaction.
     */
    public var type: String

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

    public init(type: String, metadata: ReactionMetadata? = nil, headers: ReactionHeaders? = nil) {
        self.type = type
        self.metadata = metadata
        self.headers = headers
    }
}

internal extension SendReactionParams {
    /// Returns a dictionary that `JSONSerialization` can serialize to a JSON "object" value.
    ///
    /// Suitable to pass as the `data` argument of an ably-cocoa publish operation.
    func asJSONObject() -> [String: String] {
        var dict: [String: String] = [:]
        dict["type"] = "\(type)"
        dict["metadata"] = "\(metadata ?? [:])"
        return dict
    }
}
