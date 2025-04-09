import Foundation

internal protocol TimerManagerProtocol: Actor {
    func setTimer(interval: TimeInterval, handler: @escaping @Sendable () -> Void)
    func cancelTimer()
    func hasRunningTask() -> Bool
}

internal final actor TimerManager: TimerManagerProtocol {
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
