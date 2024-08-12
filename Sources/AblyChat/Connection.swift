import Ably

public protocol Connection: AnyObject, Sendable {
    var status: any ConnectionStatus { get }
}

public protocol ConnectionStatus: AnyObject, Sendable {
    var current: ConnectionLifecycle { get }
    var error: ARTErrorInfo? { get }
    func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<ConnectionStatusChange>
}

public enum ConnectionLifecycle: Sendable {
    case initialized
    case connecting
    case connected
    case disconnected
    case suspended
    case failed
}

public struct ConnectionStatusChange: Sendable {
    public var current: ConnectionLifecycle
    public var previous: ConnectionLifecycle
    public var error: ARTErrorInfo?
    public var retryIn: TimeInterval

    public init(current: ConnectionLifecycle, previous: ConnectionLifecycle, error: ARTErrorInfo? = nil, retryIn: TimeInterval) {
        self.current = current
        self.previous = previous
        self.error = error
        self.retryIn = retryIn
    }
}
