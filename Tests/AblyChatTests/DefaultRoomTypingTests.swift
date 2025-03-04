import Ably
@testable import AblyChat
import Testing

struct DefaultRoomTypingTests {
    // @spec CHA-T2
    // @spec CHA-T2d
    @Test
    func retrieveCurrentlyTypingClientIDs() async throws {
        // Given
        let typingPresence = MockRealtimePresence(members: ["client1", "client2"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$typingIndicators", mockPresence: typingPresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger(), timeout: 5)

        // When
        let typingInfo = try await defaultTyping.get()

        // Then
        #expect(typingInfo.sorted() == ["client1", "client2"])
    }

    // @specPartial CHA-T2c
    @Test
    func retrieveCurrentlyTypingClientIDsWhileAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .presence, attachBehavior: .completeAndChangeState(.success, newState: .attached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger(), timeout: 5)

        let attachingStatusWaitSubscription = await lifecycleManager.testsOnly_subscribeToStatusChangeWaitEvents()

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And presence get is called
        _ = try await defaultTyping.get()

        // Then: The manager was waiting for its room status to change before presence `get` was called
        _ = try #require(await attachingStatusWaitSubscription.first { _ in true })
    }

    // @specPartial CHA-T2c
    @Test
    func retrieveCurrentlyTypingClientIDsWhileAttachingWithFailure() async throws {
        // Given: attachment failure
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)

        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .presence, attachBehavior: .completeAndChangeState(.failure(attachError), newState: .failed, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(mockPresence: realtimePresence)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger(), timeout: 5)

        let attachingStatusWaitSubscription = await lifecycleManager.testsOnly_subscribeToStatusChangeWaitEvents()

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And fails to attach
        await #expect(throws: ARTErrorInfo.self) {
            do {
                _ = try await defaultTyping.get()
            } catch {
                // Then: An exception with status code of 500 should be thrown
                let error = try #require(error as? ARTErrorInfo)
                #expect(error.statusCode == 500)
                #expect(error.code == ErrorCode.roomInInvalidState.rawValue)
                throw error
            }
        }
        // Then: The manager were waiting for its room status to change from attaching
        _ = try #require(await attachingStatusWaitSubscription.first { _ in true })
    }

    // @spec CHA-T2g
    @Test
    func failToRetrieveCurrentlyTypingClientIDsWhenRoomInInvalidState() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1", "client2"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .failure(error))
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger(), timeout: 5)

        // Then
        await #expect(throws: ARTErrorInfo.self) {
            do {
                _ = try await defaultTyping.get()
            } catch {
                let error = try #require(error as? ARTErrorInfo)
                #expect(error.statusCode == 400)
                #expect(error.localizedDescription.contains("attach"))
                throw error
            }
        }
    }

    // @spec CHA-T3
    @Test
    func usersMayConfigureTimeoutForTyping() async throws {
        // Given
        let typingPresence = MockRealtimePresence(members: [])
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages", attachResult: .success),
            MockRealtimeChannel(name: "basketball::$chat::$typingIndicators", attachResult: .success, mockPresence: typingPresence),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        // Given
        let timeout = 0.5 // default is 5 (seconds)
        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(typing: .init(timeout: timeout)), logger: TestLogger(), lifecycleManagerFactory: DefaultRoomLifecycleManagerFactory())

        let defaultTyping = try #require(room.typing as? DefaultTyping)
        let typingStoppedSubscription = defaultTyping.testsOnly_subscribeToStopTestTypingEvents()

        try await room.attach()

        // When
        try await defaultTyping.start()
        let typingStartedAt = Date()

        // Then: The `DefaultTyping` will emit typing stop event in `timeout` interval +/-
        let typingStopped = try #require(await typingStoppedSubscription.first { _ in true })
        let interval = typingStartedAt.distance(to: typingStopped.timestamp)
        #expect(interval.isEqual(to: timeout, tolerance: 0.4)) // tolerance value is based on CI fails
    }

    // @spec CHA-T4a
    // @spec CHA-T4a1
    // @spec CHA-T5a
    // @spec CHA-T5b
    @Test
    func usersMayIndicateThatTheyHaveStartedOrStoppedTyping() async throws {
        // Given
        let typingPresence = MockRealtimePresence(members: [])
        let channel = MockRealtimeChannel(name: "basketball::$chat::$typingIndicators", mockPresence: typingPresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger(), timeout: 5)

        // CHA-T4a

        // When
        try await defaultTyping.start()

        // Then: CHA-T4a1
        var typingInfo = try await defaultTyping.get()
        #expect(typingInfo == ["client1"])

        // CHA-T5b

        // When
        try await defaultTyping.stop()

        // Then
        typingInfo = try await defaultTyping.get()
        #expect(typingInfo.isEmpty)

        // CHA-T5a

        // When
        try await defaultTyping.stop()

        // Then
        typingInfo = try await defaultTyping.get()
        #expect(typingInfo.isEmpty)
    }

    // @spec CHA-T4a2
    // @spec CHA-T4b
    @Test
    func ifTypingIsAlreadyInProgressThenTimeoutIsExtended() async throws {
        // Given
        let timeout = 0.5
        let typingPresence = MockRealtimePresence(members: [])
        let channel = MockRealtimeChannel(name: "basketball::$chat::$typingIndicators", mockPresence: typingPresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger(), timeout: timeout)

        let typingStartedSubscription = defaultTyping.testsOnly_subscribeToStartTestTypingEvents()
        let typingStoppedSubscription = defaultTyping.testsOnly_subscribeToStopTestTypingEvents()

        // When: Typing is already in progress, the CHA-T3 timeout is extended to be timeoutMs from now
        let timeoutExtension = 0.3
        try await defaultTyping.start()
        try? await Task.sleep(nanoseconds: UInt64(timeoutExtension * 1_000_000_000))
        try await defaultTyping.start() // CHA-T4b

        let typingStarted = try #require(await typingStartedSubscription.first { _ in true })
        let typingStopped = try #require(await typingStoppedSubscription.first { _ in true }) // CHA-T4a2

        // Then
        let interval = typingStarted.timestamp.distance(to: typingStopped.timestamp)
        #expect(interval.isEqual(to: timeout + timeoutExtension, tolerance: 0.4))
    }

    // @spec CHA-T6a
    @Test
    func usersMaySubscribeToTypingEvents() async throws {
        // Given
        let typingPresence = MockRealtimePresence(members: [])
        let channel = MockRealtimeChannel(name: "basketball::$chat::$typingIndicators", mockPresence: typingPresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger(), timeout: 5)

        // CHA-T6a

        // When
        let subscription = await defaultTyping.subscribe()
        try await defaultTyping.start()

        // Then
        let typingEvent = try #require(await subscription.first { _ in true })
        #expect(typingEvent.currentlyTyping == ["client1"])
    }

    // @spec CHA-T6c
    @Test
    func whenPresenceEventReceivedClientWillPerformPresenceGet() async throws {
        // Given
        let typingPresence = MockRealtimePresence(members: [])
        let channel = MockRealtimeChannel(name: "basketball::$chat::$typingIndicators", mockPresence: typingPresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger(), timeout: 0.1)

        // Given: subscription to typing events
        _ = await defaultTyping.subscribe()

        // Given: test presence.get() call subscription
        let typingPresenceGetSubscription = defaultTyping.testsOnly_subscribeToPresenceGetTypingEvents()

        // When: A presence event is received from the realtime client
        try await defaultTyping.start()

        // Then: The Chat client will perform a presence.get() operation
        _ = try #require(await typingPresenceGetSubscription.first { _ in true })
    }

    // @spec CHA-T6c1
    @Test
    func ifPresenceGetFailsItShallBeRetriedUsingBackoffWithJitter() async throws {
        // Given: presence.get() failure
        let presenceGetError = ARTErrorInfo(domain: "SomeDomain", code: 123)

        // Given
        let maxPresenceGetRetryDuration = 3.0 // arbitrary, TODO: improve https://github.com/ably/ably-chat-swift/issues/216
        let typingPresence = MockRealtimePresence(members: [], presenceGetError: presenceGetError)
        let channel = MockRealtimeChannel(name: "basketball::$chat::$typingIndicators", mockPresence: typingPresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger(), timeout: 0.1, maxPresenceGetRetryDuration: maxPresenceGetRetryDuration)

        // Given: subscription to typing events
        _ = await defaultTyping.subscribe()

        // Given: test presence.get() call failure subscription
        let typingPresenceGetRetrySubscription = defaultTyping.testsOnly_subscribeToPresenceGetRetryTypingEvents()

        // When: A presence event is received from the realtime client and presence.get() operation fails
        try await defaultTyping.start()

        // Then: It shall be retried using a backoff with jitter, up to a max timeout
        let retryStartedAt = Date()
        let retryShouldStopBefore = retryStartedAt + maxPresenceGetRetryDuration - 1 // TODO: improve
        for await event in typingPresenceGetRetrySubscription {
            print("Retrying presence.get() at \(event.timestamp)")
            if event.timestamp >= retryShouldStopBefore {
                break
            }
        }
        #expect(Date().distance(to: retryStartedAt) <= maxPresenceGetRetryDuration)
    }

    // @spec CHA-T6c2
    @Test
    func ifMultiplePresenceEventsReceivedThenOnlyTheLatestEventIsEmitted() async throws {
        // TODO: https://github.com/ably/ably-chat-swift/issues/216
    }

    // @spec CHA-T7
    @Test
    func onDiscontinuity() async throws {
        // Given
        let typingPresence = MockRealtimePresence(members: [])
        let channel = MockRealtimeChannel(mockPresence: typingPresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultTyping = DefaultTyping(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger(), timeout: 5)

        // When: The feature channel emits a discontinuity through `onDiscontinuity`
        let featureChannelDiscontinuity = DiscontinuityEvent(error: ARTErrorInfo.createUnknownError()) // arbitrary error
        let discontinuitySubscription = await defaultTyping.onDiscontinuity()
        await featureChannel.emitDiscontinuity(featureChannelDiscontinuity)

        // Then: The DefaultOccupancy instance emits this discontinuity through `onDiscontinuity`
        let discontinuity = try #require(await discontinuitySubscription.first { _ in true })
        #expect(discontinuity == featureChannelDiscontinuity)
    }
}
