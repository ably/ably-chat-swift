import Ably
import AblyChat

func after(_ delay: TimeInterval, closure: @MainActor @escaping () -> Void) {
    Task {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await closure()
    }
}

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
