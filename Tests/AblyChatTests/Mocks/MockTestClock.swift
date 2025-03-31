@testable import AblyChat
import Clocks
import Foundation

// Adapter that bridges the Clocks.TestClock with our ClockProtocol
@available(iOS 16.0, tvOS 16, *)
final class MockTestClock: ClockProtocol {
    typealias Instant = SwiftTestInstant
    typealias Duration = SwiftTestDuration

    private let testClock = TestClock()

    var now: SwiftTestInstant {
        SwiftTestInstant(instant: testClock.now)
    }

    func sleep(for duration: SwiftTestDuration) async throws {
        try await testClock.sleep(for: duration.duration)
    }

    func advance(by: TimeInterval) async {
        await testClock.advance(by: .seconds(by))
    }
}

// Wrapper for TestClock.Instant to conform to our ClockInstant protocol
@available(iOS 16.0, tvOS 16, *)
struct SwiftTestInstant: ClockInstant {
    static func == (lhs: SwiftTestInstant, rhs: SwiftTestInstant) -> Bool {
        lhs.instant == rhs.instant
    }

    static func > (lhs: SwiftTestInstant, rhs: SwiftTestInstant) -> Bool {
        lhs.instant > rhs.instant
    }

    static func < (lhs: SwiftTestInstant, rhs: SwiftTestInstant) -> Bool {
        lhs.instant < rhs.instant
    }

    let instant: TestClock<Swift.Duration>.Instant

    func advanced(byTimeInterval timeInterval: TimeInterval) -> SwiftTestInstant {
        SwiftTestInstant(instant: instant.advanced(by: .seconds(timeInterval)))
    }
}

// Wrapper for Swift.Duration to conform to our ClockDuration protocol
@available(iOS 16.0, tvOS 16, *)
struct SwiftTestDuration: ClockDuration {
    let duration: Swift.Duration

    var timeInterval: TimeInterval {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    static func seconds(_ seconds: Double) -> SwiftTestDuration {
        SwiftTestDuration(duration: .seconds(seconds))
    }

    static func + (lhs: SwiftTestDuration, rhs: SwiftTestDuration) -> SwiftTestDuration {
        SwiftTestDuration(duration: lhs.duration + rhs.duration)
    }

    static func - (lhs: SwiftTestDuration, rhs: SwiftTestDuration) -> SwiftTestDuration {
        SwiftTestDuration(duration: lhs.duration - rhs.duration)
    }

    static func < (lhs: SwiftTestDuration, rhs: SwiftTestDuration) -> Bool {
        lhs.duration < rhs.duration
    }

    static func > (lhs: SwiftTestDuration, rhs: SwiftTestDuration) -> Bool {
        lhs.duration > rhs.duration
    }

    static func == (lhs: SwiftTestDuration, rhs: SwiftTestDuration) -> Bool {
        lhs.duration == rhs.duration
    }
}
