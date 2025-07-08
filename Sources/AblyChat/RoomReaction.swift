import Foundation

/**
 * ``Headers`` type for chat reactions.
 */
public typealias ReactionHeaders = Headers

/**
 * ``Metadata`` type for chat reactions.
 */
public typealias ReactionMetadata = Metadata

// (CHA-ER2) A Reaction corresponds to a single reaction in a chat room. This is analogous to a single user-specified message on an Ably channel (NOTE: not a ProtocolMessage).

/**
 * Represents a room-level reaction.
 */
public struct RoomReaction: Sendable {
    /**
     * The type of the reaction, for example "like" or "love".
     */
    public var name: String

    /**
     * Metadata of the reaction. If no metadata was set this is an empty object.
     */
    public var metadata: ReactionMetadata

    /**
     * Headers of the reaction. If no headers were set this is an empty object.
     */
    public var headers: ReactionHeaders

    /**
     * The timestamp at which the reaction was sent.
     */
    public var createdAt: Date

    /**
     * The clientId of the user who sent the reaction.
     */
    public var clientID: String

    /**
     * Whether the reaction was sent by the current user.
     */
    public var isSelf: Bool

    public init(name: String, metadata: ReactionMetadata, headers: ReactionHeaders, createdAt: Date, clientID: String, isSelf: Bool) {
        self.name = name
        self.metadata = metadata
        self.headers = headers
        self.createdAt = createdAt
        self.clientID = clientID
        self.isSelf = isSelf
    }
}
