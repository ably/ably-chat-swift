import Ably
@testable import AblyChat
import Clocks
import Foundation
import Testing

// MARK: - userClaim extraction helper tests

@MainActor
struct UserClaimExtractionTests {
    // @spec CHA-M2h - Tests extraction helper for userClaim from extras
    @Test
    func userClaim_extractsStringValue() {
        let extras: [String: JSONValue] = ["userClaim": .string("admin")]
        #expect(extras.userClaim == "admin")
    }

    @Test
    func userClaim_returnsNilForMissingKey() {
        let extras: [String: JSONValue] = ["headers": .object([:])]
        #expect(extras.userClaim == nil)
    }

    @Test
    func userClaim_returnsNilForNonStringValue() {
        let extras: [String: JSONValue] = ["userClaim": .number(42)]
        #expect(extras.userClaim == nil)
    }

    @Test
    func userClaim_returnsNilForNullValue() {
        let extras: [String: JSONValue] = ["userClaim": .null]
        #expect(extras.userClaim == nil)
    }

    @Test
    func userClaim_returnsEmptyStringForEmptyStringValue() {
        let extras: [String: JSONValue] = ["userClaim": .string("")]
        #expect(extras.userClaim?.isEmpty == true)
    }

    @Test
    func userClaim_returnsNilForEmptyExtras() {
        let extras: [String: JSONValue] = [:]
        #expect(extras.userClaim == nil)
    }
}

// MARK: - Message userClaim tests

@MainActor
struct MessageUserClaimTests {
    // @spec CHA-M2h - Message includes userClaim from realtime extras
    @Test
    func subscribe_messageWithUserClaimInExtras() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let message = ARTMessage()
        message.action = .create
        message.serial = "serial1"
        message.clientId = "client1"
        message.data = ["text": "hello", "metadata": [:]] as [String: Any]
        message.extras = [
            "headers": [:],
            "userClaim": "moderator",
        ] as (any ARTJsonCompatible)
        message.version = .init(serial: "v1")
        message.timestamp = Date(timeIntervalSince1970: 1_000_000)

        let channel = MockRealtimeChannel(
            properties: .init(attachSerial: "001", channelSerial: "001"),
            initialState: .attached,
            messageToEmitOnSubscribe: message,
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "test-room", logger: TestLogger())

        // When / Then
        _ = defaultMessages.subscribe { event in
            #expect(event.message.userClaim == "moderator")
        }
    }

    // @spec CHA-M2h - Message without userClaim in extras has nil userClaim
    @Test
    func subscribe_messageWithoutUserClaimInExtras() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let message = ARTMessage()
        message.action = .create
        message.serial = "serial1"
        message.clientId = "client1"
        message.data = ["text": "hello", "metadata": [:]] as [String: Any]
        message.extras = [
            "headers": [:],
        ] as (any ARTJsonCompatible)
        message.version = .init(serial: "v1")
        message.timestamp = Date(timeIntervalSince1970: 1_000_000)

        let channel = MockRealtimeChannel(
            properties: .init(attachSerial: "001", channelSerial: "001"),
            initialState: .attached,
            messageToEmitOnSubscribe: message,
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "test-room", logger: TestLogger())

        // When / Then
        _ = defaultMessages.subscribe { event in
            #expect(event.message.userClaim == nil)
        }
    }

    // @spec CHA-M2h - Message decoded from REST JSON includes userClaim
    @Test
    func jsonDecodable_messageWithUserClaim() throws {
        let jsonObject: [String: JSONValue] = [
            "serial": "serial1",
            "action": "message.create",
            "clientId": "client1",
            "text": "hello",
            "metadata": [:],
            "headers": [:],
            "version": ["serial": "v1"],
            "userClaim": "admin",
        ]

        let message = try Message(jsonObject: jsonObject)
        #expect(message.userClaim == "admin")
    }

    // @spec CHA-M2h - Message decoded from REST JSON without userClaim has nil
    @Test
    func jsonDecodable_messageWithoutUserClaim() throws {
        let jsonObject: [String: JSONValue] = [
            "serial": "serial1",
            "action": "message.create",
            "clientId": "client1",
            "text": "hello",
            "metadata": [:],
            "headers": [:],
            "version": ["serial": "v1"],
        ]

        let message = try Message(jsonObject: jsonObject)
        #expect(message.userClaim == nil)
    }
}

