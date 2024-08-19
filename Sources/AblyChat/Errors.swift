import Ably

/**
 The error domain used for the ``Ably.ARTErrorInfo`` error instances thrown by the Ably Chat SDK.

 See ``ErrorCode`` for the possible ``ARTErrorInfo.code`` values.
 */
public let errorDomain = "AblyChatErrorDomain"

/**
 The error codes for errors in the ``errorDomain`` error domain.
 */
public enum ErrorCode: Int {
    /// ``Rooms.get(roomID:options:)`` was called with a different set of room options than was used on a previous call. You must first release the existing room instance using ``Rooms.release(roomID:)``.
    ///
    /// TODO this code is a guess, revisit in https://github.com/ably-labs/ably-chat-swift/issues/32
    case inconsistentRoomOptions = 1

    // TODO: describe, and code is a guess
    case channelAttachResultedInSuspended = 2
    case channelAttachResultedInFailed = 3

    case roomInFailedState = 102_101 // CHA-RL2d
    case roomIsReleasing = 102_102 // CHA-RL1b, CHA-RL2b
    case roomIsReleased = 102_103 // CHA-RL1c, CHA-RL2c

    case messagesDetachmentFailed = 102_050
    case presenceDetachmentFailed = 102_051
    case reactionsDetachmentFailed = 102_052
    case occupancyDetachmentFailed = 102_053
    case typingDetachmentFailed = 102_054

    /// The ``ARTErrorInfo.statusCode`` that should be returned for this error.
    internal var statusCode: Int {
        // TODO: These are currently a guess, revisit in https://github.com/ably-labs/ably-chat-swift/issues/32
        switch self {
        case .inconsistentRoomOptions, .channelAttachResultedInSuspended, .channelAttachResultedInFailed, .roomInFailedState, .roomIsReleasing, .roomIsReleased, .messagesDetachmentFailed, .presenceDetachmentFailed, .reactionsDetachmentFailed, .occupancyDetachmentFailed, .typingDetachmentFailed:
            400
        }
    }
}

/**
 The errors thrown by the Chat SDK.

 This type exists in addition to ``ErrorCode`` to allow us to attach metadata which can be incorporated into the error’s `localizedDescription` and `cause`.
 */
internal enum ChatError {
    case inconsistentRoomOptions(requested: RoomOptions, existing: RoomOptions)
    case channelAttachResultedInSuspended(underlyingError: ARTErrorInfo)
    case channelAttachResultedInFailed(underlyingError: ARTErrorInfo)
    case roomInFailedState
    case roomIsReleasing
    case roomIsReleased
    case detachmentFailed(feature: RoomFeature, underlyingError: ARTErrorInfo)

    /// The ``ARTErrorInfo.code`` that should be returned for this error.
    internal var code: ErrorCode {
        switch self {
        case .inconsistentRoomOptions:
            .inconsistentRoomOptions
        case .channelAttachResultedInSuspended:
            .channelAttachResultedInSuspended
        case .channelAttachResultedInFailed:
            .channelAttachResultedInFailed
        case .roomInFailedState:
            .roomInFailedState
        case .roomIsReleasing:
            .roomIsReleasing
        case .roomIsReleased:
            .roomIsReleased
        case let .detachmentFailed(feature, _):
            switch feature {
            case .messages:
                .messagesDetachmentFailed
            case .occupancy:
                .occupancyDetachmentFailed
            case .presence:
                .presenceDetachmentFailed
            case .reactions:
                .reactionsDetachmentFailed
            case .typing:
                .typingDetachmentFailed
            }
        }
    }

    /// The ``ARTErrorInfo.localizedDescription`` that should be returned for this error.
    internal var localizedDescription: String {
        switch self {
        case let .inconsistentRoomOptions(requested, existing):
            "Rooms.get(roomID:options:) was called with a different set of room options than was used on a previous call. You must first release the existing room instance using Rooms.release(roomID:). Requested options: \(requested), existing options: \(existing)"
        case .channelAttachResultedInSuspended:
            "TODO"
        case .channelAttachResultedInFailed:
            "TODO"
        case .roomInFailedState:
            "Cannot perform operation because the room is in a failed state."
        case .roomIsReleasing:
            "Cannot perform operation because the room is in a releasing state."
        case .roomIsReleased:
            "Cannot perform operation because the room is in a released state."
        case let .detachmentFailed(feature, _):
            {
                let description = switch feature {
                case .messages:
                    "messages"
                case .occupancy:
                    "occupancy"
                case .presence:
                    "presence"
                case .reactions:
                    "reactions"
                case .typing:
                    "typing"
                }
                return "The \(description) feature failed to detach."
            }()
        }
    }

    /// The ``ARTErrorInfo.cause`` that should be returned for this error.
    internal var cause: ARTErrorInfo? {
        switch self {
        case let .channelAttachResultedInSuspended(underlyingError):
            underlyingError
        case let .channelAttachResultedInFailed(underlyingError):
            underlyingError
        case let .detachmentFailed(_, underlyingError):
            underlyingError
        case .inconsistentRoomOptions,
             .roomInFailedState,
             .roomIsReleasing,
             .roomIsReleased:
            nil
        }
    }
}

internal extension ARTErrorInfo {
    convenience init(chatError: ChatError) {
        var userInfo: [String: Any] = [:]
        // TODO: copied and pasted from implementation of -[ARTErrorInfo createWithCode:status:message:requestId:] because there’s no way to pass domain; revisit in https://github.com/ably-labs/ably-chat-swift/issues/32. Also the ARTErrorInfoStatusCode variable in ably-cocoa is not public.
        userInfo["ARTErrorInfoStatusCode"] = chatError.code.statusCode
        userInfo[NSLocalizedDescriptionKey] = chatError.localizedDescription

        // TODO: This is kind of an implementation detail (that NSUnderlyingErrorKey is what populates `cause`); consider documenting in ably-cocoa as part of https://github.com/ably-labs/ably-chat-swift/issues/32.
        if let cause = chatError.cause {
            userInfo[NSUnderlyingErrorKey] = cause
        }

        self.init(
            domain: errorDomain,
            code: chatError.code.rawValue,
            userInfo: userInfo
        )
    }
}
