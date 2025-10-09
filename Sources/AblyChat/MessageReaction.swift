import Ably

/**
 * Enum representing different raw message reaction events in the chat system.
 */
public enum MessageReactionRawEventType: Sendable {
    /**
     * A reaction was added to a message.
     */
    case create
    /**
     * A reaction was removed from a message.
     */
    case delete

    internal var rawValue: String {
        switch self {
        case .create:
            "reaction.create"
        case .delete:
            "reaction.delete"
        }
    }
}

internal extension MessageReactionRawEventType {
    static func fromAnnotationAction(_ annotationAction: ARTAnnotationAction) -> Self? {
        switch annotationAction {
        case .create:
            .create
        case .delete:
            .delete
        @unknown default:
            nil
        }
    }
}

/**
 * Enum representing different message reaction summary events in the chat system.
 */
public enum MessageReactionSummaryEventType: Sendable {
    /**
     * A reactions summary was updated for a message.
     */
    case summary
}

/**
 * Represents a message-level reaction.
 */
public struct MessageReaction: Sendable {
    /**
     * The reaction type (Unique, Distinct, or Multiple).
     */
    public var type: MessageReactionType
    /**
     * The reaction itself, typically an emoji.
     */
    public var name: String

    /**
     * The serial of the message, for which this reaction was created.
     */
    public var messageSerial: String

    /**
     * An optional count field for reactions of type "multiple".
     */
    public var count: Int?

    /**
     * The clientId of the user who sent the reaction.
     */
    public var clientID: String

    /**
     * Whether the reaction was sent by the current user.
     */
    public var isSelf: Bool

    /// Memberwise initializer to create a `MessageReaction`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: MessageReactionType, name: String, messageSerial: String, count: Int? = nil, clientID: String, isSelf: Bool) {
        self.type = type
        self.name = name
        self.messageSerial = messageSerial
        self.count = count
        self.clientID = clientID
        self.isSelf = isSelf
    }
}

/**
 * All annotation types supported by Chat Message Reactions.
 */
public enum MessageReactionType: Sendable {
    /**
     * Allows for at most one reaction per client per message. If a client reacts
     * to a message a second time, only the second reaction is counted in the
     * summary.
     *
     * This is similar to reactions on iMessage, Facebook Messenger or WhatsApp.
     */
    case unique

    /**
     * Allows for at most one reaction of each type per client per message. It is
     * possible for a client to add multiple reactions to the same message as
     * long as they are different (eg different emojis). Duplicates are not
     * counted in the summary.
     *
     * This is similar to reactions on Slack.
     */
    case distinct

    /**
     * Allows any number of reactions, including repeats, and they are counted in
     * the summary. The reaction payload also includes a count of how many times
     * each reaction should be counted (defaults to 1 if not set).
     *
     * This is similar to the clap feature on Medium or how room reactions work.
     */
    case multiple
}

extension MessageReactionType: InternalRawRepresentable {
    internal typealias RawValue = String

    internal enum Wire: String, Sendable {
        case unique = "reaction:unique.v1"
        case distinct = "reaction:distinct.v1"
        case multiple = "reaction:multiple.v1"
    }

    internal init?(rawValue: String) {
        switch Wire(rawValue: rawValue) {
        case .unique:
            self = .unique
        case .distinct:
            self = .distinct
        case .multiple:
            self = .multiple
        default:
            return nil
        }
    }

    internal var rawValue: String {
        switch self {
        case .unique:
            Wire.unique.rawValue
        case .distinct:
            Wire.distinct.rawValue
        case .multiple:
            Wire.multiple.rawValue
        }
    }
}

/**
 * Represents a summary of all reactions on a message.
 */
public struct MessageReactionSummary: Sendable, Equatable {
    /**
     * Map of reaction to the summary (total and clients) for reactions of type ``MessageReactionType/unique`` and ``MessageReactionType/distinct``.
     */
    public struct ClientIDList: Sendable, Equatable {
        /**
         * Total amount of reactions of a given type.
         */
        public var total: Int

