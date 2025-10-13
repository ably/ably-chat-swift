import Foundation

/**
 * ``Headers`` type for chat reactions.
 */
public typealias RoomReactionHeaders = Headers

/**
 * ``Metadata`` type for chat reactions.
 */
public typealias RoomReactionMetadata = Metadata

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
    public var metadata: RoomReactionMetadata

    /**
     * Headers of the reaction. If no headers were set this is an empty object.
     */
    public var headers: RoomReactionHeaders

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

    /// Memberwise initializer to create a `RoomReaction`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(name: String, metadata: RoomReactionMetadata, headers: RoomReactionHeaders, createdAt: Date, clientID: String, isSelf: Bool) {
        self.name = name
        self.metadata = metadata
        self.headers = headers
        self.createdAt = createdAt
        self.clientID = clientID
        self.isSelf = isSelf
    }
}
