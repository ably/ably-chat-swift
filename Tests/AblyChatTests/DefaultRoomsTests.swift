import Ably
@testable import AblyChat
import Testing

// The channel name of basketball::$chat is passed in to these tests due to `DefaultRoom` kicking off the `DefaultMessages` initialization. This in turn needs a valid `roomName` or else the `MockChannels` class will throw an error as it would be expecting a channel with the name \(roomName)::$chat to exist (where `roomName` is the property passed into `rooms.get`).
@MainActor
struct DefaultRoomsTests {
    // MARK: - Test helpers

    /// A mock implementation of an `InternalRoom`'s `release` operation. Its ``complete()`` method allows you to signal to the mock that the release should complete.
    final class SignallableReleaseOperation: Sendable {
        private let continuation: AsyncStream<Void>.Continuation

        /// When this function is set as a ``MockRoom``'s `releaseImplementation`, calling ``complete()`` will cause the corresponding `release()` to complete with the result passed to that method.
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

    // @spec CHA-RC4a
    @Test
    func get_withoutOptions_usesDefaultOptions() async throws {
        // Given: an instance of DefaultRooms
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options)
        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        // When: get(name:) is called
        let name = "basketball"
        _ = try await rooms.get(named: name)

        // Then: It uses the default options
        let createRoomArguments = try #require(roomFactory.createRoomArguments)
        #expect(createRoomArguments.options == RoomOptions())
    }

    // @specNotApplicable CHA-RC4b - Our API does not have a concept of "partial options" unlike the JS API which this spec item considers.

    // @spec CHA-RC1f
    // @spec CHA-RC1f3
    @Test
    func get_returnsRoomWithGivenNameAndOptions() async throws {
        // Given: an instance of DefaultRooms
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options)
        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        // When: get(name:options:) is called
        let name = "basketball"
        let room = try await rooms.get(named: name, options: options)

        // Then: It returns a room that uses the same Realtime instance, with the given name and options, and it creates a room map entry for that name
        #expect(room === roomToReturn)

        #expect(rooms.testsOnly_hasRoomMapEntryWithName(name))

