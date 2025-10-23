import Foundation

/// A clock protocol that provides the current time and a sleep function in line with the Swift Clocks API. This is useful in avoiding an iOS 16 dependency for the Swift Clock types.
internal protocol ClockProtocol: Sendable {
    associatedtype Instant: ClockInstant where Instant: Sendable
    associatedtype Duration: ClockDuration where Duration: Sendable

    var now: Instant { get }
    func sleep(until deadline: Instant) async throws
}

internal struct SystemClock: ClockProtocol, Sendable {
    internal typealias Instant = SystemInstant
    internal typealias Duration = SystemDuration

    internal var now: SystemInstant {
        SystemInstant(date: Date())
    }

    internal func sleep(until deadline: SystemInstant) async throws {
        let duration = deadline.timeInterval(since: now)
        if duration > 0 {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }
    }
}

// Protocol representing a point in time
internal protocol ClockInstant: Sendable, Comparable {
    func advanced(byTimeInterval timeInterval: TimeInterval) -> Self
}

// Protocol representing a time duration
internal protocol ClockDuration: Sendable {
    static func seconds(_ seconds: Double) -> Self
    var timeInterval: TimeInterval { get }
}

// Implementation for system clock
internal struct SystemInstant: ClockInstant, Sendable {
    private let date: Date

    internal init(date: Date) {
        self.date = date
    }

    // Implement the new method
    internal func advanced(byTimeInterval timeInterval: TimeInterval) -> SystemInstant {
        SystemInstant(date: date.addingTimeInterval(timeInterval))
    }

    internal func timeInterval(since other: SystemInstant) -> TimeInterval {
        date.timeIntervalSince(other.date)
    }

    internal static func < (lhs: SystemInstant, rhs: SystemInstant) -> Bool {
        lhs.date < rhs.date
    }

    internal static func > (lhs: SystemInstant, rhs: SystemInstant) -> Bool {
        lhs.date > rhs.date
    }

    internal static func == (lhs: SystemInstant, rhs: SystemInstant) -> Bool {
        lhs.date == rhs.date
    }
}

internal struct SystemDuration: ClockDuration, Sendable {
    internal let timeInterval: TimeInterval

    internal static func seconds(_ seconds: Double) -> SystemDuration {
        SystemDuration(timeInterval: seconds)
    }
}
