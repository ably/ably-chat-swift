import Ably

/**
 * Chat Message Actions.
 */
public enum MessageAction: String, Codable, Sendable {
    /**
     * Action applied to a new message.
     */
    case create = "message.create"

    internal static func fromRealtimeAction(_ action: ARTMessageAction) -> Self? {
        switch action {
        case .create:
            .create
        // ignore any other actions except `message.create` for now
        case .unset,
             .update,
             .delete,
             .annotationCreate,
             .annotationDelete,
             .metaOccupancy:
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
