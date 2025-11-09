import Ably

/**
 * This interface is used to interact with occupancy in a chat room: subscribing to occupancy updates and
 * fetching the current room occupancy metrics.
 *
 * Get an instance via ``Room/occupancy``.
 */
@MainActor
public protocol Occupancy: AnyObject, Sendable {
    // swiftlint:disable:next missing_docs
    associatedtype Subscription: AblyChat.Subscription

    /**
     * Subscribes to occupancy updates for the chat room.
     *
     * Receives updates whenever the number of connections or present members in the room changes.
     * This is useful for displaying active user counts, monitoring room capacity, or tracking
     * engagement metrics.
     *
     * - Note:
     *   - Requires ``OccupancyOptions/enableEvents`` to be true in the room's occupancy options. It's a programmer error otherwise.
     *   - The room should be attached to receive occupancy events.
     *
     * - Parameters:
     *   - callback: Callback invoked when room occupancy changes
     *
     * - Returns: Subscription object with an unsubscribe method
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Create room with occupancy events enabled
     * let room = try await chatClient.rooms.get(named: "conference-room", options: RoomOptions(
     *     occupancy: .init(enableEvents: true)
     * ))
     *
     * // Subscribe to occupancy updates
     * let subscription = room.occupancy.subscribe { event in
     *     let connections = event.occupancy.connections
     *     let presenceMembers = event.occupancy.presenceMembers
     *
     *     print("Room occupancy updated:")
     *     print("Total connections: \(connections)")
     *     print("Presence members: \(presenceMembers)")
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
    func subscribe(_ callback: @escaping @MainActor (OccupancyEvent) -> Void) -> Subscription

    /**
     * Fetches the current occupancy of the chat room from the server.
     *
     * Retrieves the latest occupancy metrics, including the number
     * of active connections and presence members. Use this for on-demand occupancy
     * checks or when occupancy events are not enabled.
     *
     * - Note: This method uses the Ably Chat REST API and so does not require the room
     * to be attached to be called.
     *
     * - Returns: Current occupancy data
     *
     * - Throws: ``ErrorInfo``
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get(named: "webinar-room")
     *
     * // Get current occupancy on demand
     * do {
     *     let occupancy = try await room.occupancy.get()
     *
     *     print("Current room statistics:")
     *     print("Active connections: \(occupancy.connections)")
     *     print("Presence members: \(occupancy.presenceMembers)")
     * } catch {
     *     print("Failed to fetch occupancy: \(error)")
     * }
     * ```
     */
    func get() async throws(ErrorInfo) -> OccupancyData

    /**
     * Gets the latest occupancy data cached from realtime events.
     *
     * Returns the most recent occupancy metrics received via subscription. Returns nil
     * if no occupancy events have been received yet since the room was attached.
     *
     * - Note:
     *   - Requires `enableEvents` to be true in the room's occupancy options.
     *   - Returns nil until the first occupancy event is received.
     *   - It is a programmer error to read this property if occupancy events are not enabled in the room options.
     *
     * - Returns: Latest cached occupancy data or nil if no events received
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Room with occupancy events enabled
     * let room = try await chatClient.rooms.get(named: "gaming-lobby", options: RoomOptions(
     *     occupancy: .init(enableEvents: true)
     * ))
     *
     * // Subscribe to occupancy events
     * room.occupancy.subscribe { event in
     *     print("Occupancy updated: \(event.occupancy)")
     * }
     *
     * // Get cached occupancy instantly (after first event)
     * func displayCurrentOccupancy() {
     *     if let occupancy = room.occupancy.current {
     *         print("Current cached occupancy:")
     *         print("Connections: \(occupancy.connections)")
     *         print("Presence: \(occupancy.presenceMembers)")
     *     } else {
     *         print("No occupancy data received yet, try fetching from server")
     *     }
     * }
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     * ```
     */
    var current: OccupancyData? { get }
}

/// `AsyncSequence` variant of receiving room occupancy events.
public extension Occupancy {
    /**
     * Subscribes a given listener to occupancy updates of the chat room.
     *
     * Note that it is a programmer error to call this method if occupancy events are not enabled in the room options. Make sure to set `enableEvents: true` in your room's occupancy options to use this feature.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``OccupancyEvent`` events.
     */
    func subscribe(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<OccupancyEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<OccupancyEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = subscribe { occupancyEvent in
            subscriptionAsyncSequence.emit(occupancyEvent)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.unsubscribe()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``subscribe(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func subscribe() -> SubscriptionAsyncSequence<OccupancyEvent> {
        subscribe(bufferingPolicy: .unbounded)
    }
}

/**
 * Represents the occupancy of a chat room.
 */
public struct OccupancyData: Sendable {
    /**
     * The number of connections to the chat room.
     */
    public var connections: Int

    /**
     * The number of presence members in the chat room - members who have entered presence.
     */
    public var presenceMembers: Int

    /// Memberwise initializer to create a `OccupancyData`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(connections: Int, presenceMembers: Int) {
        self.connections = connections
        self.presenceMembers = presenceMembers
    }
}

/**
 * Enum representing occupancy events.
 */
public enum OccupancyEventType: Sendable {
    /**
     * Event triggered when occupancy is updated.
     */
    case updated
}

/**
 * Represents an occupancy event.
 */
public struct OccupancyEvent: Sendable {
    /**
     * The type of the occupancy event.
     */
    public var type: OccupancyEventType

    /**
     * The occupancy data.
     */
    public var occupancy: OccupancyData

    /// Memberwise initializer to create a `OccupancyEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(type: OccupancyEventType, occupancy: OccupancyData) {
        self.type = type
        self.occupancy = occupancy
    }
}

extension OccupancyData: JSONObjectDecodable {
    internal init(jsonObject: [String: JSONValue]) throws(ErrorInfo) {
        try self.init(
            connections: Int(jsonObject.numberValueForKey("connections")),
            presenceMembers: Int(jsonObject.numberValueForKey("presenceMembers")),
        )
    }
}
