import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultRoomsDisposeTests {
    // MARK: - Test helpers

    /// A mock implementation of an `InternalRoom`'s `release` operation. Its ``complete()`` method allows you to signal to the mock that the release should complete.
    final class SignallableReleaseOperation: Sendable {
        private let continuation: AsyncStream<Void>.Continuation

        /// When this function is set as a ``MockRoom``'s `releaseImplementation`, calling ``complete()`` will cause the corresponding `release()` to complete with the result passed to that method.
        let releaseImplementation: @Sendable () async -> Void

        init() {
            let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
            self.continuation = continuation

            releaseImplementation = { @Sendable () async in
                await (stream.first { _ in true })
            }
        }

        /// Causes the async function embedded in ``releaseImplementation`` to return.
        func complete() {
            continuation.yield(())
        }
    }

    // MARK: - Dispose tests

    // @spec CHA-CL1a
    @Test
    func dispose_preventsSubsequentGetCalls() async throws {
        // Given: an instance of DefaultRooms
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()
        let roomToReturn = MockRoom(options: options)
        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        // When: dispose() is called
        await rooms.dispose()

        // Then: Subsequent calls to get() throw a clientDisposed error
        let thrownError = try await #require(throws: ErrorInfo.self) {
            try await rooms.get(named: "basketball", options: options)
        }
        #expect(thrownError.hasCode(.resourceDisposed))
        #expect(thrownError.message.contains("client has been disposed"))
    }

    // @spec CHA-CL1a
    @Test
    func dispose_releasesAllRooms() async throws {
        // Given: an instance of DefaultRooms with multiple rooms
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
            .init(name: "football::$chat"),
        ]))
        let options = RoomOptions()

        let room1ReleaseOperation = SignallableReleaseOperation()
        let room1 = MockRoom(options: options, releaseImplementation: room1ReleaseOperation.releaseImplementation)

        let room2ReleaseOperation = SignallableReleaseOperation()
        let room2 = MockRoom(options: options, releaseImplementation: room2ReleaseOperation.releaseImplementation)

        let roomFactory = MockRoomFactory()
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        // Get room1
        roomFactory.setRoom(room1)
        _ = try await rooms.get(named: "basketball", options: options)

        // Get room2
        roomFactory.setRoom(room2)
        _ = try await rooms.get(named: "football", options: options)

        // When: dispose() is called
        async let disposeTask: Void = rooms.dispose()

        // Allow the release operations to complete
        room1ReleaseOperation.complete()
        room2ReleaseOperation.complete()

        await disposeTask

        // Then: Both rooms had release() called
        #expect(room1.releaseCallCount == 1)
        #expect(room2.releaseCallCount == 1)
    }

    // @spec CHA-CL1a
    @Test
    func dispose_isIdempotent() async throws {
        // Given: an instance of DefaultRooms that has already been disposed
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let roomFactory = MockRoomFactory()
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        await rooms.dispose()

        // When: dispose() is called again
        // Then: No error is thrown and operation completes
        await rooms.dispose()
    }

    // @spec CHA-CL1a
    @Test
    func dispose_clearsRoomStates() async throws {
        // Given: an instance of DefaultRooms with a room
        let realtime = MockRealtime(channels: .init(channels: [
            .init(name: "basketball::$chat"),
        ]))
        let options = RoomOptions()

        let roomReleaseOperation = SignallableReleaseOperation()
        let roomToReturn = MockRoom(options: options, releaseImplementation: roomReleaseOperation.releaseImplementation)
        let roomFactory = MockRoomFactory(room: roomToReturn)
        let rooms = DefaultRooms(realtime: realtime, logger: TestLogger(), roomFactory: roomFactory)

        _ = try await rooms.get(named: "basketball", options: options)
        #expect(rooms.testsOnly_hasRoomMapEntryWithName("basketball"))

        // When: dispose() is called
        async let disposeTask: Void = rooms.dispose()
        roomReleaseOperation.complete()
        await disposeTask

        // Then: Room states are cleared
        #expect(!rooms.testsOnly_hasRoomMapEntryWithName("basketball"))
    }
}

@MainActor
struct TypingTimerManagerDisposeTests {
    @available(iOS 16.0, tvOS 16, *)
    private func createTypingTimerManager(with testClock: MockTestClock) -> TypingTimerManager<MockTestClock> {
        TypingTimerManager(
            heartbeatThrottle: 5.0,
            gracePeriod: 2.0,
            logger: TestLogger(),
            clock: testClock,
        )
    }

    // @spec CHA-CL1a (typing cleanup)
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func dispose_clearsHeartbeatTimer() async throws {
        // Given: a TypingTimerManager with an active heartbeat timer
        let clock = MockTestClock()
        let manager = createTypingTimerManager(with: clock)

        manager.startHeartbeatTimer()
        #expect(manager.isHeartbeatTimerActive)

        // When: dispose() is called
        manager.dispose()

        // Then: The heartbeat timer is cleared
        #expect(!manager.isHeartbeatTimerActive)
    }

    // @spec CHA-CL1a (typing cleanup)
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func dispose_clearsWhoIsTypingTimers() async throws {
        // Given: a TypingTimerManager with active "who is typing" timers
        let clock = MockTestClock()
        let manager = createTypingTimerManager(with: clock)

        manager.startTypingTimer(for: "client1")
        manager.startTypingTimer(for: "client2")
        #expect(manager.currentlyTypingClientIDs() == Set(["client1", "client2"]))

        // When: dispose() is called
        manager.dispose()

        // Then: All "who is typing" timers are cleared
        #expect(manager.currentlyTypingClientIDs().isEmpty)
    }
}
