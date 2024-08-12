import Foundation

public struct RoomOptions: Sendable {
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

public struct PresenceOptions: Sendable {
    public var enter = true
    public var subscribe = true

    public init(enter: Bool = true, subscribe: Bool = true) {
        self.enter = enter
        self.subscribe = subscribe
    }
}

public struct TypingOptions: Sendable {
    public var timeout: TimeInterval = 10

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }
}

public struct RoomReactionsOptions: Sendable {
    public init() {}
}

public struct OccupancyOptions: Sendable {
    public init() {}
}
