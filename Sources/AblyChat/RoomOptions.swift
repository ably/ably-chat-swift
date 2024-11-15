import Foundation

public struct RoomOptions: Sendable, Equatable {
    public var presence: PresenceOptions?
    public var typing: TypingOptions?
    public var reactions: RoomReactionsOptions?
    public var occupancy: OccupancyOptions?

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
public struct PresenceOptions: Sendable, Equatable {
    public var enter = true
    public var subscribe = true

    public init(enter: Bool = true, subscribe: Bool = true) {
        self.enter = enter
        self.subscribe = subscribe
    }
}

public struct TypingOptions: Sendable, Equatable {
    public var timeout: TimeInterval = 10

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }
}

public struct RoomReactionsOptions: Sendable, Equatable {
    public init() {}
}

public struct OccupancyOptions: Sendable, Equatable {
    public init() {}
}
