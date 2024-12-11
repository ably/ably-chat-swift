import Foundation

/**
 * Represents the options for a given chat room.
 */
public struct RoomOptions: Sendable, Equatable {
    /**
     * The presence options for the room. To enable presence in the room, set this property.
     * Alternatively, you may use ``RoomOptions/allFeaturesEnabled`` to enable presence with the default options.
     */
    public var presence: PresenceOptions?

    /**
     * The typing options for the room. To enable typing in the room, set this property.
     * Alternatively, you may use ``RoomOptions/allFeaturesEnabled`` to enable typing with the default options.
     */
    public var typing: TypingOptions?

    /**
     * The reactions options for the room. To enable reactions in the room, set this property.
     * Alternatively, you may use ``RoomOptions/allFeaturesEnabled`` to enable reactions with the default options.
     */
    public var reactions: RoomReactionsOptions?

    /**
     * The occupancy options for the room. To enable occupancy in the room, set this property.
     * Alternatively, you may use ``RoomOptions/allFeaturesEnabled`` to enable occupancy with the default options.
     */
    public var occupancy: OccupancyOptions?

    /// A `RoomOptions` which enables all room features, using the default settings for each feature.
    public static let allFeaturesEnabled: Self = .init(
        presence: .init(),
        typing: .init(),
        reactions: .init(),
        occupancy: .init()
    )

    public init(presence: PresenceOptions? = nil, typing: TypingOptions? = nil, reactions: RoomReactionsOptions? = nil, occupancy: OccupancyOptions? = nil) {
        self.presence = presence
        self.typing = typing
        self.reactions = reactions
        self.occupancy = occupancy
    }
}

// (CHA-PR9) Users may configure their presence options via the RoomOptions provided at room configuration time.
// (CHA-PR9a) Setting enter to false prevents the user from entering presence by means of the ChannelMode on the underlying realtime channel. Entering presence will result in an error. The default is true.
// (CHA-PR9b) Setting subscribe to false prevents the user from subscribing to presence by means of the ChannelMode on the underlying realtime channel. This does not prevent them from receiving their own presence messages, but they will not receive them from others. The default is true.

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
    public var enter = true

    /**
     * Whether the underlying Realtime channel should use the presence subscribe mode, allowing subscription to presence.
     * This property does not affect the presence lifecycle, and users must still call ``Presence/subscribe(events:)``
     * in order to subscribe to presence.
     * Defaults to true.
     */
    public var subscribe = true

    public init(enter: Bool = true, subscribe: Bool = true) {
        self.enter = enter
        self.subscribe = subscribe
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
    public init() {}
}
