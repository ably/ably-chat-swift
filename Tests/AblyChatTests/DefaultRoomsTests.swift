@testable import AblyChat
import Testing

// The channel name of basketball::$chat::$chatMessages is passed in to these tests due to `DefaultRoom` kicking off the `DefaultMessages` initialization. This in turn needs a valid `roomId` or else the `MockChannels` class will throw an error as it would be expecting a channel with the name \(roomID)::$chat::$chatMessages to exist (where `roomId` is the property passed into `rooms.get`).
struct DefaultRoomsTests {
    // TODO update this to match; try and figure out how to reduce some duplication
    /// A mock implementation of a `SimpleClock`’s `sleep(timeInterval:)` operation. Its ``complete(result:)`` method allows you to signal to the mock that the sleep should complete.
    final class SignallableReleaseOperation: Sendable {
        private let continuation: AsyncStream<Void>.Continuation

        /// When this behavior is set as a ``MockSimpleClock``’s `sleepBehavior`, calling ``complete(result:)`` will cause the corresponding `sleep(timeInterval:)` to complete with the result passed to that method.
        ///
        /// ``sleep(timeInterval:)`` will respond to task cancellation by throwing `CancellationError`.
        let releaseImplementation: (@Sendable () async -> Void)

        init() {
            let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
            self.continuation = continuation

            releaseImplementation = { @Sendable () async in
                await (stream.first { _ in true }) // this will return if we yield to the continuation or if the Task is cancelled
            }
        }

        /// Causes the async function embedded in ``behavior`` to return.
        func complete() {
            continuation.yield(())
        }
    }

    // MARK: - Get a room

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

    // @specOneOf(1/2) CHA-RC1f2 - Tests the case where there is already a room in the room map
    @Test
    func get_whenRoomExistsInRoomMap_returnsExistingRoomWithGivenID() async throws {
        // Given: an instance of DefaultRooms, which has, per CHA-RC1f3, a room in the room map with a given ID
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options)
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"
        let firstRoom = try await rooms.get(roomID: roomID, options: options)

        // When: get(roomID:options:) is called with the same room ID and options
        let secondRoom = try await rooms.get(roomID: roomID, options: options)

        // Then: It returns the same room object
        #expect(secondRoom === firstRoom)
    }

    // @specOneOf(2/2) CHA-RC1f2 - Tests the case where, per CHA-RC1f4, there is, in the spec’s language, a _future_ in the room map
    // TODO what about when this future fails? another test?
    @Test
    func get_whenFutureExistsInRoomMap_returnsExistingRoomWithGivenID() async throws {
        // Given: an instance of DefaultRooms, for which, per CHA-RC1f4, a previous call to get(roomID:options:) with a given ID is waiting for a CHA-RC1g release operation to complete
        // TODO implement this condition
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()

        let releaseOperation = SignallableReleaseOperation()
        let roomToReturn = MockRoom(options: options, releaseImplementation: releaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"
        async let firstRoom = try await rooms.get(roomID: roomID, options: options)

        // TODO here we need to wait for it to wait

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

        let roomReleaseOperation = SignallableReleaseOperation()

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
        #expect(isChatError(caughtError, withCodeAndStatusCode: .fixedStatusCode(.inconsistentRoomOptions)))
    }

    // MARK: - Release a room

    // @spec CHA-RC1d
    // @spec CHA-RC1e
    @Test
    func release() async throws {
        // Given: an instance of DefaultRooms, on which get(roomID:options:) has already been called with a given ID
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()
        let hasExistingRoomAtMomentRoomReleaseCalledStreamComponents = AsyncStream.makeStream(of: Bool.self)
        let roomFactory = MockRoomFactory()
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: roomFactory)

        let roomID = "basketball"

        let roomToReturn = MockRoom(options: options) {
            await hasExistingRoomAtMomentRoomReleaseCalledStreamComponents.continuation.yield(rooms.testsOnly_hasExistingRoomWithID(roomID))
        }
        await roomFactory.setRoom(roomToReturn)

        _ = try await rooms.get(roomID: roomID, options: .init())
        try #require(await rooms.testsOnly_hasExistingRoomWithID(roomID))

        // When: `release(roomID:)` is called with this room ID
        _ = try await rooms.release(roomID: roomID)

        // Then:
        // 1. first, the room is removed from the room map
        // 2. next, `release` is called on the room

        // These two lines are convoluted because the #require macro has a hard time with stuff of type Bool? and emits warnings about ambiguity unless you jump through the hoops it tells you to
        let hasExistingRoomAtMomentRoomReleaseCalled = await hasExistingRoomAtMomentRoomReleaseCalledStreamComponents.stream.first { _ in true }
        #expect(try !#require(hasExistingRoomAtMomentRoomReleaseCalled as Bool?))

        #expect(await roomToReturn.releaseCallCount == 1)
    }
}
