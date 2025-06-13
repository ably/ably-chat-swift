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

        currentTask = Task {
            try? await clock.sleep(for: .seconds(interval))
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
