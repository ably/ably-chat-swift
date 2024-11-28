import Ably

/**
 * This interface is used to interact with room-level reactions in a chat room: subscribing to reactions and sending them.
 *
 * Get an instance via {@link Room.reactions}.
 */
public protocol RoomReactions: AnyObject, Sendable, EmitsDiscontinuities {
    /**
     * Send a reaction to the room including some metadata.
     *
     * This method accepts parameters for a room-level reaction. It accepts an object
     *
     *
     * @param params an object containing {type, headers, metadata} for the room
     * reaction to be sent. Type is required, metadata and headers are optional.
     * @returns The returned promise resolves when the reaction was sent. Note
     * that it is possible to receive your own reaction via the reactions
     * listener before this promise resolves.
     */
    func send(params: SendReactionParams) async throws

    /**
     * Returns an instance of the Ably realtime channel used for room-level reactions.
     * Avoid using this directly unless special features that cannot otherwise be implemented are needed.
     *
     * @returns The Ably realtime channel.
     */
    var channel: RealtimeChannelProtocol { get }

    /**
     * Send a reaction to the room including some metadata.
     *
     * This method accepts parameters for a room-level reaction. It accepts an object
     *
     *
     * @param params an object containing {type, headers, metadata} for the room
     * reaction to be sent. Type is required, metadata and headers are optional.
     * @returns The returned promise resolves when the reaction was sent. Note
     * that it is possible to receive your own reaction via the reactions
     * listener before this promise resolves.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<Reaction>
}

/**
 * Params for sending a room-level reactions. Only `type` is mandatory.
 */
public struct SendReactionParams: Sendable {
    /**
     * The type of the reaction, for example an emoji or a short string such as
     * "like".
     *
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
     *
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
     *
     */
    public var headers: ReactionHeaders?

    public init(type: String, metadata: ReactionMetadata? = nil, headers: ReactionHeaders? = nil) {
        self.type = type
        self.metadata = metadata
        self.headers = headers
    }
}

internal extension SendReactionParams {
    // Same as `ARTDataQuery.asQueryItems` from ably-cocoa.
    func asQueryItems() -> [String: String] {
        var dict: [String: String] = [:]
        dict["type"] = "\(type)"
        dict["metadata"] = "\(metadata ?? [:])"
        return dict
    }
}
