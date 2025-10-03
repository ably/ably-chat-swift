import Ably

/**
 * Represents a chat room.
 */
@MainActor
public protocol Room: AnyObject, Sendable {
    associatedtype Channel

    associatedtype Messages: AblyChat.Messages
    associatedtype Presence: AblyChat.Presence
    associatedtype Reactions: AblyChat.RoomReactions
    associatedtype Typing: AblyChat.Typing
    associatedtype Occupancy: AblyChat.Occupancy

    associatedtype StatusSubscription: StatusSubscriptionProtocol

    /**
     * The unique identifier of the room.
     *
     * - Returns: The room identifier.
     */
    nonisolated var name: String { get }

    /**
     * Allows you to send, subscribe-to and query messages in the room.
     *
     * - Returns: The messages instance for the room.
     */
    nonisolated var messages: Messages { get }

    /**
     * Allows you to subscribe to presence events in the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The presence instance for the room.
     */
    nonisolated var presence: Presence { get }

    /**
     * Allows you to interact with room-level reactions.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The room reactions instance for the room.
     */
    nonisolated var reactions: Reactions { get }

    /**
     * Allows you to interact with typing events in the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The typing instance for the room.
     */
    nonisolated var typing: Typing { get }

    /**
     * Allows you to interact with occupancy metrics for the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The occupancy instance for the room.
     */
    nonisolated var occupancy: Occupancy { get }

    /**
     * The current status of the room.
     *
     * - Returns: The current room status.
     */
    var status: RoomStatus { get }

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
     *   - callback: The listener closure for capturing ``DiscontinuityEvent``.
     *
     * - Returns: A subscription that can be used to unsubscribe from ``DiscontinuityEvent``.
     */
    @discardableResult
    func onDiscontinuity(_ callback: @escaping @MainActor (DiscontinuityEvent) -> Void) -> StatusSubscription

    /**
     * Attaches to the room to receive events in realtime.
     *
     * If a room fails to attach, it will enter either the ``RoomStatus/suspended(error:)`` or ``RoomStatus/failed(error:)`` state.
     *
     * If the room enters the failed state, then it will not automatically retry attaching and intervention is required.
     *
     * If the room enters the suspended state, then the call to attach will throw `ARTErrorInfo` with the cause of the suspension. However,
     * the room will automatically retry attaching after a delay.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func attach() async throws(ARTErrorInfo)

    /**
     * Detaches from the room to stop receiving events in realtime.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func detach() async throws(ARTErrorInfo)

    /**
     * Returns the room options.
     *
     * - Returns: A copy of the options used to create the room.
     */
    nonisolated var options: RoomOptions { get }

    /**
     * Get the underlying Ably realtime channel used for the room.
     *
     * - Returns: The realtime channel.
     */
    nonisolated var channel: Channel { get }
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
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``DiscontinuityEvent`` events.
     */
    func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<DiscontinuityEvent> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<DiscontinuityEvent>(bufferingPolicy: bufferingPolicy)

        let subscription = onDiscontinuity { statusChange in
            subscriptionAsyncSequence.emit(statusChange)
        }
        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.off()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``onDiscontinuity(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func onDiscontinuity() -> SubscriptionAsyncSequence<DiscontinuityEvent> {
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
public struct RoomStatusChange: Sendable, Equatable {
    /**
     * The new status of the room.
     */
    public var current: RoomStatus

    /**
     * The previous status of the room.
     */
    public var previous: RoomStatus

    public init(current: RoomStatus, previous: RoomStatus) {
        self.current = current
        self.previous = previous
    }
}

@MainActor
internal protocol RoomFactory: Sendable {
    associatedtype Realtime: InternalRealtimeClientProtocol where Realtime.Channels.Channel.Proxied == Room.Channel
    associatedtype Room: AblyChat.InternalRoom

    func createRoom(realtime: Realtime, chatAPI: ChatAPI, name: String, options: RoomOptions, logger: any InternalLogger) throws(InternalError) -> Room
}

internal final class DefaultRoomFactory<Realtime: InternalRealtimeClientProtocol>: Sendable, RoomFactory {
    private let lifecycleManagerFactory = DefaultRoomLifecycleManagerFactory()

    internal func createRoom(realtime: Realtime, chatAPI: ChatAPI, name: String, options: RoomOptions, logger: any InternalLogger) throws(InternalError) -> DefaultRoom<Realtime, DefaultRoomLifecycleManager> {
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
    internal nonisolated let name: String
    internal nonisolated let options: RoomOptions
    private let chatAPI: ChatAPI

    internal nonisolated let messages: DefaultMessages
    internal nonisolated let reactions: DefaultRoomReactions
    internal nonisolated let presence: DefaultPresence
    internal nonisolated let occupancy: DefaultOccupancy
    internal nonisolated let typing: DefaultTyping

    // Exposed for testing.
    private nonisolated let realtime: Realtime

    private let lifecycleManager: LifecycleManager
    private let internalChannel: Realtime.Channels.Channel

    // Note: This property only exists to satisfy the `Room` interface. Do not use this property inside this class; use `internalChannel`.
    internal nonisolated var channel: Realtime.Channels.Channel.Proxied {
        internalChannel.proxied
    }

    #if DEBUG
        internal nonisolated var testsOnly_internalChannel: Realtime.Channels.Channel {
            internalChannel
        }
    #endif

    private let logger: any InternalLogger

    internal init<LifecycleManagerFactory: RoomLifecycleManagerFactory>(realtime: Realtime, chatAPI: ChatAPI, name: String, options: RoomOptions, logger: any InternalLogger, lifecycleManagerFactory: LifecycleManagerFactory) throws(InternalError) where LifecycleManagerFactory.Manager == LifecycleManager {
        self.realtime = realtime
        self.name = name
        self.options = options
        self.logger = logger
        self.chatAPI = chatAPI

        guard let clientId = realtime.clientId else {
            throw ARTErrorInfo(chatError: .clientIdRequired).toInternalError()
        }

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
            clientID: clientId,
            logger: logger,
        )

        reactions = DefaultRoomReactions(
            channel: internalChannel,
            clientID: clientId,
            roomName: name,
            logger: logger,
        )

        presence = DefaultPresence(
            channel: internalChannel,
            roomLifecycleManager: lifecycleManager,
            roomName: name,
            clientID: clientId,
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
            clientID: clientId,
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

    public func attach() async throws(ARTErrorInfo) {
        do {
            try await lifecycleManager.performAttachOperation()
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    public func detach() async throws(ARTErrorInfo) {
        do {
            try await lifecycleManager.performDetachOperation()
        } catch {
            throw error.toARTErrorInfo()
        }
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

    // MARK: - Discontinuities

    @discardableResult
    internal func onDiscontinuity(_ callback: @escaping @MainActor (DiscontinuityEvent) -> Void) -> LifecycleManager.StatusSubscription {
        lifecycleManager.onDiscontinuity(callback)
    }
}
