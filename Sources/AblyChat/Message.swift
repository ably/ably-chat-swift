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
public typealias MessageOperationMetadata = OperationMetadata

/**
 * Represents a single message in a chat room.
 */
public struct Message: Sendable, Equatable {
    /**
     * The unique identifier of the message.
     */
    public var serial: String

    /**
     * The action type of the message. This can be used to determine if the message was created, updated, or deleted.
     */
    public var action: ChatMessageAction

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
    public var reactions: MessageReactionSummary

    /// Memberwise initializer to create a `Message`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(serial: String, action: ChatMessageAction, clientID: String, text: String, metadata: MessageMetadata, headers: MessageHeaders, version: MessageVersion, timestamp: Date, reactions: MessageReactionSummary) {
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
      * Helper function to copy a message with its properties replaced per the parameters.
      *
      * If an argument is omitted or `nil`, then the current value of that property will be preserved.
     */
    public func copy(
        text: String? = nil,
        metadata: MessageMetadata? = nil,
        headers: MessageHeaders? = nil,
    ) -> Message {
        var copied = self

        if let text {
            copied.text = text
        }

        if let metadata {
            copied.metadata = metadata
        }

        if let headers {
            copied.headers = headers
        }

        return copied
    }
}

/// Represents the version information for a message.
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
    public var metadata: MessageOperationMetadata?

    /// Memberwise initializer to create a `MessageVersion`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(serial: String, timestamp: Date, clientID: String? = nil, description: String? = nil, metadata: MessageOperationMetadata? = nil) {
        self.serial = serial
        self.timestamp = timestamp
        self.clientID = clientID
        self.description = description
        self.metadata = metadata
    }
}

extension Message: JSONObjectDecodable {
    internal init(jsonObject: [String: JSONValue]) throws(ErrorInfo) {
        let serial = try jsonObject.stringValueForKey("serial")
        let reactionSummary: MessageReactionSummary = if let summaryJson = try? jsonObject.objectValueForKey("reactions"), !summaryJson.isEmpty {
            MessageReactionSummary(
                values: summaryJson,
            )
        } else {
            .empty
        }
        let rawAction = try jsonObject.stringValueForKey("action")
        guard let action = ChatMessageAction(rawValue: rawAction) else {
            throw JSONValueDecodingError.failedToDecodeFromRawValue(type: ChatMessageAction.self, rawValue: rawAction).toErrorInfo()
        }
        let timestamp = try jsonObject.optionalAblyProtocolDateValueForKey("timestamp") ?? Date(timeIntervalSince1970: 0) // CHA-M4k5
        try self.init(
            serial: serial,
            action: action,
            clientID: jsonObject.stringValueForKey("clientId"),
            text: jsonObject.stringValueForKey("text"),
            metadata: jsonObject.objectValueForKey("metadata"),
            headers: jsonObject.objectValueForKey("headers").ablyChat_mapValuesWithTypedThrow { jsonValue throws(ErrorInfo) in
                try .init(jsonValue: jsonValue)
            },
            version: .init(jsonObject: jsonObject.objectValueForKey("version"), defaultTimestamp: timestamp),
            timestamp: timestamp,
            reactions: reactionSummary,
        )
    }
}

internal extension MessageVersion {
    init(jsonObject: [String: JSONValue], defaultTimestamp: Date) throws(ErrorInfo) {
        try self.init(
            serial: jsonObject.stringValueForKey("serial"),
            timestamp: jsonObject.optionalAblyProtocolDateValueForKey("timestamp") ?? defaultTimestamp,
            clientID: jsonObject.optionalStringValueForKey("clientId"),
            description: jsonObject.optionalStringValueForKey("description"),
            metadata: jsonObject.optionalObjectValueForKey("metadata")?.compactMapValues { $0.stringValue },
        )
    }
}

/// Extension providing message reaction summary utilities.
public extension Message {
    /**
     * Creates a new message instance with the event applied.
     *
     * - Parameters:
     *   - summaryEvent: The event to be applied to the returned message.
     *
     * - Throws: ``ErrorInfo`` if the event is for a different message.
     *
     * - Returns: A new message instance with the event applied.
     */
    func with(_ summaryEvent: MessageReactionSummaryEvent) throws(ErrorInfo) -> Self {
        // (CHA-M11j) For MessageReactionSummaryEvent, the method must verify that the summary.messageSerial in the event matches the message's own serial. If they don't match, an error with code InvalidArgument must be thrown.
        guard serial == summaryEvent.messageSerial else {
            throw InternalError.cannotApplyReactionSummaryEventForDifferentMessage.toErrorInfo()
        }

        var newMessage = self
        newMessage.reactions = summaryEvent.reactions
        return newMessage
    }

    /**
     * Creates a new message instance with the message event applied.
     *
     * - Parameters:
     *   - messageEvent: The message event to be applied to the returned message.
     *
     * - Throws: ``ErrorInfo`` if the event is for a different message, if it's a created event, or if there are other validation errors.
     *
     * - Returns: A new message instance with the event applied, or the original message if the event is older.
     */
    func with(_ messageEvent: ChatMessageEvent) throws(ErrorInfo) -> Self {
        // (CHA-M11h) When the method receives a MessageEvent of type created, it must throw an ErrorInfo with code InvalidArgument.
        if messageEvent.type == .created {
            throw InternalError.cannotApplyCreatedMessageEvent.toErrorInfo()
        }

        // (CHA-M11i) For MessageEvent the method must verify that the message.serial in the event matches the message's own serial. If they don't match, an error with code InvalidArgument must be thrown.
        guard serial == messageEvent.message.serial else {
            throw InternalError.cannotApplyMessageEventForDifferentMessage.toErrorInfo()
        }

        // (CHA-M11c) For MessageEvent of type update and delete, if the event message is older or the same, the original message must be returned unchanged.
        // (CHA-M10e) To sort Message versions of the same Message (instances with the same serial) in global order, sort Message instances lexicographically by their version.serial property.
        if messageEvent.message.version.serial <= version.serial {
            return self
        }

        // (CHA-M11d) For MessageEvent of type update and delete, if the event message is newer, the method must return a new message based on the event and deep-copying the reactions from the original message.
        var newMessage = messageEvent.message
        newMessage.reactions = reactions
        return newMessage
    }
}