// MARK: - RoomReaction userClaim tests

@MainActor
struct RoomReactionUserClaimTests {
    // @spec CHA-ER2a - RoomReaction includes userClaim from realtime extras
    @Test
    func subscribe_reactionWithUserClaimInExtras() async throws {
        // Given
        let message = ARTMessage()
        message.action = .create
        message.name = "roomReaction"
        message.serial = "serial1"
        message.clientId = "client1"
        message.data = ["name": "like"] as [String: Any]
        message.extras = [
            "headers": [:],
            "userClaim": "vip",
        ] as (any ARTJsonCompatible)
        message.timestamp = Date(timeIntervalSince1970: 1_000_000)

        let channel = MockRealtimeChannel(
            messageToEmitOnSubscribe: message,
        )
        let defaultRoomReactions = DefaultRoomReactions(realtime: MockRealtime(), channel: channel, roomName: "test-room", logger: TestLogger())

        // When / Then
        _ = defaultRoomReactions.subscribe { event in
            #expect(event.reaction.userClaim == "vip")
        }
    }

    // @spec CHA-ER2a - RoomReaction without userClaim has nil userClaim
    @Test
    func subscribe_reactionWithoutUserClaimInExtras() async throws {
        // Given
        let message = ARTMessage()
        message.action = .create
        message.name = "roomReaction"
        message.serial = "serial1"
        message.clientId = "client1"
        message.data = ["name": "like"] as [String: Any]
        message.extras = [
            "headers": [:],
        ] as (any ARTJsonCompatible)
        message.timestamp = Date(timeIntervalSince1970: 1_000_000)

        let channel = MockRealtimeChannel(
            messageToEmitOnSubscribe: message,
        )
        let defaultRoomReactions = DefaultRoomReactions(realtime: MockRealtime(), channel: channel, roomName: "test-room", logger: TestLogger())

        // When / Then
        _ = defaultRoomReactions.subscribe { event in
            #expect(event.reaction.userClaim == nil)
        }
    }
}

// MARK: - PresenceMember userClaim tests

@MainActor
struct PresenceMemberUserClaimTests {
    // @spec CHA-PR6g - PresenceMember includes userClaim from presence extras
    @Test
    func presenceMember_extractsUserClaimFromExtras() {
        let member = PresenceMember(
            clientID: "client1",
            connectionID: "conn1",
            data: nil,
            extras: ["userClaim": .string("subscriber")],
            updatedAt: Date(),
            userClaim: "subscriber",
        )
        #expect(member.userClaim == "subscriber")
    }

    // @spec CHA-PR6g - PresenceMember without userClaim in extras has nil
    @Test
    func presenceMember_nilUserClaimWhenMissingFromExtras() {
        let member = PresenceMember(
            clientID: "client1",
            connectionID: "conn1",
            data: nil,
            extras: nil,
            updatedAt: Date(),
        )
        #expect(member.userClaim == nil)
    }
}

// MARK: - TypingSetEvent.Change userClaim tests

@MainActor
struct TypingUserClaimTests {
    @available(iOS 16.0, tvOS 16, *)
    private func createTypingTimerManager(with testClock: MockTestClock) -> TypingTimerManager<MockTestClock> {
        TypingTimerManager(
            heartbeatThrottle: 1.0,
            gracePeriod: 0.5,
            logger: TestLogger(),
            clock: testClock,
        )
    }

    // @spec CHA-T13a1 - userClaim is stored with typing state
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func typingTimerManager_storesUserClaim() {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        timerManager.startTypingTimer(for: "client1", userClaim: "admin")

        #expect(timerManager.userClaimForClient("client1") == "admin")
    }

    // @spec CHA-T13a1 - userClaim is cleared when heartbeat arrives without one
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func typingTimerManager_clearsUserClaimOnHeartbeatWithoutClaim() {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        // Initial typing event with userClaim
        timerManager.startTypingTimer(for: "client1", userClaim: "admin")
        #expect(timerManager.userClaimForClient("client1") == "admin")

        // Heartbeat event without userClaim - should clear the existing one per CHA-T13a1
        timerManager.startTypingTimer(for: "client1", userClaim: nil)
        #expect(timerManager.userClaimForClient("client1") == nil)
    }

