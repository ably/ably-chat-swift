import Ably
import Foundation

/**
 * ``Headers`` type for chat messages.
 */
public typealias MessageHeaders = Headers

/**
 * ``Metadata`` type for chat messages.
 */
public typealias MessageMetadata = Metadata

/**
 * ``Metadata`` type used for the metadata within an operation e.g. updating or deleting a message
 */
public typealias OperationMetadata = Metadata

/**
 * Represents a single message in a chat room.
 */
public struct Message: Sendable, Identifiable, Equatable {
    // id to meet Identifiable conformance. 2 messages in the same channel cannot have the same serial.
    public var id: String { serial }

    /**
     * The unique identifier of the message.
     */
    public var serial: String

    /**
     * The action type of the message. This can be used to determine if the message was created, updated, or deleted.
     */
    public var action: MessageAction

    /**
     * The clientId of the user who created the message.
     */

    public var clientID: String

    /**
     * The roomId of the chat room to which the message belongs.
     */
    public var roomID: String

    /**
     * The text of the message.
     */
    public var text: String

    /**
     * The timestamp at which the message was created.
     */
    public var createdAt: Date?

    /**
     * The metadata of a chat message. Allows for attaching extra info to a message,
     * which can be used for various features such as animations, effects, or simply
     * to link it to other resources such as images, relative points in time, etc.
     *
     * Metadata is part of the Ably Pub/sub message content and is not read by Ably.
     *
     * This value is always set. If there is no metadata, this is an empty object.
     *
     * Do not use metadata for authoritative information. There is no server-side
     * validation. When reading the metadata treat it like user input.
     */
    public var metadata: MessageMetadata

    /**
     * The headers of a chat message. Headers enable attaching extra info to a message,
     * which can be used for various features such as linking to a relative point in
     * time of a livestream video or flagging this message as important or pinned.
     *
     * Headers are part of the Ably realtime message extras.headers and they can be used
     * for [Filtered Subscriptions](https://faqs.ably.com/subscription-filters) and similar.
     *
     * This value is always set. If there are no headers, this is an empty object.
     *
     * Do not use the headers for authoritative information. There is no server-side
     * validation. When reading the headers treat them like user input.
     */
    public var headers: MessageHeaders

    // (CHA-M10a)
    /**
     * A unique identifier for the latest version of this message.
     */
    public var version: String

    /**
     * The timestamp at which this version was updated, deleted, or created.
     */
    public var timestamp: Date?

    /**
     * The details of the operation that modified the message. This is only set for update and delete actions. It contains
     * information about the operation: the clientId of the user who performed the operation, a description, and metadata.
     */
    public var operation: MessageOperation?

    /**
     * The reactions summary for this message.
     */
    public var reactions: MessageReactionSummary?

    public init(serial: String, action: MessageAction, clientID: String, roomID: String, text: String, createdAt: Date?, metadata: MessageMetadata, headers: MessageHeaders, version: String, timestamp: Date?, operation: MessageOperation? = nil, reactions: MessageReactionSummary? = nil) {
        self.serial = serial
        self.action = action
        self.clientID = clientID
        self.roomID = roomID
        self.text = text
        self.createdAt = createdAt
        self.metadata = metadata
        self.headers = headers
        self.version = version
        self.timestamp = timestamp
        self.operation = operation
        self.reactions = reactions
    }

    /**
      * Helper function to copy a message with updated values. This is useful when updating a message e.g. `room().messages.update(newMessage: messageCopy...)`.
      * If metadata/headers are not provided, it keeps the metadata/headers from the original message.
      * If metadata/headers are explicitly passed in, the new `Message` will have these values. You can set them to `[:]` if you wish to remove them.
     */
    public func copy(
        text: String? = nil,
        metadata: MessageMetadata? = nil,
        headers: MessageHeaders? = nil,
        reactions: MessageReactionSummary? = nil
    ) -> Message {
        Message(
            serial: serial,
            action: action,
            clientID: clientID,
            roomID: roomID,
            text: text ?? self.text,
            createdAt: createdAt,
            metadata: metadata ?? self.metadata,
            headers: headers ?? self.headers,
            version: version,
            timestamp: timestamp,
            operation: operation,
            reactions: reactions ?? self.reactions
        )
    }
}

public struct MessageOperation: Sendable, Equatable {
    public var clientID: String
    public var description: String?
    public var metadata: MessageMetadata?

    public init(clientID: String, description: String? = nil, metadata: MessageMetadata? = nil) {
        self.clientID = clientID
        self.description = description
        self.metadata = metadata
    }
}

extension Message: JSONObjectDecodable {
    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        let operationJson = try? jsonObject.objectValueForKey("operation")
        let serial = try jsonObject.stringValueForKey("serial")
        var reactionSummary: MessageReactionSummary?
        if let summaryJson = try? jsonObject.objectValueForKey("reactions"), !summaryJson.isEmpty {
            reactionSummary = try MessageReactionSummary(
                messageSerial: serial,
                values: summaryJson
            )
        }
        try self.init(
            serial: serial,
            action: jsonObject.rawRepresentableValueForKey("action"),
            clientID: jsonObject.stringValueForKey("clientId"),
            roomID: jsonObject.stringValueForKey("roomId"),
            text: jsonObject.stringValueForKey("text"),
            createdAt: jsonObject.optionalAblyProtocolDateValueForKey("createdAt"),
            metadata: jsonObject.objectValueForKey("metadata"),
            headers: jsonObject.objectValueForKey("headers").ablyChat_mapValuesWithTypedThrow { jsonValue throws(InternalError) in
                try .init(jsonValue: jsonValue)
            },
            version: jsonObject.stringValueForKey("version"),
            timestamp: jsonObject.optionalAblyProtocolDateValueForKey("timestamp"),
            operation: operationJson.map { op throws(InternalError) in
                try .init(
                    clientID: op.stringValueForKey("clientId"),
                    description: try? op.stringValueForKey("description"),
                    metadata: try? op.objectValueForKey("metadata")
                )
            },
            reactions: reactionSummary
        )
    }
}

public extension Message {
    /**
     * Creates a new message instance with the event applied.
     *
     * - Parameters:
     *   - summaryEvent: The event to be applied to the returned message.
     *
     * - Throws: ``ARTErrorInfo`` if the event is for a different message.
     *
     * - Returns: A new message instance with the event applied.
     */
    func with(summaryEvent: MessageReactionSummaryEvent) throws(ARTErrorInfo) -> Self {
        // (CHA-M11e) For MessageReactionSummaryEvent, the method must verify that the summary.messageSerial in the event matches the message’s own serial. If they don’t match, an error with code 40000 and status code 400 must be thrown.
        guard serial == summaryEvent.summary.messageSerial else {
            throw ARTErrorInfo(chatError: .cannotApplyEventForDifferentMessage)
        }
        return copy(reactions: summaryEvent.summary)
    }
}
