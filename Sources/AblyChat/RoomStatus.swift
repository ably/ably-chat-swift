import Ably

/**
 * The different states that a room can be in throughout its lifecycle.
 */
public enum RoomStatus: Sendable, Equatable {
    /**
     * A temporary state for when the room object is first initialized.
     */
    case initialized

    /**
     * The library is currently attempting to attach the room.
     */
    case attaching(error: ARTErrorInfo?)

    /**
     * The room is currently attached and receiving events.
     */
    case attached

    /**
     * The room is currently detaching and will not receive events.
     */
    case detaching

    /**
     * The room is currently detached and will not receive events.
     */
    case detached

    /**
     * The room is in an extended state of detachment, but will attempt to re-attach when able.
     */
    case suspended(error: ARTErrorInfo)

    /**
     * The room is currently detached and will not attempt to re-attach. User intervention is required.
     */
    case failed(error: ARTErrorInfo)

    /**
     * The room is in the process of releasing. Attempting to use a room in this state may result in undefined behavior.
     */
    case releasing

    /**
     * The room has been released and is no longer usable.
     */
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
