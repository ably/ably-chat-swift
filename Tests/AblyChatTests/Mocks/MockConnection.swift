import Ably
@testable import AblyChat

final class MockConnection: InternalConnectionProtocol {
    let state: ARTRealtimeConnectionState

    let errorReason: ARTErrorInfo?

    private var stateCallback: ((ARTConnectionStateChange) -> Void)?

    init(state: ARTRealtimeConnectionState = .initialized, errorReason: ARTErrorInfo? = nil) {
        self.state = state
        self.errorReason = errorReason
    }

    func on(_ callback: @escaping @MainActor (ARTConnectionStateChange) -> Void) -> ARTEventListener {
        stateCallback = callback
        return ARTEventListener()
    }

    func off(_: ARTEventListener) {
        stateCallback = nil
    }

    func off() {
        fatalError("Not implemented")
    }
}
