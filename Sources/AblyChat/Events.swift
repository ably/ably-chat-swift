import Ably

/**
 * Chat Message Actions.
 */
public enum ChatMessageAction: Sendable {
    /**
     * Action applied to a new message.
     */
    case messageCreate
    // swiftlint:disable:next missing_docs
    case messageUpdate
    // swiftlint:disable:next missing_docs
    case messageDelete

    internal static func fromRealtimeAction(_ action: ARTMessageAction) -> Self? {
        switch action {
        case .create:
            .messageCreate
        case .update:
            .messageUpdate
        case .delete:
            .messageDelete
        // ignore any other actions for now (CHA-M4k11)
        case .meta,
             .messageSummary:
            nil
        @unknown default:
            nil
        }
    }
}

extension ChatMessageAction: InternalRawRepresentable {
    internal typealias RawValue = String

    internal enum Wire: String, Sendable {
        case create = "message.create"
        case update = "message.update"
        case delete = "message.delete"
    }

    internal init?(rawValue: String) {
        switch Wire(rawValue: rawValue) {
        case .create:
            self = .messageCreate
        case .update:
            self = .messageUpdate
        case .delete:
            self = .messageDelete
        default:
            return nil
        }
    }

    internal var rawValue: String {
        switch self {
        case .messageCreate:
            Wire.create.rawValue
        case .messageUpdate:
            Wire.update.rawValue
        case .messageDelete:
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
    // swiftlint:disable:next missing_docs
    case started
    // swiftlint:disable:next missing_docs
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
    // swiftlint:disable:next missing_docs
    case setChanged

    internal var rawValue: String {
        switch self {
        case .setChanged:
            "typing.set.changed"
        }
    }
}
