@testable import AblyChat
import Foundation

internal final actor MockTimerManager: TimerManagerProtocol {
    let callRecorder = MockMethodCallRecorder()

    private var handler: (@Sendable () -> Void)?

    internal func setTimer(interval: TimeInterval, handler: @escaping @Sendable () -> Void) {
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
