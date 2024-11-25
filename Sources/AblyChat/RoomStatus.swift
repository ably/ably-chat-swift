import Ably

// TODO: rename
public enum RoomStatus: Sendable, Equatable {
    case initialized
    case attaching(error: ARTErrorInfo?)
    case attached
    case detaching
    case detached
    case suspended(error: ARTErrorInfo)
    case failed(error: ARTErrorInfo)
    case releasing
    case released

    internal var error: ARTErrorInfo? {
        switch self {
        case let .attaching(error):
            error
        case let .suspended(error):
            error
        case let .failed(error):
            error
        case .initialized,
             .attached,
             .detaching,
             .detached,
             .releasing,
             .released:
            nil
        }
    }

    // Helpers to allow us to test whether a `RoomStatus` value has a certain case, without caring about the associated value. These are useful for in contexts where we want to use a `Bool` to communicate a case. For example:
    //
    // 1. testing (e.g.  `#expect(status.isFailed)`)
    // 2. testing that a status does _not_ have a particular case (e.g. if !status.isFailed), which a `case` statement cannot succinctly express

    public var isAttaching: Bool {
        if case .attaching = self {
            true
        } else {
            false
        }
    }

    public var isSuspended: Bool {
        if case .suspended = self {
            true
        } else {
            false
        }
    }

    public var isFailed: Bool {
        if case .failed = self {
            true
        } else {
            false
        }
    }
}
