import Ably

// TODO: the JS one says "Any JSON serializable data type."; what's the best way to represent this in Swift? Maybe would be best done with `Encodable`
public typealias PresenceData = Any & Sendable

public protocol Presence: AnyObject, Sendable, EmitsDiscontinuities {
    func get() async throws -> any PaginatedResult<[PresenceMember]>
    func get(params: ARTRealtimePresenceQuery?) async throws -> any PaginatedResult<[PresenceMember]>
    func isUserPresent(clientID: String) async throws -> Bool
    func enter() async throws
    func enter(data: PresenceData) async throws
    func update() async throws
    func update(data: PresenceData) async throws
    func leave() async throws
    func leave(data: PresenceData) async throws
    func subscribe(event: PresenceEventType) -> Subscription<PresenceEvent>
    func subscribe(events: [PresenceEventType]) -> Subscription<PresenceEvent>
}

public struct PresenceMember: Sendable {
    // TODO: why is this defined inline in the JS one? how is it different to its `PresenceEvents` enum (i.e. our PresenceEventsType enum)?
    public enum Action: Sendable {
        case present
        case enter
        case leave
        case update
    }

    public init(clientID: String, data: any PresenceData, action: PresenceMember.Action, extras: any Sendable, updatedAt: Date) {
        self.clientID = clientID
        self.data = data
        self.action = action
        self.extras = extras
        self.updatedAt = updatedAt
    }

    public var clientID: String
    // TODO: it’s `unknown` in JS; this probably isn’t equivalent because I guess it could be nil
    public var data: PresenceData
    public var action: Action
    // TODO: what about this?
    public var extras: Sendable
    public var updatedAt: Date
}

public enum PresenceEventType: Sendable {
    case enter
    case leave
    case update
    case present
}

// TODO: how is this different to PresenceMember?
public struct PresenceEvent: Sendable {
    public var action: PresenceEventType
    public var clientID: String
    public var timestamp: Date
    public var data: PresenceData

    public init(action: PresenceEventType, clientID: String, timestamp: Date, data: any PresenceData) {
        self.action = action
        self.clientID = clientID
        self.timestamp = timestamp
        self.data = data
    }
}
