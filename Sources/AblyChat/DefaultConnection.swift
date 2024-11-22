import Ably

// TODO: I'm not too keen on this class in the way it is... I had a few difficulties keeping a mutable status and error on the class (due to Sendable conformance). I had to resort to using an actor to manage the status and error. This then meant needing to change the `Connection` protocol so `state` and `error` have async getters. To make things more complicated, Swift supports async getters but not async setters (and it doesn't allow you to mix a sync setter with an async getter). You call the relevant methods on the actor to update the status and error. We should revisit this as part of wider concurrency concerns here: https://github.com/ably-labs/ably-chat-swift/issues/49
internal final class DefaultConnection: Connection {
    // (CHA-CS2a) The chat client must expose its current connection status.
    internal var status: ConnectionStatus {
        get async { await connectionStatusManager.status }
    }

    // (CHA-CS2b) The chat client must expose the latest error, if any, associated with its current status.
    internal var error: ARTErrorInfo? {
        get async { await connectionStatusManager.error }
    }

    private let realtime: any RealtimeClientProtocol
    private let timerManager = TimerManager()
    private let connectionStatusManager = ConnectionStatusManager()

    internal init(realtime: any RealtimeClientProtocol) {
        // (CHA-CS3) The initial status and error of the connection will be whatever status the realtime client returns whilst the connection status object is constructed.
        self.realtime = realtime
        Task {
            await connectionStatusManager.updateStatus(to: .init(from: realtime.connection.state))
            await connectionStatusManager.updateError(to: realtime.connection.errorReason)
        }
    }

    // (CHA-CS4d) Clients must be able to register a listener for connection status events and receive such events.
    internal func onStatusChange(bufferingPolicy: BufferingPolicy) -> Subscription<ConnectionStatusChange> {
        let subscription = Subscription<ConnectionStatusChange>(bufferingPolicy: bufferingPolicy)

        // (CHA-CS5) The chat client must monitor the underlying realtime connection for connection status changes.
        realtime.connection.on { [weak self] stateChange in
            guard let self else {
                return
            }
            let currentState = ConnectionStatus(from: stateChange.current)
            let previousState = ConnectionStatus(from: stateChange.previous)

            // (CHA-CS4a) Connection status update events must contain the newly entered connection status.
            // (CHA-CS4b) Connection status update events must contain the previous connection status.
            // (CHA-CS4c) Connection status update events must contain the connection error (if any) that pertains to the newly entered connection status.
            let statusChange = ConnectionStatusChange(
                current: currentState,
                previous: previousState,
                error: stateChange.reason,
                retryIn: stateChange.retryIn
            )

            Task {
                let isTimerRunning = await timerManager.hasRunningTask()
                //  (CHA-CS5a) The chat client must suppress transient disconnection events. It is not uncommon for Ably servers to perform connection shedding to balance load, or due to retiring. Clients should not need to concern themselves with transient events.

                // (CHA-CS5a2) If a transient disconnect timer is active and the realtime connection status changes to `DISCONNECTED` or `CONNECTING`, the library must not emit a status change.
                if isTimerRunning, currentState == .disconnected || currentState == .connecting {
                    return
                }

                // (CHA-CS5a3) If a transient disconnect timer is active and the realtime connections status changes to `CONNECTED`, `SUSPENDED` or `FAILED`, the library shall cancel the transient disconnect timer. The superseding status change shall be emitted.
                if isTimerRunning, currentState == .connected || currentState == .suspended || currentState == .failed {
                    await timerManager.cancelTimer()
                    subscription.emit(statusChange)
                    // update local state and error
                    await connectionStatusManager.updateError(to: stateChange.reason)
                    await connectionStatusManager.updateStatus(to: currentState)
                }

                // (CHA-CS5a1) If the realtime connection status transitions from `CONNECTED` to `DISCONNECTED`, the chat client connection status must not change. A 5 second transient disconnect timer shall be started.
                if previousState == .connected, currentState == .disconnected, !isTimerRunning {
                    await timerManager.setTimer(interval: 5.0) { [timerManager, connectionStatusManager] in
                        Task {
                            // (CHA-CS5a4) If a transient disconnect timer expires the library shall emit a connection status change event. This event must contain the current status of of timer expiry, along with the original error that initiated the transient disconnect timer.
                            await timerManager.cancelTimer()
                            subscription.emit(statusChange)

                            // update local state and error
                            await connectionStatusManager.updateError(to: stateChange.reason)
                            await connectionStatusManager.updateStatus(to: currentState)
                        }
                    }
                    return
                }

                if isTimerRunning {
                    await timerManager.cancelTimer()
                }
            }

            // (CHA-CS5b) Not withstanding CHA-CS5a. If a connection state event is observed from the underlying realtime library, the client must emit a status change event. The current status of that event shall reflect the status change in the underlying realtime library, along with the accompanying error.
            subscription.emit(statusChange)
            Task {
                // update local state and error
                await connectionStatusManager.updateError(to: stateChange.reason)
                await connectionStatusManager.updateStatus(to: currentState)
            }
        }

        return subscription
    }
}

private final actor ConnectionStatusManager {
    private(set) var status: ConnectionStatus = .disconnected
    private(set) var error: ARTErrorInfo?

    internal func updateStatus(to newStatus: ConnectionStatus) {
        status = newStatus
    }

    internal func updateError(to newError: ARTErrorInfo?) {
        error = newError
    }
}
