import Foundation

/// Manages a single timer that executes a handler after a specified interval.
///
/// This class provides a simple interface for creating timers that can be cancelled
/// and reset. It is designed to work with any clock implementation conforming to
/// `ClockProtocol`, making it testable with mock clocks.
///
/// Key behaviors:
/// - Only one timer can be active at a time
/// - Setting a new timer automatically cancels any existing timer
/// - Timers can be explicitly cancelled before they fire
@MainActor
internal final class TimerManager<Clock: ClockProtocol> {
    private var currentTask: Task<Void, Never>?
    private let clock: Clock

    internal init(clock: Clock) {
        self.clock = clock
    }

    /// Sets a timer that will execute the handler after the specified interval.
    ///
    /// If a timer is already running, it will be cancelled and replaced with the new timer.
    /// This allows for timer reset behavior - calling `setTimer` again before the current
    /// timer expires will cancel the existing timer and start a new one from scratch.
    ///
    /// - Parameters:
    ///   - interval: The time interval (in seconds) to wait before executing the handler
    ///   - handler: The closure to execute when the timer fires
    internal func setTimer(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        cancelTimer()

        // Calculate the deadline before kicking off the asynchronous work. This is so that using TestClock's advance(by:) behaves reliably; we want to be sure that even if the Task below is scheduled by the system long after advance(by:) is called, its `sleep` call will still return in response to an advance(by:) call that causes `interval` to have elapsed on the clock relative to the time when `setTimer` was called.
        let deadline = clock.now.advanced(byTimeInterval: interval)

        currentTask = Task {
            // This is for compatibility with the TestClock that we use in the tests; calling `sleep(until:)` with a deadline equal to the current time does _not_ make `sleep(until:)` return immediately; see https://github.com/pointfreeco/swift-clocks/issues/23 (it is not clear from the comments there whether or not this should be considered a misbehaviour; let's handle it either way).
            //
            // (You might ask "why would you call sleep(until:) with a deadline equal to the current time?", but bear in mind — per the above comment about Task scheduling — that this task might get scheduled long after time has advanced relative to the moment that setTimer was called.)
            if clock.now >= deadline {
                handler()
                return
            }

            try? await clock.sleep(until: deadline)
            guard !Task.isCancelled else {
                return
            }
            handler()
        }
    }

    /// Cancels the currently running timer, if any.
    ///
    /// If no timer is running, this method does nothing. After cancellation,
    /// the timer's handler will not be executed.
    internal func cancelTimer() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// Returns whether a timer is currently active.
    ///
    /// - Returns: `true` if a timer is running, `false` otherwise
    internal func hasRunningTask() -> Bool {
        currentTask != nil
    }
}
