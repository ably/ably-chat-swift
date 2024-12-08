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

/**
 * Type for PresenceData. Any JSON serializable data type.
 */
public typealias UserCustomData = [String: PresenceCustomData]

// (CHA-PR2a) The presence data format is a JSON object as described below. Customers may specify content of an arbitrary type to be placed in the userCustomData field.
public struct PresenceData: Codable, Sendable {
    public var userCustomData: UserCustomData?

    public init(userCustomData: UserCustomData? = nil) {
        self.userCustomData = userCustomData
    }
}

internal extension PresenceData {
    func asQueryItems() -> [String: Any] {
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

/**
 * This interface is used to interact with presence in a chat room: subscribing to presence events,
 * fetching presence members, or sending presence events (join,update,leave).
 *
 * Get an instance via {@link Room.presence}.
 */
public protocol Presence: AnyObject, Sendable, EmitsDiscontinuities {
    /**
     * Same as ``get(params: PresenceQuery)``, but with defaults params.
     */
    func get() async throws -> [PresenceMember]

    /**
     * Method to get list of the current online users and returns the latest presence messages associated to it.
     * @param {Ably.RealtimePresenceParams} params - Parameters that control how the presence set is retrieved.
     * @returns {Promise<PresenceMessage[]>} or upon failure, the promise will be rejected with an {@link Ably.ErrorInfo} object which explains the error.
     */
    func get(params: PresenceQuery) async throws -> [PresenceMember]

    /**
     * Method to check if user with supplied clientId is online
     * @param {string} clientId - The client ID to check if it is present in the room.
     * @returns {Promise<{boolean}>} or upon failure, the promise will be rejected with an {@link Ably.ErrorInfo} object which explains the error.
     */
    func isUserPresent(clientID: String) async throws -> Bool

    /**
     * Method to join room presence, will emit an enter event to all subscribers. Repeat calls will trigger more enter events.
     * @param {PresenceData} data - The users data, a JSON serializable object that will be sent to all subscribers.
     * @returns {Promise<void>} or upon failure, the promise will be rejected with an {@link Ably.ErrorInfo} object which explains the error.
     */
    func enter(data: PresenceData?) async throws

    /**
     * Method to update room presence, will emit an update event to all subscribers. If the user is not present, it will be treated as a join event.
     * @param {PresenceData} data - The users data, a JSON serializable object that will be sent to all subscribers.
     * @returns {Promise<void>} or upon failure, the promise will be rejected with an {@link Ably.ErrorInfo} object which explains the error.
     */
    func update(data: PresenceData?) async throws

    /**
     * Method to leave room presence, will emit a leave event to all subscribers. If the user is not present, it will be treated as a no-op.
     * @param {PresenceData} data - The users data, a JSON serializable object that will be sent to all subscribers.
     * @returns {Promise<void>} or upon failure, the promise will be rejected with an {@link Ably.ErrorInfo} object which explains the error.
     */
    func leave(data: PresenceData?) async throws

    /**
     * Subscribe the given listener from the given list of events.
     * @param event {'enter' | 'leave' | 'update' | 'present'} single event name to subscribe to
     * @param listener listener to subscribe
     */
    func subscribe(event: PresenceEventType, bufferingPolicy: BufferingPolicy) async -> Subscription<PresenceEvent>
    
    /// Same as calling ``subscribe(event:bufferingPolicy:)`` with ``BufferingPolicy.unbounded``.
    ///
    /// The `Presence` protocol provides a default implementation of this method.
    func subscribe(event: PresenceEventType) async -> Subscription<PresenceEvent>

    /**
     * Subscribe the given listener from the given list of events.
     * @param eventOrEvents {'enter' | 'leave' | 'update' | 'present'} single event name or array of events to subscribe to
     * @param listener listener to subscribe
     */
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

/**
 * Type for PresenceMember
 */
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

    /**
     * The clientId of the presence member.
     */
    public var clientID: String
    
    /**
     * The data associated with the presence member.
     */
    public var data: PresenceData?
    
    /**
     * The current state of the presence member.
     */
    public var action: Action
    
    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/13): try to improve this type
    
    /**
     * The extras associated with the presence member.
     */
    public var extras: (any Sendable)?
    public var updatedAt: Date
}

/**
 * Enum representing presence events.
 */
public enum PresenceEventType: Sendable {
    /**
     * Event triggered when a user enters.
     */
    case enter
    
    /**
     * Event triggered when a user leaves.
     */
    case leave
    
    /**
     * Event triggered when a user updates their presence data.
     */
    case update
    
    /**
     * Event triggered when a user initially subscribes to presence.
     */
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

/**
 * Type for PresenceEvent
 */
public struct PresenceEvent: Sendable {
    /**
     * The type of the presence event.
     */
    public var action: PresenceEventType
    
    /**
     * The clientId of the client that triggered the presence event.
     */
    public var clientID: String
    
    /**
     * The timestamp of the presence event.
     */
    public var timestamp: Date
    
    /**
     * The data associated with the presence event.
     */
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
// Originally, ``Presence/get(params:)`` accepted an ARTRealtimePresenceQuery object, but I’ve changed it to accept this type, because else when you try and write an actor that implements ``Presence``, you get a compiler error like "Non-sendable type 'ARTRealtimePresenceQuery' in parameter of the protocol requirement satisfied by actor-isolated instance method 'get(params:)' cannot cross actor boundary; this is an error in the Swift 6 language mode".
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