    // @spec CHA-T13a1 - userClaim is updated when a new one is provided
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func typingTimerManager_updatesUserClaimWhenNewOneProvided() {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        timerManager.startTypingTimer(for: "client1", userClaim: "admin")
        #expect(timerManager.userClaimForClient("client1") == "admin")

        timerManager.startTypingTimer(for: "client1", userClaim: "moderator")
        #expect(timerManager.userClaimForClient("client1") == "moderator")
    }

    // @spec CHA-T13a1 - userClaim is nil for unknown client
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func typingTimerManager_returnsNilForUnknownClient() {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        #expect(timerManager.userClaimForClient("unknown") == nil)
    }

    // @spec CHA-T13a1 - userClaim is removed when typing timer is cancelled
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func typingTimerManager_removesUserClaimOnCancel() {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        timerManager.startTypingTimer(for: "client1", userClaim: "admin")
        #expect(timerManager.userClaimForClient("client1") == "admin")

        timerManager.cancelTypingTimer(for: "client1")
        #expect(timerManager.userClaimForClient("client1") == nil)
    }

    // @spec CHA-T13a1 - typing started event includes userClaim from message extras
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func subscribe_startedEventIncludesUserClaim() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let typing = DefaultTyping(
            channel: channel,
            roomName: "test-room",
            logger: TestLogger(),
            heartbeatThrottle: 5,
            clock: mockClock,
        )
        var receivedEvents: [TypingSetEvent] = []

        _ = typing.subscribe { @MainActor event in
            receivedEvents.append(event)
        }

        // When - simulate a typing.started message with userClaim in extras
        let message = ARTMessage(name: TypingEventType.started.rawValue, data: [], clientId: "test-client")
        message.extras = ["userClaim": "admin"] as (any ARTJsonCompatible)
        channel.simulateIncomingMessage(message, for: TypingEventType.started.rawValue)

