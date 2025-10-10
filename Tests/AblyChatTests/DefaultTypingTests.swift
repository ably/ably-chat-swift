import Ably
@testable import AblyChat
import Clocks
import Foundation
import Testing

@MainActor
struct DefaultTypingTests {
    @available(iOS 16.0, tvOS 16.0, *)
    private func createTyping(
        channel: MockRealtimeChannel = MockRealtimeChannel(),
        heartbeatThrottle: TimeInterval = 30, // Use a shorter throttle for faster tests
        mockClock: MockTestClock = MockTestClock(),
    ) -> DefaultTyping {
        let mockLogger = MockInternalLogger()

        return DefaultTyping(
            channel: channel,
            roomName: "test-room",
            logger: mockLogger,
            heartbeatThrottle: heartbeatThrottle,
            clock: mockClock,
        )
    }

    // @spec CHA-T4
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func keystroke_PublishesStartedEvent() async throws {
        // Given
        let channel = MockRealtimeChannel(initialState: .attached, attachBehavior: .complete(.success))
        let typing = createTyping(channel: channel)

        // When
        try await typing.keystroke()

        // Then
        #expect(channel.publishedMessages.last?.name == TypingEventType.started.rawValue)
        #expect(channel.publishedMessages.last?.extras?["ephemeral"] == .bool(true))
    }

    // @spec CHA-T4c
    // @spec CHA-T14
    // @spec CHA-T14a
    // @spec CHA-T14b
    // @spec CHA-T14b1
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func keystroke_multipleKeystroke_onlySends1WithinThrottleAllowance() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let typing = createTyping(channel: channel, mockClock: mockClock)

        // When - send multiple keystrokes in quick succession
        for _ in 0 ..< 5 {
            Task {
                try await typing.keystroke()
            }
        }

        await mockClock.advance(by: 10)

