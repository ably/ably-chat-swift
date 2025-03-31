import Ably
@testable import AblyChat
import Clocks
import Foundation
import Testing

/*
 @MainActor
 struct DefaultTypingTests {
     // Test setup
     private func createTyping(
         channel: MockRealtimeChannel = MockRealtimeChannel(),
         heartbeatThrottle: TimeInterval = 5, // Use a shorter throttle for faster tests
         mockTypingTimerManager: MockTypingTimerManager? = nil
     ) -> DefaultTyping {
         let mockLogger = MockInternalLogger()
         let mockFeatureChannel = MockFeatureChannel(
             channel: channel,
             resultOfWaitToBeAblePerformPresenceOperations: .success(())
         )

         let typingTimerManager = mockTypingTimerManager ?? {
             let manager = MockTypingTimerManager()
             // Default behavior: allow first keystroke, then throttle subsequent ones
             manager.shouldPublishTypingResults = [true, false, false, false, false]
             return manager
         }()

         return DefaultTyping(
             featureChannel: mockFeatureChannel,
             roomID: "test-room",
             clientID: "test-client",
             logger: mockLogger,
             heartbeatThrottle: heartbeatThrottle,
             gracePeriod: 2,
             typingTimerManager: typingTimerManager
         )
     }

     // @spec CHA-T4
     @Test
     func keystroke_PublishesStartedEvent() async throws {
         // Given
         let channel = MockRealtimeChannel()
         let mockTypingManager = MockTypingTimerManager()
         mockTypingManager.shouldPublishTypingResults = [true]
         let typing = createTyping(channel: channel, mockTypingTimerManager: mockTypingManager)

         // When
         try await typing.keystroke()

         // Then
         #expect(channel.publishedMessages.last?.name == TypingEvents.started.rawValue)
         #expect(channel.publishedMessages.last?.extras?["ephemeral"] == .bool(true))
     }

     // @spec CHA-T4c
     @Test
     @available(iOS 16, *)
     func keystroke_multipleKeystroke_onlySends1WithinThrottleAllowance() async throws {
         // Given
         let channel = MockRealtimeChannel()
         let mockTypingManager = MockTypingTimerManager()
         // First call should publish, subsequent calls should be throttled
         mockTypingManager.shouldPublishTypingResults = [true, false, false, false, false]
         let typing = createTyping(channel: channel, mockTypingTimerManager: mockTypingManager)
         let testClock = TestClock()

         // When - send multiple keystrokes in quick succession
         for _ in 0 ..< 5 {
 //            Task {
             try await typing.keystroke()
 //            }
         }

         await testClock.advance(by: .seconds(20))

         // Then - only the first publish should happen
         #expect(channel.publishedMessages.count == 1, "Only one message should be published during throttle period")
     }

     // @spec CHA-T4a5
     @Test
     func keystroke_WaitsForPublishToComplete() async throws {
         // Given
         let channel = MockRealtimeChannel()
         let mockTypingManager = MockTypingTimerManager()
         mockTypingManager.shouldPublishTypingResults = [true]
         let typing = createTyping(channel: channel, mockTypingTimerManager: mockTypingManager)

         // When
         try await typing.keystroke()

         // Then - we can only verify that the keystroke() method completed and published a message
         #expect(channel.publishedMessages.count == 1, "Should have published one message")
     }

     // @spec CHA-T5
     @Test
     func stop_PublishesStoppedEvent() async throws {
         // Given
         let channel = MockRealtimeChannel()
         let mockTypingManager = MockTypingTimerManager()
         // Simulate active typing timer
         mockTypingManager.activeTimers.insert("test-client")
         let typing = createTyping(channel: channel, mockTypingTimerManager: mockTypingManager)

         // When
         try await typing.stop()

         // Then
         #expect(channel.publishedMessages.last?.name == TypingEvents.stopped.rawValue)
         #expect(channel.publishedMessages.last?.extras?["ephemeral"] == .bool(true))
     }

     // @spec CHA-T5a
     @Test
     func stop_DoesNothingIfNotTyping() async throws {
         // Given
         let channel = MockRealtimeChannel()
         let mockTypingManager = MockTypingTimerManager()
         // No active typing timer for "test-client"
         let typing = createTyping(channel: channel, mockTypingTimerManager: mockTypingManager)

         // When - calling stop without starting typing
         try await typing.stop()

         // Then - no message should be published
         #expect(channel.publishedMessages.isEmpty, "Should not publish any message if not typing")
     }

     // @spec CHA-T9
     @Test
     func get_ReturnsTypingClients() async throws {
         // Given
         let channel = MockRealtimeChannel()
         let mockTypingManager = MockTypingTimerManager()
         // Set up mock clients who are typing
         mockTypingManager.typingClients.insert("client1")
         mockTypingManager.typingClients.insert("client2")
         let typing = createTyping(channel: channel, mockTypingTimerManager: mockTypingManager)

         // When
         let typingClients = try await typing.get()

         // Then
         #expect(typingClients.count == 2, "Should return all typing clients")
         #expect(typingClients.contains("client1"), "Should include client1")
         #expect(typingClients.contains("client2"), "Should include client2")
     }
 }

 */
