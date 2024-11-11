@testable import AblyChat

actor MockRoomFactory: RoomFactory {
    private let room: MockRoom?
    private(set) var createRoomArguments: (realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: any InternalLogger)?

    init(room: MockRoom? = nil) {
        self.room = room
    }

    func createRoom(realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: any InternalLogger) async throws -> MockRoom {
        createRoomArguments = (realtime: realtime, chatAPI: chatAPI, roomID: roomID, options: options, logger: logger)

        guard let room else {
            fatalError("MockRoomFactory.createRoom called, but the mock factory has not been set up with a room to return")
        }

        return room
    }
}
