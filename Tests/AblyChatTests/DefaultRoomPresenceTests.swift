import Ably
@testable import AblyChat
import Testing

struct DefaultRoomPresenceTests {
    // MARK: CHA-PR1

    // @spec CHA-PR1
    @Test
    func channelNameIsSetAsChatMessagesChannelName() async throws {
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let featureChannel = MockFeatureChannel(channel: channel)

        // When
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // Then
        #expect(defaultPresence.channel.name == "basketball::$chat::$chatMessages")
    }

    // MARK: CHA-PR3

    // @spec CHA-PR3a
    // @spec CHA-PR3e
    @Test
    func usersMayEnterPresence() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client2", logger: TestLogger())

        // When
        try await defaultPresence.enter(data: ["status": "Online"])

        // Then
        let presenceMembers = try await defaultPresence.get()
        #expect(presenceMembers.map(\.clientID).sorted() == ["client1", "client2"])
        let client2 = presenceMembers.filter { member in
            member.clientID == "client2" && member.data?.objectValue?["status"]?.stringValue == "Online"
        }
        #expect(client2 != nil)
    }

    // @specOneOf(1/2) CHA-PR3d
    @Test
    func usersMayEnterPresenceWhileAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .presence, attachBehavior: .completeAndChangeState(.success, newState: .attached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        let attachingStatusWaitSubscription = await lifecycleManager.testsOnly_subscribeToStatusChangeWaitEvents()

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And presence enter is called
        try await defaultPresence.enter()

        // Then: The manager was waiting for its room status to change before presence `enter` was called
        _ = try #require(await attachingStatusWaitSubscription.first { _ in true })
    }

    // @specOneOf(2/2) CHA-PR3d
    @Test
    func usersMayEnterPresenceWhileAttachingWithFailure() async throws {
        // Given: attachment failure
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)

        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .presence, attachBehavior: .completeAndChangeState(.failure(attachError), newState: .failed, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay)) // Without this delay most of the time attach fail happens before lifecycleManager has a chance to start waiting. I tried to use SignallableChannelOperation, but looks like `await #expect(...)` doesn't understand `let async x/try await x` syntax.
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

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
                try await defaultPresence.enter()
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

    // @spec CHA-PR3h
    @Test
    func failToEnterPresenceWhenRoomInInvalidState() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // Then
        await #expect(throws: ARTErrorInfo.self) {
            do {
                _ = try await defaultPresence.enter()
            } catch {
                let error = try #require(error as? ARTErrorInfo)
                #expect(error.statusCode == 400)
                #expect(error.localizedDescription.contains("attach"))
                throw error
            }
        }
    }

    // MARK: CHA-PR10

    // @spec CHA-PR10a
    // @spec CHA-PR10e
    @Test
    func usersMayUpdatePresence() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger())

        // When
        try await defaultPresence.update(data: ["status": "Online"])

        // Then
        let presenceMembers = try await defaultPresence.get()
        let client1 = presenceMembers.filter { member in
            member.clientID == "client1" && member.data?.objectValue?["status"]?.stringValue == "Online"
        }
        #expect(client1 != nil)
    }

    // @specOneOf(1/2) CHA-PR10d
    @Test
    func usersMayUpdatePresenceWhileAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .presence, attachBehavior: .completeAndChangeState(.success, newState: .attached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        let attachingStatusWaitSubscription = await lifecycleManager.testsOnly_subscribeToStatusChangeWaitEvents()

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And presence update is called
        try await defaultPresence.update()

        // Then: The manager was waiting for its room status to change before presence `update` was called
        _ = try #require(await attachingStatusWaitSubscription.first { _ in true })
    }

    // @specOneOf(2/2) CHA-PR10d
    @Test
    func usersMayUpdatePresenceWhileAttachingWithFailure() async throws {
        // Given: attachment failure
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)

        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .presence, attachBehavior: .completeAndChangeState(.failure(attachError), newState: .failed, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

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
                try await defaultPresence.update()
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

    // @spec CHA-PR10h
    @Test
    func failToUpdatePresenceWhenRoomInInvalidState() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // Then
        await #expect(throws: ARTErrorInfo.self) {
            do {
                _ = try await defaultPresence.update()
            } catch {
                let error = try #require(error as? ARTErrorInfo)
                #expect(error.statusCode == 400)
                #expect(error.localizedDescription.contains("attach"))
                throw error
            }
        }
    }

    // MARK: CHA-PR4

    // @spec CHA-PR4a
    @Test
    func usersMayLeavePresence() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "client1", logger: TestLogger())

        // When
        try await defaultPresence.leave()

        // Then
        let presenceMembers = try await defaultPresence.get()
        #expect(presenceMembers.isEmpty)
    }

    // MARK: CHA-PR5

    // @spec CHA-PR5
    @Test
    func ifUserIsPresent() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1", "client2"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(())) // CHA-PR6d
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // When
        let isUserPresent1 = try await defaultPresence.isUserPresent(clientID: "client2")
        let isUserPresent2 = try await defaultPresence.isUserPresent(clientID: "client3")

        // Then
        #expect(isUserPresent1 == true)
        #expect(isUserPresent2 == false)
    }

    // MARK: CHA-PR6

    // @spec CHA-PR6
    // @spec CHA-PR6d
    @Test
    func retrieveAllTheMembersOfThePresenceSet() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1", "client2"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .success(()))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // When
        let presenceMembers = try await defaultPresence.get()

        // Then
        #expect(presenceMembers.map(\.clientID).sorted() == ["client1", "client2"])
    }

    // @spec CHA-PR6h
    @Test
    func failToRetrieveAllTheMembersOfThePresenceSetWhenRoomInInvalidState() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1", "client2"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let featureChannel = MockFeatureChannel(channel: channel, resultOfWaitToBeAblePerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        // Then
        await #expect(throws: ARTErrorInfo.self) {
            do {
                _ = try await defaultPresence.get()
            } catch {
                let error = try #require(error as? ARTErrorInfo)
                #expect(error.statusCode == 400)
                #expect(error.localizedDescription.contains("attach"))
                throw error
            }
        }
    }

    // @specOneOf(1/2) CHA-PR6c
    @Test
    func retrieveAllTheMembersOfThePresenceSetWhileAttaching() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .presence, attachBehavior: .completeAndChangeState(.success, newState: .attached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

        let attachingStatusWaitSubscription = await lifecycleManager.testsOnly_subscribeToStatusChangeWaitEvents()

        // When: The room is in the attaching state
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)

        let attachOperationID = UUID()
        async let _ = lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: attachOperationID)

        // Wait for room to become ATTACHING
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: And presence get is called
        _ = try await defaultPresence.get()

        // Then: The manager was waiting for its room status to change before presence `get` was called
        _ = try #require(await attachingStatusWaitSubscription.first { _ in true })
    }

    // @specOneOf(2/2) CHA-PR6c
    @Test
    func retrieveAllTheMembersOfThePresenceSetWhileAttachingWithFailure() async throws {
        // Given: attachment failure
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)

        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .presence, attachBehavior: .completeAndChangeState(.failure(attachError), newState: .failed, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        // Given: A DefaultPresence with DefaultFeatureChannel and MockRoomLifecycleContributor
        let realtimePresence = MockRealtimePresence(members: ["client1"].map { .init(clientId: $0) })
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages", mockPresence: realtimePresence)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultPresence = await DefaultPresence(featureChannel: featureChannel, roomID: "basketball", clientID: "mockClientId", logger: TestLogger())

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
                _ = try await defaultPresence.get()
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

    // MARK: CHA-PR7

    // @spec CHA-PR7a
    // @spec CHA-PR7b
    @Test
    func usersMaySubscribeToAllPresenceEvents() async throws {
        // Given
        let realtimePresence = MockRealtimePresence(members: ["client1", "client2"].map { .init(clientId: $0) })
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
        let realtimePresence = MockRealtimePresence(members: [])
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
