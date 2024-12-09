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

public typealias PresenceData = JSONValue

// TODO: explain - wanted to use something that's not an optional because we already have `null` handling for JSON and double optionals or anything that looks like that will be confusing
internal enum PresenceDataArgument {
    case notSupplied
    case supplied(JSONValue)
}

// (CHA-PR2a) The presence data format is a JSON object as described below. Customers may specify content of an arbitrary type to be placed in the userCustomData field.
internal struct PresenceDataDTO {
    enum UserCustomData {
        case notSupplied
        case supplied(PresenceData)

        var asOptionalPresenceData: PresenceData? {
            switch self {
            case .notSupplied:
                nil
            case let .supplied(presenceData):
                presenceData
            }
        }
    }

    var userCustomData: UserCustomData

    // TODO: test (it's a bit of a pointless dance you could argue, but I really want to avoid using stuff like nil or null)
    static func forPresenceOperationWithDataArgument(_ dataArgument: PresenceDataArgument) -> Self {
        switch dataArgument {
        case .notSupplied:
            .init(userCustomData: .notSupplied)
        case let .supplied(presenceData):
            .init(userCustomData: .supplied(presenceData))
        }
    }
}

internal extension PresenceDataDTO {
    private enum JSONKeys: String {
        case userCustomData
    }

    // TODO: test and handle errors
    init?(jsonValue: JSONValue) {
        guard case let .object(jsonObject) = jsonValue else {
            return nil
        }

        if let userCustomDataValue = jsonObject[JSONKeys.userCustomData.rawValue] {
            userCustomData = .supplied(userCustomDataValue)
        } else {
            userCustomData = .notSupplied
        }
    }

    // TODO: explain, and is the "object" in the name confusing?
    var toJSONObject: [String: JSONValue] {
        var result: [String: JSONValue] = [:]

        switch userCustomData {
        case .notSupplied:
            break
        case let .supplied(value):
            result[JSONKeys.userCustomData.rawValue] = value
        }

        return result
    }
}

// TODO: might users also want to do something with this? like encode or something
public indirect enum JSONValue: Sendable, Equatable {
    // TODO:
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    // TODO: we could update everywhere to use this instead of the Encodable faffery

    // TODO: test
    init?(ablyCocoaPresenceData: Any?) {
        // TODO: what if there is no presence data? I haven't figured this out from the JS handling
        guard let ablyCocoaPresenceData else {
            return nil
        }

        switch ablyCocoaPresenceData {
        case let dictionary as [String: Any]:
            // TODO: handle this failure
            self = .object(dictionary.mapValues { .init(ablyCocoaPresenceData: $0)! })
        case let array as [Any]:
            // TODO: handle this failure
            self = .array(array.map { .init(ablyCocoaPresenceData: $0)! })
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            // TODO: decide best way to handle this; should we preserve NSNumber?
            self = .number(number.doubleValue)
        case let bool as Bool:
            self = .bool(bool)
        case is NSNull:
            self = .null
        default:
            fatalError("TODO")
        }
    }

    // TODO: explain
    fileprivate var toAblyCocoaPresenceDataValue: Any {
        switch self {
        case let .object(underlying):
            underlying.toAblyCocoaPresenceData
        case let .array(underlying):
            underlying.map(\.toAblyCocoaPresenceDataValue)
        case let .string(underlying):
            underlying
        case let .number(underlying):
            underlying
        case let .bool(underlying):
            underlying
        case .null:
            NSNull()
        }
    }
}

internal extension [String: JSONValue] {
    var toAblyCocoaPresenceData: [String: Any] {
        // TODO: test
        mapValues(\.toAblyCocoaPresenceDataValue)
    }
}

public protocol Presence: AnyObject, Sendable, EmitsDiscontinuities {
    func get() async throws -> [PresenceMember]
    func get(params: PresenceQuery) async throws -> [PresenceMember]
    func isUserPresent(clientID: String) async throws -> Bool
    func enter(data: PresenceData) async throws
    func enter() async throws
    func update(data: PresenceData) async throws
    func update() async throws
    func leave(data: PresenceData) async throws
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

    public init(clientID: String, data: PresenceData?, action: PresenceMember.Action, extras: (any Sendable)?, updatedAt: Date) {
        self.clientID = clientID
        self.data = data
        self.action = action
        self.extras = extras
        self.updatedAt = updatedAt
    }

    public var clientID: String
    // TODO: are we sure we want to represent the absence of presence data by an optional? if so make it clear that optional is different to .null
    // TODO: why was this non-optional in the initializer?
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
