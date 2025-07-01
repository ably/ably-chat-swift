import Ably

/**
 * Chat Message Actions.
 */
public enum MessageAction: String, Sendable {
    /**
     * Action applied to a new message.
     */
    case create = "message.create"
    case update = "message.update"
    case delete = "message.delete"

    internal static func fromRealtimeAction(_ action: ARTMessageAction) -> Self? {
        switch action {
        case .create:
            .create
        case .update:
            .update
        case .delete:
            .delete
        // ignore any other actions except `message.create` for now
        case .meta,
             .messageSummary:
            nil
        @unknown default:
            nil
        }
    }
}

/// Realtime chat message names.
internal enum RealtimeMessageName: String, Sendable {
    /// Represents a regular chat message.
    case chatMessage = "chat.message"
}

internal enum RoomReactionEvents: String {
    case reaction = "roomReaction"
}

internal enum OccupancyEvents: String {
    case meta = "[meta]occupancy"
}

/// Enum representing the typing event types.
public enum TypingEventType: String, Sendable {
    case started = "typing.started"
    case stopped = "typing.stopped"
}

/// Enum representing the typing set event types.
public enum TypingSetEventType: String, Sendable {
    case setChanged = "typing.set.changed"
}
