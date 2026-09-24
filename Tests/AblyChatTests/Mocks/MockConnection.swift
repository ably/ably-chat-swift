@testable import AblyChat
import AblyPubSubDevice

final class MockConnection: InternalConnectionProtocol {
    let state: RealtimeConnectionState

    let errorReason: ErrorInfo?

    init(state: RealtimeConnectionState = .initialized, errorReason: ErrorInfo? = nil) {
        self.state = state
        self.errorReason = errorReason
    }

    func on(_: @escaping @MainActor (ConnectionStateChange) -> Void) -> EventListener {
        fatalError("Not implemented")
    }

    func off(_: EventListener) {
        fatalError("Not implemented")
    }
}
