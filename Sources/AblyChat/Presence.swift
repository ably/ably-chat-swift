import Ably

// swiftlint:disable:next missing_docs
public typealias PresenceData = JSONObject

/**
 * This interface is used to interact with presence in a chat room: subscribing to presence events,
 * fetching presence members, or sending presence events (`enter`, `update`, `leave`).
 *
 * Get an instance via ``Room/presence``.
 */
@MainActor
public protocol Presence: AnyObject, Sendable {
    // swiftlint:disable:next missing_docs
    associatedtype Subscription: AblyChat.Subscription

    /**
     * Same as ``get(params:)``, but with defaults params.
     */
    func get() async throws(ErrorInfo) -> [PresenceMember]

    /**
     * Method to get list of the current online users and returns the latest presence messages associated to it.
     *
     * - Parameters:
     *   - params: ``PresenceParams`` that control how the presence set is retrieved.
     *
     * - Returns: An array of ``PresenceMember``s.
     *
     * - Throws: An `ErrorInfo`.
     */
    func get(withParams params: PresenceParams) async throws(ErrorInfo) -> [PresenceMember]

    /**
     * Method to check if user with supplied clientId is online.
     *
     * - Parameters:
     *   - clientID: The client ID to check if it is present in the room.
     *
     * - Returns: A boolean value indicating whether the user is present in the room.
     *
     * - Throws: An `ErrorInfo`.
     */
    func isUserPresent(withClientID clientID: String) async throws(ErrorInfo) -> Bool

    /**
     * Method to join room presence, will emit an enter event to all subscribers. Repeat calls will trigger more enter events.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ErrorInfo`.
     */
    func enter(withData data: PresenceData) async throws(ErrorInfo)

    /**
     * Method to update room presence, will emit an update event to all subscribers. If the user is not present, it will be treated as a join event.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ErrorInfo`.
     */
    func update(withData data: PresenceData) async throws(ErrorInfo)

    /**
     * Method to leave room presence, will emit a leave event to all subscribers. If the user is not present, it will be treated as a no-op.
     *
     * - Parameters:
     *   - data: The users data, a JSON serializable object that will be sent to all subscribers.
     *
     * - Throws: An `ErrorInfo`.
     */
    func leave(withData data: PresenceData) async throws(ErrorInfo)

    /**
     * Subscribes a given listener to all presence events in the chat room.
     *
     * Note that it is a programmer error to call this method if presence events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's presence options to use this feature (this is the default value).
     *
     * - Parameters:
     *   - callback: The listener closure for capturing room ``PresenceEvent`` events.
     *
     * - Returns: A subscription that can be used to unsubscribe from ``PresenceEvent`` events.
     */
    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (PresenceEvent) -> Void) -> Subscription

    /**
     * Method to join room presence, will emit an enter event to all subscribers. Repeat calls will trigger more enter events.
     * In oppose to ``enter(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ErrorInfo`.
     */
    func enter() async throws(ErrorInfo)

    /**
     * Method to update room presence, will emit an update event to all subscribers. If the user is not present, it will be treated as a join event.
     * In oppose to ``update(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ErrorInfo`.
     */
    func update() async throws(ErrorInfo)

    /**
     * Method to leave room presence, will emit a leave event to all subscribers. If the user is not present, it will be treated as a no-op.
     * In oppose to ``leave(data:)`` it doesn't publish any custom presence data.
     *
     * - Throws: An `ErrorInfo`.
     */
    func leave() async throws(ErrorInfo)
}

// swiftlint:disable:next missing_docs
public extension Presence {
    /**
     * Subscribes to all presence events in the chat room.
     *
     * Note that it is a programmer error to call this method if presence events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's presence options to use this feature (this is the default value).
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``PresenceEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<PresenceEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<PresenceEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribe { presence in
            subscriptionAsyncSequence.emit(presence)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe() -> SubscriptionAsyncSequence<PresenceEvent> {
        subscribe(bufferingPolicy: .unbounded)
    }
}

/**
 * Type for PresenceMember
 */
public struct PresenceMember: Sendable {
    /// Memberwise initializer to create a `PresenceMember`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(clientID: String, connectionID: String, data: PresenceData?, extras: [String: JSONValue]?, updatedAt: Date) {
        self.clientID = clientID
        self.connectionID = connectionID
        self.data = data
        self.extras = extras
        self.updatedAt = updatedAt
    }

    /**
     * The clientId of the presence member.
     */
    public var clientID: String

    /// The connection ID of this presence member.
    public var connectionID: String

    /**
     * The data associated with the presence member.
     * `nil` means that there is no presence data; this is different to a `JSONValue` of case `.null`
     */
    public var data: PresenceData?

    /**
     * The extras associated with the presence member.
     */
    public var extras: [String: JSONValue]?
    // swiftlint:disable:next missing_docs
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

    internal init?(ablyCocoaValue: ARTPresenceAction) {
        switch ablyCocoaValue {
        case .present:
            self = .present
        case .enter:
            self = .enter
        case .leave:
            self = .leave
        case .update:
            self = .update
        case .absent:
            // This should never be emitted as an event
            return nil
        @unknown default:
            return nil
        }
    }

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
    public var type: PresenceEventType

    /**
     * The member associated with the presence event.
     */
    public var member: PresenceMember

    /// Memberwise initializer to create a `PresenceEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: PresenceEventType, member: PresenceMember) {
        self.type = type
        self.member = member
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

    // swiftlint:disable:next missing_docs
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
