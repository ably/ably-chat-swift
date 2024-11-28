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

public struct SendReactionParams: Sendable {
    public var type: String
    public var metadata: ReactionMetadata?
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
