import Ably
import AblyChat

final class MockConnection: NSObject, ConnectionProtocol, @unchecked Sendable {
    let id: String?

    let key: String?

    let maxMessageSize: Int = 0

    let state: ARTRealtimeConnectionState

    let errorReason: ARTErrorInfo?

    let recoveryKey: String?

    private var stateCallback: ((ARTConnectionStateChange) -> Void)?

    init(id: String? = nil, key: String? = nil, state: ARTRealtimeConnectionState = .initialized, errorReason: ARTErrorInfo? = nil, recoveryKey: String? = nil) {
        self.id = id
        self.key = key
        self.state = state
        self.errorReason = errorReason
        self.recoveryKey = recoveryKey
    }

    func createRecoveryKey() -> String? {
        fatalError("Not implemented")
    }

    func connect() {
        fatalError("Not implemented")
    }

    func close() {
        fatalError("Not implemented")
    }

    func ping(_: @escaping ARTCallback) {
        fatalError("Not implemented")
    }

    func on(_: ARTRealtimeConnectionEvent, callback _: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    func on(_ callback: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
        stateCallback = callback
        return ARTEventListener()
    }

    func once(_: ARTRealtimeConnectionEvent, callback _: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    func once(_: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
        fatalError("Not implemented")
    }

    func off(_: ARTRealtimeConnectionEvent, listener _: ARTEventListener) {
        fatalError("Not implemented")
    }

    func off(_: ARTEventListener) {
        stateCallback = nil
    }

    func off() {
        fatalError("Not implemented")
    }

    func transitionToState(_ state: ARTRealtimeConnectionState, event: ARTRealtimeConnectionEvent, error: ARTErrorInfo? = nil) {
        let stateChange = ARTConnectionStateChange(current: state, previous: self.state, event: event, reason: error)
        stateCallback?(stateChange)
    }
}
