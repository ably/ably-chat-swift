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
    case nonspecific = 40000

    /// ``Rooms.get(roomID:options:)`` was called with a different set of room options than was used on a previous call. You must first release the existing room instance using ``Rooms.release(roomID:)``.
    ///
    /// TODO this code is a guess, revisit in https://github.com/ably-labs/ably-chat-swift/issues/32
    case inconsistentRoomOptions = 1

    case messagesAttachmentFailed = 102_001
    case presenceAttachmentFailed = 102_002
    case reactionsAttachmentFailed = 102_003
    case occupancyAttachmentFailed = 102_004
    case typingAttachmentFailed = 102_005

    case messagesDetachmentFailed = 102_050
    case presenceDetachmentFailed = 102_051
    case reactionsDetachmentFailed = 102_052
    case occupancyDetachmentFailed = 102_053
    case typingDetachmentFailed = 102_054

    case roomInFailedState = 102_101
    case roomIsReleasing = 102_102
    case roomIsReleased = 102_103

    /// The ``ARTErrorInfo.statusCode`` that should be returned for this error.
    internal var statusCode: Int {
        // TODO: These are currently a guess, revisit once outstanding spec question re status codes is answered (https://github.com/ably/specification/pull/200#discussion_r1755222945), and also revisit in https://github.com/ably-labs/ably-chat-swift/issues/32
        switch self {
        case .nonspecific,
             .inconsistentRoomOptions,
             .messagesDetachmentFailed,
             .presenceDetachmentFailed,
             .reactionsDetachmentFailed,
             .occupancyDetachmentFailed,
             .typingDetachmentFailed,
             .roomInFailedState,
             .roomIsReleasing,
             .roomIsReleased:
            400
        case .messagesAttachmentFailed,
             .presenceAttachmentFailed,
             .reactionsAttachmentFailed,
             .occupancyAttachmentFailed,
             .typingAttachmentFailed:
            // TODO: This is currently a best guess based on the limited status code information given in the spec at time of writing (i.e. CHA-RL1h4); it's not clear to me whether these error codes are always meant to have the same status code. Revisit once aforementioned spec question re status codes answered.
            500
        }
    }
}

/**
 The errors thrown by the Chat SDK.

 This type exists in addition to ``ErrorCode`` to allow us to attach metadata which can be incorporated into the error’s `localizedDescription` and `cause`.
 */
internal enum ChatError {
    case inconsistentRoomOptions(requested: RoomOptions, existing: RoomOptions)
    case attachmentFailed(feature: RoomFeature, underlyingError: ARTErrorInfo)
    case detachmentFailed(feature: RoomFeature, underlyingError: ARTErrorInfo)
    case roomInFailedState
    case roomIsReleasing
    case roomIsReleased
    case presenceOperationRequiresRoomAttach(feature: RoomFeature)
    case presenceOperationDisallowedForCurrentRoomStatus(feature: RoomFeature)

    /// The ``ARTErrorInfo.code`` that should be returned for this error.
    internal var code: ErrorCode {
        switch self {
        case .inconsistentRoomOptions:
            .inconsistentRoomOptions
        case let .attachmentFailed(feature, _):
            switch feature {
            case .messages:
                .messagesAttachmentFailed
            case .occupancy:
                .occupancyAttachmentFailed
            case .presence:
                .presenceAttachmentFailed
            case .reactions:
                .reactionsAttachmentFailed
            case .typing:
                .typingAttachmentFailed
            }
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
        case .roomInFailedState:
            .roomInFailedState
        case .roomIsReleasing:
            .roomIsReleasing
        case .roomIsReleased:
            .roomIsReleased
        case .presenceOperationRequiresRoomAttach,
             .presenceOperationDisallowedForCurrentRoomStatus:
            .nonspecific
        }
    }

    private static func descriptionOfFeature(_ feature: RoomFeature) -> String {
        switch feature {
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
    }

    /// A helper type for parameterising the construction of error messages.
    private enum AttachOrDetach {
        case attach
        case detach
    }

    private static func localizedDescription(
        forFailureOfOperation operation: AttachOrDetach,
        feature: RoomFeature
    ) -> String {
        let operationDescription = switch operation {
        case .attach:
            "attach"
        case .detach:
            "detach"
        }

        return "The \(descriptionOfFeature(feature)) feature failed to \(operationDescription)."
    }

    /// The ``ARTErrorInfo.localizedDescription`` that should be returned for this error.
    internal var localizedDescription: String {
        switch self {
        case let .inconsistentRoomOptions(requested, existing):
            "Rooms.get(roomID:options:) was called with a different set of room options than was used on a previous call. You must first release the existing room instance using Rooms.release(roomID:). Requested options: \(requested), existing options: \(existing)"
        case let .attachmentFailed(feature, _):
            Self.localizedDescription(forFailureOfOperation: .attach, feature: feature)
        case let .detachmentFailed(feature, _):
            Self.localizedDescription(forFailureOfOperation: .detach, feature: feature)
        case .roomInFailedState:
            "Cannot perform operation because the room is in a failed state."
        case .roomIsReleasing:
            "Cannot perform operation because the room is in a releasing state."
        case .roomIsReleased:
            "Cannot perform operation because the room is in a released state."
        case let .presenceOperationRequiresRoomAttach(feature):
            "To perform this \(Self.descriptionOfFeature(feature)) operation, you must first attach the room."
        case let .presenceOperationDisallowedForCurrentRoomStatus(feature):
            "This \(Self.descriptionOfFeature(feature)) operation can not be performed given the current room status."
        }
    }

    /// The ``ARTErrorInfo.cause`` that should be returned for this error.
    internal var cause: ARTErrorInfo? {
        switch self {
        case let .attachmentFailed(_, underlyingError):
            underlyingError
        case let .detachmentFailed(_, underlyingError):
            underlyingError
        case .inconsistentRoomOptions,
             .roomInFailedState,
             .roomIsReleasing,
             .roomIsReleased,
             .presenceOperationRequiresRoomAttach,
             .presenceOperationDisallowedForCurrentRoomStatus:
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
