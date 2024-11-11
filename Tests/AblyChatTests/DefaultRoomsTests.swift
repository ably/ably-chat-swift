@testable import AblyChat
import Testing

// The channel name of basketball::$chat::$chatMessages is passed in to these tests due to `DefaultRoom` kicking off the `DefaultMessages` initialization. This in turn needs a valid `roomId` or else the `MockChannels` class will throw an error as it would be expecting a channel with the name \(roomID)::$chat::$chatMessages to exist (where `roomId` is the property passed into `rooms.get`).
struct DefaultRoomsTests {
    // @spec CHA-RC1a
    @Test
    func get_returnsRoomWithGivenID() async throws {
        // Given: an instance of DefaultRooms
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options)
        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: roomFactory)

        // When: get(roomID:options:) is called
        let roomID = "basketball"
        let room = try await rooms.get(roomID: roomID, options: options)

        // Then: It returns a room that uses the same Realtime instance, with the given ID and options
        let mockRoom = try #require(room as? MockRoom)
        #expect(mockRoom === roomToReturn)

        let createRoomArguments = try #require(await roomFactory.createRoomArguments)
        #expect(createRoomArguments.realtime === realtime)
        #expect(createRoomArguments.roomID == roomID)
        #expect(createRoomArguments.options == options)
    }

    // @spec CHA-RC1b
    @Test
    func get_returnsExistingRoomWithGivenID() async throws {
        // Given: an instance of DefaultRooms, on which get(roomID:options:) has already been called with a given ID
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options)
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"
        let firstRoom = try await rooms.get(roomID: roomID, options: options)

        // When: get(roomID:options:) is called with the same room ID
        let secondRoom = try await rooms.get(roomID: roomID, options: options)

        // Then: It returns the same room object
        #expect(secondRoom === firstRoom)
    }

    // @spec CHA-RC1c
    @Test
    func get_throwsErrorWhenOptionsDoNotMatch() async throws {
        // Given: an instance of DefaultRooms, on which get(roomID:options:) has already been called with a given ID and options
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options)
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"
        _ = try await rooms.get(roomID: roomID, options: options)

        // When: get(roomID:options:) is called with the same ID but different options
        let differentOptions = RoomOptions(presence: .init(subscribe: false))

        let caughtError: Error?
        do {
            _ = try await rooms.get(roomID: roomID, options: differentOptions)
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then: It throws an inconsistentRoomOptions error
        #expect(isChatError(caughtError, withCode: .inconsistentRoomOptions))
    }
}
