import Foundation

/**
 * Represents the options for a given chat room.
 */
public struct RoomOptions: Sendable {
    /**
     * The presence options for the room.
     */
    public var presence = PresenceOptions()

    /**
     * The typing options for the room.
     */
    public var typing = TypingOptions()

    /**
     * The occupancy options for the room.
     */
    public var occupancy = OccupancyOptions()

    /**
     * The message options for the room. Messages are always enabled, this object is for additional configuration.
     */
    public var messages = MessagesOptions()

    // swiftlint:disable:next missing_docs
    public init(messages: MessagesOptions = MessagesOptions(), presence: PresenceOptions = PresenceOptions(), typing: TypingOptions = TypingOptions(), occupancy: OccupancyOptions = OccupancyOptions()) {
        self.messages = messages
        self.presence = presence
        self.typing = typing
        self.occupancy = occupancy
    }
}

/**
 * Represents the presence options for a chat room.
 */
public struct PresenceOptions: Sendable {
    /**
     * Whether or not the client should receive presence events from the server. This setting
     * can be disabled if you are using presence in your Chat Room, but this particular client does not
     * need to receive the messages.
     *
     * Defaults to true.
     */
    public var enableEvents = true

    // swiftlint:disable:next missing_docs
    public init(enableEvents: Bool = true) {
        self.enableEvents = enableEvents
    }
}

/**
 * Represents the message options for a chat room.
 */
public struct MessagesOptions: Sendable {
    /**
     * Whether to enable receiving raw individual message reactions from the
     * realtime channel. Set to true if subscribing to raw message reactions.
     *
     * Note reaction summaries (aggregates) are always available regardless of
     * this setting.
     *
     * Defaults to false.
     */
    public var rawMessageReactions = false

    /**
     * The default message reaction type to use for sending message reactions.
     *
     * Any message reaction type can be sent regardless of this setting by specifying the `type` parameter
     * in the ``MessageReactions/send(forMessageWithSerial:params:)`` method.
     *
     * Defaults to ``MessageReactionType/distinct``.
     */
    public var defaultMessageReactionType = MessageReactionType.distinct

    // swiftlint:disable:next missing_docs
    public init(rawMessageReactions: Bool = false, defaultMessageReactionType: MessageReactionType = .distinct) {
        self.rawMessageReactions = rawMessageReactions
        self.defaultMessageReactionType = defaultMessageReactionType
    }
}

/**
 * Represents the typing options for a chat room.
 */
public struct TypingOptions: Sendable {
    // (CHA-T10) Users may configure a heartbeat interval (the no-op period for typing.keystroke when the heartbeat timer is set active at CHA-T4a4). This configuration is provided at the RoomOptions.typing.heartbeatThrottleMs property, or idiomatic equivalent. The default is 10000ms.
    /**
     * A throttle, in seconds, that enforces the minimum time interval between consecutive `typing.started`
     * events sent by the client to the server.
     * If ``Typing/keystroke()`` is called, the first call will emit an event immediately.
     * Later calls will no-op until the time has elapsed.
     * Calling ``Typing/stop()`` will immediately send a `typing.stopped` event to the server and reset the interval,
     * allowing the client to send another `typing.started` event immediately.
     *
     * Defaults to 10 seconds.
     */
    public var heartbeatThrottle: TimeInterval = 10

    // swiftlint:disable:next missing_docs
    public init(heartbeatThrottle: TimeInterval = 10) {
        self.heartbeatThrottle = heartbeatThrottle
    }
}

/**
 * Represents the occupancy options for a chat room.
 */
public struct OccupancyOptions: Sendable {
    /**
     * Whether to enable occupancy events.
     *
     * Note that enabling this feature will increase the number of messages received by the client as additional
     * messages will be sent by the server to indicate occupancy changes.
     *
     * Defaults to false.
     */
    public var enableEvents = false

    // swiftlint:disable:next missing_docs
    public init(enableEvents: Bool = false) {
        self.enableEvents = enableEvents
    }
}

// MARK: - Equatable

internal extension RoomOptions {
    /// A type that has all of `RoomOptions`'s properties and which is `Equatable`. This lets us compare two `RoomOptions` values — as we need to do when fetching a room when there is an existing room — without having to mark it publicly as `Equatable`.
    ///
    /// This is currently kept in sync manually with the options types. (TODO: https://github.com/ably/ably-chat-swift/issues/373, use a tool like Sourcery to keep in sync automatically)
    struct EquatableBox: Equatable {
        internal var messages: MessagesOptions.EquatableBox
        internal var presence: PresenceOptions.EquatableBox
        internal var typing: TypingOptions.EquatableBox
        internal var occupancy: OccupancyOptions.EquatableBox

        internal init(_ options: RoomOptions) {
            messages = MessagesOptions.EquatableBox(options.messages)
            presence = PresenceOptions.EquatableBox(options.presence)
            typing = TypingOptions.EquatableBox(options.typing)
            occupancy = OccupancyOptions.EquatableBox(options.occupancy)
        }
    }

    var equatableBox: EquatableBox {
        .init(self)
    }
}

internal extension PresenceOptions {
    struct EquatableBox: Equatable {
        internal var enableEvents: Bool

        internal init(_ options: PresenceOptions) {
            enableEvents = options.enableEvents
        }
    }

    var equatableBox: EquatableBox {
        .init(self)
    }
}

internal extension MessagesOptions {
    struct EquatableBox: Equatable {
        internal var rawMessageReactions: Bool
        internal var defaultMessageReactionType: MessageReactionType

        internal init(_ options: MessagesOptions) {
            rawMessageReactions = options.rawMessageReactions
            defaultMessageReactionType = options.defaultMessageReactionType
        }
    }

    var equatableBox: EquatableBox {
        .init(self)
    }
}

internal extension TypingOptions {
    struct EquatableBox: Equatable {
        internal var heartbeatThrottle: TimeInterval

        internal init(_ options: TypingOptions) {
            heartbeatThrottle = options.heartbeatThrottle
        }
    }

    var equatableBox: EquatableBox {
        .init(self)
    }
}

internal extension OccupancyOptions {
    struct EquatableBox: Equatable {
        internal var enableEvents: Bool

        internal init(_ options: OccupancyOptions) {
            enableEvents = options.enableEvents
        }
    }

    var equatableBox: EquatableBox {
        .init(self)
    }
}
