import Ably

/**
 * The different states that a room can be in throughout its lifecycle.
 */
public enum RoomStatus: Sendable {
    /**
     * A temporary state for when the room object is first initialized.
     */
    case initialized

    /**
     * The library is currently attempting to attach the room.
     */
    case attaching

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
    case suspended

    /**
     * The room is currently detached and will not attempt to re-attach. User intervention is required.
     */
    case failed

    /**
     * The room is in the process of releasing. Attempting to use a room in this state may result in undefined behavior.
     */
    case releasing

    /**
     * The room has been released and is no longer usable.
     */
    case released
}

internal enum InternalRoomStatus: Sendable {
    case initialized
    case attaching(error: ARTErrorInfo?)
    case attached(error: ARTErrorInfo?)
    case detaching(error: ARTErrorInfo?)
    case detached(error: ARTErrorInfo?)
    case suspended(error: ARTErrorInfo)
    case failed(error: ARTErrorInfo)
    case releasing
    case released

    internal var toPublicRoomStatus: RoomStatus {
        switch self {
        case .initialized:
            .initialized
        case .attaching:
            .attaching
        case .attached:
            .attached
        case .detaching:
            .detaching
        case .detached:
            .detached
        case .suspended:
            .suspended
        case .failed:
            .failed
        case .releasing:
            .releasing
        case .released:
            .released
        }
    }

    internal var error: ARTErrorInfo? {
        switch self {
        case let .attaching(error):
            error
        case let .attached(error):
            error
        case let .detaching(error):
            error
        case let .detached(error):
            error
        case let .suspended(error):
            error
        case let .failed(error):
            error
        case .initialized,
             .releasing,
             .released:
            nil
        }
    }

    // Helpers to allow us to test whether a `RoomStatus` value has a certain case, without caring about the associated value. These are useful for in contexts where we want to use a `Bool` to communicate a case. For example:
    //
    // 1. testing (e.g.  `#expect(status.isFailed)`)
    // 2. testing that a status does _not_ have a particular case (e.g. if !status.isFailed), which a `case` statement cannot succinctly express

    internal var isAttaching: Bool {
        if case .attaching = self {
            true
        } else {
            false
        }
    }

    internal var isAttached: Bool {
        if case .attached = self {
            true
        } else {
            false
        }
    }

    internal var isDetaching: Bool {
        if case .detaching = self {
            true
        } else {
            false
        }
    }

    internal var isDetached: Bool {
        if case .detached = self {
            true
        } else {
            false
        }
    }

    internal var isSuspended: Bool {
        if case .suspended = self {
            true
        } else {
            false
        }
    }

    internal var isFailed: Bool {
        if case .failed = self {
            true
        } else {
            false
        }
    }

    internal var isReleasing: Bool {
        if case .releasing = self {
            true
        } else {
            false
        }
    }

    internal var isReleased: Bool {
        if case .released = self {
            true
        } else {
            false
        }
    }
}
