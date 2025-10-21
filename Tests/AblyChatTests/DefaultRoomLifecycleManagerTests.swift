import Ably
@testable import AblyChat
import AsyncAlgorithms
import Testing

@MainActor
struct DefaultRoomLifecycleManagerTests {
    // MARK: - Test helpers

    /// A mock implementation of a realtime channel's `attach` or `detach` operation. Its ``complete(behavior:)`` method allows you to signal to the mock that the mocked operation should perform a given behavior (e.g. complete with a given result).
    final class SignallableChannelOperation: Sendable {
        private let continuation: AsyncStream<MockRealtimeChannel.AttachOrDetachBehavior>.Continuation

        /// When this behavior is set as a ``MockRealtimeChannel``'s `attachBehavior` or `detachBehavior`, calling ``complete(behavior:)`` will cause the corresponding channel operation to perform the behavior passed to that method.
        let behavior: MockRealtimeChannel.AttachOrDetachBehavior

        init() {
            let (stream, continuation) = AsyncStream.makeStream(of: MockRealtimeChannel.AttachOrDetachBehavior.self)
            self.continuation = continuation

            behavior = .fromFunction { _ in
                await stream.first { _ in true }!
            }
        }

        /// Causes the async function embedded in ``behavior`` to return with the given behavior.
        func complete(behavior: MockRealtimeChannel.AttachOrDetachBehavior) {
            continuation.yield(behavior)
        }
    }

    private func createManager(
        forTestingWhatHappensWhenCurrentlyIn roomStatus: RoomStatus? = nil,
        forTestingWhatHappensWhenHasHasAttachedOnce hasAttachedOnce: Bool? = nil,
        forTestingWhatHappensWhenHasIsExplicitlyDetached isExplicitlyDetached: Bool? = nil,
        channel: MockRealtimeChannel? = nil,
        clock: any SimpleClock = MockSimpleClock(),
    ) -> DefaultRoomLifecycleManager {
        .init(
            testsOnly_roomStatus: roomStatus,
            testsOnly_hasAttachedOnce: hasAttachedOnce,
            testsOnly_isExplicitlyDetached: isExplicitlyDetached,
            channel: channel ?? createChannel(),
            logger: TestLogger(),
            clock: clock,
        )
    }

    private func createChannel(
        initialState: ARTRealtimeChannelState = .initialized,
        initialErrorReason: ErrorInfo? = nil,
        attachBehavior: MockRealtimeChannel.AttachOrDetachBehavior? = nil,
        detachBehavior: MockRealtimeChannel.AttachOrDetachBehavior? = nil,
    ) -> MockRealtimeChannel {
        .init(
            initialState: initialState,
            initialErrorReason: initialErrorReason,
            attachBehavior: attachBehavior,
            detachBehavior: detachBehavior,
        )
    }

    // MARK: - Initial state

    // @spec CHA-RS2a
    // @spec CHA-RS3
    @Test
    func current_startsAsInitialized() async {
        let manager = createManager()

        #expect(manager.roomStatus == .initialized)
        #expect(manager.error == nil)
    }

    // MARK: - ATTACH operation

    // @spec CHA-RL1a
    @Test
    func attach_whenAlreadyAttached() async throws {
        // Given: A DefaultRoomLifecycleManager in the ATTACHED status
        let channel = createChannel()
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .attached)

        // When: `performAttachOperation()` is called on the lifecycle manager
        try await manager.performAttachOperation()

