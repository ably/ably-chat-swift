import Ably

/**
 * Represents a connection to Ably.
 */
public protocol Connection: AnyObject, Sendable {
    /**
     * The current status of the connection.
     */
    var status: ConnectionStatus { get async }

    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/12): consider how to avoid the need for an unwrap
    /**
     * The current error, if any, that caused the connection to enter the current status.
     */
    var error: ARTErrorInfo? { get async }

    /**
     * Registers a listener that will be called whenever the connection status changes.
     * @param listener The function to call when the status changes.
     * @returns An object that can be used to unregister the listener.
     */
    func onStatusChange(bufferingPolicy: BufferingPolicy) -> Subscription<ConnectionStatusChange>
}

public enum ConnectionStatus: Sendable {
    // (CHA-CS1a) The INITIALIZED status is a default status when the realtime client is first initialized. This value will only (likely) be seen if the realtime client doesn’t have autoconnect turned on.
    case initialized
    // (CHA-CS1b) The CONNECTING status is used when the client is in the process of connecting to Ably servers.
    case connecting
    // (CHA-CS1c) The CONNECTED status is used when the client connected to Ably servers.
    case connected
    // (CHA-CS1d) The DISCONNECTED status is used when the client is not currently connected to Ably servers. This state may be temporary as the underlying Realtime SDK seeks to reconnect.
    case disconnected
    // (CHA-CS1e) The SUSPENDED status is used when the client is in an extended state of disconnection, but will attempt to reconnect.
    case suspended
    // (CHA-CS1f) The FAILED status is used when the client is disconnected from the Ably servers due to some non-retriable failure such as authentication failure. It will not attempt to reconnect.
    case failed

    internal init(from realtimeConnectionState: ARTRealtimeConnectionState) {
        switch realtimeConnectionState {
        case .initialized:
            self = .initialized
        case .connecting:
            self = .connecting
        case .connected:
            self = .connected
        case .disconnected:
            self = .disconnected
        case .suspended:
            self = .suspended
        case .failed, .closing, .closed:
            self = .failed
        @unknown default:
            self = .failed
        }
    }
}

public struct ConnectionStatusChange: Sendable {
    public var current: ConnectionStatus
    public var previous: ConnectionStatus
    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/12): consider how to avoid the need for an unwrap
    public var error: ARTErrorInfo?
    public var retryIn: TimeInterval

    public init(current: ConnectionStatus, previous: ConnectionStatus, error: ARTErrorInfo? = nil, retryIn: TimeInterval) {
        self.current = current
        self.previous = previous
        self.error = error
        self.retryIn = retryIn
    }
}
