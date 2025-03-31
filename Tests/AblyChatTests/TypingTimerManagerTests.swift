@testable import AblyChat
import Foundation
import Testing

// Task.yield() is used throughout these tests to allow asynchronous timer tasks to process.
// When we advance the mock clock, it changes the reported time but doesn't automatically
// trigger any pending tasks. The yield() suspends the current test task momentarily,
// giving the timer tasks a chance to observe the new time and execute their handlers.
// Without these yields, tests would continue executing before timer callbacks have a chance
// to run, leading to false negatives in our assertions.

@MainActor
final class TypingTimerManagerTests {
    var mockLogger: MockInternalLogger!

    func createTypingTimerManager(with mockClock: MockClock) -> TypingTimerManager {
        mockLogger = MockInternalLogger()
        return TypingTimerManager(
            heartbeatThrottle: 1.0,
            gracePeriod: 0.5,
            logger: mockLogger,
            clock: mockClock
        )
    }

    // @specOneOf(1/2) CHA-T4a4 - Tests the heartbeat timer initialization and state management
    @Test
    func testHeartbeatTimerLifecycle() {
        let mockClock = MockClock()
        let timerManager = createTypingTimerManager(with: mockClock)
        #expect(!timerManager.isHeartbeatTimerActive)

        timerManager.startHeartbeatTimer()
        #expect(timerManager.isHeartbeatTimerActive)

        timerManager.cancelHeartbeatTimer()
        #expect(!timerManager.isHeartbeatTimerActive)
    }

    // @specOneOf(2/2) CHA-T4a4 - Tests heartbeat timer expiration behavior
    @Test
    func testHeartbeatTimerExpiration() {
        let mockClock = MockClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        timerManager.startHeartbeatTimer()
        #expect(timerManager.isHeartbeatTimerActive)

        mockClock.advance(by: 1.1)
        #expect(!timerManager.isHeartbeatTimerActive)
    }

    // @specOneOf(1/2) CHA-T13b1 - Tests starting "is somebody typing" timers to add client to typing set
    @Test
    func testStartTypingTimer() {
        let mockClock = MockClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        #expect(!timerManager.isTypingTimerActive(for: "client1"))

        timerManager.startTypingTimer(for: "client1")
        #expect(timerManager.isTypingTimerActive(for: "client1"))
        #expect(timerManager.currentlyTypingClients() == ["client1"])
    }

    // @specOneOf(2/2) CHA-T13b1 - Tests the currentlyTypingClients method returns correct set of typing clients.
    // @spec CHA-T13b4 - Tests canceling typing timer to remove client from typing set
    @Test
    func testMultipleClientTyping() {
        let mockClock = MockClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        timerManager.startTypingTimer(for: "client1")
        timerManager.startTypingTimer(for: "client2")
        timerManager.startTypingTimer(for: "client3")

        #expect(timerManager.currentlyTypingClients() == ["client1", "client2", "client3"])

        timerManager.cancelTypingTimer(for: "client2")

        #expect(timerManager.currentlyTypingClients() == ["client1", "client3"])
    }

    // @spec CHA-T13b3 - Tests timeout expiration removing client from typing set and calling the onCancelled handler.
    @Test
    func testTypingTimerExpiration() async {
        let mockClock = MockClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        var handlerCalled = false

        timerManager.startTypingTimer(for: "client1") {
            handlerCalled = true
        }

        #expect(timerManager.isTypingTimerActive(for: "client1"))

        // Advance time to trigger timer expiration (heartbeatThrottle + gracePeriod)
        mockClock.advance(by: 1.6)

        await Task.yield()

        #expect(handlerCalled)
        #expect(!timerManager.isTypingTimerActive(for: "client1"))
        #expect(timerManager.currentlyTypingClients().isEmpty)
    }

    // @spec CHA-T13b2 - Tests that each additional typing heartbeat resets the timeout
    // @spec CHA-T4b - Tests extending the timeout when typing is already in progress
    @Test
    func testTimerReset() async {
        let mockClock = MockClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        var handlerCalled = false

        timerManager.startTypingTimer(for: "client1") {
            handlerCalled = true
        }

        // Advance time but not enough to expire
        mockClock.advance(by: 1.0)

        // Reset timer before it expires
        timerManager.startTypingTimer(for: "client1") {
            handlerCalled = true
        }

        // Advance time enough to expire original timer
        mockClock.advance(by: 0.7)
        await Task.yield()

        // Client should still be typing because we reset the timer
        #expect(timerManager.isTypingTimerActive(for: "client1"))
        #expect(!handlerCalled)

        // Now advance enough to expire the reset timer
        mockClock.advance(by: 1.0)
        await Task.yield()

        #expect(handlerCalled)
        #expect(!timerManager.isTypingTimerActive(for: "client1"))
    }

    // @spec CHA-T10a1 - Tests that grace period is correctly applied to prevent flickering
    @Test
    func testGracePeriodTiming() async {
        let mockClock = MockClock()
        let timerManager = createTypingTimerManager(with: mockClock)

        var handlerCalled = false

        timerManager.startTypingTimer(for: "client1") {
            handlerCalled = true
        }

        // Advance by heartbeatThrottle only - should still be typing
        mockClock.advance(by: 1.0)
        await Task.yield()

        #expect(timerManager.isTypingTimerActive(for: "client1"))
        #expect(!handlerCalled)

        // Advance by grace period - now should expire
        mockClock.advance(by: 0.5)
        await Task.yield()

        #expect(handlerCalled)
        #expect(!timerManager.isTypingTimerActive(for: "client1"))
    }
}

// Mock clock for deterministic time-based testing
class MockClock: ClockProvider {
    private var currentTime = Date()

    func now() -> Date {
        currentTime
    }

    func advance(by timeInterval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(timeInterval)
    }
}
