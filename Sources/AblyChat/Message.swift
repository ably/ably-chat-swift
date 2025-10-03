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
     * The text of the message.
     */
    public var text: String

    /**
     * The timestamp at which the message was created.
     */
    public var timestamp: Date

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

    /**
     * Information about the latest version of this message.
     */
    public var version: MessageVersion

    /**
     * The reactions summary for this message.
     */
    public var reactions: MessageReactionSummary?

    public init(serial: String, action: MessageAction, clientID: String, text: String, metadata: MessageMetadata, headers: MessageHeaders, version: MessageVersion, timestamp: Date, reactions: MessageReactionSummary? = nil) {
        self.serial = serial
        self.action = action
        self.clientID = clientID
        self.text = text
        self.metadata = metadata
        self.headers = headers
        self.version = version
        self.timestamp = timestamp
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
        reactions: MessageReactionSummary? = nil,
    ) -> Message {
        Message(
            serial: serial,
            action: action,
            clientID: clientID,
            text: text ?? self.text,
            metadata: metadata ?? self.metadata,
            headers: headers ?? self.headers,
            version: version,
            timestamp: timestamp,
            reactions: reactions ?? self.reactions,
        )
    }
}

public struct MessageVersion: Sendable, Equatable {
    /**
     * A unique identifier for the latest version of this message.
     */
    public var serial: String

    /**
     * The timestamp at which this version was updated, deleted, or created.
     */
    public var timestamp: Date

    /**
     * The optional clientId of the user who performed the update or deletion.
     */
    public var clientID: String?

    /**
     * The optional description for the update or deletion.
     */
    public var description: String?

    /**
     * The optional metadata associated with the update or deletion.
     */
    public var metadata: MessageMetadata?

    public init(serial: String, timestamp: Date, clientID: String? = nil, description: String? = nil, metadata: MessageMetadata? = nil) {
        self.serial = serial
        self.timestamp = timestamp
        self.clientID = clientID
        self.description = description
        self.metadata = metadata
    }
}

extension Message: JSONObjectDecodable {
    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        let serial = try jsonObject.stringValueForKey("serial")
        var reactionSummary: MessageReactionSummary?
        if let summaryJson = try? jsonObject.objectValueForKey("reactions"), !summaryJson.isEmpty {
            reactionSummary = MessageReactionSummary(
                messageSerial: serial,
                values: summaryJson,
            )
        }
        let rawAction = try jsonObject.stringValueForKey("action")
        guard let action = MessageAction(rawValue: rawAction) else {
            throw JSONValueDecodingError.failedToDecodeFromRawValue(rawAction).toInternalError()
        }
        let timestamp = try jsonObject.optionalAblyProtocolDateValueForKey("timestamp") ?? Date(timeIntervalSince1970: 0) // CHA-M4k5
        try self.init(
            serial: serial,
            action: action,
            clientID: jsonObject.stringValueForKey("clientId"),
            text: jsonObject.stringValueForKey("text"),
            metadata: jsonObject.objectValueForKey("metadata"),
            headers: jsonObject.objectValueForKey("headers").ablyChat_mapValuesWithTypedThrow { jsonValue throws(InternalError) in
                try .init(jsonValue: jsonValue)
            },
            version: .init(jsonObject: jsonObject.objectValueForKey("version"), defaultTimestamp: timestamp),
            timestamp: timestamp,
            reactions: reactionSummary,
        )
    }
}

extension MessageVersion {
    // It's a conflicting rule: explicit_acl vs extensionAccessControl
    // swiftlint:disable:next explicit_acl
    init(jsonObject: [String: JSONValue], defaultTimestamp: Date) throws(InternalError) {
        try self.init(
            serial: jsonObject.stringValueForKey("serial"),
            timestamp: jsonObject.optionalAblyProtocolDateValueForKey("timestamp") ?? defaultTimestamp,
            clientID: jsonObject.optionalStringValueForKey("clientId"),
            description: jsonObject.optionalStringValueForKey("description"),
            metadata: jsonObject.optionalObjectValueForKey("metadata"),
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
