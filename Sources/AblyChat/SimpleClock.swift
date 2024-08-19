/// A clock that causes the current task to sleep.
///
/// Exists for mocking in tests. Note that we can’t use the Swift `Clock` type since it doesn’t exist in our minimum supported OS versions.
internal protocol SimpleClock: Sendable {
    /// Behaves like `Task.sleep(nanoseconds:)`.
    func sleep(nanoseconds duration: UInt64) async throws
}
