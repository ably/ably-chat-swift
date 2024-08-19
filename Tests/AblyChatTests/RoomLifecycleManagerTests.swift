import Ably
@testable import AblyChat
import XCTest

// TODO: note that this function can't be called multiple times
// TODO: document and see whether this is a good function
private func makeAsyncFunction() -> (returnFromFunction: @Sendable (MockRoomLifecycleContributorChannel.AttachOrDetachResult) -> Void, function: @Sendable (Int) async -> MockRoomLifecycleContributorChannel.AttachOrDetachResult) {
    let (stream, continuation) = AsyncStream.makeStream(of: MockRoomLifecycleContributorChannel.AttachOrDetachResult.self)
    return (
        returnFromFunction: { result in
            continuation.yield(result)
        },
        function: { _ in
            await (stream.first { _ in true })!
        }
    )
}

private func createManager(contributors: [RoomLifecycleManager<MockRoomLifecycleContributorChannel>.Contributor] = [], clock: SimpleClock = MockSimpleClock()) -> RoomLifecycleManager<MockRoomLifecycleContributorChannel> {
    .init(contributors: contributors, logger: TestLogger(), clock: clock)
}

private func createManager(forTestingWhatHappensWhenCurrentlyIn current: RoomLifecycle, contributors: [RoomLifecycleManager<MockRoomLifecycleContributorChannel>.Contributor] = [], clock: SimpleClock = MockSimpleClock()) -> RoomLifecycleManager<MockRoomLifecycleContributorChannel> {
    .init(forTestingWhatHappensWhenCurrentlyIn: current, contributors: contributors, logger: TestLogger(), clock: clock)
}

private func createContributor(
    initialState: ARTRealtimeChannelState = .initialized,
    feature: RoomFeature = .messages, // Arbitrarily chosen, its value only matters in test cases where we check which error is thrown
    attachBehavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior? = nil,
    detachBehavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior? = nil
) -> RoomLifecycleManager<MockRoomLifecycleContributorChannel>.Contributor {
    .init(feature: feature, channel: .init(initialState: initialState, attachBehavior: attachBehavior, detachBehavior: detachBehavior))
}

final class RoomLifecycleManagerTests: XCTestCase {
    // @spec CHA-RS2a (TODO what's the best way to test this)
    // @spec CHA-RS3
    func test_current_startsAsInitialized() async {
        let manager = createManager()

        let current = await manager.current
        XCTAssertEqual(current, .initialized)
    }

    func test_error_startsAsNil() async {
        let manager = createManager()
        let error = await manager.error
        XCTAssertNil(error)
    }

    // MARK: - ATTACH operation

    // @spec CHA-RL1a
    func test_attach_whenAlreadyAttached() async throws {
        // Given: A RoomLifecycleManager in the ATTACHED state
        let contributor = createContributor()
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .attached, contributors: [contributor])

        // When: `performAttachOperation()` is called on the lifecycle manager
        try await manager.performAttachOperation()

