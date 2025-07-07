import Ably
@testable import AblyChat
import Testing

struct DefaultPresenceTests {
    // MARK: CHA-PR3

    // @spec CHA-PR3a
    // @specOneOf(2/2) CHA-PR3e
    @Test
    func usersMayEnterPresence() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: MockRoomLifecycleManager(),
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // When
        try await defaultPresence.enter(data: ["status": "Online"])

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "enterClient(_:data:)",
            arguments: ["name": "client1", "data": JSONValue.object(["userCustomData": ["status": "Online"]])]
        )
        )
    }

    // @specOneOf(3/4) CHA-PR3d
    @Test
    func usersMayEnterPresenceWhileAttaching() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // When
        try await defaultPresence.enter()

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"]
        )
        )
    }

    // @specOneOf(4/4) CHA-PR3d
    @Test
    func usersMayEnterPresenceWhileAttachingWithFailure() async throws {
        // Given
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        let error = ARTErrorInfo(chatError: .roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            // When
            try await defaultPresence.enter()
        }
        await #expect {
            try await doIt()
        } /* Then */ throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError)
        }

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"]
        )
        )
    }

    // @specOneOf(2/2) CHA-PR3h
    @Test
    func failToEnterPresenceWhenRoomInInvalidState() async throws {
        // Given
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultPresence.enter()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400))
        }
    }

    // MARK: CHA-PR10

    // @spec CHA-PR10a
    // @specOneOf(2/2) CHA-PR10e
    @Test
    func usersMayUpdatePresence() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )
        // When
        try await defaultPresence.update(data: ["status": "Online"])

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "update(_:)",
            arguments: ["data": JSONValue.object(["userCustomData": ["status": "Online"]])]
        )
        )
    }

    // @specOneOf(3/4) CHA-PR10d
    @Test
    func usersMayUpdatePresenceWhileAttaching() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // When
        try await defaultPresence.update()

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"]
        )
        )
    }

    // @specOneOf(4/4) CHA-PR10d
    @Test
    func usersMayUpdatePresenceWhileAttachingWithFailure() async throws {
        // Given
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        let error = ARTErrorInfo(chatError: .roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            // When
            try await defaultPresence.update()
        }
        await #expect {
            try await doIt()
        } /* Then */ throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError)
        }

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"]
        )
        )
    }

    // @specOneOf(2/2) CHA-PR10h
    @Test
    func failToUpdatePresenceWhenRoomInInvalidState() async throws {
        // Given
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultPresence.update()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400))
        }
    }

    // MARK: CHA-PR4

    // @spec CHA-PR4a
    @Test
    func usersMayLeavePresence() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // When
        try await defaultPresence.leave()

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "leave(_:)",
            arguments: ["data": JSONValue.object([:])]
        )
        )
    }

    // MARK: CHA-PR5

    // @spec CHA-PR5
    @Test
    func ifUserIsPresent() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // When
        _ = try await defaultPresence.isUserPresent(clientID: "client1")

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "get(_:)",
            arguments: ["query": "\(ARTRealtimePresenceQuery(clientId: "client1", connectionId: "").callRecorderDescription)"]
        )
        )
    }

    // MARK: CHA-PR6

    // @spec CHA-PR6
    // @specOneOf(2/2) CHA-PR6d
    @Test
    func retrieveAllTheMembersOfThePresenceSet() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // When
        _ = try await defaultPresence.get()

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "get()",
            arguments: [:]
        )
        )
    }

    // @specOneOf(2/2) CHA-PR6h
    @Test
    func failToRetrieveAllTheMembersOfThePresenceSetWhenRoomInInvalidState() async throws {
        // Given
        let error = ARTErrorInfo(chatError: .presenceOperationRequiresRoomAttach(feature: .presence))
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultPresence.get()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400))
        }
    }

    // @specOneOf(3/4) CHA-PR6c
    @Test
    func retrieveAllTheMembersOfThePresenceSetWhileAttaching() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // When
        _ = try await defaultPresence.get()

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"]
        )
        )
    }

    // @specOneOf(4/4) CHA-PR6c
    @Test
    func retrieveAllTheMembersOfThePresenceSetWhileAttachingWithFailure() async throws {
        // Given
        let attachError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        let error = ARTErrorInfo(chatError: .roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            // When
            try await defaultPresence.get()
        }
        await #expect {
            try await doIt()
        } /* Then */ throws: { error in
            isChatError(error, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError)
        }

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"]
        )
        )
    }

    // MARK: CHA-PR7

    // @spec CHA-PR7a
    // @spec CHA-PR7b
    @Test
    func usersMaySubscribeToAllPresenceEvents() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            clientID: "client1",
            logger: logger,
            options: .init()
        )

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
}
