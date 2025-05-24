@testable import AblyChat
import Foundation

@MainActor
internal final class MockTimerManager: TimerManagerProtocol {
    let callRecorder = MockMethodCallRecorder()

    private var handler: (@MainActor @Sendable () -> Void)?

    internal func setTimer(interval: TimeInterval, handler: @escaping @MainActor @Sendable () -> Void) {
        callRecorder.addRecord(
            signature: "setTimer(interval:handler:)",
            arguments: ["interval": interval]
        )
        self.handler = handler
    }

    internal func cancelTimer() {
        handler = nil
        callRecorder.addRecord(
            signature: "cancelTimer",
            arguments: [:]
        )
    }

    internal func hasRunningTask() -> Bool {
        handler != nil
    }

    internal func expireTimer() {
        handler?()
    }
}
