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
     * Whether the underlying Realtime channel should use the presence enter mode, allowing entry into presence.
     * This property does not affect the presence lifecycle, and users must still call ``Presence/enter()``
     * in order to enter presence.
     * Defaults to true.
     */
    /**
     * Whether or not the client should receive presence events from the server. This setting
     * can be disabled if you are using presence in your Chat Room, but this particular client does not
     * need to receive the messages.
     *
     * Defaults to true.
     */
    public var receivePresenceEvents = true

    public init(receivePresenceEvents: Bool = true) {
        self.receivePresenceEvents = receivePresenceEvents
    }
}

// (CHA-T3) Users may configure a timeout interval for when they are typing. This configuration is provided as part of the RoomOptions typing.timeoutMs property, or idiomatic equivalent. The default is 5000ms.

/**
 * Represents the typing options for a chat room.
 */
public struct TypingOptions: Sendable, Equatable {
    /**
     * The timeout for typing events in seconds. If ``Typing/start()`` is not called for this amount of time, a stop
     * typing event will be fired, resulting in the user being removed from the currently typing set.
     * Defaults to 5 seconds.
     */
    public var timeout: TimeInterval = 5

    public init(timeout: TimeInterval = 5) {
        self.timeout = timeout
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
    public var enableInboundOccupancy = false

    public init(enableInboundOccupancy: Bool = false) {
        self.enableInboundOccupancy = enableInboundOccupancy
    }
}
