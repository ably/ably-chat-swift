import Ably

// TODO: (https://github.com/ably-labs/ably-chat-swift/issues/13): try to improve this type
public typealias PresenceData = any Sendable

public protocol Presence: AnyObject, Sendable, EmitsDiscontinuities {
    func get() async throws -> [PresenceMember]
    func get(params: PresenceQuery?) async throws -> [PresenceMember]
    func isUserPresent(clientID: String) async throws -> Bool
    func enter() async throws
    func enter(data: PresenceData) async throws
    func update() async throws
    func update(data: PresenceData) async throws
    func leave() async throws
    func leave(data: PresenceData) async throws
    func subscribe(event: PresenceEventType) async -> Subscription<PresenceEvent>
    func subscribe(events: [PresenceEventType]) async -> Subscription<PresenceEvent>
}

public struct PresenceMember: Sendable {
    public enum Action: Sendable {
        case present
        case enter
        case leave
        case update
    }

    public init(clientID: String, data: PresenceData, action: PresenceMember.Action, extras: (any Sendable)?, updatedAt: Date) {
        self.clientID = clientID
        self.data = data
        self.action = action
        self.extras = extras
        self.updatedAt = updatedAt
    }

    public var clientID: String
    public var data: PresenceData?
    public var action: Action
    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/13): try to improve this type
    public var extras: (any Sendable)?
    public var updatedAt: Date
}

public enum PresenceEventType: Sendable {
    case enter
    case leave
    case update
    case present
}

public struct PresenceEvent: Sendable {
    public var action: PresenceEventType
    public var clientID: String
    public var timestamp: Date
    public var data: PresenceData?

    public init(action: PresenceEventType, clientID: String, timestamp: Date, data: PresenceData?) {
        self.action = action
        self.clientID = clientID
        self.timestamp = timestamp
        self.data = data
    }
}

// This is a Sendable equivalent of ably-cocoa’s ARTRealtimePresenceQuery type.
//
// Originally, ``Presence.get(params:)`` accepted an ARTRealtimePresenceQuery object, but I’ve changed it to accept this type, because else when you try and write an actor that implements ``Presence``, you get a compiler error like "Non-sendable type 'ARTRealtimePresenceQuery' in parameter of the protocol requirement satisfied by actor-isolated instance method 'get(params:)' cannot cross actor boundary; this is an error in the Swift 6 language mode".
//
// Now, based on my limited understanding, you _should_ be able to send non-Sendable values from one isolation domain to another (the purpose of the "region-based isolation" and "`sending` parameters" features added in Swift 6), but to get this to work I had to mark ``Presence`` as requiring conformance to the `Actor` protocol, and since I didn’t understand _why_ I had to do that, I didn’t want to put it in the public API.
//
// So, for now, let’s just accept this copy (which I don’t think is a big problem anyway); we can always revisit it with more Swift concurrency knowledge in the future. Created https://github.com/ably-labs/ably-chat-swift/issues/64 to revisit.
public struct PresenceQuery: Sendable {
    public var limit = 100
    public var clientID: String?
    public var connectionID: String?
    public var waitForSync = true

    internal init(limit: Int = 100, clientID: String? = nil, connectionID: String? = nil, waitForSync: Bool = true) {
        self.limit = limit
        self.clientID = clientID
        self.connectionID = connectionID
        self.waitForSync = waitForSync
    }
}
