import Ably

/**
 * Type for data that can be entered into presence as an object literal.
 */
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
     * Same as ``Presence/get(withParams:)``, but with defaults params.
     */
    func get() async throws(ErrorInfo) -> [PresenceMember]

    /**
     * Retrieves the current members present in the chat room.
     *
     * - Note: The room must be attached before calling this method.
     *
     * - Parameters:
     *   - params: Optional parameters to filter the presence set
     *
     * - Returns: An array of presence members currently in the room
     *
     * - Throws: ``ErrorInfo`` with code ``InternalError/ErrorCode/roomInInvalidState`` if the room is not attached
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options and attach to it
     * let room = try await chatClient.rooms.get("meeting-room")
     * try await room.attach()
     *
     * do {
     *     // Get all currently present members
     *     let members = try await room.presence.get()
     *     print("\(members.count) users present in the room")
     *
     *     for member in members {
     *         print("User \(member.clientID) is present with data: \(String(describing: member.data))")
     *     }
     *
     *     // Get members with a specific client ID
     *     let specificUser = try await room.presence.get(withParams: .init(clientID: "user-456"))
     *     if !specificUser.isEmpty {
     *         print("User-456 is in the room")
     *     }
     * } catch {
     *     print("Failed to get presence members: \(error)")
     * }
     * ```
     */
    func get(withParams params: PresenceParams) async throws(ErrorInfo) -> [PresenceMember]

    /**
     * Checks whether a specific user is currently present in the chat room.
     * Useful if you just need a boolean check rather than the full presence member data.
     *
     * - Note: The room must be attached before calling this method.
     *
     * - Parameters:
     *   - clientID: The client ID of the user to check
     *
     * - Returns: true if the user is present, false otherwise
     *
     * - Throws: ``ErrorInfo`` with code ``InternalError/ErrorCode/roomInInvalidState`` if the room is not attached, or with ``ErrorInfo`` if the operation fails for any other reason
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options and attach to it
     * let room = try await chatClient.rooms.get("meeting-room")
     * try await room.attach()
     *
     * do {
     *     // Check if a specific user is present
     *     let isPresent = try await room.presence.isUserPresent(withClientID: "user-456")
     *
     *     if isPresent {
     *         print("User-456 is currently in the room")
     *     } else {
     *         print("User-456 is not in the room")
     *     }
     * } catch {
     *     print("Failed to check user presence: \(error)")
     * }
     * ```
     */
    func isUserPresent(withClientID clientID: String) async throws(ErrorInfo) -> Bool

    /**
     * Enters the current user into the chat room presence set.
     * Emits an 'enter' event to all presence subscribers. Multiple calls will emit additional `update` events if the
     * user is already present.
     *
     * - Note: The room must be attached before calling this method.
     *
     * - Parameters:
     *   - data: Optional JSON-serializable data to associate with the user's presence
     *
     * - Throws: ``ErrorInfo`` with code ``InternalError/ErrorCode/roomInInvalidState`` if the room is not attached
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options and attach to it
     * let room = try await chatClient.rooms.get("meeting-room")
     * try await room.attach()
     *
     * do {
     *     // Enter with user metadata
     *     try await room.presence.enter(withData: [
     *         "avatar": "https://example.com/avatar.jpg",
     *         "status": "online",
     *         "role": "moderator"
     *     ])
     *
     *     print("Successfully entered the room")
     * } catch {
     *     print("Failed to enter room: \(error)")
     * }
     * ```
     */
    func enter(withData data: PresenceData) async throws(ErrorInfo)

    /**
     * Updates the presence data for the current user in the chat room.
     * Emits an 'update' event to all subscribers. If the user is not already present, they will be entered automatically.
     *
     * - Note:
     *   - The room must be attached before calling this method.
     *   - This method uses PUT-like semantics - the entire presence data is replaced with the new value.
     *
     * - Parameters:
     *   - data: JSON-serializable data to replace the user's current presence data
     *
     * - Throws: ``ErrorInfo`` with code ``InternalError/ErrorCode/roomInInvalidState`` if the room is not attached
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options
     * let room = try await chatClient.rooms.get("meeting-room")
     * try await room.attach()
     *
     * do {
     *     // Initial enter with status
     *     try await room.presence.enter(withData: [
     *         "username": "John Doe",
     *         "status": "online"
     *     ])
     *
     *     // Update status to busy (replaces entire data object)
     *     try await room.presence.update(withData: [
     *         "username": "John Doe",
     *         "status": "busy",
     *         "statusMessage": "In a meeting"
     *     ])
     *
     *     print("Presence status updated")
     * } catch {
     *     print("Failed to update presence: \(error)")
     * }
     * ```
     */
    func update(withData data: PresenceData) async throws(ErrorInfo)

    /**
     * Removes the current user from the chat room presence set.
     * Emits a 'leave' event to all subscribers. If the user is not present, this is a no-op.
     *
     * - Note: The room must be attached before calling this method.
     *
     * - Parameters:
     *   - data: Optional final presence data to include with the leave event
     *
     * - Throws: ``ErrorInfo`` with code ``InternalError/ErrorCode/roomInInvalidState`` if the room is not attached
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options
     * let room = try await chatClient.rooms.get("meeting-room")
     * try await room.attach()
     *
     * do {
     *     // Enter the room
     *     try await room.presence.enter(withData: [
     *         "avatar": "https://example.com/avatar.jpg",
     *         "status": "online"
     *     ])
     *
     *     // Do some work in the room...
     *
     *     // Leave with a final status message
     *     try await room.presence.leave(withData: [
     *         "status": "offline",
     *         "lastSeen": "\(Date())"
     *     ])
     *
     *     print("Successfully left the room")
     * } catch {
     *     print("Failed to leave room: \(error)")
     * }
     * ```
     */
    func leave(withData data: PresenceData) async throws(ErrorInfo)

    /**
     * Subscribes to all presence events in the chat room.
     *
     * - Note:
     *   - Requires `enableEvents` to be true in the room's presence options.
     *   - The room must be attached to receive events in real-time.
     *
     * - Parameters:
     *   - callback: Callback function invoked when any presence event occurs
     *
     * - Returns: Subscription object with an unsubscribe method
     *
     * - Throws: An ``ErrorInfo`` with ``InternalError/ErrorCode/featureNotEnabledInRoom`` if presence events are not enabled
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options
     * let room = try await chatClient.rooms.get("meeting-room")
     *
     * // Subscribe to all presence events
     * let subscription = room.presence.subscribe { event in
     *     let type = event.type
     *     let member = event.member
     *     switch type {
     *     case .enter:
     *         print("\(member.clientID) entered at \(member.updatedAt)")
     *     case .leave:
     *         print("\(member.clientID) left at \(member.updatedAt)")
     *     case .update:
     *         print("\(member.clientID) updated their data: \(String(describing: member.data))")
     *     case .present:
     *         print("\(member.clientID) is already present")
     *     }
     * }
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     *
     * // Later, unsubscribe when done
     * subscription.unsubscribe()
     * ```
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
 * Type for PresenceMember.
 *
 * Presence members are unique based on their `connectionId` and `clientId`. It is possible for
 * multiple users to have the same `clientId` if they are connected to the room from different devices.
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

    /**
     * The connection ID of this presence member.
     */
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

    /**
     * The timestamp of when the last change in state occurred for this presence member.
     */
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
