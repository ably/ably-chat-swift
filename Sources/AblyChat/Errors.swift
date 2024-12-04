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

    case roomInInvalidState = 102_107

    /// Has a case for each of the ``ErrorCode`` cases that imply a fixed status code.
    internal enum CaseThatImpliesFixedStatusCode {
        case inconsistentRoomOptions
        case messagesAttachmentFailed
        case presenceAttachmentFailed
        case reactionsAttachmentFailed
        case occupancyAttachmentFailed
        case typingAttachmentFailed
        case messagesDetachmentFailed
        case presenceDetachmentFailed
        case reactionsDetachmentFailed
        case occupancyDetachmentFailed
        case typingDetachmentFailed
        case roomInFailedState
        case roomIsReleasing
        case roomIsReleased

        internal var toNumericErrorCode: ErrorCode {
            switch self {
            case .inconsistentRoomOptions:
                .inconsistentRoomOptions
            case .messagesAttachmentFailed:
                .messagesAttachmentFailed
            case .presenceAttachmentFailed:
                .presenceAttachmentFailed
            case .reactionsAttachmentFailed:
                .reactionsAttachmentFailed
            case .occupancyAttachmentFailed:
                .occupancyAttachmentFailed
            case .typingAttachmentFailed:
                .typingAttachmentFailed
            case .messagesDetachmentFailed:
                .messagesDetachmentFailed
            case .presenceDetachmentFailed:
                .presenceDetachmentFailed
            case .reactionsDetachmentFailed:
                .reactionsDetachmentFailed
            case .occupancyDetachmentFailed:
                .occupancyDetachmentFailed
            case .typingDetachmentFailed:
                .typingDetachmentFailed
            case .roomInFailedState:
                .roomInFailedState
            case .roomIsReleasing:
                .roomIsReleasing
            case .roomIsReleased:
                .roomIsReleased
            }
        }

        /// The ``ARTErrorInfo.statusCode`` that should be returned for this error.
        internal var statusCode: Int {
            // These status codes are taken from the "Chat-specific Error Codes" section of the spec.
            switch self {
            case .inconsistentRoomOptions,
                 .roomInFailedState,
                 .roomIsReleasing,
                 .roomIsReleased:
                400
            case
                .messagesAttachmentFailed,
                .presenceAttachmentFailed,
                .reactionsAttachmentFailed,
                .occupancyAttachmentFailed,
                .typingAttachmentFailed,
                .messagesDetachmentFailed,
                .presenceDetachmentFailed,
                .reactionsDetachmentFailed,
                .occupancyDetachmentFailed,
                .typingDetachmentFailed:
                500
            }
        }
    }

    /// Has a case for each of the ``ErrorCode`` cases that do not imply a fixed status code.
    internal enum CaseThatImpliesVariableStatusCode {
        case roomInInvalidState

        internal var toNumericErrorCode: ErrorCode {
            switch self {
            case .roomInInvalidState:
                .roomInInvalidState
            }
        }
    }
}

/**
 * Represents a case of ``ErrorCode`` plus a status code.
 */
internal enum ErrorCodeAndStatusCode {
    case fixedStatusCode(ErrorCode.CaseThatImpliesFixedStatusCode)
    case variableStatusCode(ErrorCode.CaseThatImpliesVariableStatusCode, statusCode: Int)

    /// The ``ARTErrorInfo.code`` that should be returned for this error.
    internal var code: ErrorCode {
        switch self {
        case let .fixedStatusCode(code):
            code.toNumericErrorCode
        case let .variableStatusCode(code, _):
            code.toNumericErrorCode
        }
    }

    /// The ``ARTErrorInfo.statusCode`` that should be returned for this error.
    internal var statusCode: Int {
        switch self {
        case let .fixedStatusCode(code):
            code.statusCode
        case let .variableStatusCode(_, statusCode):
            statusCode
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
    case roomTransitionedToInvalidStateForPresenceOperation(cause: ARTErrorInfo?)

    internal var codeAndStatusCode: ErrorCodeAndStatusCode {
        switch self {
        case .inconsistentRoomOptions:
            .fixedStatusCode(.inconsistentRoomOptions)
        case let .attachmentFailed(feature, _):
            switch feature {
            case .messages:
                .fixedStatusCode(.messagesAttachmentFailed)
            case .occupancy:
                .fixedStatusCode(.occupancyAttachmentFailed)
            case .presence:
                .fixedStatusCode(.presenceAttachmentFailed)
            case .reactions:
                .fixedStatusCode(.reactionsAttachmentFailed)
            case .typing:
                .fixedStatusCode(.typingAttachmentFailed)
            }
        case let .detachmentFailed(feature, _):
            switch feature {
            case .messages:
                .fixedStatusCode(.messagesDetachmentFailed)
            case .occupancy:
                .fixedStatusCode(.occupancyDetachmentFailed)
            case .presence:
                .fixedStatusCode(.presenceDetachmentFailed)
            case .reactions:
                .fixedStatusCode(.reactionsDetachmentFailed)
            case .typing:
                .fixedStatusCode(.typingDetachmentFailed)
            }
        case .roomInFailedState:
            .fixedStatusCode(.roomInFailedState)
        case .roomIsReleasing:
            .fixedStatusCode(.roomIsReleasing)
        case .roomIsReleased:
            .fixedStatusCode(.roomIsReleased)
        case .roomTransitionedToInvalidStateForPresenceOperation:
            // CHA-RL9c
            .variableStatusCode(.roomInInvalidState, statusCode: 500)
        case .presenceOperationRequiresRoomAttach:
            // CHA-PR3h, CHA-PR10h, CHA-PR6h, CHA-T2g
            .variableStatusCode(.roomInInvalidState, statusCode: 400)
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
        case .roomTransitionedToInvalidStateForPresenceOperation:
            "The room operation failed because the room was in an invalid state."
        }
    }

    /// The ``ARTErrorInfo.cause`` that should be returned for this error.
    internal var cause: ARTErrorInfo? {
        switch self {
        case let .attachmentFailed(_, underlyingError):
            underlyingError
        case let .detachmentFailed(_, underlyingError):
            underlyingError
        case let .roomTransitionedToInvalidStateForPresenceOperation(cause):
            cause
        case .inconsistentRoomOptions,
             .roomInFailedState,
             .roomIsReleasing,
             .roomIsReleased,
             .presenceOperationRequiresRoomAttach:
            nil
        }
    }
}

internal extension ARTErrorInfo {
    convenience init(chatError: ChatError) {
        var userInfo: [String: Any] = [:]
        // TODO: copied and pasted from implementation of -[ARTErrorInfo createWithCode:status:message:requestId:] because there’s no way to pass domain; revisit in https://github.com/ably-labs/ably-chat-swift/issues/32. Also the ARTErrorInfoStatusCode variable in ably-cocoa is not public.
        userInfo["ARTErrorInfoStatusCode"] = chatError.codeAndStatusCode.statusCode
        userInfo[NSLocalizedDescriptionKey] = chatError.localizedDescription

        // TODO: This is kind of an implementation detail (that NSUnderlyingErrorKey is what populates `cause`); consider documenting in ably-cocoa as part of https://github.com/ably-labs/ably-chat-swift/issues/32.
        if let cause = chatError.cause {
            userInfo[NSUnderlyingErrorKey] = cause
        }

        self.init(
            domain: errorDomain,
            code: chatError.codeAndStatusCode.code.rawValue,
            userInfo: userInfo
        )
    }
}
