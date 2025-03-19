import Ably
@testable import AblyChat

final class MockConnection: NSObject, InternalConnectionProtocol {
    let state: ARTRealtimeConnectionState

    let errorReason: ARTErrorInfo?

    init(state: ARTRealtimeConnectionState = .initialized, errorReason: ARTErrorInfo? = nil) {
        self.state = state
        self.errorReason = errorReason
    }

    func on(_: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    func off(_: ARTEventListener) {
        fatalError("Not implemented")
    }
}
