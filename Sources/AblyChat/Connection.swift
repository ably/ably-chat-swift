import Ably

/**
 * Represents a connection to Ably.
 */
@MainActor
public protocol Connection: AnyObject, Sendable {
    /**
     * The current status of the connection.
     */
    var status: ConnectionStatus { get }

    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/12): consider how to avoid the need for an unwrap
    /**
     * The current error, if any, that caused the connection to enter the current status.
     */
    var error: ARTErrorInfo? { get }

    /**
     * Subscribes a given listener to a connection status changes.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing ``ConnectionStatusChange`` events.
     *
     * - Returns: A subscription handler that can be used to unsubscribe from ``ConnectionStatusChange`` events.
     */
    @discardableResult
    func onStatusChange(_ callback: @escaping @MainActor (ConnectionStatusChange) -> Void) -> SubscriptionHandle

    /// Same as calling ``onStatusChange(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Connection` protocol provides a default implementation of this method.
    func onStatusChange() -> Subscription<ConnectionStatusChange>
}

/// `AsyncSequence` variant of `Connection` status changes.
public extension Connection {
    /**
     * Subscribes a given listener to a connection status changes.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``ConnectionStatusChange`` events.
     */
    func onStatusChange(bufferingPolicy: BufferingPolicy) -> Subscription<ConnectionStatusChange> {
        let subscription = Subscription<ConnectionStatusChange>(bufferingPolicy: bufferingPolicy)

        let subscriptionHandle = onStatusChange { statusChange in
            subscription.emit(statusChange)
        }

        subscription.addTerminationHandler {
            Task { @MainActor in
                subscriptionHandle.unsubscribe()
            }
        }

        return subscription
    }

    /**
     * Subscribes a given listener to a connection status changes with the default `unbounded` buffering policy.
     */
    func onStatusChange() -> Subscription<ConnectionStatusChange> {
        onStatusChange(bufferingPolicy: .unbounded)
    }
}

/**
 * The different states that the connection can be in through its lifecycle.
 */
public enum ConnectionStatus: Sendable {
    // (CHA-CS1a) The INITIALIZED status is a default status when the realtime client is first initialized. This value will only (likely) be seen if the realtime client doesn’t have autoconnect turned on.

    /**
     * A temporary state for when the library is first initialized.
     */
    case initialized

    // (CHA-CS1b) The CONNECTING status is used when the client is in the process of connecting to Ably servers.

    /**
     * The library is currently connecting to Ably.
     */
    case connecting

    // (CHA-CS1c) The CONNECTED status is used when the client connected to Ably servers.

    /**
     * The library is currently connected to Ably.
     */
    case connected

    // (CHA-CS1d) The DISCONNECTED status is used when the client is not currently connected to Ably servers. This state may be temporary as the underlying Realtime SDK seeks to reconnect.

    /**
     * The library is currently disconnected from Ably, but will attempt to reconnect.
     */
    case disconnected

    // (CHA-CS1e) The SUSPENDED status is used when the client is in an extended state of disconnection, but will attempt to reconnect.

    /**
     * The library is in an extended state of disconnection, but will attempt to reconnect.
     */
    case suspended

    // (CHA-CS1f) The FAILED status is used when the client is disconnected from the Ably servers due to some non-retriable failure such as authentication failure. It will not attempt to reconnect.

    /**
     * The library is currently disconnected from Ably and will not attempt to reconnect.
     */
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

/**
 * Represents a change in the status of the connection.
 */
public struct ConnectionStatusChange: Sendable {
    /**
     * The new status of the connection.
     */
    public var current: ConnectionStatus

    /**
     * The previous status of the connection.
     */
    public var previous: ConnectionStatus

    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/12): consider how to avoid the need for an unwrap
    /**
     * An error that provides a reason why the connection has
     * entered the new status, if applicable.
     */
    public var error: ARTErrorInfo?

    /**
     * The time in milliseconds that the client will wait before attempting to reconnect.
     */
    public var retryIn: TimeInterval

    public init(current: ConnectionStatus, previous: ConnectionStatus, error: ARTErrorInfo? = nil, retryIn: TimeInterval) {
        self.current = current
        self.previous = previous
        self.error = error
        self.retryIn = retryIn
    }
}
