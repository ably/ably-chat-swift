import Ably

public protocol Rooms: AnyObject, Sendable {
    func get(roomID: String, options: RoomOptions) async throws -> any Room
    func release(roomID: String) async throws
    var clientOptions: ClientOptions { get }
}

internal actor DefaultRooms<RoomFactory: AblyChat.RoomFactory>: Rooms {
    private nonisolated let realtime: RealtimeClient
    private let chatAPI: ChatAPI

    #if DEBUG
        internal nonisolated var testsOnly_realtime: RealtimeClient {
            realtime
        }
    #endif

    internal nonisolated let clientOptions: ClientOptions

    private let logger: InternalLogger
    private let roomFactory: RoomFactory

    /// The set of rooms, keyed by room ID.
    private var rooms: [String: RoomFactory.Room] = [:]

    internal init(realtime: RealtimeClient, clientOptions: ClientOptions, logger: InternalLogger, roomFactory: RoomFactory) {
        self.realtime = realtime
        self.clientOptions = clientOptions
        self.logger = logger
        self.roomFactory = roomFactory
        chatAPI = ChatAPI(realtime: realtime)
    }

    internal func get(roomID: String, options: RoomOptions) async throws -> any Room {
        // CHA-RC1b
        if let existingRoom = rooms[roomID] {
            // CHA-RC1c
            if existingRoom.options != options {
                throw ARTErrorInfo(
                    chatError: .inconsistentRoomOptions(requested: options, existing: existingRoom.options)
                )
            }

            return existingRoom
        } else {
            let room = try await roomFactory.createRoom(realtime: realtime, chatAPI: chatAPI, roomID: roomID, options: options, logger: logger)
            rooms[roomID] = room
            return room
        }
    }

    #if DEBUG
        internal func testsOnly_hasExistingRoomWithID(_ roomID: String) -> Bool {
            rooms[roomID] != nil
        }
    #endif

    internal func release(roomID: String) async throws {
        guard let room = rooms[roomID] else {
            // TODO: what to do here? (https://github.com/ably/specification/pull/200/files#r1837154563) — Andy replied that it’s a no-op but that this is going to be specified in an upcoming PR when we make room-getting async
            return
        }

        // CHA-RC1d
        rooms.removeValue(forKey: roomID)

        // CHA-RL1e
        await room.release()
    }
}
