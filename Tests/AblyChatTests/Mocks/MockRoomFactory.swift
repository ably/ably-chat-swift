@testable import AblyChat

class MockRoomFactory: RoomFactory {
    private var room: MockRoom?
    private(set) var createRoomCallCount = 0
    private(set) var createRoomArguments: (realtime: any InternalRealtimeClientProtocol, chatAPI: ChatAPI, name: String, options: RoomOptions, logger: any InternalLogger)?

    init(room: MockRoom? = nil) {
        self.room = room
    }

    func setRoom(_ room: MockRoom) {
        self.room = room
    }

    func createRoom(realtime: any InternalRealtimeClientProtocol, chatAPI: ChatAPI, name: String, options: RoomOptions, logger: any InternalLogger) throws(InternalError) -> MockRoom {
        createRoomCallCount += 1
        createRoomArguments = (realtime: realtime, chatAPI: chatAPI, name: name, options: options, logger: logger)

        guard let room else {
            fatalError("MockRoomFactory.createRoom called, but the mock factory has not been set up with a room to return")
        }

        return room
    }
}
