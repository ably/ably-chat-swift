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

        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            // TODO: Explain
            currentTask = Task.immediate {
                try? await clock.sleep(for: .seconds(interval))
                guard !Task.isCancelled else {
                    return
                }
                handler()
            }
        } else {
            fatalError("Task.immediate is required for tests")
            // TODO: Fallback on earlier versions
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
