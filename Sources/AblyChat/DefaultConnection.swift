import Ably

internal final class DefaultConnection: Connection {
    private let realtime: any InternalRealtimeClientProtocol

    // (CHA-CS2a) The chat client must expose its current connection status.
    internal var status: ConnectionStatus {
        .fromRealtimeConnectionState(realtime.connection.state)
    }

    // (CHA-CS2b) The chat client must expose the latest error, if any, associated with its current status.
    internal var error: ErrorInfo? {
        realtime.connection.errorReason
    }

    internal init(realtime: any InternalRealtimeClientProtocol) {
        // (CHA-CS3) The initial status and error of the connection will be whatever status the realtime client returns whilst the connection status object is constructed.
        self.realtime = realtime
    }

    // (CHA-CS4d) Clients must be able to register a listener for connection status events and receive such events.
    @discardableResult
    internal func onStatusChange(_ callback: @escaping @MainActor (ConnectionStatusChange) -> Void) -> some StatusSubscription {
        // (CHA-CS5) The chat client must monitor the underlying realtime connection for connection status changes.
        let eventListener = realtime.connection.on { [weak self] stateChange in
            guard self != nil else {
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
                // TODO: Actually emit `nil` when appropriate (we can't currently since ably-cocoa's corresponding property is mis-typed): https://github.com/ably/ably-chat-swift/issues/394
                retryIn: stateChange.retryIn,
            )

            // (CHA-CS5c) The current status of that event shall reflect the status change in the underlying realtime library, along with the accompanying error.
            callback(statusChange)
        }

        return DefaultStatusSubscription { [weak self] in
            guard let self else {
                return
            }
            realtime.connection.off(eventListener)
        }
    }
}