        // Then - only the first publish should happen
        #expect(channel.publishedMessages.count == 1, "Only one message should be published during throttle period")
    }

    // @spec CHA-T6 - Tests subscribing to typing events
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func subscribe_ReturnsSubscriptionForTypingEvents() async {
        // Given
        let typing = createTyping()

        // When
        let subscription: SubscriptionAsyncSequence<TypingSetEvent>? = typing.subscribe()

        // Then
        #expect(subscription != nil)
    }

    // @specOneOf(1/2) CHA-T6a - Tests subscription receives started event
    // @specOneOf(1/2) CHA-T4a3 - Tests that publish has correct name and data
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func subscribe_ReceivesStartedTypingEvent() async throws {
        // Given
        let clientId = "test-client"
        let typing = createTyping()

        // When
        let subscription = typing.subscribe()
        subscription.emit(
            TypingSetEvent(
                type: .setChanged,
                currentlyTyping: [clientId],
                change: .init(clientID: clientId, type: .started),
            ),
        )

        // Then
        let typingEvent = try #require(await subscription.first { @Sendable _ in true })
        #expect(typingEvent.change.type == .started)
        #expect(typingEvent.change.clientID == clientId)
        #expect(typingEvent.currentlyTyping == [clientId])
    }

    // @specOneOf(2/2) CHA-T6a - Tests subscription receives stopped event
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func subscribe_ReceivesStoppedTypingEvent() async throws {
        // Given
        let clientId = "test-client"
        let typing = createTyping()

        // When
        let subscription = typing.subscribe()
        subscription.emit(
            TypingSetEvent(
                type: .setChanged,
                currentlyTyping: [],
                change: .init(clientID: clientId, type: .stopped),
            ),
        )

        // Then
        let typingEvent = try #require(await subscription.first { @Sendable _ in true })
        #expect(typingEvent.change.type == .stopped)
        #expect(typingEvent.change.clientID == clientId)
        #expect(typingEvent.currentlyTyping.isEmpty)
    }

    // @spec CHA-T9 - Tests retrieving currently typing clients
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func get_ReturnsCurrentlyTypingClients() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let typing = createTyping(channel: channel, mockClock: mockClock)

        // Setup subscription and receive a typing event
        _ = typing.subscribe()

        let message = ARTMessage(name: TypingEventType.started.rawValue, data: [], clientId: "test-client")
        channel.simulateIncomingMessage(message, for: TypingEventType.started.rawValue)

        // When
        let typingClients = typing.current

        // Then
        #expect(typingClients.contains("test-client"))
    }

    // @specOneOf(2/2) CHA-T4a3 - Tests that publish has ephemeral flag
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func keystroke_PublishesWithEphemeralFlag() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let typing = createTyping(channel: channel)

        // When
        try await typing.keystroke()

        // Then
        let message = channel.publishedMessages.last
        #expect(message?.extras?["ephemeral"] == .bool(true))
    }

    // @specOneOf(3/3) CHA-T4a4 - Tests that heartbeat timer is set after successful publish
    // @spec CHA-T4c1 - Tests that keystroke doesn't send event if already typing
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func keystroke_SetsHeartbeatTimer() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let typing = createTyping(channel: channel, mockClock: mockClock)

        // When
        try await typing.keystroke()

        // Then - Make a second keystroke attempt that should be throttled
        let publishCount = channel.publishedMessages.count
        try await typing.keystroke()
        #expect(channel.publishedMessages.count == publishCount, "Heartbeat timer should throttle second publish")
    }

    // @spec CHA-T5 - Tests stop method
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func stop_PublishesStoppedEvent() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let typing = createTyping(channel: channel)

        // Start typing first
        try await typing.keystroke()

        // When
        try await typing.stop()

        // Then
        #expect(channel.publishedMessages.last?.name == TypingEventType.stopped.rawValue)
    }

    // @spec CHA-T5a - Tests stop is no-op if not typing
    // @spec CHA-T13b5 - Tests that stop events for non-typing clients are ignored
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func stop_IsNoOpWhenNotTyping() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let typing = createTyping(channel: channel)

        // When - Stop without starting
        try await typing.stop()

        // Then
        #expect(channel.publishedMessages.isEmpty)
    }

    // @spec CHA-T5d - Tests publish for stop has correct format
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func stop_PublishesCorrectFormatMessage() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let typing = createTyping(channel: channel)

        // Start typing first
        try await typing.keystroke()

        // When
        try await typing.stop()

        // Then
        let message = channel.publishedMessages.last
        #expect(message?.name == TypingEventType.stopped.rawValue)
        #expect(message?.data == nil)
        #expect(message?.extras?["ephemeral"] == .bool(true))
    }

    // @spec CHA-T5e - Tests stop unsets heartbeat timer
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func stop_UnsetsHeartbeatTimer() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let typing = createTyping(channel: channel)

        // Start typing
        try await typing.keystroke()

        // When
        try await typing.stop()

        // Then - Another keystroke should publish (if timer was cancelled)
        try await typing.keystroke()
        #expect(channel.publishedMessages.count == 3)
        #expect(channel.publishedMessages.last?.name == TypingEventType.started.rawValue)
    }

    // @specOneOf(3/3) CHA-T13b1 - Tests timeout setup for typing clients
    // @spec CHA-T13b3 - Tests that timeout expiration removes client from typing set
    @Test
    @available(iOS 16.0, tvOS 16.0, *)
    func typing_ExpiresAfterHeartbeatThrottle() async throws {
        // Given
        let channel = MockRealtimeChannel()
        let mockClock = MockTestClock()
        let heartbeatThrottle: TimeInterval = 5
        let typing = createTyping(channel: channel, heartbeatThrottle: heartbeatThrottle, mockClock: mockClock)
        let subscription = typing.subscribe()

        // Simulate someone started typing
        let message = ARTMessage(name: TypingEventType.started.rawValue, data: [], clientId: "test-client")
        channel.simulateIncomingMessage(message, for: TypingEventType.started.rawValue)

        // When - advance clock past heartbeat + grace period
        await mockClock.advance(by: heartbeatThrottle + 2)

        // Then - should receive stopped event due to timeout
        async let stoppedEvent = await subscription.first { event in
            event.change.type == .stopped && event.change.clientID == "test-client"
        }

        await #expect(stoppedEvent != nil)
        #expect(typing.current.isEmpty)
    }
}
