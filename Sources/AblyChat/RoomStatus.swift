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