        // Then: The room attach operation succeeds, and no attempt is made to attach the channel (which we'll consider as satisfying the spec's requirement that a "no-op" happen)
        #expect(channel.attachCallCount == 0)
    }

    // @spec CHA-RL1b
    @Test
    func attach_whenReleasing() async throws {
        // Given: A DefaultRoomLifecycleManager in the RELEASING status
        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .releasing,
        )

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomInInvalidState error (note that the spec point said roomIsReleasing, but this spec point no longer exists and this error code no longer exists in the spec, so use roomInInvalidState instead)
        let thrownError = try await #require(throws: ErrorInfo.self) {
            try await manager.performAttachOperation()
        }
        #expect(thrownError.hasCode(.roomInInvalidState))
    }

    // @spec CHA-RL1l
    @Test
    func attach_whenReleased() async throws {
        // Given: A DefaultRoomLifecycleManager in the RELEASED status
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .released)

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomInInvalidState error
        let thrownError = try await #require(throws: ErrorInfo.self) {
            try await manager.performAttachOperation()
        }
        #expect(thrownError.hasCode(.roomInInvalidState))
    }

    // @spec CHA-RL1d
    @Test
    func attach_ifOtherOperationInProgress_waitsForItToComplete() async throws {
        // Given: A DefaultRoomLifecycleManager with a DETACH lifecycle operation in progress (the fact that it is a DETACH is not important; it is just an operation whose execution it is easy to prolong and subsequently complete, which is helpful for this test)
        let channelDetachOperation = SignallableChannelOperation()
        let manager = createManager(
            channel: createChannel(
                // Arbitrary, allows the ATTACH to eventually complete
                attachBehavior: .success,
                // This allows us to prolong the execution of the DETACH triggered in (1)
                detachBehavior: channelDetachOperation.behavior,
            ),
        )

        let detachOperationID = UUID()
        let attachOperationID = UUID()

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        // Wait for the manager to enter DETACHING; this our sign that the DETACH operation triggered in (1) has started
        async let detachingStatusChange = statusChangeSubscription.first { $0.current == .detaching }

        // (1) This is the "DETACH lifecycle operation in progress" mentioned in Given
        async let _ = manager.performDetachOperation(testsOnly_forcingOperationID: detachOperationID)
        _ = await detachingStatusChange

        let operationWaitEventSubscription = manager.testsOnly_subscribeToOperationWaitEvents()
        async let attachWaitingForDetachEvent = operationWaitEventSubscription.first { operationWaitEvent in
            operationWaitEvent == .init(waitingOperationID: attachOperationID, waitedOperationID: detachOperationID)
        }

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let attachResult: Void = manager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Then:
        // - the manager informs us that the ATTACH operation is waiting for the DETACH operation to complete
        // - when the DETACH completes, the ATTACH operation proceeds (which we check here by verifying that it eventually completes) — note that (as far as I can tell) there is no way to test that the ATTACH operation would have proceeded _only if_ the DETACH had completed; the best we can do is allow the manager to tell us that that this is indeed what it's doing (which is what we check for in the previous bullet)

        _ = try #require(await attachWaitingForDetachEvent)

        // Allow the DETACH to complete
        channelDetachOperation.complete(behavior: .success /* arbitrary */ )

        // Check that ATTACH completes
        try await attachResult
    }

    // @spec CHA-RL1e
    @Test
    func attach_transitionsToAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with a channel on whom calling `attach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to ATTACHED, so that we can assert its current status as being ATTACHING)
        let channelAttachOperation = SignallableChannelOperation()

        let manager = createManager(
            channel: createChannel(attachBehavior: channelAttachOperation.behavior),
        )
        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let _ = try await manager.performAttachOperation()

        // Then: It emits a status change to ATTACHING, and its current status is ATTACHING
        #expect(try #require(await statusChange).current == .attaching)

        #expect(manager.roomStatus == .attaching)
        #expect(manager.error == nil)

        // Post-test: Now that we've seen the ATTACHING status, allow the channel `attach` call to complete
        channelAttachOperation.complete(behavior: .success)
    }

    // @spec CHA-RL1k
    // @spec CHA-RL1k1
    @Test
    func attach_attachesChannel_andWhenItAttachesSuccessfully_transitionsToAttached() async throws {
        // Given: A DefaultRoomLifecycleManager, whose channel's call to `attach` succeeds
        let channel = createChannel(attachBehavior: .success)
        let manager = createManager(
            // These two flags are being set just so that we can verify they get unset per CHA-RL1k1
            forTestingWhatHappensWhenHasHasAttachedOnce: true,
            forTestingWhatHappensWhenHasIsExplicitlyDetached: true,
            channel: channel,
        )

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let attachedStatusChange = statusChangeSubscription.first { $0.current == .attached }

        // When: `performAttachOperation()` is called on the lifecycle manager
        try await manager.performAttachOperation()

        // Then: It calls `attach` on the channel, the room attach operation succeeds, it emits a status change to ATTACHED, its current status is ATTACHED, and it sets the isExplicitlyDetached flag to false and the hasAttachedOnce flag to true
        #expect(channel.attachCallCount > 0)

        _ = try #require(await attachedStatusChange, "Expected status change to ATTACHED")
        try #require(manager.roomStatus == .attached)
        #expect(manager.error == nil)

        #expect(!manager.testsOnly_isExplicitlyDetached)
        #expect(manager.testsOnly_hasAttachedOnce)
    }

    // @spec CHA-RL1k2
    // @spec CHA-RL1k3
    @Test
    func attach_whenChannelFailsToAttach() async throws {
        // Given: A DefaultRoomLifecycleManager, whose channel's call to `attach` fails causing it to enter the FAILED state (arbitrarily chosen)
        let channelAttachError = ErrorInfo.createArbitraryError()
        let channel = createChannel(
            attachBehavior: .completeAndChangeState(.failure(channelAttachError), newState: .failed),
        )

        let manager = createManager(channel: channel)

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeFailedStatusChange = statusChangeSubscription.first { $0.current == .failed }

        // When: `performAttachOperation()` is called on the lifecycle manager
        var roomAttachError: ErrorInfo?
        do {
            try await manager.performAttachOperation()
        } catch {
            roomAttachError = error
        }

        // Then:
        // 1. the room status transitions to the same state as the channel entered (i.e. FAILED in this example), with the status change's `error` equal to the error thrown by the channel `attach` call
        // 2. the manager's `error` is set to this same error
        // 3. the room attach operation fails with this same error
        let failedStatusChange = try #require(await maybeFailedStatusChange)

        #expect(manager.roomStatus == .failed)

        for error in [failedStatusChange.error, manager.error, roomAttachError] {
            #expect(error == channelAttachError)
        }
    }

    // MARK: - DETACH operation

    // @spec CHA-RL2a
    @Test
    func detach_whenAlreadyDetached() async throws {
        // Given: A DefaultRoomLifecycleManager in the DETACHED status
        let channel = createChannel()
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .detached, channel: channel)

        // When: `performDetachOperation()` is called on the lifecycle manager
        try await manager.performDetachOperation()

        // Then: The room detach operation succeeds, and no attempt is made to detach the channel (which we'll consider as satisfying the spec's requirement that a "no-op" happen)
        #expect(channel.detachCallCount == 0)
    }

    // @spec CHA-RL2b
    @Test
    func detach_whenReleasing() async throws {
        // Given: A DefaultRoomLifecycleManager in the RELEASING status
        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .releasing,
        )

        // When: `performDetachOperation()` is called on the lifecycle manager
        // Then: It throws a roomInInvalidState error (note that the spec point said roomIsReleasing, but this spec point no longer exists and this error code no longer exists in the spec, so use roomInInvalidState instead)
        let thrownError = try await #require(throws: ErrorInfo.self) {
            try await manager.performDetachOperation()
        }
        #expect(thrownError.hasCode(.roomInInvalidState))
    }

    // @spec CHA-RL2l
    @Test
    func detach_whenReleased() async throws {
        // Given: A DefaultRoomLifecycleManager in the RELEASED status
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .released)

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomInInvalidState error
        let thrownError = try await #require(throws: ErrorInfo.self) {
            try await manager.performDetachOperation()
        }
        #expect(thrownError.hasCode(.roomInInvalidState))
    }

    // @spec CHA-RL2m
    @Test
    func detach_whenFailed() async throws {
        // Given: A DefaultRoomLifecycleManager in the FAILED status
        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .failed,
        )

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomInInvalidState error
        let thrownError = try await #require(throws: ErrorInfo.self) {
            try await manager.performDetachOperation()
        }
        #expect(thrownError.hasCode(.roomInInvalidState))
    }

    // @spec CHA-RL2i
    @Test
    func detach_ifOtherOperationInProgress_waitsForItToComplete() async throws {
        // Given: A DefaultRoomLifecycleManager with an ATTACH lifecycle operation in progress (the fact that it is an ATTACH is not important; it is just an operation whose execution it is easy to prolong and subsequently complete, which is helpful for this test)
        let channelAttachOperation = SignallableChannelOperation()
        let manager = createManager(
            channel: createChannel(
                // This allows us to prolong the execution of the ATTACH triggered in (1)
                attachBehavior: channelAttachOperation.behavior,
                // Arbitrary, allows the DETACH to eventually complete
                detachBehavior: .success,
            ),
        )

        let attachOperationID = UUID()
        let detachOperationID = UUID()

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        // Wait for the manager to enter ATTACHING; this our sign that the ATTACH operation triggered in (1) has started
        async let attachingStatusChange = statusChangeSubscription.first { $0.current == .attaching }

        // (1) This is the "ATTACH lifecycle operation in progress" mentioned in Given
        async let _ = manager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)
        _ = await attachingStatusChange

        let operationWaitEventSubscription = manager.testsOnly_subscribeToOperationWaitEvents()
        async let detachWaitingForAttachEvent = operationWaitEventSubscription.first { operationWaitEvent in
            operationWaitEvent == .init(waitingOperationID: detachOperationID, waitedOperationID: attachOperationID)
        }

        // When: `performDetachOperation()` is called on the lifecycle manager
        async let detachResult: Void = manager.performDetachOperation(testsOnly_forcingOperationID: detachOperationID)

        // Then:
        // - the manager informs us that the DETACH operation is waiting for the ATTACH operation to complete
        // - when the ATTACH completes, the DETACH operation proceeds (which we check here by verifying that it eventually completes) — note that (as far as I can tell) there is no way to test that the DETACH operation would have proceeded _only if_ the ATTACH had completed; the best we can do is allow the manager to tell us that that this is indeed what it's doing (which is what we check for in the previous bullet)

        _ = try #require(await detachWaitingForAttachEvent)

        // Allow the ATTACH to complete
        channelAttachOperation.complete(behavior: .success /* arbitrary */ )

        // Check that DETACH completes
        try await detachResult
    }

    // @spec CHA-RL2j
    @Test
    func detach_transitionsToDetaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with a channel on whom calling `detach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to DETACHED, so that we can assert its current status as being DETACHING)
        let channelDetachOperation = SignallableChannelOperation()

        let channel = createChannel(detachBehavior: channelDetachOperation.behavior)

        let manager = createManager(channel: channel)
        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performDetachOperation()` is called on the lifecycle manager
        async let _ = try await manager.performDetachOperation()

        // Then: It emits a status change to DETACHING, and its current status is DETACHING
        #expect(try #require(await statusChange).current == .detaching)
        #expect(manager.roomStatus == .detaching)
        #expect(manager.error == nil)

        // Post-test: Now that we've seen the DETACHING status, allow the channel `detach` call to complete
        channelDetachOperation.complete(behavior: .success)
    }

    // @spec CHA-RL2k
    // @spec CHA-RL2k1
    @Test
    func detach_detachesChannel_andWhenItDetachesSuccessfully_transitionsToDetached() async throws {
        // Given: A DefaultRoomLifecycleManager, whose channel's call to `detach` succeeds
        let channel = createChannel(detachBehavior: .success)
        let manager = createManager(
            channel: channel,
        )

        // Double-check the initial value of this flag, so that we can verify it gets set per CHA-RL2k1
        try #require(!manager.testsOnly_isExplicitlyDetached)

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let detachedStatusChange = statusChangeSubscription.first { $0.current == .detached }

        // When: `performDetachOperation()` is called on the lifecycle manager
        try await manager.performDetachOperation()

        // Then: It calls `detach` on the channel, the room detach operation succeeds, it emits a status change to DETACHED, its current status is DETACHED, and it sets the isExplicitlyDetached flag to true
        #expect(channel.detachCallCount > 0)

        _ = try #require(await detachedStatusChange, "Expected status change to DETACHED")
        try #require(manager.roomStatus == .detached)
        #expect(manager.error == nil)

        #expect(manager.testsOnly_isExplicitlyDetached)
    }

    // @spec CHA-RL2k2
    // @spec CHA-RL2k3
    @Test
    func detach_whenChannelFailsToDetach() async throws {
        // Given: A DefaultRoomLifecycleManager, whose channel's call to `detach` fails causing it to enter the FAILED state (arbitrarily chosen)
        let channelDetachError = ErrorInfo.createArbitraryError()
        let channel = createChannel(
            detachBehavior: .completeAndChangeState(.failure(channelDetachError), newState: .failed),
        )

        let manager = createManager(channel: channel)

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeFailedStatusChange = statusChangeSubscription.first { $0.current == .failed }

        // When: `performDetachOperation()` is called on the lifecycle manager
        var roomDetachError: ErrorInfo?
        do {
            try await manager.performDetachOperation()
        } catch {
            roomDetachError = error
        }

        // Then:
        // 1. the room status transitions to the same state as the channel entered (i.e. FAILED in this example), with the status change's `error` equal to the error thrown by the channel `detach` call
        // 2. the manager's `error` is set to this same error
        // 3. the room detach operation fails with this same error
        let failedStatusChange = try #require(await maybeFailedStatusChange)

        #expect(manager.roomStatus == .failed)

        for error in [failedStatusChange.error, manager.error, roomDetachError] {
            #expect(error == channelDetachError)
        }
    }

    // MARK: - RELEASE operation

    // @spec CHA-RL3a
    @Test
    func release_whenAlreadyReleased() async {
        // Given: A DefaultRoomLifecycleManager in the RELEASED status
        let channel = createChannel()
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .released, channel: channel)

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then: The room release operation succeeds, and no attempt is made to detach the channel (which we'll consider as satisfying the spec's requirement that a "no-op" happen)
        #expect(channel.detachCallCount == 0)
    }

    @Test(
        arguments: [
            // @spec CHA-RL3b
            .detached,
            // @spec CHA-RL3j
            .initialized,
        ] as[RoomStatus],
    )
    func release_whenDetachedOrInitialized(status: RoomStatus) async throws {
        // Given: A DefaultRoomLifecycleManager in the DETACHED or INITIALIZED status
        let channel = createChannel()
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: status, channel: channel)

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then: The room release operation succeeds, the room transitions to RELEASED, and no attempt is made to detach the channel (which we'll consider as satisfying the spec's requirement that the transition be "immediate")
        #expect(try #require(await statusChange).current == .released)
        #expect(manager.roomStatus == .released)
        #expect(manager.error == nil)
        #expect(channel.detachCallCount == 0)
    }

    // @spec CHA-RL3k
    @Test
    func release_ifOtherOperationInProgress_waitsForItToComplete() async throws {
        // Given: A DefaultRoomLifecycleManager with an ATTACH lifecycle operation in progress (the fact that it is an ATTACH is not important; it is just an operation whose execution it is easy to prolong and subsequently complete, which is helpful for this test)
        let channelAttachOperation = SignallableChannelOperation()
        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .detached, // arbitrary non-{RELEASED, DETACHED, INITIALIZED} status, so that we get as far as CHA-RL3n, and non-ATTACHED so that we get as far as CHA-RL1e
            channel: createChannel(
                // This allows us to prolong the execution of the ATTACH triggered in (1)
                attachBehavior: channelAttachOperation.behavior,
                // Arbitrary, allows the RELEASE to eventually complete
                detachBehavior: .success,
            ),
        )

        let attachOperationID = UUID()
        let releaseOperationID = UUID()

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        // Wait for the manager to enter ATTACHING; this our sign that the ATTACH operation triggered in (1) has started
        async let attachingStatusChange = statusChangeSubscription.first { $0.current == .attaching }

        // (1) This is the "ATTACH lifecycle operation in progress" mentioned in Given
        async let _ = manager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)
        _ = await attachingStatusChange

        let operationWaitEventSubscription = manager.testsOnly_subscribeToOperationWaitEvents()
        async let releaseWaitingForAttachEvent = operationWaitEventSubscription.first { operationWaitEvent in
            operationWaitEvent == .init(waitingOperationID: releaseOperationID, waitedOperationID: attachOperationID)
        }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        async let releaseResult: Void = manager.performReleaseOperation(testsOnly_forcingOperationID: releaseOperationID)

        // Then:
        // - the manager informs us that the RELEASE operation is waiting for the ATTACH operation to complete
        // - when the ATTACH completes, the RELEASE operation proceeds (which we check here by verifying that it eventually completes) — note that (as far as I can tell) there is no way to test that the RELEASE operation would have proceeded _only if_ the ATTACH had completed; the best we can do is allow the manager to tell us that that this is indeed what it's doing (which is what we check for in the previous bullet)

        _ = try #require(await releaseWaitingForAttachEvent)

        // Allow the ATTACH to complete
        channelAttachOperation.complete(behavior: .success /* arbitrary */ )

        // Check that RELEASE completes
        await releaseResult
    }

    // @spec CHA-RL3m
    @Test
    func release_transitionsToReleasing() async throws {
        // Given: A DefaultRoomLifecycleManager, with a channel on whom calling `detach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to RELEASED, so that we can assert its current status as being RELEASING)
        let channelDetachOperation = SignallableChannelOperation()

        let channel = createChannel(detachBehavior: channelDetachOperation.behavior)

        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attached, // arbitrary non-{RELEASED, DETACHED, INITIALIZED} status, so that we get as far as CHA-RL3n
            channel: channel,
        )
        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        async let _ = await manager.performReleaseOperation()

        // Then: It emits a status change to RELEASING, and its current status is RELEASING
        #expect(try #require(await statusChange).current == .releasing)
        #expect(manager.roomStatus == .releasing)
        #expect(manager.error == nil)

        // Post-test: Now that we've seen the RELEASING status, allow the channel `detach` call to complete
        channelDetachOperation.complete(behavior: .success)
    }

    // @spec CHA-RL3n1
    // @specOneOf(1/3) CHA-RL3o - Tests the case where the operation completes without any detach attempt
    @Test
    func release_whenChannelIsFailed() async throws {
        // Given: A DefaultRoomLifecycleManager, with a channel in the FAILED state
        let channel = createChannel(initialState: .failed)

        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attached, // arbitrary non-{RELEASED, DETACHED, INITIALIZED} status, so that we get as far as CHA-RL3n
            channel: channel,
        )

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let releasedStatusChange = statusChangeSubscription.first { $0.current == .released }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then:
        // - it does not call `detach()` on the channel
        // - the room transitions to RELEASED
        // - the call to `performReleaseOperation()` completes
        #expect(channel.detachCallCount == 0)

        _ = await releasedStatusChange

        #expect(manager.roomStatus == .released)
        #expect(manager.error == nil)
    }

    // @specOneOf(1/2) CHA-RL3n2 - Tests the case where there's a single detach attempt
    // @specOneOf(2/3) CHA-RL3o - Tests the case where the operation completes after single detach attempt
    @Test
    func release_whenChannelIsNotFailed() async throws {
        // Given: A DefaultRoomLifecycleManager, with a channel in a non-FAILED state and on whom calling `detach()` succeeds
        let channel = createChannel(initialState: .attached /* arbitrary non-FAILED */, detachBehavior: .success)

        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attached, // arbitrary non-{RELEASED, DETACHED, INITIALIZED} status, so that we get as far as CHA-RL3n
            channel: channel,
        )

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let releasedStatusChange = statusChangeSubscription.first { $0.current == .released }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then:
        // - it calls `detach()` on the channel
        // - the room transitions to RELEASED
        // - the call to `performReleaseOperation()` completes
        #expect(channel.detachCallCount == 1)

        _ = await releasedStatusChange

        #expect(manager.roomStatus == .released)
        #expect(manager.error == nil)
    }

    // @spec CHA-RL3n4
    // @specOneOf(2/2) CHA-RL3n2 - Tests the case where there are multiple detach attempts
    // @specOneOf(3/3) CHA-RL3o - Tests the case where the operation completes after multiple detach attempts
    @Test
    func release_whenDetachFails_ifChannelIsNotFailed_retriesAfterPause() async {
        // Given: A DefaultRoomLifecycleManager, with a channel for which:
        // - the first two times that `detach()` is called, it fails, leaving the channel in a non-FAILED state
        // - the third time that `detach()` is called, it succeeds
        let detachImpl = { @Sendable (callCount: Int) async -> MockRealtimeChannel.AttachOrDetachBehavior in
            if callCount < 3 {
                return .failure(.createArbitraryError())
            }
            return .success
        }
        let channel = createChannel(detachBehavior: .fromFunction(detachImpl))

        let clock = MockSimpleClock()

        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attached, // arbitrary non-{RELEASED, DETACHED, INITIALIZED} status, so that we get as far as CHA-RL3n
            channel: channel,
            clock: clock,
        )

        // Then: When `performReleaseOperation()` is called on the manager
        await manager.performReleaseOperation()

        // It: calls `detach()` on the channel 3 times, with a 0.25s pause between each attempt, and the call to `performReleaseOperation` completes
        #expect(channel.detachCallCount == 3)

        // We use "did it call clock.sleep(…)?" as a good-enough proxy for the question "did it wait for the right amount of time at the right moment?"
        #expect(clock.sleepCallArguments == Array(repeating: 0.25, count: 2))
    }

    // @spec CHA-RL3n3
    @Test
    func release_whenDetachFails_ifChannelIsFailed_doesNotRetry() async {
        // Given: A DefaultRoomLifecycleManager, with a channel for which, when `detach()` is called, it fails, causing the channel to enter the FAILED state
        let channel = createChannel(detachBehavior: .completeAndChangeState(.failure(.createArbitraryError()), newState: .failed))

        let clock = MockSimpleClock()

        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attached, // arbitrary non-{RELEASED, DETACHED, INITIALIZED} status, so that we get as far as CHA-RL3n
            channel: channel,
            clock: clock,
        )

        let statusChangeSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let releasedStatusChange = statusChangeSubscription.first { $0.current == .released }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then:
        // - it calls `detach()` precisely once on the channel (that is, it does not retry)
        // - it does not perform a pause
        // - the room transitions to RELEASED
        // - the call to `performReleaseOperation()` completes
        #expect(channel.detachCallCount == 1)

        #expect(clock.sleepCallArguments.isEmpty)

        _ = await releasedStatusChange

        #expect(manager.roomStatus == .released)
        #expect(manager.error == nil)
    }

    // MARK: - Handling channel state events

    // @specOneOf(1/3) CHA-RL11a
    // @spec CHA-RL11b
    @Test
    func channelStateChange_withOperationInProgress() async throws {
        // Given: A DefaultRoomLifecycleManager, with a room lifecycle operation in progress
        let channelAttachBehavior = SignallableChannelOperation()
        let channel = createChannel(
            attachBehavior: channelAttachBehavior.behavior,
        )
        let manager = createManager(
            channel: channel,
        )

        let roomStatusSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let _ = manager.performAttachOperation()
        // Wait for the transition to ATTACHED, so that we know the manager considers the ATTACH operation to be in progress
        _ = await roomStatusSubscription.first { @Sendable in $0.current == .attaching }

        let originalRoomStatus = manager.roomStatus
        let originalError = manager.error

        // When: The channel emits a state change
        let channelStateChange = ChannelStateChange(
            current: .detaching, // arbitrary, just different to the ATTACHING we started off in
            previous: .attached, // arbitrary
            event: .detaching,
            reason: .createArbitraryError(),
            resumed: false,
        )

        channel.emitEvent(channelStateChange)

        // Then: The manager does not change room status or error
        #expect(manager.roomStatus == originalRoomStatus)
        #expect(manager.error == originalError)

        // Post-test: Allow the room lifecycle operation to complete
        channelAttachBehavior.complete(behavior: .success /* arbitrary */ )
    }

    // @specOneOf(2/3) CHA-RL11a
    // @spec CHA-RL11c
    @Test
    func channelStateChange_withNoOperationInProgress() async throws {
        // Given: A DefaultRoomLifecycleManager, with no room lifecycle operation in progress
        let channel = createChannel()
        let manager = createManager(channel: channel)

        let roomStatusSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)

        // When: The channel emits a state change
        let channelStateChangeError = ErrorInfo.createArbitraryError()
        let channelStateChange = ChannelStateChange(
            current: .attaching, // arbitrary
            previous: .attached, // arbitrary
            event: .attaching,
            reason: channelStateChangeError,
            resumed: false,
        )

        channel.emitEvent(channelStateChange)

        // Then: The manager changes room status to match that informed by the channel event
        let roomStatusChange = try #require(await roomStatusSubscription.first { @Sendable _ in true })
        #expect(roomStatusChange.current == .attaching)
        #expect(manager.roomStatus == .attaching)
        #expect(manager.error == channelStateChangeError)
    }

    // @specOneOf(3/3) CHA-RL11a - Tests that only state change events can cause a room status change
    @Test
    func channel_nonStateChangeEvent_doesNotCauseRoomStatusChange() async throws {
        // Given: A DefaultRoomLifecycleManager, with no room lifecycle operation in progress
        let channel = createChannel()
        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .detached, // arbitrary value different to the ATTACHED in the UPDATE event emitted below
            channel: channel,
        )

        let initialRoomStatus = manager.roomStatus
        let initialError = manager.error

        let roomStatusSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)

        // When: The channel emits an UPDATE event (i.e. not a state change)
        let channelUpdateEvent = ChannelStateChange(
            current: .attached, // arbitrary
            previous: .attached, // arbitrary
            event: .update,
            reason: .createArbitraryError(),
            resumed: false,
        )

        channel.emitEvent(channelUpdateEvent)

        // Then: The manager does not update the room status or error
        #expect(manager.roomStatus == initialRoomStatus)
        #expect(manager.error == initialError)

        roomStatusSubscription.testsOnly_finish()
        let emittedRoomStatusEvents = await Array(roomStatusSubscription)
        #expect(emittedRoomStatusEvents.isEmpty)
    }

    // @spec CHA-RL12a
    // @spec CHA-RL12b
    @Test(arguments: [
        (
            hasAttachedOnce: true,
            isExplicitlyDetached: false,

            // State change to ATTACHED, resumed false
            channelEvent: ChannelStateChange(
                current: .attached,
                previous: .attaching, // arbitrary
                event: .attached,
                reason: .createArbitraryError(),
                resumed: false,
            ),

            expectDiscontinuity: true,
        ),
        (
            hasAttachedOnce: true,
            isExplicitlyDetached: false,

            // UPDATE event, resumed false
            channelEvent: ChannelStateChange(
                current: .attached, // arbitrary
                previous: .attached,
                event: .update,
                reason: .createArbitraryError(),
                resumed: false,
            ),

            expectDiscontinuity: true,
        ),
        (
            hasAttachedOnce: true,
            isExplicitlyDetached: false,

            // UPDATE event, resumed true (so ineligible for a discontinuity) - not sure if this happens in reality, but RTL12 suggests it's possible
            channelEvent: ChannelStateChange(
                current: .attached, // arbitrary
                previous: .attached,
                event: .update,
                reason: nil,
                resumed: true,
            ),

            expectDiscontinuity: false,
        ),
        (
            hasAttachedOnce: true,
            isExplicitlyDetached: false,

            // non-(UPDATE or ATTACHED) event (so ineligible for a discontinuity)
            channelEvent: ChannelStateChange(
                current: .attaching, // arbitrary non-(UPDATE or ATTACHED)
                previous: .attached,
                event: .attaching,
                reason: nil,
                resumed: false,
            ),

            expectDiscontinuity: false,
        ),
        (
            hasAttachedOnce: false,
            isExplicitlyDetached: false,

            // State change to ATTACHED, resumed false (i.e. an event eligible for a discontinuity, but which will be excluded because of hasAttachedOnce)
            channelEvent: ChannelStateChange(
                current: .attaching, // arbitrary
                previous: .attached,
                event: .attached,
                reason: .createArbitraryError(),
                resumed: false,
            ),

            expectDiscontinuity: false,
        ),
        (
            hasAttachedOnce: true,
            isExplicitlyDetached: true,

            // State change to ATTACHED, resumed false (i.e. an event eligible for a discontinuity, but which will be excluded because of isExplicitlyDetached)
            channelEvent: ChannelStateChange(
                current: .attaching, // arbitrary
                previous: .attached,
                event: .attached,
                reason: .createArbitraryError(),
                resumed: false,
            ),

            expectDiscontinuity: false,
        ),
    ])
    func channelStateEvent_discontinuity(
        hasAttachedOnce: Bool,
        isExplicitlyDetached: Bool,
        channelEvent: ChannelStateChange,
        expectDiscontinuity: Bool,
    ) async throws {
        // Given: A DefaultRoomLifecycleManager, whose hasAttachedOnce and isExplicitlyDetached internal state is set per test arguments
        let channelAttachBehavior = hasAttachedOnce ? MockRealtimeChannel.AttachOrDetachBehavior.complete(.success) : nil
        let channelDetachBehavior = isExplicitlyDetached ? MockRealtimeChannel.AttachOrDetachBehavior.complete(.success) : nil

        let channel = createChannel(attachBehavior: channelAttachBehavior, detachBehavior: channelDetachBehavior)
        let manager = createManager(channel: channel)

        // Perform the operations necessary to get the hasAttachedOnce and isExplicitlyDetached flags to be the values we wish them to be.
        if hasAttachedOnce {
            try await manager.performAttachOperation()
            try #require(manager.testsOnly_hasAttachedOnce)
        }
        if isExplicitlyDetached {
            try await manager.performDetachOperation()
            try #require(manager.testsOnly_isExplicitlyDetached)
        }

        let discontinuitiesSubscription = manager.onDiscontinuity(bufferingPolicy: .unbounded)

        // When: The channel emits a state event
        channel.emitEvent(channelEvent)

        // Then: If the state event is a potential discontinuity, and this is confirmed by our internal state, the manager emits a discontinuity
        discontinuitiesSubscription.testsOnly_finish()
        let emittedDiscontinuities = await Array(discontinuitiesSubscription)

        if expectDiscontinuity {
            try #require(emittedDiscontinuities.count == 1)
            let discontinuityError = emittedDiscontinuities[0]

            #expect(
                discontinuityError.hasCode(
                    .roomDiscontinuity,
                    cause: channelEvent.reason,
                ),
            )
        } else {
            #expect(emittedDiscontinuities.isEmpty)
        }
    }

    // MARK: - Waiting to be able to perform presence operations

    // @specOneOf(1/2) CHA-RL9a
    // @spec CHA-RL9b
    //
    // @specOneOf(1/4) CHA-PR3d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    // @specOneOf(1/4) CHA-PR10d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    // @specOneOf(1/4) CHA-PR6c - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenAttaching_whenTransitionsToAttached() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let channelAttachOperation = SignallableChannelOperation()

        let channel = createChannel(attachBehavior: channelAttachOperation.behavior)

        let manager = createManager(
            channel: channel,
        )

        let roomStatusSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = manager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = await roomStatusSubscription.first { @Sendable in $0.current == .attaching }

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        let statusChangeWaitSubscription = manager.testsOnly_subscribeToStatusChangeWaitEvents()
        async let waitToBeAbleToPerformPresenceOperationsResult: Void = manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )

        // Then: The manager waits for its room status to change
        _ = try #require(await statusChangeWaitSubscription.first { @Sendable _ in true })

        // and When: The ATTACH operation succeeds, thus putting the room in the ATTACHED status
        channelAttachOperation.complete(behavior: .success)

        // Then: The call to `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` succeeds
        try await waitToBeAbleToPerformPresenceOperationsResult
    }

    // @specOneOf(2/2) CHA-RL9a
    // @spec CHA-RL9c
    //
    // @specOneOf(2/4) CHA-PR3d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    // @specOneOf(2/4) CHA-PR10d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    // @specOneOf(2/4) CHA-PR6c - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenAttaching_whenTransitionsToNonAttachedStatus() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let channelAttachOperation = SignallableChannelOperation()

        let channel = createChannel(attachBehavior: channelAttachOperation.behavior)

        let manager = createManager(
            channel: channel,
        )

        let roomStatusSubscription = manager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = manager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = await roomStatusSubscription.first { @Sendable in $0.current == .attaching }

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        let statusChangeWaitSubscription = manager.testsOnly_subscribeToStatusChangeWaitEvents()
        async let waitToBeAbleToPerformPresenceOperationsResult: Void = manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )

        // Then: The manager waits for its room status to change
        _ = try #require(await statusChangeWaitSubscription.first { @Sendable _ in true })

        // and When: The ATTACH operation fails, thus putting the room in the FAILED status (i.e. a non-ATTACHED status)
        let channelAttachError = ErrorInfo.createArbitraryError()
        channelAttachOperation.complete(behavior: .completeAndChangeState(.failure(channelAttachError), newState: .failed))

        // Then: The call to `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` fails with a `roomInInvalidState` error, whose cause is the error associated with the room status change
        var caughtError: ErrorInfo?
        do {
            try await waitToBeAbleToPerformPresenceOperationsResult
        } catch {
            caughtError = error as? ErrorInfo
        }

        let expectedCause = channelAttachError // using our knowledge of CHA-RL1k2
        #expect(try #require(caughtError).hasCode(.roomInInvalidState, cause: expectedCause))
    }

    // @specOneOf(1/2) CHA-PR3e - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    // @specOneOf(1/2) CHA-PR10e - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    // @specOneOf(1/2) CHA-PR6d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect.
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenAttached() async throws {
        // Given: A DefaultRoomLifecycleManager in the ATTACHED status
        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attached,
        )

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        // Then: It returns
        try await manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )
    }

    // @specOneOf(1/2) CHA-PR3h - Tests the wait described in the spec point, but not that the feature actually performs this wait.
    // @specOneOf(1/2) CHA-PR10h - Tests the wait described in the spec point, but not that the feature actually performs this wait.
    // @specOneOf(1/2) CHA-PR6h - Tests the wait described in the spec point, but not that the feature actually performs this wait.
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenAnyOtherStatus() async throws {
        // Given: A DefaultRoomLifecycleManager in a status other than ATTACHING or ATTACHED
        let manager = createManager(
            forTestingWhatHappensWhenCurrentlyIn: .detached, // arbitrary given the above constraints
        )

        // (Note: I wanted to use #expect(…, throws:) below, but for some reason it made the compiler _crash_! No idea why. So, gave up on that.)

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        let caughtError = try await #require(throws: ErrorInfo.self) {
            try await manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )
        }

        // Then: It throws a roomInInvalidState error for that feature, with a message explaining that the room must first be attached
        #expect(caughtError.hasCode(.roomInInvalidState, message: "To perform this messages operation, you must first attach the room."))
    }
}
