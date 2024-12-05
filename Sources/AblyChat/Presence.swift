import Ably

// TODO: (https://github.com/ably-labs/ably-chat-swift/issues/13): try to improve this type
public enum PresenceCustomData: Sendable, Codable, Equatable {
    case string(String)
    case number(Int) // Changed from NSNumber to Int to conform to Codable. Address in linked issue above.
    case bool(Bool)
    case null

    public var value: Any? {
        switch self {
        case let .string(value):
            value
        case let .number(value):
            value
        case let .bool(value):
            value
        case .null:
            nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .null
        }
    }
}

public typealias UserCustomData = [String: PresenceCustomData]

// (CHA-PR2a) The presence data format is a JSON object as described below. Customers may specify content of an arbitrary type to be placed in the userCustomData field.
public struct PresenceData: Codable, Sendable {
    public var userCustomData: UserCustomData?

    public init(userCustomData: UserCustomData? = nil) {
        self.userCustomData = userCustomData
    }
}

internal extension PresenceData {
    /// Returns a dictionary that `JSONSerialization` can serialize to a JSON "object" value.
    ///
    /// Suitable to pass as the `data` argument of an ably-cocoa presence operation.
    func asJSONObject() -> [String: Any] {
        // Return an empty userCustomData string if no custom data is available
        guard let userCustomData else {
            return ["userCustomData": ""]
        }

        // Create a dictionary for userCustomData
        var userCustomDataDict: [String: Any] = [:]

        // Iterate over the custom data and handle different PresenceCustomData cases
        for (key, value) in userCustomData {
            switch value {
            case let .string(stringValue):
                userCustomDataDict[key] = stringValue
            case let .number(numberValue):
                userCustomDataDict[key] = numberValue
            case let .bool(boolValue):
                userCustomDataDict[key] = boolValue
            case .null:
                userCustomDataDict[key] = NSNull() // Use NSNull to represent null in the dictionary
            }
        }

        // Return the final dictionary
        return ["userCustomData": userCustomDataDict]
    }
}

public protocol Presence: AnyObject, Sendable, EmitsDiscontinuities {
    func get() async throws -> [PresenceMember]
    func get(params: PresenceQuery) async throws -> [PresenceMember]
    func isUserPresent(clientID: String) async throws -> Bool
    func enter(data: PresenceData?) async throws
    func enter() async throws
    func update(data: PresenceData?) async throws
    func update() async throws
    func leave(data: PresenceData?) async throws
    func leave() async throws
    func subscribe(event: PresenceEventType, bufferingPolicy: BufferingPolicy) async -> Subscription<PresenceEvent>
    /// Same as calling ``subscribe(event:bufferingPolicy:)`` with ``BufferingPolicy.unbounded``.
    ///
    /// The `Presence` protocol provides a default implementation of this method.
    func subscribe(event: PresenceEventType) async -> Subscription<PresenceEvent>
    func subscribe(events: [PresenceEventType], bufferingPolicy: BufferingPolicy) async -> Subscription<PresenceEvent>
    /// Same as calling ``subscribe(events:bufferingPolicy:)`` with ``BufferingPolicy.unbounded``.
    ///
    /// The `Presence` protocol provides a default implementation of this method.
    func subscribe(events: [PresenceEventType]) async -> Subscription<PresenceEvent>
}

public extension Presence {
    func enter() async throws {
        try await enter(data: nil)
    }

    func update() async throws {
        try await update(data: nil)
    }

    func leave() async throws {
        try await leave(data: nil)
    }
}

public extension Presence {
    func subscribe(event: PresenceEventType) async -> Subscription<PresenceEvent> {
        await subscribe(event: event, bufferingPolicy: .unbounded)
    }

    func subscribe(events: [PresenceEventType]) async -> Subscription<PresenceEvent> {
        await subscribe(events: events, bufferingPolicy: .unbounded)
    }
}

public struct PresenceMember: Sendable {
    public enum Action: Sendable {
        case present
        case enter
        case leave
        case update
        case absent
        case unknown

        internal init(from action: ARTPresenceAction) {
            switch action {
            case .present:
                self = .present
            case .enter:
                self = .enter
            case .leave:
                self = .leave
            case .update:
                self = .update
            case .absent:
                self = .absent
            @unknown default:
                self = .unknown
                print("Unknown presence action encountered: \(action)")
            }
        }
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

    internal func toARTPresenceAction() -> ARTPresenceAction {
        switch self {
        case .present:
            .present
        case .enter:
            .enter
        case .leave:
            .leave
        case .update:
            .update
        }
    }
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

    internal func asARTRealtimePresenceQuery() -> ARTRealtimePresenceQuery {
        let query = ARTRealtimePresenceQuery()
        query.limit = UInt(limit)
        query.clientId = clientID
        query.connectionId = connectionID
        query.waitForSync = waitForSync
        return query
    }
}
