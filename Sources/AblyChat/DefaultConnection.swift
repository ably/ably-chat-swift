import Ably

internal final class DefaultConnection: Connection {
    private let realtime: any InternalRealtimeClientProtocol
    private let timerManager = TimerManager(clock: SystemClock())

    // (CHA-CS2a) The chat client must expose its current connection status.
    internal var status: ConnectionStatus {
        .fromRealtimeConnectionState(realtime.connection.state)
    }

    // (CHA-CS2b) The chat client must expose the latest error, if any, associated with its current status.
    internal var error: ARTErrorInfo? {
        realtime.connection.errorReason
    }

    internal init(realtime: any InternalRealtimeClientProtocol) {
        // (CHA-CS3) The initial status and error of the connection will be whatever status the realtime client returns whilst the connection status object is constructed.
        self.realtime = realtime
    }

    // (CHA-CS4d) Clients must be able to register a listener for connection status events and receive such events.
    @discardableResult
    internal func onStatusChange(_ callback: @escaping @MainActor (ConnectionStatusChange) -> Void) -> some StatusSubscriptionProtocol {
        // (CHA-CS5) The chat client must monitor the underlying realtime connection for connection status changes.
        let eventListener = realtime.connection.on { [weak self] stateChange in
            guard let self else {
                return
            }
            let currentState = ConnectionStatus.fromRealtimeConnectionState(stateChange.current)
            let previousState = ConnectionStatus.fromRealtimeConnectionState(stateChange.previous)

            // (CHA-CS4a) Connection status update events must contain the newly entered connection status.
            // (CHA-CS4b) Connection status update events must contain the previous connection status.
            // (CHA-CS4c) Connection status update events must contain the connection error (if any) that pertains to the newly entered connection status.
            let statusChange = ConnectionStatusChange(
                current: currentState,
                previous: previousState,
                error: stateChange.reason,
                retryIn: stateChange.retryIn,
            )

            let isTimerRunning = timerManager.hasRunningTask()
            //  (CHA-CS5a) The chat client must suppress transient disconnection events. It is not uncommon for Ably servers to perform connection shedding to balance load, or due to retiring. Clients should not need to concern themselves with transient events.

            // (CHA-CS5a2) If a transient disconnect timer is active and the realtime connection status changes to `DISCONNECTED` or `CONNECTING`, the library must not emit a status change.
            if isTimerRunning, currentState == .disconnected || currentState == .connecting {
                return
            }

            // (CHA-CS5a3) If a transient disconnect timer is active and the realtime connections status changes to `CONNECTED`, `SUSPENDED` or `FAILED`, the library shall cancel the transient disconnect timer. The superseding status change shall be emitted.
            if isTimerRunning, currentState == .connected || currentState == .suspended || currentState == .failed {
                timerManager.cancelTimer()
                callback(statusChange)
            }

            // (CHA-CS5a1) If the realtime connection status transitions from `CONNECTED` to `DISCONNECTED`, the chat client connection status must not change. A 5 second transient disconnect timer shall be started.
            if previousState == .connected, currentState == .disconnected, !isTimerRunning {
                timerManager.setTimer(interval: 5.0) { [timerManager] in
                    // (CHA-CS5a4) If a transient disconnect timer expires the library shall emit a connection status change event. This event must contain the current status of of timer expiry, along with the original error that initiated the transient disconnect timer.
                    timerManager.cancelTimer()
                    callback(statusChange)
                }
                return
            }

            if isTimerRunning {
                timerManager.cancelTimer()
            }

            // (CHA-CS5b) Not withstanding CHA-CS5a. If a connection state event is observed from the underlying realtime library, the client must emit a status change event. The current status of that event shall reflect the status change in the underlying realtime library, along with the accompanying error.
            callback(statusChange)
        }

        return DefaultStatusSubscription { [weak self] in
            guard let self else {
                return
            }
            timerManager.cancelTimer()
            realtime.connection.off(eventListener)
        }
    }
}
