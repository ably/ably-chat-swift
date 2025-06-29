import Ably
import AblyChat
import SwiftUI

/// Executes closure on the `MainActor` after a delay (in seconds).
func after(_ delay: TimeInterval, closure: @MainActor @escaping () -> Void) {
    Task {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await closure()
    }
}

/// Periodically executes closure on the `MainActor`with interval (in seconds).
func periodic(with interval: @escaping @MainActor @Sendable () -> Double, closure: @escaping @MainActor () -> Bool) {
    Task {
        while true {
            try? await Task.sleep(nanoseconds: UInt64(interval() * 1_000_000_000))
            if await !closure() {
                break
            }
        }
    }
}

@MainActor
func byChance(_ probability: Double) -> Bool {
    var chance = probability
    if chance <= 1 {
        chance = probability * 100
    }
    if [Int](1 ... 100).randomElement()! <= Int(chance) {
        return true
    }
    return false
}

extension View {
    func padding(left: CGFloat) -> some View {
        padding(.leading, left)
    }

    func padding(right: CGFloat) -> some View {
        padding(.trailing, right)
    }

    func padding(top: CGFloat) -> some View {
        padding(.top, top)
    }

    func padding(bottom: CGFloat) -> some View {
        padding(.bottom, bottom)
    }
}
