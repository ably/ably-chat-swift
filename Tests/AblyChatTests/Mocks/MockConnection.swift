import Ably
@testable import AblyChat

final class MockConnection: InternalConnectionProtocol {
    let state: ARTRealtimeConnectionState

    let errorReason: ErrorInfo?

    init(state: ARTRealtimeConnectionState = .initialized, errorReason: ErrorInfo? = nil) {
        self.state = state
        self.errorReason = errorReason
    }

    func on(_: @escaping @MainActor (ConnectionStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    func off(_: ARTEventListener) {
        fatalError("Not implemented")
    }
}
