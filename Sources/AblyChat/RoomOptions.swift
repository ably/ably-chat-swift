import Foundation

/**
 * Represents the options for a given chat room.
 */
public struct RoomOptions: Sendable, Equatable {
    /**
     * The presence options for the room.
     */
    public var presence = PresenceOptions()

    /**
     * The typing options for the room.
     */
    public var typing = TypingOptions()

    /**
     * The reactions options for the room.
     */
    public var reactions = RoomReactionsOptions()

    /**
     * The occupancy options for the room.
     */
    public var occupancy = OccupancyOptions()

    public init(presence: PresenceOptions = PresenceOptions(), typing: TypingOptions = TypingOptions(), reactions: RoomReactionsOptions = RoomReactionsOptions(), occupancy: OccupancyOptions = OccupancyOptions()) {
        self.presence = presence
        self.typing = typing
        self.reactions = reactions
        self.occupancy = occupancy
    }
}

/**
 * Represents the presence options for a chat room.
 */
public struct PresenceOptions: Sendable, Equatable {
    /**
     * Whether or not the client should receive presence events from the server. This setting
     * can be disabled if you are using presence in your Chat Room, but this particular client does not
     * need to receive the messages.
     *
     * Defaults to true.
     */
    public var enableEvents = true

    public init(enableEvents: Bool = true) {
        self.enableEvents = enableEvents
    }
}

/**
 * Represents the typing options for a chat room.
 */
public struct TypingOptions: Sendable, Equatable {
    // (CHA-T10) Users may configure a heartbeat interval (the no-op period for typing.keystroke when the heartbeat timer is set active at CHA-T4a4). This configuration is provided at the RoomOptions.typing.heartbeatThrottleMs property, or idiomatic equivalent. The default is 10000ms.
    /**
     * The heartbeat interval for typing events in seconds. Once ``Typing/keystroke()`` is called, subsequent keystroke events will be
     * ignored until this interval, and an internally defined timeout has passed. This is useful for preventing a user from sending too many typing events, and thus messages on the channel.
     *
     * A stop typing event is automatically emitted after this interval has passed.
     * These events can be observed via ``Typing/subscribe()``.
     *
     * Defaults to 10 seconds.
     */
    public var heartbeatThrottle: TimeInterval = 10

    public init(heartbeatThrottle: TimeInterval = 10) {
        self.heartbeatThrottle = heartbeatThrottle
    }
}

/**
 * Represents the reactions options for a chat room.
 */
public struct RoomReactionsOptions: Sendable, Equatable {
    public init() {}
}

/**
 * Represents the occupancy options for a chat room.
 */
public struct OccupancyOptions: Sendable, Equatable {
    /**
     * Whether to enable inbound occupancy events.
     *
     * Note that enabling this feature will increase the number of messages received by the client.
     *
     * Defaults to false.
     */
    public var enableEvents = false

    public init(enableEvents: Bool = false) {
        self.enableEvents = enableEvents
    }
}
