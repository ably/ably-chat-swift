@preconcurrency import Ably
@testable import AblyChat
import Testing

struct DefaultRoomLifecycleManagerTests {
    // MARK: - Test helpers

    /// A mock implementation of a realtime channel’s `attach` or `detach` operation. Its ``complete(behavior:)`` method allows you to signal to the mock that the mocked operation should perform a given behavior (e.g. complete with a given result).
    final class SignallableChannelOperation: Sendable {
        private let continuation: AsyncStream<MockRoomLifecycleContributorChannel.AttachOrDetachBehavior>.Continuation

        /// When this behavior is set as a ``MockRealtimeChannel``’s `attachBehavior` or `detachBehavior`, calling ``complete(behavior:)`` will cause the corresponding channel operation to perform the behavior passed to that method.
        let behavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior

        init() {
            let (stream, continuation) = AsyncStream.makeStream(of: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior.self)
            self.continuation = continuation

            behavior = .fromFunction { _ in
                await stream.first { _ in true }!
            }
        }

        /// Causes the async function embedded in ``behavior`` to return with the given behavior.
        func complete(behavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior) {
            continuation.yield(behavior)
        }
    }

    /// A mock implementation of a `SimpleClock`’s `sleep(timeInterval:)` operation. Its ``complete(result:)`` method allows you to signal to the mock that the sleep should complete.
    final class SignallableSleepOperation: Sendable {
        private let continuation: AsyncStream<Void>.Continuation

        /// When this behavior is set as a ``MockSimpleClock``’s `sleepBehavior`, calling ``complete(result:)`` will cause the corresponding `sleep(timeInterval:)` to complete with the result passed to that method.
        ///
        /// ``sleep(timeInterval:)`` will respond to task cancellation by throwing `CancellationError`.
        let behavior: MockSimpleClock.SleepBehavior

        init() {
            let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
            self.continuation = continuation

            behavior = .fromFunction {
                await (stream.first { _ in true }) // this will return if we yield to the continuation or if the Task is cancelled
                try Task.checkCancellation()
            }
        }

        /// Causes the async function embedded in ``behavior`` to return.
        func complete() {
            continuation.yield(())
        }
    }

    private func createManager(
        forTestingWhatHappensWhenCurrentlyIn status: DefaultRoomLifecycleManager<MockRoomLifecycleContributor>.Status? = nil,
        forTestingWhatHappensWhenHasPendingDiscontinuityEvents pendingDiscontinuityEvents: [MockRoomLifecycleContributor.ID: [ARTErrorInfo]]? = nil,
        forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs idsOfContributorsWithTransientDisconnectTimeout: Set<MockRoomLifecycleContributor.ID>? = nil,
        contributors: [MockRoomLifecycleContributor] = [],
        clock: SimpleClock = MockSimpleClock()
    ) async -> DefaultRoomLifecycleManager<MockRoomLifecycleContributor> {
        await .init(
            testsOnly_status: status,
            testsOnly_pendingDiscontinuityEvents: pendingDiscontinuityEvents,
            testsOnly_idsOfContributorsWithTransientDisconnectTimeout: idsOfContributorsWithTransientDisconnectTimeout,
            contributors: contributors,
            logger: TestLogger(),
            clock: clock
        )
    }

    private func createContributor(
        initialState: ARTRealtimeChannelState = .initialized,
        initialErrorReason: ARTErrorInfo? = nil,
        feature: RoomFeature = .messages, // Arbitrarily chosen, its value only matters in test cases where we check which error is thrown
        attachBehavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior? = nil,
        detachBehavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior? = nil,
        subscribeToStateBehavior: MockRoomLifecycleContributorChannel.SubscribeToStateBehavior? = nil
    ) -> MockRoomLifecycleContributor {
        .init(
            feature: feature,
            channel: .init(
                initialState: initialState,
                initialErrorReason: initialErrorReason,
                attachBehavior: attachBehavior,
                detachBehavior: detachBehavior,
                subscribeToStateBehavior: subscribeToStateBehavior
            )
        )
    }

    /// Given a room lifecycle manager and a channel state change, this method will return once the manager has performed all of the side effects that it will perform as a result of receiving this state change. You can provide a function which will be called after ``waitForManager`` has started listening for the manager’s “state change handled” notifications.
    func waitForManager(_ manager: DefaultRoomLifecycleManager<some RoomLifecycleContributor>, toHandleContributorStateChange stateChange: ARTChannelStateChange, during action: () async -> Void) async {
        let subscription = await manager.testsOnly_subscribeToHandledContributorStateChanges()
        async let handledSignal = subscription.first { $0 === stateChange }
        await action()
        _ = await handledSignal
    }

    /// Given a room lifecycle manager and the ID of a transient disconnect timeout, this method will return once the manager has performed all of the side effects that it will perform as a result of creating that timeout. You can provide a function which will be called after ``waitForManager`` has started listening for the manager’s “transient disconnect timeout handled” notifications.
    func waitForManager(_ manager: DefaultRoomLifecycleManager<some RoomLifecycleContributor>, toHandleTransientDisconnectTimeoutWithID id: UUID, during action: () async -> Void) async {
        let subscription = await manager.testsOnly_subscribeToHandledTransientDisconnectTimeouts()
        async let handledSignal = subscription.first { $0 == id }
        await action()
        _ = await handledSignal
    }

    // MARK: - Initial state

    // @spec CHA-RS2a
    // @spec CHA-RS3
    @Test
    func current_startsAsInitialized() async {
        let manager = await createManager()

        #expect(await manager.roomStatus == .initialized)
    }

    // MARK: - ATTACH operation

    // @spec CHA-RL1a
    @Test
    func attach_whenAlreadyAttached() async throws {
        // Given: A DefaultRoomLifecycleManager in the ATTACHED status
        let contributor = createContributor()
        let manager = await createManager(forTestingWhatHappensWhenCurrentlyIn: .attached, contributors: [contributor])

        // When: `performAttachOperation()` is called on the lifecycle manager
        try await manager.performAttachOperation()

        // Then: The room attach operation succeeds, and no attempt is made to attach a contributor (which we’ll consider as satisfying the spec’s requirement that a "no-op" happen)
        #expect(await contributor.channel.attachCallCount == 0)
    }