        // Then: The room attach operation succeeds, and no attempt is made to attach a contributor (which we’ll consider as satisfying the spec’s requirement that a "no-op" happen)
        let attachCallCount = await contributor.channel.attachCallCount
        XCTAssertEqual(attachCallCount, 0)
    }

    // @spec CHA-RL1b
    func test_attach_whenReleasing() async throws {
        // Given: A RoomLifecycleManager in the RELEASING state
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .releasing)

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomIsReleasing error
        try await assertThrowsARTErrorInfo(withCode: .roomIsReleasing) {
            try await manager.performAttachOperation()
        }
    }

    // @spec CHA-RL1c
    func test_attach_whenReleased() async throws {
        // Given: A RoomLifecycleManager in the RELEASED state
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .released)

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomIsReleased error
        try await assertThrowsARTErrorInfo(withCode: .roomIsReleased) {
            try await manager.performAttachOperation()
        }
    }

    // @spec CHA-RL1e
    func test_attach_transitionsToAttaching() async throws {
        // Given: A RoomLifecycleManager, with a contributor on whom calling `attach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to ATTACHED, so that we can assert its current state as being ATTACHING)
        let (returnAttachResult, attachResult) = makeAsyncFunction()

        let manager = createManager(contributors: [createContributor(attachBehavior: .fromFunction(attachResult))])
        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let _ = try await manager.performAttachOperation()

        // Then: It emits a status change to ATTACHING, and its current state is ATTACHING
        guard let statusChange = await statusChange else {
            XCTFail("Expected status change but didn’t get one")
            return
        }
        XCTAssertEqual(statusChange.current, .attaching)

        let current = await manager.current
        XCTAssertEqual(current, .attaching)

        // Post-test: Now that we’ve seen the ATTACHING state, allow the contributor `attach` call to complete
        returnAttachResult(.success)
    }

    // @spec CHA-RL1f, CHA-RL1g
    func test_attach_attachesAllContributors_andWhenTheyAllAttachSuccessfully_transitionsToAttached() async throws {
        // Given: A RoomLifecycleManager, all of whose contributors’ calls to `attach` succeed
        let contributors = (1 ... 3).map { _ in createContributor(attachBehavior: .complete(.success)) }
        let manager = createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let attachedStatusChange = statusChangeSubscription.first { $0.current == .attached }

        // When: `performAttachOperation()` is called on the lifecycle manager
        try await manager.performAttachOperation()

        // Then: It calls `attach` on all the contributors, the room attach operation succeeds, it emits a status change to ATTACHED, and its current state is ATTACHED
        for contributor in contributors {
            let attachCallCount = await contributor.channel.attachCallCount
            XCTAssertGreaterThan(attachCallCount, 0)
        }

        guard let statusChange = await attachedStatusChange else {
            XCTFail("Expected status change to ATTACHED but didn't get one")
            return
        }

        XCTAssertEqual(statusChange.current, .attached)

        let current = await manager.current
        XCTAssertEqual(current, .attached)
    }

    // @spec CHA-RL1h2
    // @specpartial CHA-RL1h1 - tests that an error gets thrown when channel attach fails due to entering SUSPENDED
    // @specpartial CHA-RL1h3 - tests which error gets thrown when room enters SUSPENDED
    func test_attach_whenContributorFailsToAttachAndEntersSuspended_transitionsToSuspended() async throws {
        // Given: A RoomLifecycleManager, one of whose contributors’ call to `attach` fails causing it to enter the SUSPENDED state
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        let contributors = (1 ... 3).map { i in
            if i == 1 {
                createContributor(attachBehavior: .completeAndChangeState(.failure(attachError), newState: .suspended))
            } else {
                createContributor(attachBehavior: .complete(.success))
            }
        }

        let manager = createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let suspendedStatusChange = statusChangeSubscription.first { $0.current == .suspended }

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let roomAttachResult: Void = manager.performAttachOperation()

        // Then:
        //
        // 1. the room status transitions to SUSPENDED, with the state change’s `error` having `cause` equal to the channel’s `errorReason`
        // 2. the room status’s `error` is set to this same error
        // TODO: Andy has updated CHA-RL1h3; they're meant to be the same error now
        // 3. the room attach operation fails with the channel’s `errorReason`
        guard let suspendedStatusChange = await suspendedStatusChange else {
            XCTFail("Expected status change to SUSPENDED but didn’t get one")
            return
        }

        XCTAssertEqual(suspendedStatusChange.error?.cause, attachError)

        let (current, error) = await (manager.current, manager.error)
        XCTAssertEqual(current, .suspended)
        XCTAssertEqual(error?.cause, attachError)

        var roomAttachError: Error?
        do {
            _ = try await roomAttachResult
        } catch {
            roomAttachError = error
        }

        let roomAttachARTErrorInfo = try XCTUnwrap(roomAttachError as? ARTErrorInfo)
        XCTAssertEqual(roomAttachARTErrorInfo, attachError)
    }

    // @specpartial CHA-RL1h1 - tests that an error gets thrown when channel attach fails due to entering FAILED, but that spec point isn’t clear about what error should be thrown
    // @spec CHA-RL1h4
    func test_attach_whenContributorFailsToAttachAndEntersFailed_transitionsToFailed() async throws {
        // Given: A RoomLifecycleManager, one of whose contributors’ call to `attach` fails causing it to enter the FAILED state
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        let contributors = (1 ... 3).map { i in
            if i == 1 {
                createContributor(
                    attachBehavior: .completeAndChangeState(.failure(attachError), newState: .failed)
                )
            } else {
                createContributor(
                    attachBehavior: .complete(.success),
                    // The room is going to try to detach per CHA-RL1h6, so even though that's not what this test is testing, we need a detachBehavior so the mock doesn’t blow up
                    detachBehavior: .complete(.success)
                )
            }
        }

        let manager = createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let failedStatusChange = statusChangeSubscription.first { $0.current == .failed }

        // When: `performAttachOperation()` is called on the lifecycle manager
        async let roomAttachResult: Void = manager.performAttachOperation()

        // Then:
        // 1. the room status transitions to FAILED, with the state change’s `error` having `cause` equal to the channel’s `errorReason`
        // 2. the room status’s `error` is set to this same error
        // 3. the room attach operation fails with this same error
        guard let failedStatusChange = await failedStatusChange else {
            XCTFail("Expected status change to FAILED but didn’t get one")
            return
        }

        XCTAssertEqual(failedStatusChange.error?.cause, attachError)

        let (current, error) = await (manager.current, manager.error)
        XCTAssertEqual(current, .failed)
        XCTAssertEqual(error?.cause, attachError)

        var roomAttachError: Error?
        do {
            _ = try await roomAttachResult
        } catch {
            roomAttachError = error
        }

        let roomAttachARTErrorInfo = try XCTUnwrap(roomAttachError as? ARTErrorInfo)
        XCTAssertEqual(roomAttachARTErrorInfo, attachError)
    }

    // @spec CHA-RL1h5
    func test_attach_whenAttachPutsChannelIntoFailedState_detachesAllNonFailedChannels() async throws {
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
                detachBehavior: .complete(.success)
            ),
            createContributor(
                attachBehavior: .completeAndChangeState(.failure(.create(withCode: 123, message: "")), newState: .failed)
            ),
            createContributor(
                detachBehavior: .complete(.success)
            ),
        ]

        let manager = createManager(contributors: contributors)

        // When: `performAttachOperation()` is called on the lifecycle manager
        try? await manager.performAttachOperation()

        // Then:
        //
        // - the lifecycle manager will call `detach` on contributors 0 and 2
        // - the lifecycle manager will not call `detach` on contributor 1
        //
        // (TODO Note that we aren’t testing that the room _waits_ for the detach calls to complete, because I didn’t think of a good way)
        let contributor0DetachCallCount = await contributors[0].channel.detachCallCount
        XCTAssertGreaterThan(contributor0DetachCallCount, 0)
        let contributor2DetachCallCount = await contributors[2].channel.detachCallCount
        XCTAssertGreaterThan(contributor2DetachCallCount, 0)
        let contributor1DetachCallCount = await contributors[1].channel.detachCallCount
        XCTAssertEqual(contributor1DetachCallCount, 0)
    }

    // @spec CHA-RL1h6
    // TODO: Andy has changed the wording of CHA-RL1h6, it no longer refers to the room status so change this test name
    func test_attach_whenAttachPutsRoomIntoFailedState_ifADetachFailsItIsRetriedUntilSuccess() async throws {
        // Given: A room with the following contributors, in the following order:
        //
        // 0. a channel:
        //     - for whom calling `attach` will complete successfully, putting it in the ATTACHED state (i.e. an arbitrarily-chosen state that is not FAILED)
        //     - and for whom subsequently calling `detach` will fail on the first attempt and succeed on the second
        // 1. a channel for whom calling `attach` will fail, putting it in the FAILED state (we won’t make any assertions about this channel; it’s just to trigger the room’s channel detach behaviour)

        let detachResult = { @Sendable (callCount: Int) async -> MockRoomLifecycleContributorChannel.AttachOrDetachResult in
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

        let manager = createManager(contributors: contributors)

        // When: `performAttachOperation()` is called on the lifecycle manager
        try? await manager.performAttachOperation()

        // Then: the lifecycle manager will call `detach` twice on contributor 0 (i.e. it will retry the failed detach)
        let detachCallCount = await contributors[0].channel.detachCallCount
        XCTAssertEqual(detachCallCount, 2)
    }

    // MARK: - DETACH operation

    // @spec CHA-RL2a
    func test_detach_whenAlreadyDetached() async throws {
        // Given: A RoomLifecycleManager in the DETACHED state
        let contributor = createContributor()
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .detached, contributors: [contributor])

        // When: `performDetachOperation()` is called on the lifecycle manager
        try await manager.performDetachOperation()

        // Then: The room detach operation succeeds, and no attempt is made to detach a contributor (which we’ll consider as satisfying the spec’s requirement that a "no-op" happen)
        let detachCallCount = await contributor.channel.detachCallCount
        XCTAssertEqual(detachCallCount, 0)
    }

    // @spec CHA-RL2b
    func test_detach_whenReleasing() async throws {
        // Given: A RoomLifecycleManager in the RELEASING state
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .releasing)

        // When: `performDetachOperation()` is called on the lifecycle manager
        // Then: It throws a roomIsReleasing error
        try await assertThrowsARTErrorInfo(withCode: .roomIsReleasing) {
            try await manager.performDetachOperation()
        }
    }

    // @spec CHA-RL2c
    func test_detach_whenReleased() async throws {
        // Given: A RoomLifecycleManager in the RELEASED state
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .released)

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomIsReleased error
        try await assertThrowsARTErrorInfo(withCode: .roomIsReleased) {
            try await manager.performDetachOperation()
        }
    }

    // @spec CHA-RL2c
    func test_detach_whenFailed() async throws {
        // Given: A RoomLifecycleManager in the FAILED state
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .failed)

        // When: `performAttachOperation()` is called on the lifecycle manager
        // Then: It throws a roomInFailedState error
        try await assertThrowsARTErrorInfo(withCode: .roomInFailedState) {
            try await manager.performDetachOperation()
        }
    }

    // @specpartial CHA-RL2e - TODO I don't know what the "transient disconnect timeouts" means yet
    func test_detach_transitionsToDetaching() async throws {
        // Given: A RoomLifecycleManager, with a contributor on whom calling `detach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to DETACHED, so that we can assert its current state as being DETACHING)
        let (returnDetachResult, detachResult) = makeAsyncFunction()

        let manager = createManager(contributors: [createContributor(detachBehavior: .fromFunction(detachResult))])
        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performDetachOperation()` is called on the lifecycle manager
        async let _ = try await manager.performDetachOperation()

        // Then: It emits a status change to DETACHING, and its current state is DETACHING
        guard let statusChange = await statusChange else {
            XCTFail("Expected status change but didn’t get one")
            return
        }
        XCTAssertEqual(statusChange.current, .detaching)

        let current = await manager.current
        XCTAssertEqual(current, .detaching)

        // Post-test: Now that we’ve seen the DETACHING state, allow the contributor `detach` call to complete
        returnDetachResult(.success)
    }

    // @spec CHA-RL2f, CHA-RL2g
    func test_detach_detachesAllContributors_andWhenTheyAllDetachSuccessfully_transitionsToDetached() async throws {
        // Given: A RoomLifecycleManager, all of whose contributors’ calls to `detach` succeed
        let contributors = (1 ... 3).map { _ in createContributor(detachBehavior: .complete(.success)) }
        let manager = createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let detachedStatusChange = statusChangeSubscription.first { $0.current == .detached }

        // When: `performDetachOperation()` is called on the lifecycle manager
        try await manager.performDetachOperation()

        // Then: It calls `detach` on all the contributors, the room detach operation succeeds, it emits a status change to DETACHED, and its current state is DETACHED
        for contributor in contributors {
            let detachCallCount = await contributor.channel.detachCallCount
            XCTAssertGreaterThan(detachCallCount, 0)
        }

        guard let statusChange = await detachedStatusChange else {
            XCTFail("Expected status change to DETACHED but didn't get one")
            return
        }

        XCTAssertEqual(statusChange.current, .detached)

        let current = await manager.current
        XCTAssertEqual(current, .detached)
    }

    // @spec CHA-RL2h1
    func test_detach_whenAContributorFailsToDetachAndEntersFailed_detachesRemainingContributorsAndTransitionsToFailed() async throws {
        // Given: A RoomLifecycleManager, which has 4 contributors:
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

        let manager = createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let failedStatusChange = statusChangeSubscription.first { $0.current == .failed }

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
        // - emits a state change to FAILED and the call to `performDetachOperation()` fails; the error associated with the state change and the `performDetachOperation()` has the *DetachmentFailed code corresponding to contributor 1’s feature, and its `cause` is contributor 1’s `errorReason` (contributor 1 because it’s the "first feature to fail" as the spec says)
        for contributor in contributors {
            let detachCallCount = await contributor.channel.detachCallCount
            XCTAssertGreaterThan(detachCallCount, 0)
        }

        guard let failedStateChange = await failedStatusChange else {
            XCTFail("Expected state change to FAILED")
            return
        }

        for maybeError in [maybeRoomDetachError, failedStateChange.error] {
            try assertIsChatError(maybeError, withCode: .presenceDetachmentFailed, cause: contributor1DetachError)
        }
    }

    // @spec CHA-RL2h3
    func test_detach_whenAContributorFailsToDetachAndEntersANonFailedState_pausesAWhileThenRetriesDetach() async throws {
        // Given: A RoomLifecycleManager, with a contributor for whom:
        //
        // - the first two times `detach` is called, it throws an error, leaving it in the ATTACHED state
        // - the third time `detach` is called, it succeeds
        let detachImpl = { @Sendable (callCount: Int) async -> MockRoomLifecycleContributorChannel.AttachOrDetachResult in
            if callCount < 3 {
                return .failure(ARTErrorInfo(domain: "SomeDomain", code: 123)) // exact error is unimportant
            }
            return .success
        }
        let contributor = createContributor(initialState: .attached, detachBehavior: .fromFunction(detachImpl))
        let clock = MockSimpleClock()

        let manager = createManager(contributors: [contributor], clock: clock)

        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let asyncLetStatusChanges = Array(statusChangeSubscription.prefix(2))

        // When: `performDetachOperation()` is called on the manager
        // TODO: why does this need to capture the error? we just want it to succeed. check elsewhere for this pattern
        let roomDetachError: Error?
        do {
            try await manager.performDetachOperation()
            roomDetachError = nil
        } catch {
            roomDetachError = error
        }

        // Then: It attempts to detach the channel 3 times, waiting 1s between each attempt, the room transitions from DETACHING to DETACHED with no status updates in between, and the call to `performDetachOperation()` succeeds
        let detachCallCount = await contributor.channel.detachCallCount
        XCTAssertEqual(detachCallCount, 3)

        // We use "did it call clock.sleep(…)?" as a good-enough proxy for the question "did it wait for the right amount of time at the right moment?"
        let clockSleepArguments = await clock.sleepCallArguments
        XCTAssertEqual(clockSleepArguments, Array(repeating: 1_000_000_000, count: 2))

        let statusChanges = await asyncLetStatusChanges
        XCTAssertEqual(statusChanges.map(\.current), [.detaching, .detached])

        XCTAssertNil(roomDetachError)
    }

    // MARK: - RELEASE operation

    // @spec CHA-RL3a
    func test_release_whenAlreadyReleased() async {
        // Given: A RoomLifecycleManager in the RELEASED state
        let contributor = createContributor()
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .released, contributors: [contributor])

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then: The room release operation succeeds, and no attempt is made to detach a contributor (which we’ll consider as satisfying the spec’s requirement that a "no-op" happen)
        let detachCallCount = await contributor.channel.detachCallCount
        XCTAssertEqual(detachCallCount, 0)
    }

    // @spec CHA-RL3b
    func test_release_whenDetached() async {
        // Given: A RoomLifecycleManager in the DETACHED state
        let contributor = createContributor()
        let manager = createManager(forTestingWhatHappensWhenCurrentlyIn: .detached, contributors: [contributor])

        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then: The room release operation succeeds, the room transitions to RELEASED, and no attempt is made to detach a contributor (which we’ll consider as satisfying the spec’s requirement that the transition be "immediate")
        guard let statusChange = await statusChange else {
            XCTFail("Expected status change")
            return
        }

        XCTAssertEqual(statusChange.current, .released)

        let current = await manager.current
        XCTAssertEqual(current, .released)

        let detachCallCount = await contributor.channel.detachCallCount
        XCTAssertEqual(detachCallCount, 0)
    }

    // @specpartial CHA-RL3c - TODO I don't know what the "transient disconnect timeouts" means yet
    func test_release_transitionsToReleasing() async {
        // Given: A RoomLifecycleManager, with a contributor on whom calling `detach()` will not complete until after the "Then" part of this test (the motivation for this is to suppress the room from transitioning to RELEASED, so that we can assert its current state as being RELEASING)
        let (returnDetachResult, detachResult) = makeAsyncFunction()

        let manager = createManager(contributors: [createContributor(detachBehavior: .fromFunction(detachResult))])
        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let statusChange = statusChangeSubscription.first { _ in true }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        async let _ = await manager.performReleaseOperation()

        // Then: It emits a status change to RELEASING, and its current state is RELEASING
        guard let statusChange = await statusChange else {
            XCTFail("Expected status change but didn’t get one")
            return
        }
        XCTAssertEqual(statusChange.current, .releasing)

        let current = await manager.current
        XCTAssertEqual(current, .releasing)

        // Post-test: Now that we’ve seen the RELEASING state, allow the contributor `detach` call to complete
        returnDetachResult(.success)
    }

    // @spec CHA-RL3d, CHA-RL3e, CHA-RL3g
    func test_release_detachesAllNonFailedContributors() async throws {
        // Given: A RoomLifecycleManager, with the following contributors:
        // - two in a non-FAILED state, and on whom calling `detach()` succeeds
        // - one in the FAILED state
        let contributors = [
            createContributor(initialState: .attached /* arbitrary non-FAILED */, detachBehavior: .complete(.success)),
            createContributor(initialState: .failed, detachBehavior: .complete(.failure(.init(domain: "SomeDomain", code: 123) /* arbitrary error */ ))),
            createContributor(initialState: .detached /* arbitrary non-FAILED */, detachBehavior: .complete(.success)),
        ]

        let manager = createManager(contributors: contributors)

        let statusChangeSubscription = await manager.onChange(bufferingPolicy: .unbounded)
        async let releasedStatusChange = statusChangeSubscription.first { $0.current == .released }

        // When: `performReleaseOperation()` is called on the lifecycle manager
        await manager.performReleaseOperation()

        // Then:
        // - it calls `detach()` on the non-FAILED contributors
        // - it does not call `detach()` on the FAILED contributor
        // - the room transitions to RELEASED
        // - the call to `performReleaseOperation()` completes
        for nonFailedContributor in [contributors[0], contributors[2]] {
            let detachCallCount = await nonFailedContributor.channel.detachCallCount
            XCTAssertEqual(detachCallCount, 1)
        }

        let failedContributorDetachCallCount = await contributors[1].channel.detachCallCount
        XCTAssertEqual(failedContributorDetachCallCount, 0)

        _ = await releasedStatusChange

        let current = await manager.current
        XCTAssertEqual(current, .released)
    }

    // TODO: check CHA-RL3e for CHA-RL3f retries

    // @spec CHA-RL3f
    func test_release_whenDetachFails_ifContributorIsNotFailed_retriesAfterPause() async {
        // Given: A RoomLifecycleManager, with a contributor for which:
        // - the first two times that `detach()` is called, it fails, leaving the contributor into a non-FAILED state
        // - the third time that `detach()` is called, it succeeds
        let detachImpl = { @Sendable (callCount: Int) async -> MockRoomLifecycleContributorChannel.AttachOrDetachResult in
            if callCount < 3 {
                return .failure(ARTErrorInfo(domain: "SomeDomain", code: 123)) // exact error is unimportant
            }
            return .success
        }
        let contributor = createContributor(detachBehavior: .fromFunction(detachImpl))

        let clock = MockSimpleClock()

        let manager = createManager(contributors: [contributor], clock: clock)

        // Then: When `performReleaseOperation()` is called on the manager
        await manager.performReleaseOperation()

        // It: calls `detach()` on the channel 3 times, with a 0.5s pause between each attempt, and the call to `performReleaseOperation` completes
        let detachCallCount = await contributor.channel.detachCallCount
        XCTAssertEqual(detachCallCount, 3)

        // We use "did it call clock.sleep(…)?" as a good-enough proxy for the question "did it wait for the right amount of time at the right moment?"
        let clockSleepArguments = await clock.sleepCallArguments
        XCTAssertEqual(clockSleepArguments, Array(repeating: 1_000_000_000, count: 2))
    }
}
