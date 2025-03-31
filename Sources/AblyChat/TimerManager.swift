import Foundation

@MainActor
internal final class TimerManager {
    private var currentTask: Task<Void, Never>?
    private var scheduledTime: Date?
    private let clock: ClockProvider

    internal init(clock: ClockProvider = SystemClock()) {
        self.clock = clock
    }

    internal func setTimer(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        cancelTimer()
        scheduledTime = clock.now().addingTimeInterval(interval)

        currentTask = Task {
            while !Task.isCancelled {
                // Check if we've reached the scheduled time
                if let scheduledTime, clock.now() >= scheduledTime {
                    guard !Task.isCancelled else {
                        return
                    }
                    handler()
                    break
                }
                await Task.yield()
            }
        }
    }

    internal func cancelTimer() {
        currentTask?.cancel()
        currentTask = nil
        scheduledTime = nil
    }

    internal func hasRunningTask() -> Bool {
        currentTask != nil
    }
}
