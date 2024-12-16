import Ably

public typealias PresenceData = JSONValue

/**
 * This interface is used to interact with presence in a chat room: subscribing to presence events,
 * fetching presence members, or sending presence events (`enter`, `update`, `leave`).
 *
 * Get an instance via ``Room/presence``.
 */
public protocol Presence: AnyObject, Sendable, EmitsDiscontinuities {
    /**
     * Same as ``get(params:)``, but with defaults params.
     */
    func get() async throws -> [PresenceMember]

    /**
     * Method to get list of the current online users and returns the latest presence messages associated to it.
     *
     * - Parameters:
     *   - params: ``PresenceQuery`` that control how the presence set is retrieved.
     *
     * - Returns: An array of ``PresenceMember``s.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func get(params: PresenceQuery) async throws -> [PresenceMember]

    /**
     * Method to check if user with supplied clientId is online.
     *
     * - Parameters:
     *   - clientID: The client ID to check if it is present in the room.
     *
     * - Returns: A boolean value indicating whether the user is present in the room.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func isUserPresent(clientID: String) async throws -> Bool

    /**
     * Method to join room presence, will emit an enter event to all subscribers. Repeat calls will trigger more enter events.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func enter(data: PresenceData) async throws

    /**
     * Method to update room presence, will emit an update event to all subscribers. If the user is not present, it will be treated as a join event.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func update(data: PresenceData) async throws

    /**
     * Method to leave room presence, will emit a leave event to all subscribers. If the user is not present, it will be treated as a no-op.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func leave(data: PresenceData) async throws

    /**
     * Subscribes a given listener to a particular presence event in the chat room.
     *
     * - Parameters:
     *   - event: A single presence event type ``PresenceEventType`` to subscribe to.
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``PresenceEvent`` events.
     */
    func subscribe(event: PresenceEventType, bufferingPolicy: BufferingPolicy) async -> Subscription<PresenceEvent>

    /**
     * Subscribes a given listener to different presence events in the chat room.
     *
     * - Parameters:
     *   - events: An array of presence event types ``PresenceEventType`` to subscribe to.
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``PresenceEvent`` events.
     */
    func subscribe(events: [PresenceEventType], bufferingPolicy: BufferingPolicy) async -> Subscription<PresenceEvent>

    /**
     * Method to join room presence, will emit an enter event to all subscribers. Repeat calls will trigger more enter events.
     * In oppose to ``enter(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func enter() async throws

    /**
     * Method to update room presence, will emit an update event to all subscribers. If the user is not present, it will be treated as a join event.
     * In oppose to ``update(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func update() async throws

    /**
     * Method to leave room presence, will emit a leave event to all subscribers. If the user is not present, it will be treated as a no-op.
     * In oppose to ``leave(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func leave() async throws

    /// Same as calling ``subscribe(event:bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Presence` protocol provides a default implementation of this method.
    func subscribe(event: PresenceEventType) async -> Subscription<PresenceEvent>

    /// Same as calling ``subscribe(events:bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
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

    public init(clientID: String, data: PresenceData?, action: PresenceMember.Action, extras: (any Sendable)?, updatedAt: Date) {
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
     * `nil` means that there is no presence data; this is different to a `JSONValue` of case `.null`
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
