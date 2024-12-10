@testable import AblyChat
import Testing

// The channel name of basketball::$chat::$chatMessages is passed in to these tests due to `DefaultRoom` kicking off the `DefaultMessages` initialization. This in turn needs a valid `roomId` or else the `MockChannels` class will throw an error as it would be expecting a channel with the name \(roomID)::$chat::$chatMessages to exist (where `roomId` is the property passed into `rooms.get`).
struct DefaultRoomsTests {
    // MARK: - Test helpers

    /// A mock implementation of an `InternalRoom`’s `release` operation. Its ``complete()`` method allows you to signal to the mock that the release should complete.
    final class SignallableReleaseOperation: Sendable {
        private let continuation: AsyncStream<Void>.Continuation

        /// When this function is set as a ``MockRoom``’s `releaseImplementation`, calling ``complete()`` will cause the corresponding `release()` to complete with the result passed to that method.
        ///
        /// ``release`` will respond to task cancellation by throwing `CancellationError`.
        let releaseImplementation: @Sendable () async -> Void

        init() {
            let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
            self.continuation = continuation

            releaseImplementation = { @Sendable () async in
                await (stream.first { _ in true }) // this will return if we yield to the continuation or if the Task is cancelled
            }
        }

        /// Causes the async function embedded in ``releaseImplementation`` to return.
        func complete() {
            continuation.yield(())
        }
    }

    // MARK: - Get a room

    // @spec CHA-RC1f
    // @spec CHA-RC1f3
    @Test
    func get_returnsRoomWithGivenIDAndOptions() async throws {
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

        // Then: It returns a room that uses the same Realtime instance, with the given ID and options, and it creates a room map entry for that ID
        let mockRoom = try #require(room as? MockRoom)
        #expect(mockRoom === roomToReturn)

        #expect(await rooms.testsOnly_hasRoomMapEntryWithID(roomID))

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
        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: roomFactory)

        let roomID = "basketball"
        let firstRoom = try await rooms.get(roomID: roomID, options: options)

        // When: get(roomID:options:) is called with the same room ID and options
        let secondRoom = try await rooms.get(roomID: roomID, options: options)

