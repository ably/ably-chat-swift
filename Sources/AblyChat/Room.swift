import Ably

/**
 * Represents a chat room.
 */
@MainActor
public protocol Room<Channel>: AnyObject, Sendable {
    /// The type of the underlying Ably realtime channel.
    associatedtype Channel

    /// The type of the messages handler.
    associatedtype Messages: AblyChat.Messages
    /// The type of the presence handler.
    associatedtype Presence: AblyChat.Presence
    /// The type of the room reactions handler.
    associatedtype Reactions: AblyChat.RoomReactions
    /// The type of the typing indicator handler.
    associatedtype Typing: AblyChat.Typing
    /// The type of the occupancy handler.
    associatedtype Occupancy: AblyChat.Occupancy

    /// The type of the status subscription.
    associatedtype StatusSubscription: AblyChat.StatusSubscription

    /**
     * The unique identifier of the room.
     *
     * - Returns: The room identifier.
     */
    var name: String { get }

    /**
     * Allows you to send, subscribe-to and query messages in the room.
     *
     * - Returns: The messages instance for the room.
     */
    var messages: Messages { get }

    /**
     * Allows you to subscribe to presence events in the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The presence instance for the room.
     */
    var presence: Presence { get }

    /**
     * Allows you to interact with room-level reactions.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The room reactions instance for the room.
     */
    var reactions: Reactions { get }

    /**
     * Allows you to interact with typing events in the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The typing instance for the room.
     */
    var typing: Typing { get }

    /**
     * Allows you to interact with occupancy metrics for the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The occupancy instance for the room.
     */
    var occupancy: Occupancy { get }

    /**
     * The current status of the room.
     *
     * - Returns: The current room status.
     */
    var status: RoomStatus { get }

    /**
     * The current error, if any, that caused the room to enter the current status.
     */
    var error: ErrorInfo? { get }

    /**
     * Subscribes a given listener to the room status changes.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing ``RoomStatusChange`` events.
     *
     * - Returns: A subscription that can be used to unsubscribe from ``RoomStatusChange`` events.
     */
    @discardableResult
    func onStatusChange(_ callback: @escaping @MainActor (RoomStatusChange) -> Void) -> StatusSubscription

    /**
     * Subscribes a given listener to a detected discontinuity.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing discontinuity events.
     *
     * - Returns: A subscription that can be used to unsubscribe from discontinuity events.
     */
    @discardableResult
    func onDiscontinuity(_ callback: @escaping @MainActor (ErrorInfo) -> Void) -> StatusSubscription

    /**
     * Attaches to the room to receive events in realtime.
     *
     * If a room fails to attach, it will enter either the ``RoomStatus/suspended(error:)`` or ``RoomStatus/failed(error:)`` state.
     *
     * If the room enters the failed state, then it will not automatically retry attaching and intervention is required.
     *
     * If the room enters the suspended state, then the call to attach will throw `ErrorInfo` with the cause of the suspension. However,
     * the room will automatically retry attaching after a delay.
     *
     * - Throws: An `ErrorInfo`.
     */
    func attach() async throws(ErrorInfo)

    /**
     * Detaches from the room to stop receiving events in realtime.
     *
     * - Throws: An `ErrorInfo`.
     */
    func detach() async throws(ErrorInfo)

    /**
     * Returns the room options.
     *
     * - Returns: A copy of the options used to create the room.
     */
    var options: RoomOptions { get }

    /**
     * Get the underlying Ably realtime channel used for the room.
     *
     * - Returns: The realtime channel.
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
