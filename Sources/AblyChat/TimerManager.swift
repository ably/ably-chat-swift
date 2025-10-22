import Foundation

@MainActor
internal final class TimerManager<Clock: ClockProtocol> {
    private var currentTask: Task<Void, Never>?
    private let clock: Clock

    internal init(clock: Clock) {
        self.clock = clock
    }

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

    internal func cancelTimer() {
        currentTask?.cancel()
        currentTask = nil
    }

    internal func hasRunningTask() -> Bool {
        currentTask != nil
    }
}
