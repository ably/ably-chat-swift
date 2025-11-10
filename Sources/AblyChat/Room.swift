import Ably

/**
 * Represents a chat room.
 */
@MainActor
public protocol Room<Channel>: AnyObject, Sendable {
    /// The underlying Ably Realtime channel type used by this room.
    associatedtype Channel

    /// The messages feature type for sending and receiving chat messages.
    associatedtype Messages: AblyChat.Messages
    /// The presence feature type for managing user presence in the room.
    associatedtype Presence: AblyChat.Presence
    /// The room reactions feature type for sending and receiving room-level reactions.
    associatedtype Reactions: AblyChat.RoomReactions
    /// The typing indicators feature type for managing typing events.
    associatedtype Typing: AblyChat.Typing
    /// The occupancy feature type for monitoring room occupancy metrics.
    associatedtype Occupancy: AblyChat.Occupancy

    /// The subscription type for room status change listeners.
    associatedtype StatusSubscription: AblyChat.StatusSubscription

    /**
     * The unique identifier of the room.
     *
     * - Returns: The room name as provided when the room was created
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get("sports-discussion")
     * print("Connected to room: \(room.name)")
     *
     * // Output: Connected to room: sports-discussion
     * ```
     */
    var name: String { get }

    /**
     * Provides access to the messages feature for sending, receiving, and querying chat messages.
     *
     * - Returns: The ``Messages`` instance for this room
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get("team-chat")
     *
     * // Access messages feature
     * let messages = room.messages
     * ```
     */
    var messages: Messages { get }

    /**
     * Provides access to the presence feature for tracking user presence state.
     *
     * - Returns: The Presence instance for this room
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get("meeting-room")
     *
     * // Access presence feature
     * let presence = room.presence
     * ```
     */
    var presence: Presence { get }

    /**
     * Provides access to room-level reactions for sending ephemeral reactions.
     *
     * - Returns: The ``RoomReactions`` instance for this room
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get("live-stream")
     *
     * // Access room reactions feature
     * let reactions = room.reactions
     * ```
     */
    var reactions: Reactions { get }

    /**
     * Provides access to the typing indicators feature for showing who is currently typing.
     *
     * - Returns: The ``Typing`` instance for this room
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get("support-chat")
     *
     * // Access typing feature
     * let typing = room.typing
     * ```
     */
    var typing: Typing { get }

    /**
     * Provides access to room occupancy metrics for tracking connection and presence counts.
     *
     * - Returns: The ``Occupancy`` instance for this room
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get("webinar-room")
     *
     * // Access occupancy feature
     * let occupancy = room.occupancy
     * ```
     */
    var occupancy: Occupancy { get }

    /**
     * The current lifecycle status of the room.
     *
     * - Returns: The current ``RoomStatus`` value
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get("game-lobby")
     *
     * // Check room status
     * if room.status == .attached {
     *     print("Room is connected and ready")
     * } else if room.status == .failed {
     *     print("Room connection failed")
     * }
     * ```
     */
    var status: RoomStatus { get }

    /**
     * The error that caused the room to enter its current status, if any.
     *
     * - Returns: ErrorInfo if an error caused the current status, nil otherwise
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get("private-chat")
     *
     * if let error = room.error {
     *     print("Room error: \(error.message)")
     *     print("Error code: \(error.code)")
     *
     *     // Handle specific error codes
     *     if error.code == 40300 {
     *         showMessage("Access denied to this room")
     *     } else {
     *         showMessage("Connection failed: \(error.message)")
     *     }
     * }
     * ```
     */
    var error: ErrorInfo? { get }

    /**
     * Registers a listener to be notified of room status changes.
     *
     * Status changes indicate the room's connection lifecycle. Use this to
     * monitor room health and handle connection issues over time.
     *
     * - Parameters:
     *   - callback: Callback invoked when the room status changes
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
     * let room = try await chatClient.rooms.get("support-chat")
     *
     * // Monitor room status changes
     * let statusSubscription = room.onStatusChange { change in
     *     print("Room status: \(change.previous) -> \(change.current)")
     *
     *     // Handle different status transitions
     *     switch change.current {
     *     case .attached:
     *         print("Room is now connected")
     *         enableChatUI()
     *         showOnlineIndicator()
     *
     *     case .attaching:
     *         print("Connecting to room...")
     *         showConnectingSpinner()
     *     default:
     *         break
     *     }
     * }
     *
     * // Clean up when done
     * statusSubscription.off()
     * ```
     */
    @discardableResult
    func onStatusChange(_ callback: @escaping @MainActor (RoomStatusChange) -> Void) -> StatusSubscription

