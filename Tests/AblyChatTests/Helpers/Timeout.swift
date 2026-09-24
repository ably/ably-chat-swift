import Foundation

/// Thrown by ``withTimeout(seconds:_:)`` when the operation does not finish in time.
struct TimeoutError: Error, CustomStringConvertible {
    let seconds: TimeInterval
    let function: String
    let line: Int

    var description: String {
        "Timed out after \(seconds)s in \(function) (line \(line))"
    }
}

/// Runs `operation`, throwing ``TimeoutError`` if it has not finished within `seconds`.
///
/// Integration tests wait on events that arrive over a realtime connection. Without a bound, an
/// event that never arrives leaves the test suspended until the CI job's own limit kills it, which
/// costs a whole job and reports nothing useful. With one, the test fails in seconds and names the
/// line it was waiting on.
///
/// Swift Testing's `timeLimit` trait would be the natural way to express this, but it needs
/// macOS 13 / iOS 16 and this package supports older versions, so this does the same job by racing
/// the operation against a sleep.
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    function: String = #function,
    line: Int = #line,
    _ operation: @escaping @Sendable () async throws -> T,
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * TimeInterval(NSEC_PER_SEC)))
            throw TimeoutError(seconds: seconds, function: function, line: line)
        }

        defer {
            group.cancelAll()
        }

        // The group always has two tasks, so there is always a first result.
        // swiftlint:disable:next force_unwrapping
        return try await group.next()!
    }
}
