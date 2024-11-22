import Foundation

internal final actor TimerManager {
    private var currentTask: Task<Void, Never>?

    internal func setTimer(interval: TimeInterval, handler: @escaping @Sendable () -> Void) {
        cancelTimer()

        currentTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
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
