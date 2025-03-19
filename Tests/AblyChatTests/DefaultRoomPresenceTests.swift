import Ably
@testable import AblyChat
import Testing

struct DefaultRoomPresenceTests {
    // MARK: CHA-PR3

    // @spec CHA-PR3a
    // @spec CHA-PR3e
    @Test
    func usersMayEnterPresence() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger())

        // When
        try await defaultPresence.enter(data: ["status": "Online"])

        // Then
        #expect(realtimePresence.callRecorder.hasRecord(
            matching: "\(#selector(MockRealtimePresence.enterClient(_:data:callback:)))",
            arguments: ["name": "client1", "data": ["status": "Online"].toAblyCocoaData()])
        )
    }

    // @specOneOf(1/2) CHA-PR3d
    @Test
    func usersMayEnterPresenceWhileAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let lifecycleManager = MockRoomLifecycleManager(resultOfWaitToBeAblePerformPresenceOperations: .success(()))

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let contributor = createMockContributor(feature: .presence, attachBehavior: .complete(.success))
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        async let _ = lifecycleManager.performAttachOperation()

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And presence enter is called
        try await defaultPresence.enter()

        // Then: The manager was waiting for its room status to change before presence `enter` was called
        await #expect(lifecycleManager.waitCallCount == 1)
    }

    // @specOneOf(2/2) CHA-PR3d
    @Test
    func usersMayEnterPresenceWhileAttachingWithFailure() async throws {
        // Given: attachment failure
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        // Since mocks raise only errors that are passed to them, pass CHA-RL9 error
        let error = ARTErrorInfo(chatError: .roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let lifecycleManager = MockRoomLifecycleManager(resultOfWaitToBeAblePerformPresenceOperations: .failure(error))

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let contributor = createMockContributor(feature: .presence, attachBehavior: .complete(.failure(error)))
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        async let _ = lifecycleManager.performAttachOperation()

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            try await defaultPresence.enter()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError)
        }

        // Then: The manager were waiting for its room status to change from attaching
        await #expect(lifecycleManager.waitCallCount == 1)
    }

    // @spec CHA-PR3h
    @Test
    func failToEnterPresenceWhenRoomInInvalidState() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultPresence.enter()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400), partialDescription: "attach")
        }
    }

    // MARK: CHA-PR10

    // @spec CHA-PR10a
    // @spec CHA-PR10e
    @Test
    func usersMayUpdatePresence() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger())

        // When
        try await defaultPresence.update(data: ["status": "Online"])

        // Then
        #expect(realtimePresence.callRecorder.hasRecord(
            matching: "\(#selector(MockRealtimePresence.update(_:callback:)))",
            arguments: ["data": ["status": "Online"].toAblyCocoaData()])
        )
    }

    // @specOneOf(1/2) CHA-PR10d
    @Test
    func usersMayUpdatePresenceWhileAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let lifecycleManager = MockRoomLifecycleManager(resultOfWaitToBeAblePerformPresenceOperations: .success(()))

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let contributor = createMockContributor(feature: .presence, attachBehavior: .complete(.success))
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        async let _ = lifecycleManager.performAttachOperation()

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And presence enter is called
        try await defaultPresence.update()

        // Then: The manager was waiting for its room status to change before presence `enter` was called
        await #expect(lifecycleManager.waitCallCount == 1)
    }

    // @specOneOf(2/2) CHA-PR10d
    @Test
    func usersMayUpdatePresenceWhileAttachingWithFailure() async throws {
        // Given: attachment failure
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        // Since mocks raise only errors that are passed to them, pass CHA-RL9 error
        let error = ARTErrorInfo(chatError: .roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let lifecycleManager = MockRoomLifecycleManager(resultOfWaitToBeAblePerformPresenceOperations: .failure(error))

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let contributor = createMockContributor(feature: .presence, attachBehavior: .complete(.failure(error)))
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        async let _ = lifecycleManager.performAttachOperation()

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And fails to attach
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            try await defaultPresence.update()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError)
        }
        // Then: The manager were waiting for its room status to change from attaching
        await #expect(lifecycleManager.waitCallCount == 1)
    }

    // @spec CHA-PR10h
    @Test
    func failToUpdatePresenceWhenRoomInInvalidState() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultPresence.update()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400), partialDescription: "attach")
        }
    }

    // MARK: CHA-PR4

    // @spec CHA-PR4a
    @Test
    func usersMayLeavePresence() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger())

        // When
        try await defaultPresence.leave()

        // Then
        #expect(realtimePresence.callRecorder.hasRecord(
            matching: "\(#selector(MockRealtimePresence.leave(_:callback:)))",
            arguments: ["data": [:]])
        )
    }

    // MARK: CHA-PR5

    // @spec CHA-PR5
    @Test
    func ifUserIsPresent() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(())) // CHA-PR6d
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger())

        // When
        _ = try await defaultPresence.isUserPresent(clientID: "client1")

        // Then
        #expect(realtimePresence.callRecorder.hasRecord(
            matching: "\(#selector(MockRealtimePresence.get(_:callback:)))",
            arguments: ["query": "\(ARTRealtimePresenceQuery(clientId: "client1", connectionId: ""))"])
        )
    }

    // MARK: CHA-PR6

    // @spec CHA-PR6
    // @spec CHA-PR6d
    @Test
    func retrieveAllTheMembersOfThePresenceSet() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger())

        // When
        _ = try await defaultPresence.get()

        // Then
        #expect(realtimePresence.callRecorder.hasRecord(
            matching: "\(#selector(MockRealtimePresence.get(_:)))",
            arguments: [:])
        )
    }

    // @spec CHA-PR6h
    @Test
    func failToRetrieveAllTheMembersOfThePresenceSetWhenRoomInInvalidState() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultPresence.get()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400), partialDescription: "attach")
        }
    }

    // @specOneOf(1/2) CHA-PR6c
    @Test
    func retrieveAllTheMembersOfThePresenceSetWhileAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let lifecycleManager = MockRoomLifecycleManager(resultOfWaitToBeAblePerformPresenceOperations: .success(()))

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let contributor = createMockContributor(feature: .presence, attachBehavior: .complete(.success))
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        async let _ = lifecycleManager.performAttachOperation()

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And presence enter is called
        _ = try await defaultPresence.get()

        // Then: The manager was waiting for its room status to change before presence `enter` was called
        await #expect(lifecycleManager.waitCallCount == 1)
    }

    // @specOneOf(2/2) CHA-PR6c
    @Test
    func retrieveAllTheMembersOfThePresenceSetWhileAttachingWithFailure() async throws {
        // Given: attachment failure
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        // Since mocks raise only errors that are passed to them, pass CHA-RL9 error
        let error = ARTErrorInfo(chatError: .roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let lifecycleManager = MockRoomLifecycleManager(resultOfWaitToBeAblePerformPresenceOperations: .failure(error))

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let contributor = createMockContributor(feature: .presence, attachBehavior: .complete(.failure(error)))
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        async let _ = lifecycleManager.performAttachOperation()

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And fails to attach
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultPresence.get()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError)
        }
        // Then: The manager were waiting for its room status to change from attaching
        await #expect(lifecycleManager.waitCallCount == 1)
    }

    // MARK: CHA-PR7

    // @spec CHA-PR7a
    // @spec CHA-PR7b
    @Test
    func usersMaySubscribeToAllPresenceEvents() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(())) // CHA-PR6d
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // Given
        let subscription = await defaultPresence.subscribe(events: .all) // CHA-PR7a and CHA-PR7b since `all` is just a selection of all events

        // When
        subscription.emit(PresenceEvent(action: .present, clientID: "client1", timestamp: Date(), data: nil))

        // Then
        let presentEvent = try #require(await subscription.first { _ in true })
        #expect(presentEvent.action == .present)
        #expect(presentEvent.clientID == "client1")

        // When
        subscription.emit(PresenceEvent(action: .enter, clientID: "client1", timestamp: Date(), data: nil))

        // Then
        let enterEvent = try #require(await subscription.first { _ in true })
        #expect(enterEvent.action == .enter)
        #expect(enterEvent.clientID == "client1")

        // When
        subscription.emit(PresenceEvent(action: .update, clientID: "client1", timestamp: Date(), data: nil))

        // Then
        let updateEvent = try #require(await subscription.first { _ in true })
        #expect(updateEvent.action == .update)
        #expect(updateEvent.clientID == "client1")

        // When
        subscription.emit(PresenceEvent(action: .leave, clientID: "client1", timestamp: Date(), data: nil))

        // Then
        let leaveEvent = try #require(await subscription.first { _ in true })
        #expect(leaveEvent.action == .leave)
        #expect(leaveEvent.clientID == "client1")
    }

    // MARK: CHA-PR8

    // @spec CHA-PR8
    @Test
    func onDiscontinuity() async throws {
        // Given
        let realtimePresence = MockRealtimePresence()
        let channel = MockRealtimeChannel(mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger())

        // When: The feature channel emits a discontinuity through `onDiscontinuity`
        let featureChannelDiscontinuity = DiscontinuityEvent(error: ARTErrorInfo.createUnknownError()) // arbitrary error
        let discontinuitySubscription = await defaultPresence.onDiscontinuity()
        await featureChannel.emitDiscontinuity(featureChannelDiscontinuity)

        // Then: The DefaultOccupancy instance emits this discontinuity through `onDiscontinuity`
        let discontinuity = try #require(await discontinuitySubscription.first { _ in true })
        #expect(discontinuity == featureChannelDiscontinuity)
    }
}
