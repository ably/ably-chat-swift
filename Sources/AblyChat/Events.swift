import Ably

/**
 * Chat Message Actions.
 */
public enum MessageAction: Sendable {
    /**
     * Action applied to a new message.
     */
    case create
    case update
    case delete

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

extension MessageAction: InternalRawRepresentable {
    internal typealias RawValue = String

    internal enum Wire: String, Sendable {
        case create = "message.create"
        case update = "message.update"
        case delete = "message.delete"
    }

    internal init?(rawValue: String) {
        switch Wire(rawValue: rawValue) {
        case .create:
            self = .create
        case .update:
            self = .update
        case .delete:
            self = .delete
        default:
            return nil
        }
    }

    internal var rawValue: String {
        switch self {
        case .create:
            Wire.create.rawValue
        case .update:
            Wire.update.rawValue
        case .delete:
            Wire.delete.rawValue
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
public enum TypingEventType: Sendable {
    case started
    case stopped

    internal var rawValue: String {
        switch self {
        case .started:
            "typing.started"
        case .stopped:
            "typing.stopped"
        }
    }
}

/// Enum representing the typing set event types.
public enum TypingSetEventType: Sendable {
    case setChanged

    internal var rawValue: String {
        switch self {
        case .setChanged:
            "typing.set.changed"
        }
    }
}
