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

public struct RoomStatusChange: Sendable {
    public var current: RoomStatus
    public var previous: RoomStatus

    public init(current: RoomStatus, previous: RoomStatus) {
        self.current = current
        self.previous = previous
    }
}

internal actor DefaultRoom: Room {
    internal nonisolated let roomID: String
    internal nonisolated let options: RoomOptions
    private let chatAPI: ChatAPI

    public nonisolated let messages: any Messages

    // Exposed for testing.
    private nonisolated let realtime: RealtimeClient

    /// The channels that contribute to this room.
    private let channels: [RoomFeature: RealtimeChannelProtocol]

    #if DEBUG
        internal nonisolated var testsOnly_realtime: RealtimeClient {
            realtime
        }
    #endif

    internal private(set) var status: RoomStatus = .initialized
    // TODO: clean up old subscriptions (https://github.com/ably-labs/ably-chat-swift/issues/36)
    private var statusSubscriptions: [Subscription<RoomStatusChange>] = []
    private let logger: InternalLogger

    internal init(realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger) async throws {
        self.realtime = realtime
        self.roomID = roomID
        self.options = options
        self.logger = logger
        self.chatAPI = chatAPI

        guard let clientId = realtime.clientId else {
            throw ARTErrorInfo.create(withCode: 40000, message: "Ensure your Realtime instance is initialized with a clientId.")
        }

        channels = Self.createChannels(roomID: roomID, realtime: realtime)

        messages = await DefaultMessages(
            channel: channels[.messages]!,
            chatAPI: chatAPI,
            roomID: roomID,
            clientID: clientId
        )
    }

    private static func createChannels(roomID: String, realtime: RealtimeClient) -> [RoomFeature: RealtimeChannelProtocol] {
        .init(uniqueKeysWithValues: [RoomFeature.messages, RoomFeature.typing, RoomFeature.reactions].map { feature in
            let channel = realtime.getChannel(feature.channelNameForRoomID(roomID))
            return (feature, channel)
        })
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
        for channel in channels.map(\.value) {
            do {
                try await channel.attachAsync()
            } catch {
                logger.log(message: "Failed to attach channel \(channel), error \(error)", level: .error)
                throw error
            }
        }
        transition(to: .attached)
    }

    public func detach() async throws {
        for channel in channels.map(\.value) {
            do {
                try await channel.detachAsync()
            } catch {
                logger.log(message: "Failed to detach channel \(channel), error \(error)", level: .error)
                throw error
            }
        }
        transition(to: .detached)
    }

    // MARK: - Room status

    internal func onStatusChange(bufferingPolicy: BufferingPolicy) -> Subscription<RoomStatusChange> {
        let subscription: Subscription<RoomStatusChange> = .init(bufferingPolicy: bufferingPolicy)
        statusSubscriptions.append(subscription)
        return subscription
    }

    /// Sets ``status`` to the given status, and emits a status change to all subscribers added via ``onStatusChange(bufferingPolicy:)``.
    internal func transition(to newStatus: RoomStatus) {
        logger.log(message: "Transitioning to \(newStatus)", level: .debug)
        let statusChange = RoomStatusChange(current: newStatus, previous: status)
        status = newStatus
        for subscription in statusSubscriptions {
            subscription.emit(statusChange)
        }
    }
}