    /**
     * Registers a handler for discontinuity events in the room's connection.
     *
     * A discontinuity occurs when the connection is interrupted and cannot resume
     * from its previous state, potentially resulting in missed messages or events.
     * Use this to detect gaps in the event stream and take corrective action.
     *
     * - Note:
     *   - Discontinuities require fetching missed messages via history.
     *   - Message subscriptions automatically reset their position on discontinuity, see ``MessageSubscriptionResponse/historyBeforeSubscribe(withParams:)`` for more information.
     *   - You should subscribe to discontinuities before attaching to the room.
     *
     * - Parameters:
     *   - handler: Callback invoked when a discontinuity is detected
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
     * let room = try await chatClient.rooms.get(named: "critical-updates")
     *
     * // Handle discontinuities to ensure no messages are missed
     * let discontinuitySubscription = room.onDiscontinuity { reason in
     *     print("Discontinuity detected: \(reason)")
     *
     *     // Show warning to user
     *     showDiscontinuityWarning("Connection interrupted - fetching missed messages...")
     *
     *     // You may also want to fetch missed messages to fill gaps during the discontinuity.
     * }
     *
     * // Attach to the room to start receiving events
     * try await room.attach()
     *
     * // Clean up
     * discontinuitySubscription.off()
     * ```
     */
    @discardableResult
    func onDiscontinuity(_ callback: @escaping @MainActor (ErrorInfo) -> Void) -> StatusSubscription

    /**
     * Attaches to the room to begin receiving events.
     *
     * Establishes an attachment to the room, enabling message delivery,
     * presence updates, typing, and other events. The room must be
     * attached before non-REST-based operations (like `presence.enter()`) can be performed.
     *
     * - Note:
     *   - If attachment fails, the room enters ``RoomStatus/suspended`` or ``RoomStatus/failed`` state.
     *   - Suspended rooms automatically retry; Failed rooms require manual intervention.
     *   - Throws an ``ErrorInfo`` for suspended states, but the room will retry attaching after a delay.
     *
     * - Throws: ``ErrorInfo`` if the room enters suspended state (auto-retry will occur), or if the room enters failed state (manual intervention required)
     *
     * ## Example
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * let room = try await chatClient.rooms.get("team-standup")
     *
     * // Attach to room with error handling
     * do {
     *     try await room.attach()
     *     print("Successfully attached to room")
     *
     *     // Now safe to use room features
     *     try await room.presence.enter()
     *
     *     // And subscriptions will start receiving events
     *     room.messages.subscribe { event in
     *         print("New message: \(event.message)")
     *     }
     * } catch {
     *     print("Failed to attach to room: \(error)")
     *
     *     // Check current room status
     *     if room.status == .suspended {
     *         print("Room suspended, will retry automatically")
     *     } else if room.status == .failed {
     *         print("Room failed, manual intervention needed")
     *     }
     * }
     * ```
     */
    func attach() async throws(ErrorInfo)

    /**
     * Detaches from the room to stop receiving chat events.
     *
     * Subscriptions remain registered but won't receive events until the room is
     * reattached. Use this to gracefully detach when leaving a chat view. This command leaves all
     * subscriptions intact, so they will resume receiving events when the room is reattached.
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
     * // Get a room with default options and attach to it
     * let room = try await chatClient.rooms.get("customer-support")
     * try await room.attach()
     *
     * // Do chat operations...
     *
     * do {
     *     // Detach from room
     *     try await room.detach()
     *     print("Successfully detached from room")
     * } catch {
     *     print("Failed to detach from room: \(error)")
     * }
     * ```
     */
    func detach() async throws(ErrorInfo)

    /**
     * Returns a copy of the options used to configure the room.
     *
     * Provides access to all room configuration including presence, typing, reactions,
     * and occupancy settings. The returned object is a copy to prevent external
     * modifications to the room's configuration.
     *
     * - Returns: A copy of the room options
     *
     * ## Example
     *
     * ```swift
     * import AblyChat
     *
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Create room with specific options
     * let room = try await chatClient.rooms.get(named: "conference-hall", options: RoomOptions(
     *     presence: PresenceOptions(
     *         enableEvents: true
     *     ),
     *     typing: TypingOptions(
     *         heartbeatThrottle: 1.5
     *     ),
     *     occupancy: OccupancyOptions(
     *         enableEvents: true
     *     )
     * ))
     *
     * // Get room options to check configuration
     * let options = room.options
     *
     * print("Room configuration:")
     * print("Presence events: \(String(describing: options.presence?.enableEvents))")
     * print("Typing throttle: \(String(describing: options.typing?.heartbeatThrottle))")
     * print("Occupancy events: \(String(describing: options.occupancy?.enableEvents))")
     * ```
     */
    var options: RoomOptions { get }