        // Then: It does not create another room, and returns the same room object
        #expect(await roomFactory.createRoomCallCount == 1)
        #expect(secondRoom === firstRoom)
    }

    // @specOneOf(2/2) CHA-RC1f2 - Tests the case where, per CHA-RC1f4, there is, in the spec’s language, a _future_ in the room map
    @Test
    func get_whenFutureExistsInRoomMap_returnsExistingRoomWithGivenID() async throws {
        // Given: an instance of DefaultRooms, for which, per CHA-RC1f4, a previous call to get(roomID:options:) with a given ID is waiting for a CHA-RC1g release operation to complete
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()

        let roomReleaseOperation = SignallableReleaseOperation()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: roomFactory)

        let roomID = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(roomID: roomID, options: options)
        let roomReleaseCalls = await roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(roomID: roomID)
        // Wait for `release` to be called on the room so that we know that the CHA-RC1g release operation is in progress
        _ = await roomReleaseCalls.first { _ in true }

        let operationWaitSubscription = await rooms.testsOnly_subscribeToOperationWaitEvents()
        // This is the "Given"’s "previous call to get(roomID:options:)"
        async let firstRoom = try await rooms.get(roomID: roomID, options: options)
        // Wait for the `firstRoom` fetch to start waiting for the CHA-RC1g release operation, to know that we’ve fulfilled the conditions of the "Given"
        _ = await operationWaitSubscription.first { $0.waitingOperationType == .get && $0.waitedOperationType == .release }

        // When: get(roomID:options:) is called with the same room ID
        async let secondRoom = try await rooms.get(roomID: roomID, options: options)

        // Then: The second call to `get` waits for the first call, and when the CHA-RC1g release operation completes, the second call to get(roomID:options:) does not create another room and returns the same room object as the first call
        _ = await operationWaitSubscription.first { $0.waitingOperationType == .get && $0.waitedOperationType == .get }

        // Allow the CHA-RC1g release operation to complete
        roomReleaseOperation.complete()

        #expect(await roomFactory.createRoomCallCount == 1)
        #expect(try await firstRoom === roomToReturn)
        #expect(try await secondRoom === roomToReturn)
    }

    // @specOneOf(1/2) CHA-RC1f1 - Tests the case where there is already a room in the room map
    @Test
    func get_whenRoomExistsInRoomMap_throwsErrorWhenOptionsDoNotMatch() async throws {
        // Given: an instance of DefaultRooms, which has, per CHA-RC1f3, a room in the room map with a given ID and options
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()

        let roomToReturn = MockRoom(options: options)
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"
        _ = try await rooms.get(roomID: roomID, options: options)

        // When: get(roomID:options:) is called with the same ID but different options
        // Then: It throws a `badRequest` error
        let differentOptions = RoomOptions(presence: .init(subscribe: false))

        await #expect {
            try await rooms.get(roomID: roomID, options: differentOptions)
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .fixedStatusCode(.badRequest))
        }
    }

    // @specOneOf(2/2) CHA-RC1f1 - Tests the case where, per CHA-RC1f4, there is, in the spec’s language, a _future_ in the room map
    @Test
    func get_whenFutureExistsInRoomMap_throwsErrorWhenOptionsDoNotMatch() async throws {
        // Given: an instance of DefaultRooms, for which, per CHA-RC1f4, a previous call to get(roomID:options:) with a given ID and options is waiting for a CHA-RC1g release operation to complete
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()

        let roomReleaseOperation = SignallableReleaseOperation()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(roomID: roomID, options: options)
        let roomReleaseCalls = await roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(roomID: roomID)
        // Wait for `release` to be called on the room so that we know that the CHA-RC1g release operation is in progress
        _ = await roomReleaseCalls.first { _ in true }

        let operationWaitSubscription = await rooms.testsOnly_subscribeToOperationWaitEvents()
        // This is the "Given"’s "previous call to get(roomID:options:)"
        async let _ = try await rooms.get(roomID: roomID, options: options)
        // Wait for the `firstRoom` fetch to start waiting for the CHA-RC1g release operation, to know that we’ve fulfilled the conditions of the "Given"
        _ = await operationWaitSubscription.first { $0.waitingOperationType == .get && $0.waitedOperationType == .release }

        // When: get(roomID:options:) is called with the same ID but different options
        // Then: The second call to get(roomID:options:) throws a `badRequest` error
        let differentOptions = RoomOptions(presence: .init(subscribe: false))

        await #expect {
            try await rooms.get(roomID: roomID, options: differentOptions)
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .fixedStatusCode(.badRequest))
        }

        // Post-test: Allow the CHA-RC1g release operation to complete
        roomReleaseOperation.complete()
    }

    // @spec CHA-RC1f4
    @Test
    func get_whenReleaseInProgress() async throws {
        // Given: an instance of DefaultRooms, for which a CHA-RC1g release operation is in progrss
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))

        let roomReleaseOperation = SignallableReleaseOperation()
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(roomID: roomID, options: options)
        let roomReleaseCalls = await roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(roomID: roomID)
        // Wait for `release` to be called on the room so that we know that the CHA-RC1g release operation is in progress
        _ = await roomReleaseCalls.first { _ in true }

        // When: `get(roomID:options:)` is called on the room
        let operationWaitSubscription = await rooms.testsOnly_subscribeToOperationWaitEvents()
        async let fetchedRoom = rooms.get(roomID: roomID, options: options)

        // Then: The call to `get(roomID:options:)` creates a room map entry and waits for the CHA-RC1g release operation to complete
        _ = await operationWaitSubscription.first { $0.waitingOperationType == .get && $0.waitedOperationType == .release }
        #expect(await rooms.testsOnly_hasRoomMapEntryWithID(roomID))

        // and When: The CHA-RC1g release operation completes

        // Allow the CHA-RC1g release operation to complete
        roomReleaseOperation.complete()

        // Then: The call to `get(roomID:options:)` completes
        _ = try await fetchedRoom
    }

    // MARK: - Release a room

    // @spec CHA-RC1g2
    @Test
    func release_withNoRoomMapEntry_andNoReleaseInProgress() async throws {
        // Given: An instance of DefaultRooms, with neither a room map entry nor a release operation in progress for a given room ID
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let roomFactory = MockRoomFactory()
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: roomFactory)

        // When: `release(roomID:)` is called with this room ID
        // Then: The call to `release(roomID:)` completes (this is as much as I can do to test the spec’s “no-op”; i.e. check it doesn’t seem to wait for anything or have any obvious side effects)
        let roomID = "basketball"
        await rooms.release(roomID: roomID)
    }

    // @spec CHA-RC1g3
    @Test
    func release_withNoRoomMapEntry_andReleaseInProgress() async throws {
        // Given: an instance of DefaultRooms, for which a release operation is in progress
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))

        let roomReleaseOperation = SignallableReleaseOperation()
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(roomID: roomID, options: options)
        let roomReleaseCalls = await roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(roomID: roomID)
        // Wait for `release` to be called on the room so that we know that the release operation is in progress
        _ = await roomReleaseCalls.first { _ in true }

        // When: `release(roomID:)` is called with this room ID
        let operationWaitSubscription = await rooms.testsOnly_subscribeToOperationWaitEvents()
        async let secondReleaseResult: Void = rooms.release(roomID: roomID)

        // Then: The call to `release(roomID:)` waits for the previous release operation to complete
        _ = await operationWaitSubscription.first { $0.waitingOperationType == .release && $0.waitedOperationType == .release }

        // and When: The previous CHA-RC1g release operation completes

        // Allow the previous release operation to complete
        roomReleaseOperation.complete()

        // Then: The second call to `release(roomID:)` completes, and this second release call does not trigger a CHA-RL3 room release operation (i.e. in the language of the spec it reuses the “future” of the existing CHA-RC1g release operation)
        await secondReleaseResult
        #expect(await roomToReturn.releaseCallCount == 1)
    }

    // @spec CHA-RC1g4
    @Test
    func release_withReleaseInProgress_failsPendingGetOperations() async throws {
        // Given: an instance of DefaultRooms, for which there is a release operation already in progress, and a CHA-RC1f4 future in the room map awaiting the completion of this release operation
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))

        let roomReleaseOperation = SignallableReleaseOperation()
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let roomID = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(roomID: roomID, options: options)
        let roomReleaseCalls = await roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(roomID: roomID)
        // Wait for `release` to be called on the room so that we know that the release operation is in progress
        _ = await roomReleaseCalls.first { _ in true }

        let operationWaitSubscription = await rooms.testsOnly_subscribeToOperationWaitEvents()
        // This is the “CHA-RC1f future” of the “Given”
        async let fetchedRoom = rooms.get(roomID: roomID, options: options)

        // Wait for the call to `get(roomID:options:)` to start waiting for the CHA-RC1g release operation to complete
        _ = await operationWaitSubscription.first { $0.waitingOperationType == .get && $0.waitedOperationType == .release }

        // When: `release(roomID:)` is called on the room, with the same room ID
        async let secondReleaseResult: Void = rooms.release(roomID: roomID)

        // Then: The pending call to `get(roomID:options:)` that is waiting for the “CHA-RC1f future” of the “Given” fails with a RoomReleasedBeforeOperationCompleted error
        let roomGetError: Error?
        do {
            _ = try await fetchedRoom
            roomGetError = nil
        } catch {
            roomGetError = error
        }

        #expect(isChatError(roomGetError, withCodeAndStatusCode: .fixedStatusCode(.roomReleasedBeforeOperationCompleted)))

        // and When: The previous CHA-RC1g release operation completes

        // Allow the previous release operation to complete
        roomReleaseOperation.complete()

        // Then: The second call to `release(roomID:)` completes, and this second release call does not trigger a CHA-RL3 room release operation (i.e. in the language of the spec it reuses the “future” of the existing CHA-RC1g release operation)
        await secondReleaseResult
        #expect(await roomToReturn.releaseCallCount == 1)
    }

    // @spec CHA-RC1g5
    @Test
    func release() async throws {
        // Given: an instance of DefaultRooms, which has a room map entry for a given room ID and has no release operation in progress for that room ID
        let realtime = MockRealtime.create(channels: .init(channels: [
            .init(name: "basketball::$chat::$chatMessages"),
        ]))
        let options = RoomOptions()
        let hasExistingRoomAtMomentRoomReleaseCalledStreamComponents = AsyncStream.makeStream(of: Bool.self)
        let roomFactory = MockRoomFactory()
        let rooms = DefaultRooms(realtime: realtime, clientOptions: .init(), logger: TestLogger(), roomFactory: roomFactory)

        let roomID = "basketball"

        let roomToReturn = MockRoom(options: options) {
            await hasExistingRoomAtMomentRoomReleaseCalledStreamComponents.continuation.yield(rooms.testsOnly_hasRoomMapEntryWithID(roomID))
        }
        await roomFactory.setRoom(roomToReturn)

        _ = try await rooms.get(roomID: roomID, options: .init())
        try #require(await rooms.testsOnly_hasRoomMapEntryWithID(roomID))

        // When: `release(roomID:)` is called with this room ID
        _ = await rooms.release(roomID: roomID)

        // Then:
        // 1. first, the room is removed from the room map
        // 2. next, `release` is called on the room

        // These two lines are convoluted because the #require macro has a hard time with stuff of type Bool? and emits warnings about ambiguity unless you jump through the hoops it tells you to
        let hasExistingRoomAtMomentRoomReleaseCalled = await hasExistingRoomAtMomentRoomReleaseCalledStreamComponents.stream.first { _ in true }
        #expect(try !#require(hasExistingRoomAtMomentRoomReleaseCalled as Bool?))

        #expect(await roomToReturn.releaseCallCount == 1)
    }
}
