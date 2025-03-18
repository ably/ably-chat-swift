import Ably

/**
 * Represents a chat room.
 */
@MainActor
public protocol Room: AnyObject, Sendable {
    /**
     * The unique identifier of the room.
     *
     * - Returns: The room identifier.
     */
    nonisolated var roomID: String { get }

    /**
     * Allows you to send, subscribe-to and query messages in the room.
     *
     * - Returns: The messages instance for the room.
     */
    nonisolated var messages: any Messages { get }

    /**
     * Allows you to subscribe to presence events in the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The presence instance for the room.
     */
    nonisolated var presence: any Presence { get }

    /**
     * Allows you to interact with room-level reactions.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The room reactions instance for the room.
     */
    nonisolated var reactions: any RoomReactions { get }

    /**
     * Allows you to interact with typing events in the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The typing instance for the room.
     */
    nonisolated var typing: any Typing { get }

    /**
     * Allows you to interact with occupancy metrics for the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The occupancy instance for the room.
     */
    nonisolated var occupancy: any Occupancy { get }

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
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``RoomStatusChange`` events.
     */
    func onStatusChange(bufferingPolicy: BufferingPolicy) -> Subscription<RoomStatusChange>

    /// Same as calling ``onStatusChange(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Room` protocol provides a default implementation of this method.
    func onStatusChange() -> Subscription<RoomStatusChange>

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
     * Subscribes a given listener to a detected discontinuity.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``DiscontinuityEvent`` events.
     */
    func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent>

    /// Same as calling ``onDiscontinuity(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Room` protocol provides a default implementation of this method.
    func onDiscontinuity() -> Subscription<DiscontinuityEvent>

    /**
     * Get the underlying Ably realtime channel used for the room.
     *
     * - Returns: The realtime channel.
     */
    nonisolated var channel: any RealtimeChannelProtocol { get }
}

public extension Room {
    func onStatusChange() -> Subscription<RoomStatusChange> {
        onStatusChange(bufferingPolicy: .unbounded)
    }

    func onDiscontinuity() -> Subscription<DiscontinuityEvent> {
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
    associatedtype Room: AblyChat.InternalRoom

    func createRoom(realtime: any InternalRealtimeClientProtocol, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger) throws(InternalError) -> Room
}

internal final class DefaultRoomFactory: Sendable, RoomFactory {
    private let lifecycleManagerFactory = DefaultRoomLifecycleManagerFactory()

    internal func createRoom(realtime: any InternalRealtimeClientProtocol, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger) throws(InternalError) -> DefaultRoom {
        try DefaultRoom(
            realtime: realtime,
            chatAPI: chatAPI,
            roomID: roomID,
            options: options,
            logger: logger,
            lifecycleManagerFactory: lifecycleManagerFactory
        )
    }
}

internal class DefaultRoom: InternalRoom {
    internal nonisolated let roomID: String
    internal nonisolated let options: RoomOptions
    private let chatAPI: ChatAPI

    public nonisolated let messages: any Messages
    public nonisolated let reactions: any RoomReactions
    public nonisolated let presence: any Presence
    public nonisolated let occupancy: any Occupancy
    public nonisolated let typing: any Typing

    // Exposed for testing.
    private nonisolated let realtime: any InternalRealtimeClientProtocol

    private let lifecycleManager: any RoomLifecycleManager
    private let internalChannel: any InternalRealtimeChannelProtocol

    // Note: This property only exists to satisfy the `Room` interface. Do not use this property inside this class; use `internalChannel`.
    internal nonisolated var channel: any RealtimeChannelProtocol {
        internalChannel.underlying
    }

    #if DEBUG
        internal nonisolated var testsOnly_internalChannel: any InternalRealtimeChannelProtocol {
            internalChannel
        }
    #endif

    private let logger: InternalLogger

    internal init(realtime: any InternalRealtimeClientProtocol, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger, lifecycleManagerFactory: any RoomLifecycleManagerFactory) throws(InternalError) {
        self.realtime = realtime
        self.roomID = roomID
        self.options = options
        self.logger = logger
        self.chatAPI = chatAPI

        guard let clientId = realtime.clientId else {
            throw ARTErrorInfo.create(withCode: 40000, message: "Ensure your Realtime instance is initialized with a clientId.").toInternalError()
        }

        internalChannel = Self.createChannel(roomID: roomID, roomOptions: options, realtime: realtime)

        lifecycleManager = lifecycleManagerFactory.createManager(
            channel: internalChannel,
            logger: logger
        )

        messages = DefaultMessages(
            channel: internalChannel,
            chatAPI: chatAPI,
            roomID: roomID,
            clientID: clientId,
            logger: logger
        )

        reactions = DefaultRoomReactions(
            channel: internalChannel,
            clientID: clientId,
            roomID: roomID,
            logger: logger
        )

        presence = DefaultPresence(
            channel: internalChannel,
            roomLifecycleManager: lifecycleManager,
            roomID: roomID,
            clientID: clientId,
            logger: logger
        )

        occupancy = DefaultOccupancy(
            channel: internalChannel,
            chatAPI: chatAPI,
            roomID: roomID,
            logger: logger
        )

        typing = DefaultTyping(
            channel: internalChannel,
            roomID: roomID,
            clientID: clientId,
            logger: logger,
            heartbeatThrottle: options.typing.heartbeatThrottle
        )
    }

    private static func createChannel(roomID: String, roomOptions: RoomOptions, realtime: any InternalRealtimeClientProtocol) -> any InternalRealtimeChannelProtocol {
        let channelOptions = ARTRealtimeChannelOptions()

        // CHA-GP2a
        channelOptions.attachOnSubscribe = false

        // CHA-RC3a (Multiple features share a realtime channel. We fetch the channel exactly once, merging the channel options for the various features.)
        if !roomOptions.presence.receivePresenceEvents {
            // CHA-PR9c2
            channelOptions.modes = [.publish, .subscribe, .presence]
        }
        if roomOptions.occupancy.enableInboundOccupancy {
            // CHA-O6a, CHA-O6b
            var params: [String: String] = channelOptions.params ?? [:]
            params["occupancy"] = "metrics"
            channelOptions.params = params
        }

        // CHA-RC3c
        return realtime.channels.get("\(roomID)::$chat", options: channelOptions)
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

    internal func onStatusChange(bufferingPolicy: BufferingPolicy) -> Subscription<RoomStatusChange> {
        lifecycleManager.onRoomStatusChange(bufferingPolicy: bufferingPolicy)
    }

    internal var status: RoomStatus {
        lifecycleManager.roomStatus
    }

    // MARK: - Discontinuities

    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        lifecycleManager.onDiscontinuity(bufferingPolicy: bufferingPolicy)
    }
}