        let createRoomArguments = try #require(roomFactory.createRoomArguments)
        #expect(createRoomArguments.realtime === realtime)
        #expect(createRoomArguments.name == name)
        #expect(createRoomArguments.options == options)
    }

    // @specOneOf(1/2) CHA-RC1f2 - Tests the case where there is already a room in the room map
    @Test
    func get_whenRoomExistsInRoomMap_returnsExistingRoomWithGivenName() async throws {
        // Given: an instance of DefaultRooms, which has, per CHA-RC1f3, a room in the room map with a given name
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options)
        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        let name = "basketball"
        let firstRoom = try await rooms.get(named: name, options: options)

        // When: get(name:options:) is called with the same room name and options
        let secondRoom = try await rooms.get(named: name, options: options)

        // Then: It does not create another room, and returns the same room object
        #expect(roomFactory.createRoomCallCount == 1)
        #expect(secondRoom === firstRoom)
    }

    // @specOneOf(2/2) CHA-RC1f2 - Tests the case where, per CHA-RC1f4, there is, in the spec's language, a _future_ in the room map
    @Test
    func get_whenFutureExistsInRoomMap_returnsExistingRoomWithGivenName() async throws {
        // Given: an instance of DefaultRooms, for which, per CHA-RC1f4, a previous call to get(name:options:) with a given name is waiting for a CHA-RC1g release operation to complete
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()

        let roomReleaseOperation = SignallableReleaseOperation()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        let name = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(named: name, options: options)
        let roomReleaseCalls = roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(named: name)
        // Wait for `release` to be called on the room so that we know that the CHA-RC1g release operation is in progress
        _ = await roomReleaseCalls.first { @Sendable _ in true }

        let operationWaitSubscription = rooms.testsOnly_subscribeToOperationWaitEvents()
        // This is the "Given"'s "previous call to get(name:options:)"
        async let firstRoom = try await rooms.get(named: name, options: options)
        // Wait for the `firstRoom` fetch to start waiting for the CHA-RC1g release operation, to know that we've fulfilled the conditions of the "Given"
        _ = await operationWaitSubscription.first { @Sendable operationWaitEvent in
            operationWaitEvent.waitingOperationType == .get && operationWaitEvent.waitedOperationType == .release
        }

        // When: get(name:options:) is called with the same room name
        async let secondRoom = try await rooms.get(named: name, options: options)

        // Then: The second call to `get` waits for the first call, and when the CHA-RC1g release operation completes, the second call to get(name:options:) does not create another room and returns the same room object as the first call
        _ = await operationWaitSubscription.first { @Sendable operationWaitEvent in
            operationWaitEvent.waitingOperationType == .get && operationWaitEvent.waitedOperationType == .get
        }

        // Allow the CHA-RC1g release operation to complete
        roomReleaseOperation.complete()

        #expect(roomFactory.createRoomCallCount == 1)
        #expect(try await firstRoom === roomToReturn)
        #expect(try await secondRoom === roomToReturn)
    }

    // @specOneOf(1/2) CHA-RC1f1 - Tests the case where there is already a room in the room map
    @Test
    func get_whenRoomExistsInRoomMap_throwsErrorWhenOptionsDoNotMatch() async throws {
        // Given: an instance of DefaultRooms, which has, per CHA-RC1f3, a room in the room map with a given name and options
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()

        let roomToReturn = MockRoom(options: options)
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let name = "basketball"
        _ = try await rooms.get(named: name, options: options)

        // When: get(name:options:) is called with the same name but different options
        // Then: It throws a `roomExistsWithDifferentOptions` error
        let differentOptions = RoomOptions(presence: .init(enableEvents: false))

        let thrownError = try await #require(throws: ErrorInfo.self) {
            try await rooms.get(named: name, options: differentOptions)
        }
        #expect(thrownError.hasCodeAndStatusCode(.fixedStatusCode(.roomExistsWithDifferentOptions)))
    }

    // @specOneOf(2/2) CHA-RC1f1 - Tests the case where, per CHA-RC1f4, there is, in the spec's language, a _future_ in the room map
    @Test
    func get_whenFutureExistsInRoomMap_throwsErrorWhenOptionsDoNotMatch() async throws {
        // Given: an instance of DefaultRooms, for which, per CHA-RC1f4, a previous call to get(name:options:) with a given name and options is waiting for a CHA-RC1g release operation to complete
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()

        let roomReleaseOperation = SignallableReleaseOperation()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let name = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(named: name, options: options)
        let roomReleaseCalls = roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(named: name)
        // Wait for `release` to be called on the room so that we know that the CHA-RC1g release operation is in progress
        _ = await roomReleaseCalls.first { @Sendable _ in true }

        let operationWaitSubscription = rooms.testsOnly_subscribeToOperationWaitEvents()
        // This is the "Given"'s "previous call to get(name:options:)"
        async let _ = try await rooms.get(named: name, options: options)
        // Wait for the `firstRoom` fetch to start waiting for the CHA-RC1g release operation, to know that we've fulfilled the conditions of the "Given"
        _ = await operationWaitSubscription.first { @Sendable operationWaitEvent in
            operationWaitEvent.waitingOperationType == .get && operationWaitEvent.waitedOperationType == .release
        }

        // When: get(name:options:) is called with the same name but different options
        // Then: The second call to get(name:options:) throws a `roomExistsWithDifferentOptions` error
        let differentOptions = RoomOptions(presence: .init(enableEvents: false))

        let thrownError = try await #require(throws: ErrorInfo.self) {
            try await rooms.get(named: name, options: differentOptions)
        }
        #expect(thrownError.hasCodeAndStatusCode(.fixedStatusCode(.roomExistsWithDifferentOptions)))

        // Post-test: Allow the CHA-RC1g release operation to complete
        roomReleaseOperation.complete()
    }

    // @spec CHA-RC1f4
    @Test
    func get_whenReleaseInProgress() async throws {
        // Given: an instance of DefaultRooms, for which a CHA-RC1g release operation is in progrss
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))

        let roomReleaseOperation = SignallableReleaseOperation()
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let name = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(named: name, options: options)
        let roomReleaseCalls = roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(named: name)
        // Wait for `release` to be called on the room so that we know that the CHA-RC1g release operation is in progress
        _ = await roomReleaseCalls.first { @Sendable _ in true }

        // When: `get(name:options:)` is called on the room
        let operationWaitSubscription = rooms.testsOnly_subscribeToOperationWaitEvents()
        async let fetchedRoom = rooms.get(named: name, options: options)

        // Then: The call to `get(name:options:)` creates a room map entry and waits for the CHA-RC1g release operation to complete
        _ = await operationWaitSubscription.first { @Sendable operationWaitEvent in
            operationWaitEvent.waitingOperationType == .get && operationWaitEvent.waitedOperationType == .release
        }
        #expect(rooms.testsOnly_hasRoomMapEntryWithName(name))

        // and When: The CHA-RC1g release operation completes

        // Allow the CHA-RC1g release operation to complete
        roomReleaseOperation.complete()

        // Then: The call to `get(name:options:)` completes
        _ = try await fetchedRoom
    }

    // MARK: - Release a room

    // @spec CHA-RC1g2
    @Test
    func release_withNoRoomMapEntry_andNoReleaseInProgress() async throws {
        // Given: An instance of DefaultRooms, with neither a room map entry nor a release operation in progress for a given room name
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let roomFactory = MockRoomFactory()
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        // When: `release(name:)` is called with this room name
        // Then: The call to `release(name:)` completes (this is as much as I can do to test the spec's "no-op"; i.e. check it doesn't seem to wait for anything or have any obvious side effects)
        let name = "basketball"
        await rooms.release(named: name)
    }

    // @spec CHA-RC1g3
    @Test
    func release_withNoRoomMapEntry_andReleaseInProgress() async throws {
        // Given: an instance of DefaultRooms, for which a release operation is in progress
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))

        let roomReleaseOperation = SignallableReleaseOperation()
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let name = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(named: name, options: options)
        let roomReleaseCalls = roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(named: name)
        // Wait for `release` to be called on the room so that we know that the release operation is in progress
        _ = await roomReleaseCalls.first { @Sendable _ in true }

        // When: `release(name:)` is called with this room name
        let operationWaitSubscription = rooms.testsOnly_subscribeToOperationWaitEvents()
        async let secondReleaseResult: Void = rooms.release(named: name)

        // Then: The call to `release(name:)` waits for the previous release operation to complete
        _ = await operationWaitSubscription.first { @Sendable operationWaitEvent in
            operationWaitEvent.waitingOperationType == .release && operationWaitEvent.waitedOperationType == .release
        }

        // and When: The previous CHA-RC1g release operation completes

        // Allow the previous release operation to complete
        roomReleaseOperation.complete()

        // Then: The second call to `release(name:)` completes, and this second release call does not trigger a CHA-RL3 room release operation (i.e. in the language of the spec it reuses the "future" of the existing CHA-RC1g release operation)
        await secondReleaseResult
        #expect(roomToReturn.releaseCallCount == 1)
    }

    // @spec CHA-RC1g4
    @Test
    func release_withReleaseInProgress_failsPendingGetOperations() async throws {
        // Given: an instance of DefaultRooms, for which there is a release operation already in progress, and a CHA-RC1f4 future in the room map awaiting the completion of this release operation
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))

        let roomReleaseOperation = SignallableReleaseOperation()
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)

        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: MockRoomFactory(room: roomToReturn))

        let name = "basketball"

        // Get a room so that we can release it
        _ = try await rooms.get(named: name, options: options)
        let roomReleaseCalls = roomToReturn.releaseCallsAsyncSequence
        async let _ = rooms.release(named: name)
        // Wait for `release` to be called on the room so that we know that the release operation is in progress
        _ = await roomReleaseCalls.first { @Sendable _ in true }

        let operationWaitSubscription = rooms.testsOnly_subscribeToOperationWaitEvents()
        // This is the "CHA-RC1f future" of the "Given"
        async let fetchedRoom = rooms.get(named: name, options: options)

        // Wait for the call to `get(name:options:)` to start waiting for the CHA-RC1g release operation to complete
        _ = await operationWaitSubscription.first { @Sendable operationWaitEvent in
            operationWaitEvent.waitingOperationType == .get && operationWaitEvent.waitedOperationType == .release
        }

        // When: `release(name:)` is called on the room, with the same room name
        async let secondReleaseResult: Void = rooms.release(named: name)

        // Then: The pending call to `get(name:options:)` that is waiting for the "CHA-RC1f future" of the "Given" fails with a RoomReleasedBeforeOperationCompleted error
        let roomGetError: ErrorInfo?
        do {
            _ = try await fetchedRoom
            roomGetError = nil
        } catch {
            roomGetError = error as? ErrorInfo
        }

        #expect(try #require(roomGetError).hasCodeAndStatusCode(.fixedStatusCode(.roomReleasedBeforeOperationCompleted)))

        // and When: The previous CHA-RC1g release operation completes

        // Allow the previous release operation to complete
        roomReleaseOperation.complete()

        // Then: The second call to `release(name:)` completes, and this second release call does not trigger a CHA-RL3 room release operation (i.e. in the language of the spec it reuses the "future" of the existing CHA-RC1g release operation)
        await secondReleaseResult
        #expect(roomToReturn.releaseCallCount == 1)
    }

    // @spec CHA-RC1g5
    @Test
    func release() async throws {
        // Given: an instance of DefaultRooms, which has a room map entry for a given room name and has no release operation in progress for that room name
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()
        let hasExistingRoomAtMomentRoomReleaseCalledStreamComponents = AsyncStream.makeStream(of: Bool.self)
        let roomFactory = MockRoomFactory()
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        let name = "basketball"

        let roomToReturn = MockRoom(options: options) {
            await hasExistingRoomAtMomentRoomReleaseCalledStreamComponents.continuation.yield(rooms.testsOnly_hasRoomMapEntryWithName(name))
        }
        roomFactory.setRoom(roomToReturn)

        _ = try await rooms.get(named: name, options: .init())
        try #require(rooms.testsOnly_hasRoomMapEntryWithName(name))

        // When: `release(name:)` is called with this room name
        _ = await rooms.release(named: name)

        // Then:
        // 1. first, the room is removed from the room map
        // 2. next, `release` is called on the room

        // These two lines are convoluted because the #require macro has a hard time with stuff of type Bool? and emits warnings about ambiguity unless you jump through the hoops it tells you to
        let hasExistingRoomAtMomentRoomReleaseCalled = await hasExistingRoomAtMomentRoomReleaseCalledStreamComponents.stream.first { @Sendable _ in true }
        #expect(try !#require(hasExistingRoomAtMomentRoomReleaseCalled as Bool?))

        #expect(roomToReturn.releaseCallCount == 1)
    }
}