    /**
     * Provides direct access to the underlying Ably Realtime channel.
     *
     * Use this for advanced scenarios requiring direct access to the underlying channel. Directly interacting
     * with the Ably channel can lead to unexpected behavior, and so is generally discouraged.
     *
     * - Returns: The underlying Ably RealtimeChannel instance
     *
     * ## Example
     *
     * ```swift
     * let room = try await chatClient.rooms.get(named: "advanced-room")
     *
     * // Access underlying channel for advanced operations
     * let channel = room.channel
     * ```
     */
    var channel: Channel { get }
}

/// `AsyncSequence` variant of `Room` status changes.
public extension Room {
    /**
     * Subscribes a given listener to the room status changes.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``RoomStatusChange`` events.
     */
    func onStatusChange(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<RoomStatusChange> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<RoomStatusChange>(bufferingPolicy: bufferingPolicy)

        let subscription = onStatusChange { statusChange in
            subscriptionAsyncSequence.emit(statusChange)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.off()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``onStatusChange(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func onStatusChange() -> SubscriptionAsyncSequence<RoomStatusChange> {
        onStatusChange(bufferingPolicy: .unbounded)
    }

    /**
     * Subscribes a given listener to a detected discontinuity using `AsyncSequence` subscription.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through discontinuity events.
     */
    func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<ErrorInfo> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<ErrorInfo>(bufferingPolicy: bufferingPolicy)

        let subscription = onDiscontinuity { error in
            subscriptionAsyncSequence.emit(error)
        }
        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.off()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``onDiscontinuity(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func onDiscontinuity() -> SubscriptionAsyncSequence<ErrorInfo> {
        onDiscontinuity(bufferingPolicy: .unbounded)
    }
}

/// A ``Room`` that exposes additional functionality for use within the SDK.
internal protocol InternalRoom: Room {
    func release() async
}

/**
 * Represents a change in the status of the room.
 */
public struct RoomStatusChange: Sendable {
    /**
     * The new status of the room.
     */
    public var current: RoomStatus

    /**
     * The previous status of the room.
     */
    public var previous: RoomStatus

    /**
     * An error that provides a reason why the room has
     * entered the new status, if applicable.
     */
    public var error: ErrorInfo?

    /// Memberwise initializer to create a `RoomStatusChange`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(current: RoomStatus, previous: RoomStatus, error: ErrorInfo? = nil) {
        self.current = current
        self.previous = previous
        self.error = error
    }
}

@MainActor
internal protocol RoomFactory: Sendable {
    associatedtype Realtime: InternalRealtimeClientProtocol where Realtime.Channels.Channel.Proxied == Room.Channel
    associatedtype Room: AblyChat.InternalRoom

    func createRoom(realtime: Realtime, chatAPI: ChatAPI<Realtime>, name: String, options: RoomOptions, logger: any InternalLogger) throws(ErrorInfo) -> Room
}

internal final class DefaultRoomFactory<Realtime: InternalRealtimeClientProtocol>: Sendable, RoomFactory {
    private let lifecycleManagerFactory = DefaultRoomLifecycleManagerFactory()

    internal func createRoom(realtime: Realtime, chatAPI: ChatAPI<Realtime>, name: String, options: RoomOptions, logger: any InternalLogger) throws(ErrorInfo) -> DefaultRoom<Realtime, DefaultRoomLifecycleManager> {
        try DefaultRoom(
            realtime: realtime,
            chatAPI: chatAPI,
            name: name,
            options: options,
            logger: logger,
            lifecycleManagerFactory: lifecycleManagerFactory,
        )
    }
}

internal class DefaultRoom<Realtime: InternalRealtimeClientProtocol, LifecycleManager: RoomLifecycleManager>: InternalRoom {
    internal let name: String
    internal let options: RoomOptions
    private let chatAPI: ChatAPI<Realtime>

    internal let messages: DefaultMessages<Realtime>
    internal let reactions: DefaultRoomReactions
    internal let presence: DefaultPresence
    internal let occupancy: DefaultOccupancy<Realtime>
    internal let typing: DefaultTyping

    // Exposed for testing.
    private let realtime: Realtime

    private let lifecycleManager: LifecycleManager
    private let internalChannel: Realtime.Channels.Channel

    // Note: This property only exists to satisfy the `Room` interface. Do not use this property inside this class; use `internalChannel`.
    internal var channel: Realtime.Channels.Channel.Proxied {
        internalChannel.proxied
    }

    #if DEBUG
        internal var testsOnly_internalChannel: Realtime.Channels.Channel {
            internalChannel
        }
    #endif

    private let logger: any InternalLogger

    internal init<LifecycleManagerFactory: RoomLifecycleManagerFactory>(realtime: Realtime, chatAPI: ChatAPI<Realtime>, name: String, options: RoomOptions, logger: any InternalLogger, lifecycleManagerFactory: LifecycleManagerFactory) throws(ErrorInfo) where LifecycleManagerFactory.Manager == LifecycleManager {
        self.realtime = realtime
        self.name = name
        self.options = options
        self.logger = logger
        self.chatAPI = chatAPI

        internalChannel = Self.createChannel(roomName: name, roomOptions: options, realtime: realtime)

        lifecycleManager = lifecycleManagerFactory.createManager(
            channel: internalChannel,
            logger: logger,
        )

        messages = DefaultMessages(
            channel: internalChannel,
            chatAPI: chatAPI,
            roomName: name,
            options: options.messages,
            logger: logger,
        )

        reactions = DefaultRoomReactions(
            realtime: realtime,
            channel: internalChannel,
            roomName: name,
            logger: logger,
        )

        presence = DefaultPresence(
            channel: internalChannel,
            roomLifecycleManager: lifecycleManager,
            roomName: name,
            logger: logger,
            options: options.presence,
        )

        occupancy = DefaultOccupancy(
            channel: internalChannel,
            chatAPI: chatAPI,
            roomName: name,
            logger: logger,
            options: options.occupancy,
        )

        typing = DefaultTyping(
            channel: internalChannel,
            roomName: name,
            logger: logger,
            heartbeatThrottle: options.typing.heartbeatThrottle,
            clock: SystemClock(),
        )
    }

    private static func createChannel(roomName: String, roomOptions: RoomOptions, realtime: Realtime) -> Realtime.Channels.Channel {
        let channelOptions = ARTRealtimeChannelOptions()

        // CHA-GP2a
        channelOptions.attachOnSubscribe = false

        // Initial modes (CHA-RC3d)
        channelOptions.modes = [.publish, .subscribe, .presence, .annotationPublish]

        // CHA-RC3a (Multiple features share a realtime channel. We fetch the channel exactly once, merging the channel options for the various features.)
        if roomOptions.presence.enableEvents {
            // CHA-RC3d1
            channelOptions.modes.insert(.presenceSubscribe)
        }
        if roomOptions.occupancy.enableEvents {
            // CHA-O6a, CHA-O6b
            var params: [String: String] = channelOptions.params ?? [:]
            params["occupancy"] = "metrics"
            channelOptions.params = params
        }
        if roomOptions.messages.rawMessageReactions {
            // CHA-RC3d2
            channelOptions.modes.insert(.annotationSubscribe)
        }

        // CHA-RC3c
        return realtime.channels.get("\(roomName)::$chat", options: channelOptions)
    }

    /// See ``Room/attach()``
    public func attach() async throws(ErrorInfo) {
        try await lifecycleManager.performAttachOperation()
    }

    /// See ``Room/detach()``
    public func detach() async throws(ErrorInfo) {
        try await lifecycleManager.performDetachOperation()
    }

    internal func release() async {
        await lifecycleManager.performReleaseOperation()

        // CHA-RL3h
        realtime.channels.release(internalChannel.name)
    }

    // MARK: - Room status

    @discardableResult
    internal func onStatusChange(_ callback: @escaping @MainActor (RoomStatusChange) -> Void) -> LifecycleManager.StatusSubscription {
        lifecycleManager.onRoomStatusChange(callback)
    }

    internal var status: RoomStatus {
        lifecycleManager.roomStatus
    }

    internal var error: ErrorInfo? {
        lifecycleManager.error
    }

    // MARK: - Discontinuities

    @discardableResult
    internal func onDiscontinuity(_ callback: @escaping @MainActor (ErrorInfo) -> Void) -> LifecycleManager.StatusSubscription {
        lifecycleManager.onDiscontinuity(callback)
    }
}
