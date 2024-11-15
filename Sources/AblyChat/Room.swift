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

/// A ``Room`` that exposes additional functionality for use within the SDK.
internal protocol InternalRoom: Room {
    func release() async
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
    associatedtype Room: AblyChat.InternalRoom

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

internal actor DefaultRoom<LifecycleManagerFactory: RoomLifecycleManagerFactory>: InternalRoom where LifecycleManagerFactory.Contributor == DefaultRoomLifecycleContributor {
    internal nonisolated let roomID: String
    internal nonisolated let options: RoomOptions
    private let chatAPI: ChatAPI

    public nonisolated let messages: any Messages
    private let _reactions: (any RoomReactions)?
    private let _presence: (any Presence)?
    private let _occupancy: (any Occupancy)?

    // Exposed for testing.
    private nonisolated let realtime: RealtimeClient

    private let lifecycleManager: any RoomLifecycleManager
    private let channels: [RoomFeature: any RealtimeChannelProtocol]

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

        let featureChannels = Self.createFeatureChannels(roomID: roomID, roomOptions: options, realtime: realtime)
        channels = featureChannels.mapValues(\.channel)
        let contributors = featureChannels.values.map(\.contributor)

        lifecycleManager = await lifecycleManagerFactory.createManager(
            contributors: contributors,
            logger: logger
        )

        // TODO: Address force unwrapping of `channels` within feature initialisation below: https://github.com/ably-labs/ably-chat-swift/issues/105

        messages = await DefaultMessages(
            featureChannel: featureChannels[.messages]!,
            chatAPI: chatAPI,
            roomID: roomID,
            clientID: clientId
        )

        _reactions = options.reactions != nil ? await DefaultRoomReactions(
            featureChannel: featureChannels[.reactions]!,
            clientID: clientId,
            roomID: roomID,
            logger: logger
        ) : nil

        _presence = options.presence != nil ? await DefaultPresence(
            featureChannel: featureChannels[.presence]!,
            roomID: roomID,
            clientID: clientId,
            logger: logger
        ) : nil

        _occupancy = options.occupancy != nil ? DefaultOccupancy(
            featureChannel: featureChannels[.occupancy]!,
            chatAPI: chatAPI,
            roomID: roomID,
            logger: logger
        ) : nil
    }

    private static func createFeatureChannels(roomID: String, roomOptions: RoomOptions, realtime: RealtimeClient) -> [RoomFeature: DefaultFeatureChannel] {
        .init(uniqueKeysWithValues: [
            RoomFeature.messages,
            RoomFeature.reactions,
            RoomFeature.presence,
            RoomFeature.occupancy,
        ].map { feature in
            let channelOptions = ARTRealtimeChannelOptions()

            // channel setup for presence and occupancy
            if feature == .presence {
                let channelOptions = ARTRealtimeChannelOptions()
                let presenceOptions = roomOptions.presence

                if presenceOptions?.enter ?? false {
                    channelOptions.modes.insert(.presence)
                }

                if presenceOptions?.subscribe ?? false {
                    channelOptions.modes.insert(.presenceSubscribe)
                }
            } else if feature == .occupancy {
                channelOptions.params = ["occupancy": "metrics"]
            }

            let channel = realtime.getChannel(feature.channelNameForRoomID(roomID), opts: channelOptions)
            let contributor = DefaultRoomLifecycleContributor(channel: .init(underlyingChannel: channel), feature: feature)

            return (feature, .init(channel: channel, contributor: contributor))
        })
    }

    public nonisolated var presence: any Presence {
        guard let _presence else {
            fatalError("Presence is not enabled for this room")
        }
        return _presence
    }

    public nonisolated var reactions: any RoomReactions {
        guard let _reactions else {
            fatalError("Reactions are not enabled for this room")
        }
        return _reactions
    }

    public nonisolated var typing: any Typing {
        fatalError("Not yet implemented")
    }

    public nonisolated var occupancy: any Occupancy {
        guard let _occupancy else {
            fatalError("Occupancy is not enabled for this room")
        }
        return _occupancy
    }

    public func attach() async throws {
        try await lifecycleManager.performAttachOperation()
    }

    public func detach() async throws {
        try await lifecycleManager.performDetachOperation()
    }

    internal func release() async {
        await lifecycleManager.performReleaseOperation()

        // CHA-RL3h
        for channel in channels.values {
            realtime.channels.release(channel.name)
        }
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
