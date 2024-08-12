import Ably

public protocol RoomStatus: AnyObject, Sendable {
    // TODO: questions re API here also apply to ConnectionStatus

    var current: RoomLifecycle { get }
    // TODO: should this be part of the RoomLifecycle enum instead?
    var error: ARTErrorInfo? { get }
    // TODO: is it weird to have a sequence of status changes?
    func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<RoomStatusChange>
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
    // TODO: tie this to the state
    public var error: ARTErrorInfo?

    public init(current: RoomLifecycle, previous: RoomLifecycle, error: ARTErrorInfo? = nil) {
        self.current = current
        self.previous = previous
        self.error = error
    }
}
