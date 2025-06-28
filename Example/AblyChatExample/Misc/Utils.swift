import Ably
import AblyChat

/// Executes closure on the `MainActor` after a delay (in seconds).
func after(_ delay: TimeInterval, closure: @MainActor @escaping () -> Void) {
    Task {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await closure()
    }
}

/// Periodically executes closure on the `MainActor`with interval (in seconds).
func periodic(with interval: TimeInterval, closure: @MainActor @escaping () -> Bool) {
    Task {
        while true {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if await !closure() {
                break
            }
        }
    }
}