        /**
         * List of clients who left given reaction type.
         */
        public var clientIDs: [String]

        /**
         * Whether the list of clientIDs has been clipped due to exceeding the maximum number of
         * clients.
         */
        public var clipped: Bool // TM7c1c

        // swiftlint:disable:next missing_docs
        public init(total: Int, clientIDs: [String], clipped: Bool) {
            self.total = total
            self.clientIDs = clientIDs
            self.clipped = clipped
        }
    }

    /**
     * Map of reaction to the summary (total and clients) for reactions of type ``MessageReactionType/multiple``.
     */
    public struct ClientIDCounts: Sendable, Equatable {
        /**
         * Total amount of reactions of a given type.
         */
        public var total: Int

        /**
         * Map of clients who left given reaction type number of times.
         */
        public var clientIDs: [String: Int]

        /**
         * The sum of the counts from all unidentified clients who have published an annotation with this
         * name, and so who are not included in the clientIDs list
         */
        public var totalUnidentified: Int // TM7d1d

        /**
         * Whether the list of clientIDs has been clipped due to exceeding the maximum number of
         * clients.
         */
        public var clipped: Bool // TM7d1c

        /**
         * The total number of distinct clientIDs in the map (equal to length of map if clipped is false).
         */
        public var totalClientIDs: Int // TM7d1e

        // swiftlint:disable:next missing_docs
        public init(total: Int, clientIDs: [String: Int], totalUnidentified: Int, clipped: Bool, totalClientIDs: Int) {
            self.total = total
            self.clientIDs = clientIDs
            self.totalUnidentified = totalUnidentified
            self.clipped = clipped
            self.totalClientIDs = totalClientIDs
        }
    }

    /**
     * Reference to the original message's serial.
     */
    public var messageSerial: String

    /**
     * Map of unique-type reactions summaries.
     */
    public var unique: [String: ClientIDList]

    /**
     * Map of distinct-type reactions summaries.
     */
    public var distinct: [String: ClientIDList]

    /**
     * Map of multiple-type reactions summaries.
     */
    public var multiple: [String: ClientIDCounts]

    /// Memberwise initializer to create a `MessageReactionSummary`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(messageSerial: String, unique: [String: MessageReactionSummary.ClientIDList], distinct: [String: MessageReactionSummary.ClientIDList], multiple: [String: MessageReactionSummary.ClientIDCounts]) {
        self.messageSerial = messageSerial
        self.unique = unique
        self.distinct = distinct
        self.multiple = multiple
    }

    /// Create an empty `MessageReactionSummary` with the given `messageSerial`.
    internal static func empty(withMessageSerial messageSerial: String) -> Self {
        .init(
            messageSerial: messageSerial,
            unique: [:],
            distinct: [:],
            multiple: [:],
        )
    }
}

/**
 * Event interface representing a summary of message reactions.
 * This event aggregates different types of reactions (single, distinct, multiple) for a specific message.
 */
public struct MessageReactionSummaryEvent: Sendable, Equatable {
    /**
     * The type of the event (should be equal to summary).
     */
    public var type: MessageReactionSummaryEventType

    /**
     * The message reactions summary.
     */
    public var summary: MessageReactionSummary

    /// Memberwise initializer to create a `MessageReactionSummaryEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: MessageReactionSummaryEventType, summary: MessageReactionSummary) {
        self.type = type
        self.summary = summary
    }
}

/**
 * Represents an individual message reaction event.
 */
public struct MessageReactionRawEvent: Sendable {
    /**
     * Whether reaction was added or removed.
     */
    public var type: MessageReactionRawEventType

    /**
     * The timestamp of this event.
     */
    public var timestamp: Date?

    /**
     * The message reaction that was received.
     */
    public var reaction: MessageReaction

    /// Memberwise initializer to create a `MessageReactionRawEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: MessageReactionRawEventType, timestamp: Date? = nil, reaction: MessageReaction) {
        self.type = type
        self.timestamp = timestamp
        self.reaction = reaction
    }
}
