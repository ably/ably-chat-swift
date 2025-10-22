@testable import AblyChat
import Clocks
import Foundation
import Semaphore
import Testing

@MainActor
final class TypingTimerManagerTests {
    var mockLogger: MockInternalLogger!

    @available(iOS 16.0, tvOS 16, *)
    func createTypingTimerManager(with testClock: MockTestClock) -> TypingTimerManager<MockTestClock> {
        mockLogger = MockInternalLogger()
        return TypingTimerManager(
            heartbeatThrottle: 1.0,
            gracePeriod: 0.5,
            logger: mockLogger,
            clock: testClock,
        )
    }

    // @specOneOf(1/3) CHA-T4a4 - Tests the heartbeat timer initialization and state management
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func heartbeatTimerLifecycle() async {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)
        #expect(!timerManager.isHeartbeatTimerActive)

        timerManager.startHeartbeatTimer()
        #expect(timerManager.isHeartbeatTimerActive)

        timerManager.cancelHeartbeatTimer()
        #expect(!timerManager.isHeartbeatTimerActive)
    }

    // @specOneOf(2/3) CHA-T4a4 - Tests heartbeat timer expiration behavior
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func heartbeatTimerExpiration() async {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        timerManager.startHeartbeatTimer()
        #expect(timerManager.isHeartbeatTimerActive)

        await mockClock.advance(by: 1.1)
        #expect(!timerManager.isHeartbeatTimerActive)
    }

    // @specOneOf(1/3) CHA-T13b1 - Tests starting "is somebody typing" timers to add client to typing set
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func testStartTypingTimer() {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        #expect(!timerManager.isCurrentlyTyping(clientID: "client1"))

        timerManager.startTypingTimer(for: "client1")
        #expect(timerManager.isCurrentlyTyping(clientID: "client1"))
        #expect(timerManager.currentlyTypingClientIDs() == ["client1"])
    }

    // @specOneOf(2/3) CHA-T13b1 - Tests the currentlyTypingClients method returns correct set of typing clients.
    // @spec CHA-T13b4 - Tests canceling typing timer to remove client from typing set
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func multipleClientTyping() {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        timerManager.startTypingTimer(for: "client1")
        timerManager.startTypingTimer(for: "client2")
        timerManager.startTypingTimer(for: "client3")

        #expect(timerManager.currentlyTypingClientIDs() == ["client1", "client2", "client3"])

        timerManager.cancelTypingTimer(for: "client2")

        #expect(timerManager.currentlyTypingClientIDs() == ["client1", "client3"])
    }

    // @spec CHA-T13b3 - Tests timeout expiration removing client from typing set and calling the onCancelled handler.
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func typingTimerExpiration() async {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        var handlerCalled = false

        let semaphoreSignalledByHandler = AsyncSemaphore(value: 0)
        timerManager.startTypingTimer(for: "client1") {
            handlerCalled = true
            semaphoreSignalledByHandler.signal()
        }

        #expect(timerManager.isCurrentlyTyping(clientID: "client1"))

        // Advance time to trigger timer expiration (heartbeatThrottle + gracePeriod)
        await mockClock.advance(by: 1.6)

        await semaphoreSignalledByHandler.wait()
        #expect(handlerCalled)
        #expect(!timerManager.isCurrentlyTyping(clientID: "client1"))
        #expect(timerManager.currentlyTypingClientIDs().isEmpty)
    }

    // @spec CHA-T13b2 - Tests that each additional typing heartbeat resets the timeout
    // @spec CHA-T4b - Tests extending the timeout when typing is already in progress
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func timerReset() async {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        var handlerCalled = false

        timerManager.startTypingTimer(for: "client1") {
            handlerCalled = true
        }

        // Advance time but not enough to expire
        await mockClock.advance(by: 1.0)

        // Reset timer before it expires
        timerManager.startTypingTimer(for: "client1") {
            handlerCalled = true
        }

        // Advance time enough to expire original timer
        await mockClock.advance(by: 0.7)

        // Client should still be typing because we reset the timer
        #expect(timerManager.isCurrentlyTyping(clientID: "client1"))
        #expect(!handlerCalled)

        // Now advance enough to expire the reset timer
        await mockClock.advance(by: 2.0)

        #expect(handlerCalled)
        #expect(!timerManager.isCurrentlyTyping(clientID: "client1"))
    }

    // @spec CHA-T10 - Users can configure the heartbeat interval (set to 1 in createTypingTimerManager)
    // @spec CHA-T10a1 - Tests that grace period is correctly applied to prevent flickering
    @Test
    @available(iOS 16.0, tvOS 16, *)
    func gracePeriodTiming() async {
        let mockClock = MockTestClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        var handlerCalled = false

        let semaphoreSignalledByHandler = AsyncSemaphore(value: 0)
        timerManager.startTypingTimer(for: "client1") {
            handlerCalled = true
            semaphoreSignalledByHandler.signal()
        }

        // Advance by heartbeatThrottle only - should still be typing
        await mockClock.advance(by: 1.0)

        #expect(timerManager.isCurrentlyTyping(clientID: "client1"))
        #expect(!handlerCalled)

        // Advance by grace period - now should expire
        await mockClock.advance(by: 0.5)

        await semaphoreSignalledByHandler.wait()
        #expect(handlerCalled)
        #expect(!timerManager.isCurrentlyTyping(clientID: "client1"))
    }
}
