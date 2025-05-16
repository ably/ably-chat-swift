import Ably

public typealias PresenceData = JSONValue

/**
 * This interface is used to interact with presence in a chat room: subscribing to presence events,
 * fetching presence members, or sending presence events (`enter`, `update`, `leave`).
 *
 * Get an instance via ``Room/presence``.
 */
@MainActor
public protocol Presence: AnyObject, Sendable {
    /**
     * Same as ``get(params:)``, but with defaults params.
     */
    func get() async throws(ARTErrorInfo) -> [PresenceMember]

    /**
     * Method to get list of the current online users and returns the latest presence messages associated to it.
     *
     * - Parameters:
     *   - params: ``PresenceParams`` that control how the presence set is retrieved.
     *
     * - Returns: An array of ``PresenceMember``s.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func get(params: PresenceParams) async throws(ARTErrorInfo) -> [PresenceMember]

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
    func isUserPresent(clientID: String) async throws(ARTErrorInfo) -> Bool

    /**
     * Method to join room presence, will emit an enter event to all subscribers. Repeat calls will trigger more enter events.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func enter(data: PresenceData) async throws(ARTErrorInfo)

    /**
     * Method to update room presence, will emit an update event to all subscribers. If the user is not present, it will be treated as a join event.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func update(data: PresenceData) async throws(ARTErrorInfo)

    /**
     * Method to leave room presence, will emit a leave event to all subscribers. If the user is not present, it will be treated as a no-op.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func leave(data: PresenceData) async throws(ARTErrorInfo)

    /**
     * Subscribes a given listener to a particular presence event in the chat room.
     *
     * Note that it is a programmer error to call this method if presence events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's presence options to use this feature (this is the default value).
     *
     * - Parameters:
     *   - event: A single presence event type ``PresenceEventType`` to subscribe to.
     *   - callback: The listener closure for capturing room ``PresenceEvent`` events.
     *
     * - Returns: A subscription handle that can be used to unsubscribe from ``PresenceEvent`` events.
     */
    @discardableResult
    func subscribe(event: PresenceEventType, _ callback: @escaping @MainActor (PresenceEvent) -> Void) -> SubscriptionHandle

    /**
     * Subscribes a given listener to different presence events in the chat room.
     *
     * Note that it is a programmer error to call this method if presence events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's presence options to use this feature (this is the default value).
     *
     * - Parameters:
     *   - events: An array of presence event types ``PresenceEventType`` to subscribe to.
     *   - callback: The listener closure for capturing room ``PresenceEvent`` events.
     *
     * - Returns: A subscription handle that can be used to unsubscribe from ``PresenceEvent`` events.
     */
    @discardableResult
    func subscribe(events: [PresenceEventType], _ callback: @escaping @MainActor (PresenceEvent) -> Void) -> SubscriptionHandle

    /**
     * Method to join room presence, will emit an enter event to all subscribers. Repeat calls will trigger more enter events.
     * In oppose to ``enter(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func enter() async throws(ARTErrorInfo)

    /**
     * Method to update room presence, will emit an update event to all subscribers. If the user is not present, it will be treated as a join event.
     * In oppose to ``update(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func update() async throws(ARTErrorInfo)

    /**
     * Method to leave room presence, will emit a leave event to all subscribers. If the user is not present, it will be treated as a no-op.
     * In oppose to ``leave(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func leave() async throws(ARTErrorInfo)
}

public extension Presence {
    /**
     * Subscribes a given listener to a particular presence event in the chat room.
     *
     * Note that it is a programmer error to call this method if presence events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's presence options to use this feature (this is the default value).
     *
     * - Parameters:
     *   - event: A single presence event type ``PresenceEventType`` to subscribe to.
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``PresenceEvent`` events.
     */
    func subscribe(event: PresenceEventType, bufferingPolicy: BufferingPolicy) -> Subscription<PresenceEvent> {
        let subscription = Subscription<PresenceEvent>(bufferingPolicy: bufferingPolicy)

        let subscriptionHandle = subscribe(event: event) { presence in
            subscription.emit(presence)
        }

        subscription.addTerminationHandler {
            Task { @MainActor in
                subscriptionHandle.unsubscribe()
            }
        }

        return subscription
    }

    /**
     * Subscribes a given listener to different presence events in the chat room.
     *
     * Note that it is a programmer error to call this method if presence events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's presence options to use this feature (this is the default value).
     *
     * - Parameters:
     *   - events: An array of presence event types ``PresenceEventType`` to subscribe to.
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``PresenceEvent`` events.
     */
    func subscribe(events: [PresenceEventType], bufferingPolicy: BufferingPolicy) -> Subscription<PresenceEvent> {
        let subscription = Subscription<PresenceEvent>(bufferingPolicy: bufferingPolicy)

        let subscriptionHandle = subscribe(events: events) { presence in
            subscription.emit(presence)
        }

        subscription.addTerminationHandler {
            Task { @MainActor in
                subscriptionHandle.unsubscribe()
            }
        }

        return subscription
    }

    /// Same as calling ``subscribe(event:bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe(event: PresenceEventType) -> Subscription<PresenceEvent> {
        subscribe(event: event, bufferingPolicy: .unbounded)
    }

    /// Same as calling ``subscribe(events:bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe(events: [PresenceEventType]) -> Subscription<PresenceEvent> {
        subscribe(events: events, bufferingPolicy: .unbounded)
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

    public init(clientID: String, data: PresenceData?, action: PresenceMember.Action, extras: [String: JSONValue]?, updatedAt: Date) {
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

    /**
     * The extras associated with the presence member.
     */
    public var extras: [String: JSONValue]?
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

/// Describes the parameters accepted by ``Presence/get(params:)``.
public struct PresenceParams: Sendable {
    /// Filters the array of returned presence members by a specific client using its ID.
    public var clientID: String?

    /// Filters the array of returned presence members by a specific connection using its ID.
    public var connectionID: String?

    /// Sets whether to wait for a full presence set synchronization between Ably and the clients on the room to complete before returning the results. Synchronization begins as soon as the room is ``RoomStatus/attached``. When set to `true` the results will be returned as soon as the sync is complete. When set to `false` the current list of members will be returned without the sync completing. The default is `true`.
    public var waitForSync = true

    public init(clientID: String? = nil, connectionID: String? = nil, waitForSync: Bool = true) {
        self.clientID = clientID
        self.connectionID = connectionID
        self.waitForSync = waitForSync
    }

    internal func asARTRealtimePresenceQuery() -> ARTRealtimePresenceQuery {
        let query = ARTRealtimePresenceQuery()
        query.clientId = clientID
        query.connectionId = connectionID
        query.waitForSync = waitForSync
        return query
    }
}
