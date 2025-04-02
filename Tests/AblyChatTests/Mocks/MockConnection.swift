import Ably
@testable import AblyChat

final class MockConnection: InternalConnectionProtocol {
    let state: ARTRealtimeConnectionState

    let errorReason: ARTErrorInfo?

    init(state: ARTRealtimeConnectionState = .initialized, errorReason: ARTErrorInfo? = nil) {
        self.state = state
        self.errorReason = errorReason
    }

    func on(_: @escaping @MainActor (ARTConnectionStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    func off(_: ARTEventListener) {
        fatalError("Not implemented")
    }
}
