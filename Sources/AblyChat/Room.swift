import Ably

public protocol Room: AnyObject, Sendable {
    var roomID: String { get }
    var messages: any Messages { get }
    // To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
    var presence: any Presence { get }
    // To access this property if reactions are not enabled for the room is a programmer error, and will lead to `fatalError` being called.
    var reactions: any RoomReactions { get }
    // To access this property if typing is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
    var typing: any Typing { get }
    // To access this property if occupancy is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
    var occupancy: any Occupancy { get }
    // TODO: change to `status`
    var status: RoomStatus { get async }
    func onStatusChange(bufferingPolicy: BufferingPolicy) async -> Subscription<RoomStatusChange>
    func attach() async throws
    func detach() async throws
    var options: RoomOptions { get }
}

public struct RoomStatusChange: Sendable, Equatable {
    public var current: RoomStatus
    public var previous: RoomStatus

    public init(current: RoomStatus, previous: RoomStatus) {
        self.current = current
        self.previous = previous
    }
}

internal protocol RoomFactory: Sendable {
    associatedtype Room: AblyChat.Room

    func createRoom(realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger) async throws -> Room
}

internal final class DefaultRoomFactory: Sendable, RoomFactory {
    private let lifecycleManagerFactory = DefaultRoomLifecycleManagerFactory()

    internal func createRoom(realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger) async throws -> DefaultRoom<DefaultRoomLifecycleManagerFactory> {
        try await DefaultRoom(
            realtime: realtime,
            chatAPI: chatAPI,
            roomID: roomID,
            options: options,
            logger: logger,
            lifecycleManagerFactory: lifecycleManagerFactory
        )
    }
}

internal actor DefaultRoom<LifecycleManagerFactory: RoomLifecycleManagerFactory>: Room where LifecycleManagerFactory.Contributor == DefaultRoomLifecycleContributor {
    internal nonisolated let roomID: String
    internal nonisolated let options: RoomOptions
    private let chatAPI: ChatAPI

    public nonisolated let messages: any Messages

    // Exposed for testing.
    private nonisolated let realtime: RealtimeClient

    private let lifecycleManager: any RoomLifecycleManager

    private let logger: InternalLogger

    internal init(realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger, lifecycleManagerFactory: LifecycleManagerFactory) async throws {
        self.realtime = realtime
        self.roomID = roomID
        self.options = options
        self.logger = logger
        self.chatAPI = chatAPI

        guard let clientId = realtime.clientId else {
            throw ARTErrorInfo.create(withCode: 40000, message: "Ensure your Realtime instance is initialized with a clientId.")
        }

        let channels = Self.createChannels(roomID: roomID, realtime: realtime)
        let contributors = Self.createContributors(channels: channels)

        lifecycleManager = await lifecycleManagerFactory.createManager(
            contributors: contributors,
            logger: logger
        )

        messages = await DefaultMessages(
            channel: channels[.messages]!,
            chatAPI: chatAPI,
            roomID: roomID,
            clientID: clientId
        )
    }

    private static func createChannels(roomID: String, realtime: RealtimeClient) -> [RoomFeature: RealtimeChannelProtocol] {
        .init(uniqueKeysWithValues: [RoomFeature.messages].map { feature in
            let channel = realtime.getChannel(feature.channelNameForRoomID(roomID))

            return (feature, channel)
        })
    }

    private static func createContributors(channels: [RoomFeature: RealtimeChannelProtocol]) -> [DefaultRoomLifecycleContributor] {
        channels.map { entry in
            let (feature, channel) = entry
            return .init(channel: .init(underlyingChannel: channel), feature: feature)
        }
    }

    public nonisolated var presence: any Presence {
        fatalError("Not yet implemented")
    }

    public nonisolated var reactions: any RoomReactions {
        fatalError("Not yet implemented")
    }

    public nonisolated var typing: any Typing {
        fatalError("Not yet implemented")
    }

    public nonisolated var occupancy: any Occupancy {
        fatalError("Not yet implemented")
    }

    public func attach() async throws {
        try await lifecycleManager.performAttachOperation()
    }

    public func detach() async throws {
        try await lifecycleManager.performDetachOperation()
    }

    // MARK: - Room status

    internal func onStatusChange(bufferingPolicy: BufferingPolicy) async -> Subscription<RoomStatusChange> {
        await lifecycleManager.onChange(bufferingPolicy: bufferingPolicy)
    }

    internal var status: RoomStatus {
        get async {
            await lifecycleManager.roomStatus
        }
    }
}