    // @spec CHA-RL1b
    @Test
    func attach_whenReleasing() async throws {
        // Given: A DefaultRoomLifecycleManager in the RELEASING status
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .releasing(releaseOperationID: UUID() /* arbitrary */ )
        )

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomIsReleasing error
        await #expect {
            try await manager.performAttachOperation()
        } throws: { error in
            isChatError(error, withCode: .roomIsReleasing)
        }
    }

    // @spec CHA-RL1c
    @Test
    func attach_whenReleased() async throws {
        // Given: A DefaultRoomLifecycleManager in the RELEASED status
        let manager = await createManager(forTestingWhatHappensWhenCurrentlyIn: .released)

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomIsReleased error
        await #expect {
            try await manager.performAttachOperation()
        } throws: { error in
            isChatError(error, withCode: .roomIsReleased)
        }
    }

    // @spec CHA-RL1d
    @Test
    func attach_ifOtherOperationInProgress_waitsForItToComplete() async throws {
        // Given: A DefaultRoomLifecycleManager with a DETACH lifecycle operation in progress (the fact that it is a DETACH is not important; it is just an operation whose execution it is easy to prolong and subsequently complete, which is helpful for this test)
        let contributorDetachOperation = SignallableChannelOperation()
        let manager = await createManager(
            contributors: [
                createContributor(
                    // Arbitrary, allows the ATTACH to eventually complete
                    attachBehavior: .success,
                    // This allows us to prolong the execution of the DETACH triggered in (1)
                    detachBehavior: contributorDetachOperation.behavior
                ),
            ]
        )

        let detachOperationID = UUID()
        let attachOperationID = UUID()

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        // Wait for the manager to enter DETACHING; this our sign that the DETACH operation triggered in (1) has started
        async let detachingStatusChange = statusChangeSubscription.first { $0.current == .detaching }

        // (1) This is the "DETACH lifecycle operation in progress" mentioned in Given
        async let _ = manager.performDetachOperation(testsOnly_forcingOperationID: detachOperationID)
        _ = await detachingStatusChange

        let operationWaitEventSubscription = await manager.testsOnly_subscribeToOperationWaitEvents()
        async let attachedWaitingForDetachedEvent = operationWaitEventSubscription.first { operationWaitEvent in
            operationWaitEvent == .init(waitingOperationID: attachOperationID, waitedOperationID: detachOperationID)
        }

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let attachResult: Void = manager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Then:
        // - the manager informs us that the ATTACH operation is waiting for the DETACH operation to complete
        // - when the DETACH completes, the ATTACH operation proceeds (which we check here by verifying that it eventually completes) — note that (as far as I can tell) there is no way to test that the ATTACH operation would have proceeded _only if_ the DETACH had completed; the best we can do is allow the manager to tell us that that this is indeed what it’s doing (which is what we check for in the previous bullet)

        _ = try #require(await attachedWaitingForDetachedEvent)

        // Allow the DETACH to complete
        contributorDetachOperation.complete(behavior: .success /* arbitrary */ )

        // Check that ATTACH completes
        try await attachResult
    }

    // @spec CHA-RL1e
    @Test
    func attach_transitionsToAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with a contributor on whom calling `attach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to ATTACHED, so that we can assert its current status as being ATTACHING)
        let contributorAttachOperation = SignallableChannelOperation()

        let manager = await createManager(contributors: [createContributor(attachBehavior: contributorAttachOperation.behavior)])
        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let _ = try await manager.performAttachOperation()

        // Then: It emits a status change to ATTACHING, and its current status is ATTACHING
        #expect(try #require(await statusChange).current == .attaching(error: nil))

        #expect(await manager.roomStatus == .attaching(error: nil))

        // Post-test: Now that we’ve seen the ATTACHING status, allow the contributor `attach` call to complete
        contributorAttachOperation.complete(behavior: .success)
    }

    // @spec CHA-RL1f
    // @spec CHA-RL1g1
    @Test
    func attach_attachesAllContributors_andWhenTheyAllAttachSuccessfully_transitionsToAttached() async throws {
        // Given: A DefaultRoomLifecycleManager, all of whose contributors’ calls to `attach` succeed
        let contributors = (1 ... 3).map { _ in createContributor(attachBehavior: .success) }
        let manager = await createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let attachedStatusChange = statusChangeSubscription.first { $0.current == .attached }

        // When: `performAttachOperation()` is called on the lifecycle manager
        try await manager.performAttachOperation()

        // Then: It calls `attach` on all the contributors, the room attach operation succeeds, it emits a status change to ATTACHED, and its current status is ATTACHED
        for contributor in contributors {
            #expect(await contributor.channel.attachCallCount > 0)
        }

        _ = try #require(await attachedStatusChange, "Expected status change to ATTACHED")
        try #require(await manager.roomStatus == .attached)
    }

    // @spec CHA-RL1g2
    @Test
    func attach_uponSuccess_emitsPendingDiscontinuityEvents() async throws {
        // Given: A DefaultRoomLifecycleManager, all of whose contributors’ calls to `attach` succeed
        let contributors = (1 ... 3).map { _ in createContributor(attachBehavior: .success) }
        let pendingDiscontinuityEvents: [MockRoomLifecycleContributor.ID: [ARTErrorInfo]] = [
            contributors[1].id: [.init(domain: "SomeDomain", code: 123) /* arbitrary */ ],
            contributors[2].id: [.init(domain: "SomeDomain", code: 456) /* arbitrary */ ],
        ]
        let manager = await createManager(
            forTestingWhatHappensWhenHasPendingDiscontinuityEvents: pendingDiscontinuityEvents,
            contributors: contributors
        )

        // When: `performAttachOperation()` is called on the lifecycle manager
        try await manager.performAttachOperation()

        // Then: It:
        // - emits all pending discontinuities to its contributors
        // - clears all pending discontinuity events (TODO: I assume this is the intended behaviour, but confirm; have asked in https://github.com/ably/specification/pull/200/files#r1781917231)
        for contributor in contributors {
            let expectedPendingDiscontinuityEvents = pendingDiscontinuityEvents[contributor.id] ?? []
            let emitDiscontinuityArguments = await contributor.emitDiscontinuityArguments
            try #require(emitDiscontinuityArguments.count == expectedPendingDiscontinuityEvents.count)
            for (emitDiscontinuityArgument, expectedArgument) in zip(emitDiscontinuityArguments, expectedPendingDiscontinuityEvents) {
                #expect(emitDiscontinuityArgument === expectedArgument)
            }
        }

        for contributor in contributors {
            #expect(await manager.testsOnly_pendingDiscontinuityEvents(for: contributor).isEmpty)
        }
    }

    // @spec CHA-RL1g3
    @Test
    func attach_uponSuccess_clearsTransientDisconnectTimeouts() async throws {
        // Given: A DefaultRoomLifecycleManager, all of whose contributors’ calls to `attach` succeed
        let contributors = (1 ... 3).map { _ in createContributor(attachBehavior: .success) }
        let manager = await createManager(
            forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs: [contributors[1].id],
            contributors: contributors
        )

        // When: `performAttachOperation()` is called on the lifecycle manager
        try await manager.performAttachOperation()

        // Then: It clears all transient disconnect timeouts
        #expect(await !manager.testsOnly_hasTransientDisconnectTimeoutForAnyContributor)
    }

    // @spec CHA-RL1h2
    // @specOneOf(1/2) CHA-RL1h1 - tests that an error gets thrown when channel attach fails due to entering SUSPENDED (TODO: but I don’t yet fully understand the meaning of CHA-RL1h1; outstanding question https://github.com/ably/specification/pull/200/files#r1765476610)
    // @spec CHA-RL1h3
    @Test
    func attach_whenContributorFailsToAttachAndEntersSuspended_transitionsToSuspendedAndPerformsRetryOperation() async throws {
        // Given: A DefaultRoomLifecycleManager, one of whose contributors’ call to `attach` fails causing it to enter the SUSPENDED status
        let contributorAttachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        var nonSuspendedContributorsDetachOperations: [SignallableChannelOperation] = []
        let contributors = (1 ... 3).map { i in
            if i == 1 {
                return createContributor(
                    attachBehavior: .fromFunction { callCount in
                        if callCount == 1 {
                            .completeAndChangeState(.failure(contributorAttachError), newState: .suspended) // The behaviour described above
                        } else {
                            .success // So the CHA-RL5f RETRY attachment cycle succeeds
                        }
                    },

                    // This is so that the RETRY operation’s wait-to-become-ATTACHED succeeds
                    subscribeToStateBehavior: .addSubscriptionAndEmitStateChange(
                        .init(
                            current: .attached,
                            previous: .detached, // arbitrary
                            event: .attached,
                            reason: .createUnknownError() // Not related to this test, just to avoid a crash in CHA-RL4b1 handling of this state change
                        )
                    )
                )
            } else {
                // These contributors will be detached by the RETRY operation; we want to be able to delay their completion (and hence delay the RETRY operation’s transition from SUSPENDED to DETACHED) until we have been able to verify that the room’s status is SUSPENDED
                let detachOperation = SignallableChannelOperation()
                nonSuspendedContributorsDetachOperations.append(detachOperation)

                return createContributor(
                    attachBehavior: .success, // So the CHA-RL5f RETRY attachment cycle succeeds
                    detachBehavior: detachOperation.behavior
                )
            }
        }

        let manager = await createManager(contributors: contributors)

        let roomStatusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeSuspendedRoomStatusChange = roomStatusChangeSubscription.suspendedElements().first { _ in true }

        let managerStatusChangeSubscription = await manager.testsOnly_onStatusChange()

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let roomAttachResult: Void = manager.performAttachOperation()

        // Then:
        //
        // 1. the room status transitions to SUSPENDED, with the status change’s `error` having the AttachmentFailed code corresponding to the feature of the failed contributor, `cause` equal to the error thrown by the contributor `attach` call
        // 2. the manager’s `error` is set to this same error
        // 3. the room attach operation fails with this same error
        let suspendedRoomStatusChange = try #require(await maybeSuspendedRoomStatusChange)

        #expect(await manager.roomStatus.isSuspended)

        var roomAttachError: Error?
        do {
            _ = try await roomAttachResult
        } catch {
            roomAttachError = error
        }

        for error in await [suspendedRoomStatusChange.error, manager.roomStatus.error, roomAttachError] {
            #expect(isChatError(error, withCode: .messagesAttachmentFailed, cause: contributorAttachError))
        }

        // and:
        // 4. The manager asynchronously performs a RETRY operation, triggered by the contributor that entered SUSPENDED

        // Allow the RETRY operation’s contributor detaches to complete
        for detachOperation in nonSuspendedContributorsDetachOperations {
            detachOperation.complete(behavior: .success) // So the CHA-RL5a RETRY detachment cycle succeeds
        }

        // Wait for the RETRY to finish
        let retryOperationTask = try #require(await managerStatusChangeSubscription.compactMap { statusChange in
            if case let .suspendedAwaitingStartOfRetryOperation(retryOperationTask, _) = statusChange.current {
                return retryOperationTask
            }
            return nil
        }
        .first { _ in
            true
        })

        await retryOperationTask.value

        // We confirm that a RETRY happened by checking for its expected side effects:
        #expect(await contributors[0].channel.detachCallCount == 0) // RETRY doesn’t touch this since it’s the one that triggered the RETRY
        #expect(await contributors[1].channel.detachCallCount == 1) // From the CHA-RL5a RETRY detachment cycle
        #expect(await contributors[2].channel.detachCallCount == 1) // From the CHA-RL5a RETRY detachment cycle

        #expect(await contributors[0].channel.attachCallCount == 2) // From the ATTACH operation and the CHA-RL5f RETRY attachment cycle
        #expect(await contributors[1].channel.attachCallCount == 1) // From the CHA-RL5f RETRY attachment cycle
        #expect(await contributors[2].channel.attachCallCount == 1) // From the CHA-RL5f RETRY attachment cycle

        _ = try #require(await roomStatusChangeSubscription.first { $0.current == .attached }) // Room status changes to ATTACHED
    }

    // @specOneOf(2/2) CHA-RL1h1 - tests that an error gets thrown when channel attach fails due to entering FAILED (TODO: but I don’t yet fully understand the meaning of CHA-RL1h1; outstanding question https://github.com/ably/specification/pull/200/files#r1765476610))
    // @spec CHA-RL1h4
    @Test
    func attach_whenContributorFailsToAttachAndEntersFailed_transitionsToFailed() async throws {
        // Given: A DefaultRoomLifecycleManager, one of whose contributors’ call to `attach` fails causing it to enter the FAILED state
        let contributorAttachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        let contributors = (1 ... 3).map { i in
            if i == 1 {
                createContributor(
                    feature: .messages, // arbitrary
                    attachBehavior: .completeAndChangeState(.failure(contributorAttachError), newState: .failed)
                )
            } else {
                createContributor(
                    feature: .occupancy, // arbitrary, just needs to be different to that used for the other contributor
                    attachBehavior: .success,
                    // The room is going to try to detach per CHA-RL1h5, so even though that's not what this test is testing, we need a detachBehavior so the mock doesn’t blow up
                    detachBehavior: .success
                )
            }
        }

        let manager = await createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeFailedStatusChange = statusChangeSubscription.failedElements().first { _ in true }

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let roomAttachResult: Void = manager.performAttachOperation()

        // Then:
        // 1. the room status transitions to FAILED, with the status change’s `error` having the AttachmentFailed code corresponding to the feature of the failed contributor, `cause` equal to the error thrown by the contributor `attach` call
        // 2. the manager’s `error` is set to this same error
        // 3. the room attach operation fails with this same error
        let failedStatusChange = try #require(await maybeFailedStatusChange)

        #expect(await manager.roomStatus.isFailed)

        var roomAttachError: Error?
        do {
            _ = try await roomAttachResult
        } catch {
            roomAttachError = error
        }

        for error in await [failedStatusChange.error, manager.roomStatus.error, roomAttachError] {
            #expect(isChatError(error, withCode: .messagesAttachmentFailed, cause: contributorAttachError))
        }
    }

    // @specPartial CHA-RL1h5 - My initial understanding of this spec point was that the "detach all non-failed channels" was meant to happen _inside_ the ATTACH operation, and that’s what I implemented. Andy subsequently updated the spec to clarify that it’s meant to happen _outside_ the ATTACH operation. I’ll implement this as a separate piece of work later (TODO: https://github.com/ably-labs/ably-chat-swift/issues/50)
    @Test
    func attach_whenAttachPutsChannelIntoFailedState_detachesAllNonFailedChannels() async throws {
        // Given: A room with the following contributors, in the following order:
        //
        // 0. a channel for whom calling `attach` will complete successfully, putting it in the ATTACHED state (i.e. an arbitrarily-chosen state that is not FAILED)
        // 1. a channel for whom calling `attach` will fail, putting it in the FAILED state
        // 2. a channel in the INITIALIZED state (another arbitrarily-chosen state that is not FAILED)
        //
        // for which, when `detach` is called on contributors 0 and 2 (i.e. the non-FAILED contributors), it completes successfully
        let contributors = [
            createContributor(
                attachBehavior: .completeAndChangeState(.success, newState: .attached),
                detachBehavior: .success
            ),
            createContributor(
                attachBehavior: .completeAndChangeState(.failure(.create(withCode: 123, message: "")), newState: .failed)
            ),
            createContributor(
                detachBehavior: .success
            ),
        ]

        let manager = await createManager(contributors: contributors)

        // When: `performAttachOperation()` is called on the lifecycle manager
        try? await manager.performAttachOperation()

        // Then:
        //
        // - the lifecycle manager will call `detach` on contributors 0 and 2
        // - the lifecycle manager will not call `detach` on contributor 1
        #expect(await contributors[0].channel.detachCallCount > 0)
        #expect(await contributors[2].channel.detachCallCount > 0)
        #expect(await contributors[1].channel.detachCallCount == 0)
    }

    // @spec CHA-RL1h6
    @Test
    func attach_whenChannelDetachTriggered_ifADetachFailsItIsRetriedUntilSuccess() async throws {
        // Given: A room with the following contributors, in the following order:
        //
        // 0. a channel:
        //     - for whom calling `attach` will complete successfully, putting it in the ATTACHED state (i.e. an arbitrarily-chosen state that is not FAILED)
        //     - and for whom subsequently calling `detach` will fail on the first attempt and succeed on the second
        // 1. a channel for whom calling `attach` will fail, putting it in the FAILED state (we won’t make any assertions about this channel; it’s just to trigger the room’s channel detach behaviour)

        let detachResult = { @Sendable (callCount: Int) async -> MockRoomLifecycleContributorChannel.AttachOrDetachBehavior in
            if callCount == 1 {
                return .failure(.create(withCode: 123, message: ""))
            } else {
                return .success
            }
        }

        let contributors = [
            createContributor(
                attachBehavior: .completeAndChangeState(.success, newState: .attached),
                detachBehavior: .fromFunction(detachResult)
            ),
            createContributor(
                attachBehavior: .completeAndChangeState(.failure(.create(withCode: 123, message: "")), newState: .failed)
            ),
        ]

        let manager = await createManager(contributors: contributors)

        // When: `performAttachOperation()` is called on the lifecycle manager
        try? await manager.performAttachOperation()

        // Then: the lifecycle manager will call `detach` twice on contributor 0 (i.e. it will retry the failed detach)
        #expect(await contributors[0].channel.detachCallCount == 2)
    }

    // MARK: - DETACH operation

    // @spec CHA-RL2a
    @Test
    func detach_whenAlreadyDetached() async throws {
        // Given: A DefaultRoomLifecycleManager in the DETACHED status
        let contributor = createContributor()
        let manager = await createManager(forTestingWhatHappensWhenCurrentlyIn: .detached, contributors: [contributor])

        // When: `performDetachOperation()` is called on the lifecycle manager
        try await manager.performDetachOperation()

        // Then: The room detach operation succeeds, and no attempt is made to detach a contributor (which we’ll consider as satisfying the spec’s requirement that a "no-op" happen)
        #expect(await contributor.channel.detachCallCount == 0)
    }

    // @spec CHA-RL2b
    @Test
    func detach_whenReleasing() async throws {
        // Given: A DefaultRoomLifecycleManager in the RELEASING status
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .releasing(releaseOperationID: UUID() /* arbitrary */ )
        )

        // When: `performDetachOperation()` is called on the lifecycle manager
        // Then: It throws a roomIsReleasing error
        await #expect {
            try await manager.performDetachOperation()
        } throws: { error in
            isChatError(error, withCode: .roomIsReleasing)
        }
    }

    // @spec CHA-RL2c
    @Test
    func detach_whenReleased() async throws {
        // Given: A DefaultRoomLifecycleManager in the RELEASED status
        let manager = await createManager(forTestingWhatHappensWhenCurrentlyIn: .released)

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomIsReleased error
        await #expect {
            try await manager.performDetachOperation()
        } throws: { error in
            isChatError(error, withCode: .roomIsReleased)
        }
    }

    // @spec CHA-RL2d
    @Test
    func detach_whenFailed() async throws {
        // Given: A DefaultRoomLifecycleManager in the FAILED status
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .failed(
                error: .createUnknownError() /* arbitrary */
            )
        )

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomInFailedState error
        await #expect {
            try await manager.performDetachOperation()
        } throws: { error in
            isChatError(error, withCode: .roomInFailedState)
        }
    }

    // @spec CHA-RL2e
    @Test
    func detach_transitionsToDetaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with a contributor on whom calling `detach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to DETACHED, so that we can assert its current status as being DETACHING)
        let contributorDetachOperation = SignallableChannelOperation()

        let contributor = createContributor(detachBehavior: contributorDetachOperation.behavior)

        let manager = await createManager(
            // We set a transient disconnect timeout, just so we can check that it gets cleared, as the spec point specifies
            forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs: [contributor.id],
            contributors: [contributor]
        )
        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performDetachOperation()` is called on the lifecycle manager
        async let _ = try await manager.performDetachOperation()

        // Then: It emits a status change to DETACHING, its current status is DETACHING, and it clears transient disconnect timeouts
        #expect(try #require(await statusChange).current == .detaching)
        #expect(await manager.roomStatus == .detaching)
        #expect(await !manager.testsOnly_hasTransientDisconnectTimeoutForAnyContributor)

        // Post-test: Now that we’ve seen the DETACHING status, allow the contributor `detach` call to complete
        contributorDetachOperation.complete(behavior: .success)
    }

    // @spec CHA-RL2f
    // @spec CHA-RL2g
    @Test
    func detach_detachesAllContributors_andWhenTheyAllDetachSuccessfully_transitionsToDetached() async throws {
        // Given: A DefaultRoomLifecycleManager, all of whose contributors’ calls to `detach` succeed
        let contributors = (1 ... 3).map { _ in createContributor(detachBehavior: .success) }
        let manager = await createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let detachedStatusChange = statusChangeSubscription.first { $0.current == .detached }

        // When: `performDetachOperation()` is called on the lifecycle manager
        try await manager.performDetachOperation()

        // Then: It calls `detach` on all the contributors, the room detach operation succeeds, it emits a status change to DETACHED, and its current status is DETACHED
        for contributor in contributors {
            #expect(await contributor.channel.detachCallCount > 0)
        }

        _ = try #require(await detachedStatusChange, "Expected status change to DETACHED")
        #expect(await manager.roomStatus == .detached)
    }

    // @spec CHA-RL2h1
    @Test
    func detach_whenAContributorFailsToDetachAndEntersFailed_detachesRemainingContributorsAndTransitionsToFailed() async throws {
        // Given: A DefaultRoomLifecycleManager, which has 4 contributors:
        //
        // 0: calling `detach` succeeds
        // 1: calling `detach` fails, causing that contributor to subsequently be in the FAILED state
        // 2: calling `detach` fails, causing that contributor to subsequently be in the FAILED state
        // 3: calling `detach` succeeds
        let contributor1DetachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        let contributor2DetachError = ARTErrorInfo(domain: "SomeDomain", code: 456)

        let contributors = [
            // Features arbitrarily chosen, just need to be distinct in order to make assertions about errors later
            createContributor(feature: .messages, detachBehavior: .success),
            createContributor(feature: .presence, detachBehavior: .completeAndChangeState(.failure(contributor1DetachError), newState: .failed)),
            createContributor(feature: .reactions, detachBehavior: .completeAndChangeState(.failure(contributor2DetachError), newState: .failed)),
            createContributor(feature: .typing, detachBehavior: .success),
        ]

        let manager = await createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeFailedStatusChange = statusChangeSubscription.failedElements().first { _ in true }

        // When: `performDetachOperation()` is called on the lifecycle manager
        let maybeRoomDetachError: Error?
        do {
            try await manager.performDetachOperation()
            maybeRoomDetachError = nil
        } catch {
            maybeRoomDetachError = error
        }

        // Then: It:
        // - calls `detach` on all of the contributors
        // - emits a status change to FAILED and the call to `performDetachOperation()` fails; the error associated with the status change and the `performDetachOperation()` has the *DetachmentFailed code corresponding to contributor 1’s feature, and its `cause` is contributor 1’s `errorReason` (contributor 1 because it’s the "first feature to fail" as the spec says)
        // TODO: Understand whether it’s `errorReason` or the contributor `detach` thrown error that’s meant to be use (outstanding question https://github.com/ably/specification/pull/200/files#r1763792152)
        for contributor in contributors {
            #expect(await contributor.channel.detachCallCount > 0)
        }

        let failedStatusChange = try #require(await maybeFailedStatusChange)

        for maybeError in [maybeRoomDetachError, failedStatusChange.error] {
            #expect(isChatError(maybeError, withCode: .presenceDetachmentFailed, cause: contributor1DetachError))
        }
    }

    // @specUntested CHA-RL2h2 - I was unable to find a way to test this spec point in an environment in which concurrency is being used; there is no obvious moment at which to stop observing the emitted status changes in order to be sure that FAILED has not been emitted twice.

    // @spec CHA-RL2h3
    @Test
    func detach_whenAContributorFailsToDetachAndEntersANonFailedState_pausesAWhileThenRetriesDetach() async throws {
        // Given: A DefaultRoomLifecycleManager, with a contributor for whom:
        //
        // - the first two times `detach` is called, it throws an error, leaving it in the ATTACHED state
        // - the third time `detach` is called, it succeeds
        let detachImpl = { @Sendable (callCount: Int) async -> MockRoomLifecycleContributorChannel.AttachOrDetachBehavior in
            if callCount < 3 {
                return .failure(ARTErrorInfo(domain: "SomeDomain", code: 123)) // exact error is unimportant
            }
            return .success
        }
        let contributor = createContributor(initialState: .attached, detachBehavior: .fromFunction(detachImpl))
        let clock = MockSimpleClock()

        let manager = await createManager(contributors: [contributor], clock: clock)

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let asyncLetStatusChanges = Array(statusChangeSubscription.prefix(2))

        // When: `performDetachOperation()` is called on the manager
        try await manager.performDetachOperation()

        // Then: It attempts to detach the channel 3 times, waiting 250ms between each attempt, the room transitions from DETACHING to DETACHED with no status updates in between, and the call to `performDetachOperation()` succeeds
        #expect(await contributor.channel.detachCallCount == 3)

        // We use "did it call clock.sleep(…)?" as a good-enough proxy for the question "did it wait for the right amount of time at the right moment?"
        #expect(await clock.sleepCallArguments == Array(repeating: 0.25, count: 2))

        #expect(await asyncLetStatusChanges.map(\.current) == [.detaching, .detached])
    }

    // MARK: - RELEASE operation

    // @spec CHA-RL3a
    @Test
    func release_whenAlreadyReleased() async {
        // Given: A DefaultRoomLifecycleManager in the RELEASED status
        let contributor = createContributor()
        let manager = await createManager(forTestingWhatHappensWhenCurrentlyIn: .released, contributors: [contributor])

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then: The room release operation succeeds, and no attempt is made to detach a contributor (which we’ll consider as satisfying the spec’s requirement that a "no-op" happen)
        #expect(await contributor.channel.detachCallCount == 0)
    }

    // @spec CHA-RL3b
    @Test
    func release_whenDetached() async throws {
        // Given: A DefaultRoomLifecycleManager in the DETACHED status
        let contributor = createContributor()
        let manager = await createManager(forTestingWhatHappensWhenCurrentlyIn: .detached, contributors: [contributor])

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then: The room release operation succeeds, the room transitions to RELEASED, and no attempt is made to detach a contributor (which we’ll consider as satisfying the spec’s requirement that the transition be "immediate")
        #expect(try #require(await statusChange).current == .released)
        #expect(await manager.roomStatus == .released)
        #expect(await contributor.channel.detachCallCount == 0)
    }

    // @spec CHA-RL3c
    @Test
    func release_whenReleasing() async throws {
        // Given: A DefaultRoomLifecycleManager with a RELEASE lifecycle operation in progress, and hence in the RELEASING status
        let contributorDetachOperation = SignallableChannelOperation()
        let contributor = createContributor(
            // This allows us to prolong the execution of the RELEASE triggered in (1)
            detachBehavior: contributorDetachOperation.behavior
        )
        let manager = await createManager(contributors: [contributor])

        let firstReleaseOperationID = UUID()
        let secondReleaseOperationID = UUID()

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        // Wait for the manager to enter RELEASING; this our sign that the DETACH operation triggered in (1) has started
        async let releasingStatusChange = statusChangeSubscription.first { $0.current == .releasing }

        // (1) This is the "RELEASE lifecycle operation in progress" mentioned in Given
        async let _ = manager.performReleaseOperation(testsOnly_forcingOperationID: firstReleaseOperationID)
        _ = await releasingStatusChange

        let operationWaitEventSubscription = await manager.testsOnly_subscribeToOperationWaitEvents()
        async let secondReleaseWaitingForFirstReleaseEvent = operationWaitEventSubscription.first { operationWaitEvent in
            operationWaitEvent == .init(waitingOperationID: secondReleaseOperationID, waitedOperationID: firstReleaseOperationID)
        }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        async let secondReleaseResult: Void = manager.performReleaseOperation(testsOnly_forcingOperationID: secondReleaseOperationID)

        // Then:
        // - the manager informs us that the second RELEASE operation is waiting for first RELEASE operation to complete
        // - when the first RELEASE completes, the second RELEASE operation also completes
        // - the second RELEASE operation does not perform any side-effects (which we check here by confirming that the CHA-RL3d contributor detach only happened once, i.e. was only performed by the first RELEASE operation)

        _ = try #require(await secondReleaseWaitingForFirstReleaseEvent)

        // Allow the first RELEASE to complete
        contributorDetachOperation.complete(behavior: .success)

        // Check that the second RELEASE completes
        await secondReleaseResult

        #expect(await contributor.channel.detachCallCount == 1)
    }

    // @spec CHA-RL3l
    @Test
    func release_transitionsToReleasing() async throws {
        // Given: A DefaultRoomLifecycleManager, with a contributor on whom calling `detach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to RELEASED, so that we can assert its current status as being RELEASING)
        let contributorDetachOperation = SignallableChannelOperation()

        let contributor = createContributor(detachBehavior: contributorDetachOperation.behavior)

        let manager = await createManager(
            // We set a transient disconnect timeout, just so we can check that it gets cleared, as the spec point specifies
            forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs: [contributor.id],
            contributors: [contributor]
        )
        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        async let _ = await manager.performReleaseOperation()

        // Then: It emits a status change to RELEASING, its current status is RELEASING, and it clears transient disconnect timeouts
        #expect(try #require(await statusChange).current == .releasing)
        #expect(await manager.roomStatus == .releasing)
        #expect(await !manager.testsOnly_hasTransientDisconnectTimeoutForAnyContributor)

        // Post-test: Now that we’ve seen the RELEASING status, allow the contributor `detach` call to complete
        contributorDetachOperation.complete(behavior: .success)
    }

    // @spec CHA-RL3d
    // @specOneOf(1/2) CHA-RL3e
    // @spec CHA-RL3g
    @Test
    func release_detachesAllNonFailedContributors() async throws {
        // Given: A DefaultRoomLifecycleManager, with the following contributors:
        // - two in a non-FAILED state, and on whom calling `detach()` succeeds
        // - one in the FAILED state
        let contributors = [
            createContributor(initialState: .attached /* arbitrary non-FAILED */, detachBehavior: .success),
            // We put the one that will be skipped in the middle, to verify that the subsequent contributors don’t get skipped
            createContributor(initialState: .failed, detachBehavior: .failure(.init(domain: "SomeDomain", code: 123) /* arbitrary error */ )),
            createContributor(initialState: .detached /* arbitrary non-FAILED */, detachBehavior: .success),
        ]

        let manager = await createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let releasedStatusChange = statusChangeSubscription.first { $0.current == .released }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then:
        // - it calls `detach()` on the non-FAILED contributors
        // - it does not call `detach()` on the FAILED contributor
        // - the room transitions to RELEASED
        // - the call to `performReleaseOperation()` completes
        for nonFailedContributor in [contributors[0], contributors[2]] {
            #expect(await nonFailedContributor.channel.detachCallCount == 1)
        }

        #expect(await contributors[1].channel.detachCallCount == 0)

        _ = await releasedStatusChange

        #expect(await manager.roomStatus == .released)
    }

    // @spec CHA-RL3f
    @Test
    func release_whenDetachFails_ifContributorIsNotFailed_retriesAfterPause() async {
        // Given: A DefaultRoomLifecycleManager, with a contributor for which:
        // - the first two times that `detach()` is called, it fails, leaving the contributor in a non-FAILED state
        // - the third time that `detach()` is called, it succeeds
        let detachImpl = { @Sendable (callCount: Int) async -> MockRoomLifecycleContributorChannel.AttachOrDetachBehavior in
            if callCount < 3 {
                return .failure(ARTErrorInfo(domain: "SomeDomain", code: 123)) // exact error is unimportant
            }
            return .success
        }
        let contributor = createContributor(detachBehavior: .fromFunction(detachImpl))

        let clock = MockSimpleClock()

        let manager = await createManager(contributors: [contributor], clock: clock)

        // Then: When `performReleaseOperation()` is called on the manager
        await manager.performReleaseOperation()

        // It: calls `detach()` on the channel 3 times, with a 0.25s pause between each attempt, and the call to `performReleaseOperation` completes
        #expect(await contributor.channel.detachCallCount == 3)

        // We use "did it call clock.sleep(…)?" as a good-enough proxy for the question "did it wait for the right amount of time at the right moment?"
        #expect(await clock.sleepCallArguments == Array(repeating: 0.25, count: 2))
    }

    // @specOneOf(2/2) CHA-RL3e - Tests that this spec point suppresses CHA-RL3f retries
    @Test
    func release_whenDetachFails_ifContributorIsFailed_doesNotRetry() async {
        // Given: A DefaultRoomLifecycleManager, with a contributor for which, when `detach()` is called, it fails, causing the contributor to enter the FAILED state
        let contributor = createContributor(detachBehavior: .completeAndChangeState(.failure(.init(domain: "SomeDomain", code: 123) /* arbitrary error */ ), newState: .failed))

        let clock = MockSimpleClock()

        let manager = await createManager(contributors: [contributor], clock: clock)

        let statusChangeSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let releasedStatusChange = statusChangeSubscription.first { $0.current == .released }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then:
        // - it calls `detach()` precisely once on the contributor (that is, it does not retry)
        // - it waits 0.25s (TODO: confirm my interpretation of CHA-RL3f, which is that the wait still happens, but is not followed by a retry; have asked in https://github.com/ably/specification/pull/200/files#r1765372854)
        // - the room transitions to RELEASED
        // - the call to `performReleaseOperation()` completes
        #expect(await contributor.channel.detachCallCount == 1)

        // We use "did it call clock.sleep(…)?" as a good-enough proxy for the question "did it wait for the right amount of time at the right moment?"
        #expect(await clock.sleepCallArguments == [0.25])

        _ = await releasedStatusChange

        #expect(await manager.roomStatus == .released)
    }

    // MARK: - RETRY operation

    // @specOneOf(1/2) CHA-RL5a
    @Test
    func retry_detachesAllContributorsExceptForTriggering() async throws {
        // Given: A RoomLifecycleManager
        let contributors = [
            createContributor(
                attachBehavior: .success, // Not related to this test, just so that the subsequent CHA-RL5f attachment cycle completes

                // Not related to this test, just so that the subsequent CHA-RL5d wait-for-ATTACHED completes
                subscribeToStateBehavior: .addSubscriptionAndEmitStateChange(
                    .init(
                        current: .attached,
                        previous: .attaching, // arbitrary
                        event: .attached,
                        reason: .createUnknownError() // Not related to this test, just to avoid a crash in CHA-RL4b1 handling of this state change
                    )
                )
            ),
            createContributor(
                attachBehavior: .success, // Not related to this test, just so that the subsequent CHA-RL5f attachment cycle completes
                detachBehavior: .success
            ),
            createContributor(
                attachBehavior: .success, // Not related to this test, just so that the subsequent CHA-RL5f attachment cycle completes
                detachBehavior: .success
            ),
        ]

        let manager = await createManager(contributors: contributors)

        // When: `performRetryOperation(triggeredByContributor:errorForSuspendedStatus:)` is called on the manager
        await manager.performRetryOperation(triggeredByContributor: contributors[0], errorForSuspendedStatus: .createUnknownError() /* arbitrary */ )

        // Then: The manager calls `detach` on all contributors except that which triggered the RETRY (I’m using this, combined with the CHA-RL5b and CHA-RL5c tests, as a good-enough way of checking that a CHA-RL2f detachment cycle happened)
        #expect(await contributors[0].channel.detachCallCount == 0)
        #expect(await contributors[1].channel.detachCallCount == 1)
        #expect(await contributors[2].channel.detachCallCount == 1)
    }

    // @specOneOf(2/2) CHA-RL5a - Verifies that, when the RETRY operation triggers a CHA-RL2f detachment cycle, the retry behaviour of CHA-RL2h3 is performed.
    @Test
    func retry_ifDetachFailsDueToNonFailedChannelState_retries() async throws {
        // Given: A RoomLifecycleManager, whose contributor at index 1 has an implementation of `detach()` which:
        // - throws an error and transitions the contributor to a non-FAILED state the first time it’s called
        // - succeeds the second time it’s called
        let detachImpl = { @Sendable (callCount: Int) -> MockRoomLifecycleContributorChannel.AttachOrDetachBehavior in
            if callCount == 1 {
                return .completeAndChangeState(.failure(.createUnknownError() /* arbitrary */ ), newState: .attached /* this is what CHA-RL2h3 mentions as being the only non-FAILED state that would happen in this situation in reality */ )
            } else {
                return .success
            }
        }

        let contributors = [
            createContributor(
                attachBehavior: .success, // Not related to this test, just so that the subsequent CHA-RL5f attachment cycle completes

                // Not related to this test, just so that the subsequent CHA-RL5d wait-for-ATTACHED completes
                subscribeToStateBehavior: .addSubscriptionAndEmitStateChange(
                    .init(
                        current: .attached,
                        previous: .attaching, // arbitrary
                        event: .attached,
                        reason: .createUnknownError() // Not related to this test, just to avoid a crash in CHA-RL4b1 handling of this state change
                    )
                )
            ),
            createContributor(
                attachBehavior: .success, // Not related to this test, just so that the subsequent CHA-RL5f attachment cycle completes
                detachBehavior: .fromFunction(detachImpl)
            ),
            createContributor(
                attachBehavior: .success, // Not related to this test, just so that the subsequent CHA-RL5f attachment cycle completes
                detachBehavior: .success
            ),
        ]

        let clock = MockSimpleClock()

        let manager = await createManager(contributors: contributors, clock: clock)

        // When: `performRetryOperation(triggeredByContributor:errorForSuspendedStatus:)` is called on the manager, triggered by a contributor that isn’t that at index 1
        await manager.performRetryOperation(triggeredByContributor: contributors[0], errorForSuspendedStatus: .createUnknownError() /* arbitrary */ )

        // Then: The manager calls `detach` in sequence on all contributors except that which triggered the RETRY, stopping upon one of these `detach` calls throwing an error, then sleeps for 250ms, then performs these `detach` calls again

        // (Note that for simplicity of the test I’m not actually making assertions about the sequence in which events happen here)
        #expect(await contributors[0].channel.detachCallCount == 0)
        #expect(await contributors[1].channel.detachCallCount == 2)
        #expect(await contributors[2].channel.detachCallCount == 1)
        #expect(await clock.sleepCallArguments == [0.25])
    }

    // @spec CHA-RL5c
    @Test
    func retry_ifDetachFailsDueToFailedChannelState_transitionsToFailed() async throws {
        // Given: A RoomLifecycleManager, whose contributor at index 1 has an implementation of `detach()` which throws an error and transitions the contributor to the FAILED state
        let contributor1DetachError = ARTErrorInfo.createUnknownError() // arbitrary

        let contributors = [
            // Features arbitrarily chosen, just need to be distinct in order to make assertions about errors later
            createContributor(feature: .messages),
            createContributor(
                feature: .presence,
                detachBehavior: .completeAndChangeState(.failure(contributor1DetachError), newState: .failed)
            ),
            createContributor(
                feature: .typing,
                detachBehavior: .success
            ),
        ]

        let manager = await createManager(contributors: contributors)

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeFailedStatusChange = roomStatusSubscription.failedElements().first { _ in true }

        // When: `performRetryOperation(triggeredByContributor:errorForSuspendedStatus:)` is called on the manager, triggered by the contributor at index 0
        await manager.performRetryOperation(triggeredByContributor: contributors[0], errorForSuspendedStatus: .createUnknownError() /* arbitrary */ )

        // Then:
        // 1. (This is basically just testing the behaviour of CHA-RL2h1 again, plus the fact that we don’t try to detach the channel that triggered the RETRY) The manager calls `detach` in sequence on all contributors except that which triggered the RETRY, and enters the FAILED status, the associated error for this status being the *DetachmentFailed code corresponding to contributor 1’s feature, and its `cause` is contributor 1’s `errorReason`
        // 2. the RETRY operation is terminated (which we confirm here by checking that it has not attempted to attach any of the contributors, which shows us that CHA-RL5f didn’t happen)
        #expect(await contributors[0].channel.detachCallCount == 0)
        #expect(await contributors[1].channel.detachCallCount == 1)
        #expect(await contributors[2].channel.detachCallCount == 1)

        let roomStatus = await manager.roomStatus
        let failedStatusChange = try #require(await maybeFailedStatusChange)

        #expect(roomStatus.isFailed)
        for error in [roomStatus.error, failedStatusChange.error] {
            #expect(isChatError(error, withCode: .presenceDetachmentFailed, cause: contributor1DetachError))
        }

        for contributor in contributors {
            #expect(await contributor.channel.attachCallCount == 0)
        }
    }

    // swiftlint:disable type_name
    /// Describes how a contributor will end up in one of the states that CHA-RL5d expects it to end up in.
    enum CHA_RL5d_JourneyToState {
        // swiftlint:enable type_name
        case transitionsToState
        case alreadyInState
    }

    // @spec CHA-RL5e
    @Test(arguments: [CHA_RL5d_JourneyToState.transitionsToState, .alreadyInState])
    func retry_whenTriggeringContributorEndsUpFailed_terminatesOperation(journeyToState: CHA_RL5d_JourneyToState) async throws {
        // Given: A RoomLifecycleManager, with a contributor that:
        // - (if test argument journeyToState is .transitionsToState) emits a state change to FAILED after subscribeToState() is called on it
        // - (if test argument journeyToState is .alreadyInState) is already FAILED (it would be more realistic for it to become FAILED _during_ the CHA-RL5a detachment cycle, but that would be more awkward to mock, so this will do)
        let contributorFailedReason = ARTErrorInfo.createUnknownError() // arbitrary

        let contributors = [
            createContributor(
                initialState: ({
                    switch journeyToState {
                    case .alreadyInState:
                        .failed
                    case .transitionsToState:
                        .suspended // arbitrary
                    }
                })(),
                initialErrorReason: ({
                    switch journeyToState {
                    case .alreadyInState:
                        contributorFailedReason
                    case .transitionsToState:
                        nil
                    }
                })(),

                detachBehavior: .success, // Not related to this test, just so that the CHA-RL5a detachment cycle completes

                subscribeToStateBehavior: ({
                    switch journeyToState {
                    case .alreadyInState:
                        return nil
                    case .transitionsToState:
                        let contributorFailedStateChange = ARTChannelStateChange(
                            current: .failed,
                            previous: .attaching, // arbitrary
                            event: .failed,
                            reason: contributorFailedReason
                        )

                        return .addSubscriptionAndEmitStateChange(contributorFailedStateChange)
                    }
                })()
            ),
            createContributor(
                detachBehavior: .success // Not related to this test, just so that the CHA-RL5a detachment cycle completes
            ),
        ]

        let manager = await createManager(
            contributors: contributors
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeFailedStatusChange = roomStatusSubscription.failedElements().first { _ in true }

        // When: `performRetryOperation(triggeredByContributor:errorForSuspendedStatus:)` is called on the manager, triggered by the aforementioned contributor
        await manager.performRetryOperation(triggeredByContributor: contributors[0], errorForSuspendedStatus: .createUnknownError() /* arbitrary */ )

        // Then:
        // 1. The room transitions to (and remains in) FAILED, and its error is:
        //    - (if test argument journeyToState is .transitionsToState) that associated with the contributor state change
        //    - (if test argument journeyToState is .alreadyInState) the channel’s `errorReason`
        // 2. The RETRY operation terminates (to confirm this, we check that the room has not attempted to attach any of the contributors, indicating that we have not proceeded to the CHA-RL5f attachment cycle)

        let failedStatusChange = try #require(await maybeFailedStatusChange)

        let roomStatus = await manager.roomStatus
        #expect(roomStatus.isFailed)

        for error in [failedStatusChange.error, roomStatus.error] {
            #expect(error === contributorFailedReason)
        }

        for contributor in contributors {
            #expect(await contributor.channel.attachCallCount == 0)
        }
    }

    // @specOneOf(1/3) CHA-RL5f - Tests the first part of CHA-RL5f, namely the transition to ATTACHING once the triggering channel becomes ATTACHED.
    @Test(arguments: [CHA_RL5d_JourneyToState.transitionsToState, .alreadyInState])
    func retry_whenTriggeringContributorEndsUpAttached_proceedsToAttachmentCycle(journeyToState: CHA_RL5d_JourneyToState) async throws {
        // Given: A RoomLifecycleManager, with a contributor that:
        // - (if test argument journeyToState is .transitionsToState) emits a state change to ATTACHED after subscribeToState() is called on it
        // - (if test argument journeyToState is .alreadyInState) is already ATTACHED (it would be more realistic for it to become ATTACHED _during_ the CHA-RL5a detachment cycle, but that would be more awkward to mock, so this will do)
        let contributors = [
            createContributor(
                initialState: ({
                    switch journeyToState {
                    case .alreadyInState:
                        .attached
                    case .transitionsToState:
                        .suspended // arbitrary
                    }
                })(),

                attachBehavior: .success, // Not related to this test, just so that the subsequent CHA-RL5f attachment cycle completes

                subscribeToStateBehavior: ({
                    switch journeyToState {
                    case .alreadyInState:
                        return nil
                    case .transitionsToState:
                        let contributorAttachedStateChange = ARTChannelStateChange(
                            current: .attached,
                            previous: .attaching, // arbitrary
                            event: .attached,
                            reason: .createUnknownError() // Not related to this test, just to avoid a crash in CHA-RL4b1 handling of this state change
                        )

                        return .addSubscriptionAndEmitStateChange(contributorAttachedStateChange)
                    }
                })()
            ),
            createContributor(
                attachBehavior: .success, // Not related to this test, just so that the subsequent CHA-RL5f attachment cycle completes
                detachBehavior: .success // Not related to this test, just so that the CHA-RL5a detachment cycle completes
            ),
        ]

        let manager = await createManager(
            contributors: contributors
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeAttachingStatusChange = roomStatusSubscription.attachingElements().first { _ in true }

        // When: `performRetryOperation(triggeredByContributor:errorForSuspendedStatus:)` is called on the manager, triggered by the aforementioned contributor
        await manager.performRetryOperation(triggeredByContributor: contributors[0], errorForSuspendedStatus: .createUnknownError() /* arbitrary */ )

        // Then: The room transitions to ATTACHING, and the RETRY operation continues (to confirm this, we check that the room has attempted to attach all of the contributors, indicating that we have proceeded to the CHA-RL5f attachment cycle)
        let attachingStatusChange = try #require(await maybeAttachingStatusChange)
        // The spec doesn’t mention an error for the ATTACHING status change, so I’ll assume there shouldn’t be one
        #expect(attachingStatusChange.error == nil)

        for contributor in contributors {
            #expect(await contributor.channel.attachCallCount == 1)
        }
    }

    // @specOneOf(2/3) CHA-RL5f - Tests the case where the CHA-RL1e attachment cycle succeeds
    @Test
    func retry_whenAttachmentCycleSucceeds() async throws {
        // Given: A RoomLifecycleManager, with contributors on all of whom calling `attach()` succeeds (i.e. conditions for a CHA-RL1e attachment cycle to succeed)
        let contributors = [
            createContributor(
                attachBehavior: .success,
                subscribeToStateBehavior: .addSubscriptionAndEmitStateChange(
                    .init(
                        current: .attached,
                        previous: .attaching, // arbitrary
                        event: .attached,
                        reason: .createUnknownError() // Not related to this test, just to avoid a crash in CHA-RL4b1 handling of this state change
                    )
                ) // Not related to this test, just so that the CHA-RL5d wait completes
            ),
            createContributor(
                attachBehavior: .success,
                detachBehavior: .success // Not related to this test, just so that the CHA-RL5a detachment cycle completes
            ),
            createContributor(
                attachBehavior: .success,
                detachBehavior: .success // Not related to this test, just so that the CHA-RL5a detachment cycle completes
            ),
        ]

        let manager = await createManager(
            contributors: contributors
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let attachedStatusChange = roomStatusSubscription.first { $0.current == .attached }

        // When: `performRetryOperation(triggeredByContributor:errorForSuspendedStatus:)` is called on the manager
        await manager.performRetryOperation(triggeredByContributor: contributors[0], errorForSuspendedStatus: .createUnknownError() /* arbitrary */ )

        // Then: The room performs a CHA-RL1e attachment cycle (we sufficiently satisfy ourselves of this fact by checking that it’s attempted to attach all of the channels), transitions to ATTACHED, and the RETRY operation completes
        for contributor in contributors {
            #expect(await contributor.channel.attachCallCount == 1)
        }

        _ = try #require(await attachedStatusChange)
        #expect(await manager.roomStatus == .attached)
    }

    // @specOneOf(3/3) CHA-RL5f - Tests the case where the CHA-RL1e attachment cycle fails
    @Test
    func retry_whenAttachmentCycleFails() async throws {
        // Given: A RoomLifecycleManager, with a contributor on whom calling `attach()` fails, putting the contributor into the FAILED state (i.e. conditions for a CHA-RL1e attachment cycle to fail)
        let contributorAttachError = ARTErrorInfo.createUnknownError() // arbitrary

        let contributors = [
            createContributor(
                attachBehavior: .success,
                detachBehavior: .success, // So that the detach performed by CHA-RL1h5’s rollback of the attachment cycle succeeds
                subscribeToStateBehavior: .addSubscriptionAndEmitStateChange(
                    .init(
                        current: .attached,
                        previous: .attaching, // arbitrary
                        event: .attached,
                        reason: .createUnknownError() // Not related to this test, just to avoid a crash in CHA-RL4b1 handling of this state change
                    )
                ) // Not related to this test, just so that the CHA-RL5d wait completes
            ),
            createContributor(
                attachBehavior: .completeAndChangeState(.failure(contributorAttachError), newState: .failed),
                detachBehavior: .success // Not related to this test, just so that the CHA-RL5a detachment cycle completes
            ),
            createContributor(
                attachBehavior: .success,
                detachBehavior: .success // So that the CHA-RL5a detachment cycle completes (not related to this test) and so that the detach performed by CHA-RL1h5’s rollback of the attachment cycle succeeds
            ),
        ]

        let manager = await createManager(
            contributors: contributors
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let failedStatusChange = roomStatusSubscription.failedElements().first { _ in true }

        // When: `performRetryOperation(triggeredByContributor:errorForSuspendedStatus:)` is called on the manager
        await manager.performRetryOperation(triggeredByContributor: contributors[0], errorForSuspendedStatus: .createUnknownError() /* arbitrary */ )

        // Then: The room performs a CHA-RL1e attachment cycle (we sufficiently satisfy ourselves of this fact by checking that it’s attempted to attach all of the channels up to and including the one for which attachment fails, and subsequently detached all channels except for the FAILED one), transitions to FAILED, and the RETRY operation completes
        #expect(await contributors[0].channel.attachCallCount == 1)
        #expect(await contributors[1].channel.attachCallCount == 1)
        #expect(await contributors[2].channel.attachCallCount == 0)

        #expect(await contributors[0].channel.detachCallCount == 1) // from CHA-RL1h5’s rollback of the attachment cycle
        #expect(await contributors[1].channel.detachCallCount == 1) // from CHA-RL5a detachment cycle
        #expect(await contributors[2].channel.detachCallCount == 2) // from CHA-RL5a detachment cycle and CHA-RL1h5’s rollback of the attachment cycle

        _ = try #require(await failedStatusChange)
        #expect(await manager.roomStatus.isFailed)
    }

    // MARK: - Handling contributor UPDATE events

    // @spec CHA-RL4a1
    @Test
    func contributorUpdate_withResumedTrue_doesNothing() async throws {
        // Given: A DefaultRoomLifecycleManager
        let contributor = createContributor()
        let manager = await createManager(contributors: [contributor])

        // When: A contributor emits an UPDATE event with `resumed` flag set to true
        let contributorStateChange = ARTChannelStateChange(
            current: .attached, // arbitrary
            previous: .attached, // arbitrary
            event: .update,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: true
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }

        // Then: The manager does not record a pending discontinuity event for this contributor, nor does it call `emitDiscontinuity` on the contributor (this is my interpretation of "no action should be taken" in CHA-RL4a1; i.e. that the actions described in CHA-RL4a2 and CHA-RL4a3 shouldn’t happen) (TODO: get clarification; have asked in https://github.com/ably/specification/pull/200#discussion_r1777385499)
        #expect(await manager.testsOnly_pendingDiscontinuityEvents(for: contributor).isEmpty)
        #expect(await contributor.emitDiscontinuityArguments.isEmpty)
    }

    // @spec CHA-RL4a3
    @Test
    func contributorUpdate_withResumedFalse_withOperationInProgress_recordsPendingDiscontinuityEvent() async throws {
        // Given: A DefaultRoomLifecycleManager, with a room lifecycle operation in progress
        let contributor = createContributor()
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attachingDueToAttachOperation(attachOperationID: UUID()), // case and ID arbitrary, just care that an operation is in progress
            contributors: [contributor]
        )

        // When: A contributor emits an UPDATE event with `resumed` flag set to false
        let contributorStateChange = ARTChannelStateChange(
            current: .attached, // arbitrary
            previous: .attached, // arbitrary
            event: .update,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: false
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }

        // Then: The manager records a pending discontinuity event for this contributor, and this discontinuity event has error equal to the contributor UPDATE event’s `reason`
        let pendingDiscontinuityEvents = await manager.testsOnly_pendingDiscontinuityEvents(for: contributor)
        try #require(pendingDiscontinuityEvents.count == 1)

        let pendingDiscontinuityEvent = pendingDiscontinuityEvents[0]
        #expect(pendingDiscontinuityEvent === contributorStateChange.reason)
    }

    // @spec CHA-RL4a4
    @Test
    func contributorUpdate_withResumedTrue_withNoOperationInProgress_emitsDiscontinuityEvent() async throws {
        // Given: A DefaultRoomLifecycleManager, with no room lifecycle operation in progress
        let contributor = createContributor()
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .initialized, // case arbitrary, just care that no operation is in progress
            contributors: [contributor]
        )

        // When: A contributor emits an UPDATE event with `resumed` flag set to false
        let contributorStateChange = ARTChannelStateChange(
            current: .attached, // arbitrary
            previous: .attached, // arbitrary
            event: .update,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: false
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }

        // Then: The manager calls `emitDiscontinuity` on the contributor, with error equal to the contributor UPDATE event’s `reason`
        let emitDiscontinuityArguments = await contributor.emitDiscontinuityArguments
        try #require(emitDiscontinuityArguments.count == 1)

        let discontinuity = emitDiscontinuityArguments[0]
        #expect(discontinuity === contributorStateChange.reason)
    }

    // @specOneOf(1/2) CHA-RL4b1 - Tests the case where the contributor has been attached previously
    @Test
    func contributorAttachEvent_withResumeFalse_withOperationInProgress_withContributorAttachedPreviously_recordsPendingDiscontinuityEvent() async throws {
        // Given: A DefaultRoomLifecycleManager, with a room lifecycle operation in progress, and which has a contributor for which a CHA-RL1f call to `attach()` has succeeded
        let contributorDetachOperation = SignallableChannelOperation()
        let contributor = createContributor(attachBehavior: .success, detachBehavior: contributorDetachOperation.behavior)
        let manager = await createManager(
            contributors: [contributor]
        )

        // This is to satisfy "a CHA-RL1f call to `attach()` has succeeded"
        try await manager.performAttachOperation()

        // This is to put the manager into the DETACHING state, to satisfy "with a room lifecycle operation in progress"
        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let _ = manager.performDetachOperation()
        _ = await roomStatusSubscription.first { $0.current == .detaching }

        // When: The aforementioned contributor emits an ATTACHED event with `resumed` flag set to false
        let contributorStateChange = ARTChannelStateChange(
            current: .attached,
            previous: .attaching, // arbitrary
            event: .attached,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: false
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }

        // Then: The manager records a pending discontinuity event for this contributor, and this discontinuity event has error equal to the contributor ATTACHED event’s `reason`
        let pendingDiscontinuityEvents = await manager.testsOnly_pendingDiscontinuityEvents(for: contributor)
        try #require(pendingDiscontinuityEvents.count == 1)

        let pendingDiscontinuityEvent = pendingDiscontinuityEvents[0]
        #expect(pendingDiscontinuityEvent === contributorStateChange.reason)

        // Teardown: Allow performDetachOperation() call to complete
        contributorDetachOperation.complete(behavior: .success)
    }

    // @specOneOf(2/2) CHA-RL4b1 - Tests the case where the contributor has not been attached previously
    @Test
    func contributorAttachEvent_withResumeFalse_withOperationInProgress_withContributorNotAttachedPreviously_doesNotRecordPendingDiscontinuityEvent() async throws {
        // Given: A DefaultRoomLifecycleManager, with a room lifecycle operation in progress, and which has a contributor for which a CHA-RL1f call to `attach()` has not previously succeeded
        let contributor = createContributor()
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attachingDueToAttachOperation(attachOperationID: UUID()), // case and ID arbitrary, just care that an operation is in progress
            contributors: [contributor]
        )

        // When: The aforementioned contributor emits an ATTACHED event with `resumed` flag set to false
        let contributorStateChange = ARTChannelStateChange(
            current: .attached,
            previous: .attaching, // arbitrary
            event: .attached,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: false
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }

        // Then: The manager does not record a pending discontinuity event for this contributor
        #expect(await manager.testsOnly_pendingDiscontinuityEvents(for: contributor).isEmpty)
    }

    // @spec CHA-RL4b5
    @Test
    func contributorFailedEvent_withNoOperationInProgress() async throws {
        // Given: A DefaultRoomLifecycleManager, with no room lifecycle operation in progress
        let contributors = [
            // TODO: The .success is currently arbitrary since the spec doesn’t say what to do if detach fails (have asked in https://github.com/ably/specification/pull/200#discussion_r1777471810)
            createContributor(detachBehavior: .success),
            createContributor(detachBehavior: .success),
            createContributor(detachBehavior: .success),
        ]
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .initialized, // case arbitrary, just care that no operation is in progress
            forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs: [
                // Give 2 of the 3 contributors a transient disconnect timeout, so we can test that _all_ such timeouts get cleared (as the spec point specifies), not just those for the FAILED contributor
                contributors[0].id,
                contributors[1].id,
            ],
            contributors: contributors
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let failedStatusChange = roomStatusSubscription.failedElements().first { _ in true }

        // When: A contributor emits an FAILED event
        let contributorStateChange = ARTChannelStateChange(
            current: .failed,
            previous: .attached, // arbitrary
            event: .failed,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: false // arbitrary
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributors[0].channel.emitStateChange(contributorStateChange)
        }

        // Then:
        // - the room status transitions to failed, with the error of the status change being the `reason` of the contributor FAILED event
        // - and it calls `detach` on all contributors
        // - it clears all transient disconnect timeouts
        _ = try #require(await failedStatusChange)
        #expect(await manager.roomStatus.isFailed)

        for contributor in contributors {
            #expect(await contributor.channel.detachCallCount == 1)
        }

        #expect(await !manager.testsOnly_hasTransientDisconnectTimeoutForAnyContributor)
    }

    // @spec CHA-RL4b6
    func contributorAttachingEvent_withNoOperationInProgress_withTransientDisconnectTimeout() async throws {
        // Given: A DefaultRoomLifecycleManager, with no operation in progress, with a transient disconnect timeout for the contributor mentioned in "When:"
        let contributor = createContributor()
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .initialized, // arbitrary no-operation-in-progress
            forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs: [contributor.id],
            contributors: [contributor]
        )

        let idOfExistingTransientDisconnectTimeout = try #require(await manager.testsOnly_idOfTransientDisconnectTimeout(for: contributor))

        // When: A contributor emits an ATTACHING event
        let contributorStateChange = ARTChannelStateChange(
            current: .attaching,
            previous: .detached, // arbitrary
            event: .attaching,
            reason: nil // arbitrary
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }

        // Then: It does not set a new transient disconnect timeout (this is my interpretation of CHA-RL4b6’s “no action is needed”, i.e. that the spec point intends to just be the contrapositive of CHA-RL4b7)
        #expect(await manager.testsOnly_idOfTransientDisconnectTimeout(for: contributor) == idOfExistingTransientDisconnectTimeout)
    }

    // @spec CHA-RL4b7
    @Test(
        arguments: [
            nil,
            ARTErrorInfo.create(withCode: 123, message: ""), // arbitrary non-nil
        ]
    )
    func contributorAttachingEvent_withNoOperationInProgress_withNoTransientDisconnectTimeout(contributorStateChangeReason: ARTErrorInfo?) async throws {
        // Given: A DefaultRoomLifecycleManager, with no operation in progress, with no transient disconnect timeout for the contributor mentioned in "When:"
        let contributor = createContributor()
        let sleepOperation = SignallableSleepOperation()
        let clock = MockSimpleClock(sleepBehavior: sleepOperation.behavior)
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .initialized, // arbitrary no-operation-in-progress
            contributors: [contributor],
            clock: clock
        )

        // When: (1) A contributor emits an ATTACHING event
        let contributorStateChange = ARTChannelStateChange(
            current: .attaching,
            previous: .detached, // arbitrary
            event: .attaching,
            reason: contributorStateChangeReason
        )

        async let maybeClockSleepArgument = clock.sleepCallArgumentsAsyncSequence.first { _ in true }

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }

        // Then: The manager records a 5 second transient disconnect timeout for this contributor
        #expect(try #require(await maybeClockSleepArgument) == 5)
        #expect(await manager.testsOnly_hasTransientDisconnectTimeout(for: contributor))

        // and When: This transient disconnect timeout completes

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeRoomAttachingStatusChange = roomStatusSubscription.attachingElements().first { _ in true }

        sleepOperation.complete()

        // Then:
        // 1. The room status transitions to ATTACHING, using the `reason` from the contributor ATTACHING change in (1)
        // 2. The manager no longer has a transient disconnect timeout for this contributor

        let roomAttachingStatusChange = try #require(await maybeRoomAttachingStatusChange)
        #expect(roomAttachingStatusChange.error == contributorStateChangeReason)

        #expect(await !manager.testsOnly_hasTransientDisconnectTimeout(for: contributor))
    }

    // @specOneOf(1/2) CHA-RL4b10
    @Test
    func contributorAttachedEvent_withNoOperationInProgress_clearsTransientDisconnectTimeouts() async throws {
        // Given: A DefaultRoomLifecycleManager, with no room lifecycle operation in progress
        let contributorThatWillEmitAttachedStateChange = createContributor()
        let contributors = [
            contributorThatWillEmitAttachedStateChange,
            createContributor(),
            createContributor(),
        ]
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .initialized, // case arbitrary, just care that no operation is in progress
            forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs: [
                // Give 2 of the 3 contributors a transient disconnect timeout, so we can test that only the timeout for the ATTACHED contributor gets cleared, not all of them
                contributorThatWillEmitAttachedStateChange.id,
                contributors[1].id,
            ],
            contributors: contributors
        )

        // When: A contributor emits a state change to ATTACHED
        let contributorAttachedStateChange = ARTChannelStateChange(
            current: .attached,
            previous: .attaching, // arbitrary
            event: .attached,
            reason: nil // arbitrary
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorAttachedStateChange) {
            await contributorThatWillEmitAttachedStateChange.channel.emitStateChange(contributorAttachedStateChange)
        }

        // Then: The manager clears any transient disconnect timeout for that contributor
        #expect(await !manager.testsOnly_hasTransientDisconnectTimeout(for: contributorThatWillEmitAttachedStateChange))
        // check the timeout for the other contributors didn’t get cleared
        #expect(await manager.testsOnly_hasTransientDisconnectTimeout(for: contributors[1]))
    }

    // @specOneOf(2/2) CHA-RL4b10 - This test is more elaborate than contributorAttachedEvent_withNoOperationInProgress_clearsTransientDisconnectTimeouts; instead of telling the manager to pretend that it has a transient disconnect timeout, we create a proper one by fulfilling the conditions of CHA-RL4b7, and we then fulfill the conditions of CHA-RL4b10 and check that the _side effects_ of the transient disconnect timeout (i.e. the state change) do not get performed. This is the _only_ test in which we go to these lengths to confirm that a transient disconnect timeout is truly cancelled; I think it’s enough to check it properly only once and then use simpler ways of checking it in other tests.
    @Test
    func contributorAttachedEvent_withNoOperationInProgress_clearsTransientDisconnectTimeouts_checkThatSideEffectsNotPerformed() async throws {
        // Given: A DefaultRoomLifecycleManager, with no operation in progress, with a transient disconnect timeout
        let contributor = createContributor()
        let sleepOperation = SignallableSleepOperation()
        let clock = MockSimpleClock(sleepBehavior: sleepOperation.behavior)
        let initialManagerStatus = DefaultRoomLifecycleManager<MockRoomLifecycleContributor>.Status.initialized // arbitrary no-operation-in-progress
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: initialManagerStatus,
            contributors: [contributor],
            clock: clock
        )
        let contributorStateChange = ARTChannelStateChange(
            current: .attaching,
            previous: .detached, // arbitrary
            event: .attaching,
            reason: nil // arbitrary
        )
        async let maybeClockSleepArgument = clock.sleepCallArgumentsAsyncSequence.first { _ in true }
        // We create a transient disconnect timeout by fulfilling the conditions of CHA-RL4b7
        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }
        try #require(await maybeClockSleepArgument != nil)

        let transientDisconnectTimeoutID = try #require(await manager.testsOnly_idOfTransientDisconnectTimeout(for: contributor))

        // When: A contributor emits a state change to ATTACHED, and we wait for the manager to inform us that any side effects that the transient disconnect timeout may cause have taken place
        let contributorAttachedStateChange = ARTChannelStateChange(
            current: .attached,
            previous: .attaching, // arbitrary
            event: .attached,
            reason: nil // arbitrary
        )

        await waitForManager(manager, toHandleTransientDisconnectTimeoutWithID: transientDisconnectTimeoutID) {
            await contributor.channel.emitStateChange(contributorAttachedStateChange)
        }

        // Then: The manager’s status remains unchanged. In particular, it has not changed to ATTACHING, meaning that the CHA-RL4b7 side effect has not happened and hence that the transient disconnect timeout was properly cancelled
        #expect(await manager.roomStatus == initialManagerStatus.toRoomStatus)
        #expect(await !manager.testsOnly_hasTransientDisconnectTimeoutForAnyContributor)
    }

    // @specOneOf(1/2) CHA-RL4b8
    @Test
    func contributorAttachedEvent_withNoOperationInProgress_roomNotAttached_allContributorsAttached() async throws {
        // Given: A DefaultRoomLifecycleManager, with no operation in progress and not in the ATTACHED status, all of whose contributors are in the ATTACHED state (to satisfy the condition of CHA-RL4b8; for the purposes of this test I don’t care that they’re in this state even _before_ the state change of the When)
        let contributors = [
            createContributor(initialState: .attached),
            createContributor(initialState: .attached),
        ]

        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .initialized, // arbitrary non-ATTACHED
            contributors: contributors
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeAttachedRoomStatusChange = roomStatusSubscription.first { $0.current == .attached }

        // When: A contributor emits a state change to ATTACHED
        let contributorStateChange = ARTChannelStateChange(
            current: .attached,
            previous: .attaching, // arbitrary
            event: .attached,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: false // arbitrary
        )

        await contributors[0].channel.emitStateChange(contributorStateChange)

        // Then: The room status transitions to ATTACHED
        _ = try #require(await maybeAttachedRoomStatusChange)
        #expect(await manager.roomStatus == .attached)
    }

    // @specOneOf(2/2) CHA-RL4b8 - Tests that the specified side effect doesn’t happen if part of the condition (i.e. all contributors now being ATTACHED) is not met
    @Test
    func contributorAttachedEvent_withNoOperationInProgress_roomNotAttached_notAllContributorsAttached() async throws {
        // Given: A DefaultRoomLifecycleManager, with no operation in progress and not in the ATTACHED status, one of whose contributors is not in the ATTACHED state state (to simulate the condition of CHA-RL4b8 not being met; for the purposes of this test I don’t care that they’re in this state even _before_ the state change of the When)
        let contributors = [
            createContributor(initialState: .attached),
            createContributor(initialState: .detached),
        ]

        let initialManagerStatus = DefaultRoomLifecycleManager<MockRoomLifecycleContributor>.Status.detached // arbitrary non-ATTACHED, no-operation-in-progress
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: initialManagerStatus,
            contributors: contributors
        )

        // When: A contributor emits a state change to ATTACHED
        let contributorStateChange = ARTChannelStateChange(
            current: .attached,
            previous: .attaching, // arbitrary
            event: .attached,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: false // arbitrary
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributors[0].channel.emitStateChange(contributorStateChange)
        }

        // Then: The room status does not change
        #expect(await manager.roomStatus == initialManagerStatus.toRoomStatus)
    }

    // @spec CHA-RL4b9
    @Test
    func contributorSuspendedEvent_withNoOperationInProgress() async throws {
        // Given: A DefaultRoomLifecycleManager with no lifecycle operation in progress
        let contributorThatWillEmitStateChange = createContributor(
            attachBehavior: .success, // So the CHA-RL5f RETRY attachment cycle succeeds

            // This is so that the RETRY operation’s wait-to-become-ATTACHED succeeds
            subscribeToStateBehavior: .addSubscriptionAndEmitStateChange(
                .init(
                    current: .attached,
                    previous: .detached, // arbitrary
                    event: .attached,
                    reason: .createUnknownError() // Not related to this test, just to avoid a crash in CHA-RL4b1 handling of this state change
                )
            )
        )

        var nonSuspendedContributorsDetachOperations: [SignallableChannelOperation] = []
        let contributors = [
            contributorThatWillEmitStateChange,
        ] + (1 ... 2).map { _ in
            // These contributors will be detached by the RETRY operation; we want to be able to delay their completion (and hence delay the RETRY operation’s transition from SUSPENDED to DETACHED) until we have been able to verify that the room’s status is SUSPENDED
            let detachOperation = SignallableChannelOperation()
            nonSuspendedContributorsDetachOperations.append(detachOperation)

            return createContributor(
                attachBehavior: .success, // So the CHA-RL5f RETRY attachment cycle succeeds
                detachBehavior: detachOperation.behavior
            )
        }

        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .initialized, // case arbitrary, just care that no operation is in progress
            // Give 2 of the 3 contributors a transient disconnect timeout, so we can test that _all_ such timeouts get cleared (as the spec point specifies), not just those for the SUSPENDED contributor
            forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs: [
                contributorThatWillEmitStateChange.id,
                contributors[1].id,
            ],
            contributors: contributors
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let maybeSuspendedRoomStatusChange = roomStatusSubscription.suspendedElements().first { _ in true }

        let managerStatusChangeSubscription = await manager.testsOnly_onStatusChange()

        // When: A contributor emits a state change to SUSPENDED
        let contributorStateChangeReason = ARTErrorInfo(domain: "SomeDomain", code: 123) // arbitrary
        let contributorStateChange = ARTChannelStateChange(
            current: .suspended,
            previous: .attached, // arbitrary
            event: .suspended,
            reason: contributorStateChangeReason,
            resumed: false // arbitrary
        )

        await waitForManager(manager, toHandleContributorStateChange: contributorStateChange) {
            await contributorThatWillEmitStateChange.channel.emitStateChange(contributorStateChange)
        }

        // Then:
        // 1. The room transitions to SUSPENDED, and this status change has error equal to the contributor state change’s `reason`
        // 2. All transient disconnect timeouts are cancelled
        let suspendedRoomStatusChange = try #require(await maybeSuspendedRoomStatusChange)
        #expect(suspendedRoomStatusChange.error === contributorStateChangeReason)

        #expect(await manager.roomStatus == .suspended(error: contributorStateChangeReason))

        #expect(await !manager.testsOnly_hasTransientDisconnectTimeoutForAnyContributor)

        // and:
        // 3. The manager performs a RETRY operation, triggered by the contributor that entered SUSPENDED

        // Allow the RETRY operation’s contributor detaches to complete
        for detachOperation in nonSuspendedContributorsDetachOperations {
            detachOperation.complete(behavior: .success) // So the CHA-RL5a RETRY detachment cycle succeeds
        }

        // Wait for the RETRY to finish
        let retryOperationTask = try #require(await managerStatusChangeSubscription.compactMap { statusChange in
            if case let .suspendedAwaitingStartOfRetryOperation(retryOperationTask, _) = statusChange.current {
                return retryOperationTask
            }
            return nil
        }
        .first { _ in
            true
        })

        await retryOperationTask.value

        // We confirm that a RETRY happened by checking for its expected side effects:
        #expect(await contributors[0].channel.detachCallCount == 0) // RETRY doesn’t touch this since it’s the one that triggered the RETRY
        #expect(await contributors[1].channel.detachCallCount == 1) // From the CHA-RL5a RETRY detachment cycle
        #expect(await contributors[2].channel.detachCallCount == 1) // From the CHA-RL5a RETRY detachment cycle

        #expect(await contributors[0].channel.attachCallCount == 1) // From the CHA-RL5f RETRY attachment cycle
        #expect(await contributors[1].channel.attachCallCount == 1) // From the CHA-RL5f RETRY attachment cycle
        #expect(await contributors[2].channel.attachCallCount == 1) // From the CHA-RL5f RETRY attachment cycle

        _ = try #require(await roomStatusSubscription.first { $0.current == .attached }) // Room status changes to ATTACHED
    }

    // MARK: - Waiting to be able to perform presence operations

    // @specOneOf(1/2) CHA-RL9a
    // @spec CHA-RL9b
    //
    // @specPartial CHA-PR3d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR10d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR6c - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-T2c - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenAttaching_whenTransitionsToAttached() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributorAttachOperation = SignallableChannelOperation()

        let contributor = createContributor(attachBehavior: contributorAttachOperation.behavior)

        let manager = await createManager(
            contributors: [contributor]
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = manager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = await roomStatusSubscription.attachingElements().first { _ in true }

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        let statusChangeWaitSubscription = await manager.testsOnly_subscribeToStatusChangeWaitEvents()
        async let waitToBeAbleToPerformPresenceOperationsResult: Void = manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )

        // Then: The manager waits for its room status to change
        _ = try #require(await statusChangeWaitSubscription.first { _ in true })

        // and When: The ATTACH operation succeeds, thus putting the room in the ATTACHED status
        contributorAttachOperation.complete(behavior: .success)

        // Then: The call to `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` succeeds
        try await waitToBeAbleToPerformPresenceOperationsResult
    }

    // @specOneOf(2/2) CHA-RL9a
    // @spec CHA-RL9c
    //
    // @specPartial CHA-PR3d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR10d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR6c - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-T2c - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenAttaching_whenTransitionsToNonAttachedStatus() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributorAttachOperation = SignallableChannelOperation()

        let contributor = createContributor(attachBehavior: contributorAttachOperation.behavior)

        let manager = await createManager(
            contributors: [contributor]
        )

        let roomStatusSubscription = await manager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = manager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = await roomStatusSubscription.attachingElements().first { _ in true }

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        let statusChangeWaitSubscription = await manager.testsOnly_subscribeToStatusChangeWaitEvents()
        async let waitToBeAbleToPerformPresenceOperationsResult: Void = manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )

        // Then: The manager waits for its room status to change
        _ = try #require(await statusChangeWaitSubscription.first { _ in true })

        // and When: The ATTACH operation fails, thus putting the room in the FAILED status (i.e. a non-ATTACHED status)
        let contributorAttachError = ARTErrorInfo.createUnknownError() // arbitrary
        contributorAttachOperation.complete(behavior: .completeAndChangeState(.failure(contributorAttachError), newState: .failed))

        // Then: The call to `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` fails with a `roomInInvalidState` error, whose cause is the error associated with the room status change
        var caughtError: Error?
        do {
            try await waitToBeAbleToPerformPresenceOperationsResult
        } catch {
            caughtError = error
        }

        let expectedCause = ARTErrorInfo(chatError: .attachmentFailed(feature: .messages, underlyingError: contributorAttachError)) // using our knowledge of CHA-RL1h4
        #expect(isChatError(caughtError, withCode: .roomInInvalidState, cause: expectedCause))
    }

    // @specPartial CHA-PR3e - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR10e - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR6d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-T2d - Tests the wait described in the spec point, but not that the feature actually performs this wait nor the side effect. TODO change this to a specOneOf once the feature is implemented
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenAttached() async throws {
        // Given: A DefaultRoomLifecycleManager in the ATTACHED status
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .attached
        )

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        // Then: It returns
        try await manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )
    }

    // @specPartial CHA-PR3f - Tests the wait described in the spec point, but not that the feature actually performs this wait. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR10f - Tests the wait described in the spec point, but not that the feature actually performs this wait. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR6e - Tests the wait described in the spec point, but not that the feature actually performs this wait. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-T2e - Tests the wait described in the spec point, but not that the feature actually performs this wait. TODO change this to a specOneOf once the feature is implemented
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenDetached() async throws {
        // Given: A DefaultRoomLifecycleManager in the DETACHED status
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .detached
        )

        // (Note: I wanted to use #expect(…, throws:) below, but for some reason it made the compiler _crash_! No idea why. So, gave up on that.)

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        var caughtError: ARTErrorInfo?
        do {
            try await manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )
        } catch {
            caughtError = error
        }

        // Then: It throws a presenceOperationRequiresRoomAttach error for that feature (which we just check via its error code, i.e. `.nonspecific`, and its message)
        #expect(isChatError(caughtError, withCode: .nonspecific, message: "To perform this messages operation, you must first attach the room."))
    }

    // @specPartial CHA-PR3f - Tests the wait described in the spec point, but not that the feature actually performs this wait. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR10f - Tests the wait described in the spec point, but not that the feature actually performs this wait. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-PR6e - Tests the wait described in the spec point, but not that the feature actually performs this wait. TODO change this to a specOneOf once the feature is implemented
    // @specPartial CHA-T2e - Tests the wait described in the spec point, but not that the feature actually performs this wait. TODO change this to a specOneOf once the feature is implemented
    @Test
    func waitToBeAbleToPerformPresenceOperations_whenAnyOtherStatus() async throws {
        // Given: A DefaultRoomLifecycleManager in a status other than ATTACHING, ATTACHED or DETACHED
        let manager = await createManager(
            forTestingWhatHappensWhenCurrentlyIn: .detaching(detachOperationID: .init()) // arbitrary given the above constraints
        )

        // (Note: I wanted to use #expect(…, throws:) below, but for some reason it made the compiler _crash_! No idea why. So, gave up on that.)

        // When: `waitToBeAbleToPerformPresenceOperations(requestedByFeature:)` is called on the lifecycle manager
        var caughtError: ARTErrorInfo?
        do {
            try await manager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .messages /* arbitrary */ )
        } catch {
            caughtError = error
        }

        // Then: It throws a presenceOperationDisallowedForCurrentRoomStatus error for that feature (which we just check via its error code, i.e. `.nonspecific`, and its message)
        #expect(isChatError(caughtError, withCode: .nonspecific, message: "This messages operation can not be performed given the current room status."))
    }
}
