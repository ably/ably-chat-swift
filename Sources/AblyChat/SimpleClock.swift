import Foundation

/// A clock that causes the current task to sleep.
///
/// Exists for mocking in tests. Note that we can’t use the Swift `Clock` type since it doesn’t exist in our minimum supported OS versions.
internal protocol SimpleClock: Sendable {
    /// Behaves like `Task.sleep(nanoseconds:)`. Uses seconds instead of nanoseconds for readability at call site (we have no need for that level of precision).
    func sleep(timeInterval: TimeInterval) async throws
}

internal final class DefaultSimpleClock: SimpleClock {
    internal func sleep(timeInterval: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(timeInterval * Double(NSEC_PER_SEC)))
    }
}
