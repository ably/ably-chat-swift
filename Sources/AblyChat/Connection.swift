import Ably

/**
 * Represents a connection to Ably.
 */
@MainActor
public protocol Connection: AnyObject, Sendable {
    // swiftlint:disable:next missing_docs
    associatedtype StatusSubscription: AblyChat.StatusSubscription

    /**
     * The current status of the connection.
     */
    var status: ConnectionStatus { get }

    /**
     * The current error, if any, that caused the connection to enter the current status.
     */
    var error: ErrorInfo? { get }

    /**
     * Subscribes a given listener to a connection status changes.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing ``ConnectionStatusChange`` events.
     *
     * - Returns: A subscription that can be used to unsubscribe from ``ConnectionStatusChange`` events.
     */
    @discardableResult
    func onStatusChange(_ callback: @escaping @MainActor (ConnectionStatusChange) -> Void) -> StatusSubscription
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
    func onStatusChange(bufferingPolicy: BufferingPolicy) -> SubscriptionAsyncSequence<ConnectionStatusChange> {
        let subscriptionAsyncSequence = SubscriptionAsyncSequence<ConnectionStatusChange>(bufferingPolicy: bufferingPolicy)

        let subscription = onStatusChange { statusChange in
            subscriptionAsyncSequence.emit(statusChange)
        }

        subscriptionAsyncSequence.addTerminationHandler {
            Task { @MainActor in
                subscription.off()
            }
        }

        return subscriptionAsyncSequence
    }

    /// Same as calling ``onStatusChange(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    func onStatusChange() -> SubscriptionAsyncSequence<ConnectionStatusChange> {
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

    internal static func fromRealtimeConnectionState(_ state: ARTRealtimeConnectionState) -> Self {
        switch state {
        case .initialized:
            .initialized
        case .connecting:
            .connecting
        case .connected:
            .connected
        case .disconnected:
            .disconnected
        case .suspended:
            .suspended
        case .failed, .closing, .closed:
            .failed
        @unknown default:
            .failed
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

    /**
     * An error that provides a reason why the connection has
     * entered the new status, if applicable.
     */
    public var error: ErrorInfo?

    /**
     * The time in milliseconds that the client will wait before attempting to reconnect.
     */
    public var retryIn: TimeInterval?

    /// Memberwise initializer to create a `ConnectionStatusChange`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(current: ConnectionStatus, previous: ConnectionStatus, error: ErrorInfo? = nil, retryIn: TimeInterval?) {
        self.current = current
        self.previous = previous
        self.error = error
        self.retryIn = retryIn
    }
}
