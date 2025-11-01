import Ably
@testable import AblyChat

final class MockConnection: InternalConnectionProtocol {
    var state: ARTRealtimeConnectionState

    var errorReason: ErrorInfo?

    private var listeners: [(ARTEventListener, @MainActor (ConnectionStateChange) -> Void)] = []

    init(state: ARTRealtimeConnectionState = .initialized, errorReason: ErrorInfo? = nil) {
        self.state = state
        self.errorReason = errorReason
    }

    func on(_ callback: @escaping @MainActor (ConnectionStateChange) -> Void) -> ARTEventListener {
        let listener = ARTEventListener()
        listeners.append((listener, callback))
        return listener
    }

    func off(_ listener: ARTEventListener) {
        listeners.removeAll { $0.0 === listener }
    }

    // Helper method to emit state changes for testing
    func emit(
        _ newState: ARTRealtimeConnectionState,
        event: ARTRealtimeConnectionEvent,
        error: ErrorInfo? = nil,
        retryIn: TimeInterval? = nil,
    ) {
        let previousState = state
        state = newState
        if let error {
            errorReason = error
        }

        let stateChange = ConnectionStateChange(
            current: newState,
            previous: previousState,
            event: event,
            reason: error,
            retryIn: retryIn ?? 0,
        )

        for (_, callback) in listeners {
            callback(stateChange)
        }
    }
}
