import Ably

public protocol RoomStatus: AnyObject, Sendable {
    var current: RoomLifecycle { get async }
    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/12): consider how to avoid the need for an unwrap
    var error: ARTErrorInfo? { get async }
    func onChange(bufferingPolicy: BufferingPolicy) async -> Subscription<RoomStatusChange>
}

public enum RoomLifecycle: Sendable {
    case initialized
    case attaching
    case attached
    case detaching
    case detached
    case suspended
    case failed
    case releasing
    case released
}

public struct RoomStatusChange: Sendable {
    public var current: RoomLifecycle
    public var previous: RoomLifecycle
    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/12): consider how to avoid the need for an unwrap
    public var error: ARTErrorInfo?

    public init(current: RoomLifecycle, previous: RoomLifecycle, error: ARTErrorInfo? = nil) {
        self.current = current
        self.previous = previous
        self.error = error
    }
}

internal actor DefaultRoomStatus: RoomStatus {
    internal private(set) var current: RoomLifecycle = .initialized
    internal private(set) var error: ARTErrorInfo?

    private let logger: InternalLogger

    internal init(logger: InternalLogger) {
        self.logger = logger
    }

    // TODO: clean up old subscriptions (https://github.com/ably-labs/ably-chat-swift/issues/36)
    private var subscriptions: [Subscription<RoomStatusChange>] = []

    internal func onChange(bufferingPolicy: BufferingPolicy) -> Subscription<RoomStatusChange> {
        let subscription: Subscription<RoomStatusChange> = .init(bufferingPolicy: bufferingPolicy)
        subscriptions.append(subscription)
        return subscription
    }

    /// Sets ``current`` to the given state, and emits a status change to all subscribers added via ``onChange(bufferingPolicy:)``.
    internal func transition(to newState: RoomLifecycle) {
        logger.log(message: "Transitioning to \(newState)", level: .debug)
        let statusChange = RoomStatusChange(current: newState, previous: current)
        current = newState
        for subscription in subscriptions {
            subscription.emit(statusChange)
        }
    }
}
