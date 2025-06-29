import Foundation

/**
 * Enum representing different message reaction events in the chat system.
 */
public enum MessageReactionEvent: String, Sendable {
    /**
     * A reaction was added to a message.
     */
    case create = "reaction.create"
    /**
     * A reaction was removed from a message.
     */
    case delete = "reaction.delete"
    /**
     * A reactions summary was updated for a message.
     */
    case summary = "reaction.summary"
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
public enum MessageReactionType: String, Sendable {
    /**
     * Allows for at most one reaction per client per message. If a client reacts
     * to a message a second time, only the second reaction is counted in the
     * summary.
     *
     * This is similar to reactions on iMessage, Facebook Messenger or WhatsApp.
     */
    case unique = "reaction:unique.v1"

    /**
     * Allows for at most one reaction of each type per client per message. It is
     * possible for a client to add multiple reactions to the same message as
     * long as they are different (eg different emojis). Duplicates are not
     * counted in the summary.
     *
     * This is similar to reactions on Slack.
     */
    case distinct = "reaction:distinct.v1"

    /**
     * Allows any number of reactions, including repeats, and they are counted in
     * the summary. The reaction payload also includes a count of how many times
     * each reaction should be counted (defaults to 1 if not set).
     *
     * This is similar to the clap feature on Medium or how room reactions work.
     */
    case multiple = "reaction:multiple.v1"
}

/**
 * Represents a summary of all reactions on a message.
 */
public struct MessageReactionSummary: Sendable, Equatable {
    /**
     * Map of reaction to the summary (total and clients) for reactions of type ``MessageReactionType/unique`` and ``MessageReactionType/distinct``.
     */
    public struct ClientIdList: Sendable, Equatable {
        /**
         * Total amount of reactions of a given type.
         */
        public var total: UInt

        /**
         * List of clients who left given reaction type.
         */
        public var clientIds: [String]
    }

    /**
     * Map of reaction to the summary (total and clients) for reactions of type ``MessageReactionType/multiple``.
     */
    public struct ClientIdCounts: Sendable, Equatable {
        /**
         * Total amount of reactions of a given type.
         */
        public var total: UInt

        /**
         * Map of clients who left given reaction type number of times.
         */
        public var clientIds: [String: UInt]
    }

    /**
     * Reference to the original message's serial.
     */
    public var messageSerial: String

    /**
     * Map of unique-type reactions summaries.
     */
    public var unique: [String: ClientIdList]

    /**
     * Map of distinct-type reactions summaries.
     */
    public var distinct: [String: ClientIdList]

    /**
     * Map of multiple-type reactions summaries.
     */
    public var multiple: [String: ClientIdCounts]
}

/**
 * Event interface representing a summary of message reactions.
 * This event aggregates different types of reactions (single, distinct, multiple) for a specific message.
 */
public struct MessageReactionSummaryEvent: Sendable, Equatable {
    /**
     * The type of the event (should be equal to summary).
     */
    public var type: MessageReactionEvent

    /**
     * The message reactions summary.
     */
    public var summary: MessageReactionSummary
}

/**
 * Represents an individual message reaction event.
 */
public struct MessageReactionRawEvent: Sendable {
    /**
     * Whether reaction was added or removed.
     */
    public var type: MessageReactionEvent

    /**
     * The timestamp of this event.
     */
    public var timestamp: Date?

    /**
     * The message reaction that was received.
     */
    public var reaction: MessageReaction
}
