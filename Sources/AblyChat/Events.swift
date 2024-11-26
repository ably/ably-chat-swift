import Ably

public enum MessageAction: String, Codable, Sendable {
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

internal enum RealtimeMessageName: String, Sendable {
    case chatMessage = "chat.message"
}

internal enum RoomReactionEvents: String {
    case reaction = "roomReaction"
}

internal enum OccupancyEvents: String {
    case meta = "[meta]occupancy"
}
