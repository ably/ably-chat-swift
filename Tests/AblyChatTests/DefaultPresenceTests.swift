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
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: MockRoomLifecycleManager(),
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // When
        try await defaultPresence.enter(withData: ["status": "Online"])

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "enter(_:)",
            arguments: ["data": ["status": JSONValue.string("Online")]],
        ))
    }

    // @spec CHA-PR3a
    @Test
    func usersMayEnterPresenceWithoutData() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: MockRoomLifecycleManager(),
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // When
        try await defaultPresence.enter()

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "enter(_:)",
            arguments: ["data": nil],
        ))
    }

    // @specOneOf(3/4) CHA-PR3d
    @Test
    func usersMayEnterPresenceWhileAttaching() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // When
        try await defaultPresence.enter()

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"],
        ))
    }

    // @specOneOf(4/4) CHA-PR3d
    @Test
    func usersMayEnterPresenceWhileAttachingWithFailure() async throws {
        // Given
        let attachError = ErrorInfo.createArbitraryError()
        let error = InternalError.internallyThrown(.roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        let thrownError = await #expect(throws: (any Error).self) {
            // When
            try await defaultPresence.enter()
        }
        // Then
        #expect(isChatError(thrownError, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError))

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"],
        ))
    }

    // @specOneOf(2/2) CHA-PR3h
    @Test
    func failToEnterPresenceWhenRoomInInvalidState() async throws {
        // Given
        let error = InternalError.internallyThrown(.presenceOperationRequiresRoomAttach(feature: .presence))
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // Then
        let thrownError = await #expect(throws: (any Error).self) {
            _ = try await defaultPresence.enter()
        }
        #expect(isChatError(thrownError, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400)))
    }

    // MARK: CHA-PR10

    // @spec CHA-PR10a
    // @specOneOf(2/2) CHA-PR10e
    @Test
    func usersMayUpdatePresence() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )
        // When
        try await defaultPresence.update(withData: ["status": "Online"])

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "update(_:)",
            arguments: ["data": ["status": JSONValue.string("Online")]],
        ))
    }

    // @specOneOf(3/4) CHA-PR10d
    @Test
    func usersMayUpdatePresenceWhileAttaching() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // When
        try await defaultPresence.update()

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"],
        ))
    }

    // @specOneOf(4/4) CHA-PR10d
    @Test
    func usersMayUpdatePresenceWhileAttachingWithFailure() async throws {
        // Given
        let attachError = ErrorInfo.createArbitraryError()
        let error = InternalError.internallyThrown(.roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        let thrownError = await #expect(throws: (any Error).self) {
            // When
            try await defaultPresence.update()
        }
        // Then
        #expect(isChatError(thrownError, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError))

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"],
        ))
    }

    // @specOneOf(2/2) CHA-PR10h
    @Test
    func failToUpdatePresenceWhenRoomInInvalidState() async throws {
        // Given
        let error = InternalError.internallyThrown(.presenceOperationRequiresRoomAttach(feature: .presence))
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // Then
        let thrownError = await #expect(throws: (any Error).self) {
            _ = try await defaultPresence.update()
        }
        #expect(isChatError(thrownError, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400)))
    }

    // MARK: CHA-PR4

    // @spec CHA-PR4a
    @Test
    func usersMayLeavePresence() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // When
        try await defaultPresence.leave(withData: ["status": "Online"])

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "leave(_:)",
            arguments: ["data": ["status": JSONValue.string("Online")]],
        ))
    }

    // MARK: CHA-PR5

    // @spec CHA-PR5
    @Test
    func ifUserIsPresent() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // When
        _ = try await defaultPresence.isUserPresent(withClientID: "client1")

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "get(_:)",
            arguments: ["query": "\(ARTRealtimePresenceQuery(clientId: "client1", connectionId: "").callRecorderDescription)"],
        ))
    }

    // MARK: CHA-PR6

    // @spec CHA-PR6
    // @specOneOf(2/2) CHA-PR6d
    @Test
    func retrieveAllTheMembersOfThePresenceSet() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // When
        _ = try await defaultPresence.get()

        // Then
        #expect(channel.presence.callRecorder.hasRecord(
            matching: "get()",
            arguments: [:],
        ))
    }

    // @specOneOf(2/2) CHA-PR6h
    @Test
    func failToRetrieveAllTheMembersOfThePresenceSetWhenRoomInInvalidState() async throws {
        // Given
        let error = InternalError.internallyThrown(.presenceOperationRequiresRoomAttach(feature: .presence))
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // Then
        let thrownError = await #expect(throws: (any Error).self) {
            _ = try await defaultPresence.get()
        }
        #expect(isChatError(thrownError, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 400)))
    }

    // @specOneOf(3/4) CHA-PR6c
    @Test
    func retrieveAllTheMembersOfThePresenceSetWhileAttaching() async throws {
        // Given
        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager()
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        // When
        _ = try await defaultPresence.get()

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"],
        ))
    }

    // @specOneOf(4/4) CHA-PR6c
    @Test
    func retrieveAllTheMembersOfThePresenceSetWhileAttachingWithFailure() async throws {
        // Given
        let attachError = ErrorInfo.createArbitraryError()
        let error = InternalError.internallyThrown(.roomTransitionedToInvalidStateForPresenceOperation(cause: attachError))

        let channel = await MockRealtimeChannel(name: "basketball::$chat")
        let logger = TestLogger()
        let roomLifecycleManager = await MockRoomLifecycleManager(resultOfWaitToBeAbleToPerformPresenceOperations: .failure(error))
        let defaultPresence = await DefaultPresence(
            channel: channel,
            roomLifecycleManager: roomLifecycleManager,
            roomName: "basketball",
            logger: logger,
            options: .init(),
        )

        let thrownError = await #expect(throws: (any Error).self) {
            // When
            try await defaultPresence.get()
        }
        // Then
        #expect(isChatError(thrownError, withCodeAndStatusCode: .variableStatusCode(.roomInInvalidState, statusCode: 500), cause: attachError))

        // Then
        #expect(roomLifecycleManager.callRecorder.hasRecord(
            matching: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "presence"],
        ))
    }

    // MARK: CHA-PR7

    // TODO: Test (https://github.com/ably/ably-chat-swift/issues/396)
}