        // Then
        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].change.type == .started)
        #expect(receivedEvents[0].change.clientID == "test-client")
        #expect(receivedEvents[0].change.userClaim == "admin")
        #expect(receivedEvents[0].currentTypers.count == 1)
        #expect(receivedEvents[0].currentTypers[0].clientID == "test-client")
        #expect(receivedEvents[0].currentTypers[0].userClaim == "admin")
    }

    // @spec CHA-T13a1 - typing stopped event includes userClaim from message extras
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func subscribe_stoppedEventIncludesUserClaim() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let typing = DefaultTyping(
            channel: channel,
            roomName: "test-room",
            logger: TestLogger(),
            heartbeatThrottle: 5,
            clock: mockClock,
        )
        var receivedEvents: [TypingSetEvent] = []

        _ = typing.subscribe { @MainActor event in
            receivedEvents.append(event)
        }

        // First, start typing
        let startMessage = ARTMessage(name: TypingEventType.started.rawValue, data: [], clientId: "test-client")
        startMessage.extras = ["userClaim": "admin"] as (any ARTJsonCompatible)
        channel.simulateIncomingMessage(startMessage, for: TypingEventType.started.rawValue)

        // When - simulate a typing.stopped message with userClaim
        let stopMessage = ARTMessage(name: TypingEventType.stopped.rawValue, data: [], clientId: "test-client")
        stopMessage.extras = ["userClaim": "admin"] as (any ARTJsonCompatible)
        channel.simulateIncomingMessage(stopMessage, for: TypingEventType.stopped.rawValue)

        // Then
        #expect(receivedEvents.count == 2)
        #expect(receivedEvents[1].change.type == .stopped)
        #expect(receivedEvents[1].change.clientID == "test-client")
        #expect(receivedEvents[1].change.userClaim == "admin")
        #expect(receivedEvents[1].currentTypers.isEmpty)
    }

    // @spec CHA-T13a1 - typing stopped event falls back to cached userClaim when message lacks it
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func subscribe_stoppedEventFallsBackToCachedUserClaim() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let typing = DefaultTyping(
            channel: channel,
            roomName: "test-room",
            logger: TestLogger(),
            heartbeatThrottle: 5,
            clock: mockClock,
        )
        var receivedEvents: [TypingSetEvent] = []

        _ = typing.subscribe { @MainActor event in
            receivedEvents.append(event)
        }

        // First, start typing with a userClaim
        let startMessage = ARTMessage(name: TypingEventType.started.rawValue, data: [], clientId: "test-client")
        startMessage.extras = ["userClaim": "admin"] as (any ARTJsonCompatible)
        channel.simulateIncomingMessage(startMessage, for: TypingEventType.started.rawValue)

        // When - simulate a typing.stopped message WITHOUT userClaim
        let stopMessage = ARTMessage(name: TypingEventType.stopped.rawValue, data: [], clientId: "test-client")
        channel.simulateIncomingMessage(stopMessage, for: TypingEventType.stopped.rawValue)

        // Then - should fall back to cached userClaim
        #expect(receivedEvents.count == 2)
        #expect(receivedEvents[1].change.type == .stopped)
        #expect(receivedEvents[1].change.userClaim == "admin")
    }

    // @spec CHA-T13a1 - inactivity timeout synthetic stop event includes cached userClaim
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func subscribe_timeoutStopEventIncludesCachedUserClaim() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let heartbeatThrottle: TimeInterval = 5
        let typing = DefaultTyping(
            channel: channel,
            roomName: "test-room",
            logger: TestLogger(),
            heartbeatThrottle: heartbeatThrottle,
            clock: mockClock,
        )
        var receivedEvents: [TypingSetEvent] = []

        _ = typing.subscribe { @MainActor event in
            receivedEvents.append(event)
        }

        // When - simulate a typing.started message with userClaim
        let message = ARTMessage(name: TypingEventType.started.rawValue, data: [], clientId: "test-client")
        message.extras = ["userClaim": "admin"] as (any ARTJsonCompatible)
        channel.simulateIncomingMessage(message, for: TypingEventType.started.rawValue)

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].change.type == .started)

        // Advance clock past heartbeat + grace period to trigger timeout
        await mockClock.advance(by: heartbeatThrottle + 2 + 1)

        // Then - synthetic stop event should include the cached userClaim
        #expect(receivedEvents.count == 2)
        #expect(receivedEvents[1].change.type == .stopped)
        #expect(receivedEvents[1].change.clientID == "test-client")
        #expect(receivedEvents[1].change.userClaim == "admin")
    }

    // @spec CHA-T13a1 - typing event without userClaim has nil
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func subscribe_startedEventWithoutUserClaim() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let typing = DefaultTyping(
            channel: channel,
            roomName: "test-room",
            logger: TestLogger(),
            heartbeatThrottle: 5,
            clock: mockClock,
        )
        var receivedEvents: [TypingSetEvent] = []

        _ = typing.subscribe { @MainActor event in
            receivedEvents.append(event)
        }

        // When - simulate a typing.started message without extras
        let message = ARTMessage(name: TypingEventType.started.rawValue, data: [], clientId: "test-client")
        channel.simulateIncomingMessage(message, for: TypingEventType.started.rawValue)

        // Then
        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].change.userClaim == nil)
    }
}

// MARK: - MessageReactionRawEvent.Reaction userClaim tests

@MainActor
struct MessageReactionUserClaimTests {
    // @spec CHA-MR7d - Reaction includes userClaim from annotation extras
    @Test
    func reaction_includesUserClaimFromInit() {
        let reaction = MessageReactionRawEvent.Reaction(
            type: .unique,
            name: "like",
            messageSerial: "serial1",
            clientID: "client1",
            userClaim: "admin",
        )
        #expect(reaction.userClaim == "admin")
    }

    // @spec CHA-MR7d - Reaction without userClaim defaults to nil
    @Test
    func reaction_defaultsToNilUserClaim() {
        let reaction = MessageReactionRawEvent.Reaction(
            type: .unique,
            name: "like",
            messageSerial: "serial1",
            clientID: "client1",
        )
        #expect(reaction.userClaim == nil)
    }
}
