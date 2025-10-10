import Ably

/**
 The error domain used for the `ARTErrorInfo` error instances thrown by the Ably Chat SDK.

 See ``ErrorCode`` for the possible `code` values.
 */
public let errorDomain = "AblyChatErrorDomain"

/**
 The error codes for errors in the ``errorDomain`` error domain.

 - Note: Future minor version updates of the library may add new values to this enum. Bear this in mind if you wish to switch exhaustively over it.
 */
public enum ErrorCode: Int {
    /// The user attempted to perform an invalid action.
    case badRequest = 40000

    /**
     * Cannot perform operation because the room is in a failed state.
     */
    case roomInFailedState = 102_101

    /**
     * Cannot perform operation because the room is in a releasing state.
     */
    case roomIsReleasing = 102_102

    /**
     * Cannot perform operation because the room is in a released state.
     */
    case roomIsReleased = 102_103

    /**
     * Room was released before the operation could complete.
     */
    case roomReleasedBeforeOperationCompleted = 102_106

    // swiftlint:disable:next missing_docs
    case roomInInvalidState = 102_107

    /**
     * The room has experienced a discontinuity.
     */
    case roomDiscontinuity = 102_100

    /**
     * The message was rejected before publishing by a rule on the chat room.
     */
    case messageRejectedByBeforePublishRule = 42211

    /**
     * The message was rejected before publishing by a moderation rule on the chat room.
     */
    case messageRejectedByModeration = 42213

    /// Has a case for each of the ``ErrorCode`` cases that imply a fixed status code.
    internal enum CaseThatImpliesFixedStatusCode {
        case badRequest
        case roomInFailedState
        case roomIsReleasing
        case roomIsReleased
        case roomReleasedBeforeOperationCompleted
        case roomDiscontinuity
        case messageRejectedByBeforePublishRule
        case messageRejectedByModeration

        internal var toNumericErrorCode: ErrorCode {
            switch self {
            case .badRequest:
                .badRequest
            case .roomInFailedState:
                .roomInFailedState
            case .roomIsReleasing:
                .roomIsReleasing
            case .roomIsReleased:
                .roomIsReleased
            case .roomReleasedBeforeOperationCompleted:
                .roomReleasedBeforeOperationCompleted
            case .roomDiscontinuity:
                .roomDiscontinuity
            case .messageRejectedByModeration:
                .messageRejectedByModeration
            case .messageRejectedByBeforePublishRule:
                .messageRejectedByBeforePublishRule
            }
        }

        /// The ``ARTErrorInfo/statusCode`` that should be returned for this error.
        internal var statusCode: Int {
            // These status codes are taken from the "Chat-specific Error Codes" section of the spec.
            switch self {
            case .badRequest,
                 .roomInFailedState,
                 .roomIsReleasing,
                 .roomIsReleased,
                 .roomReleasedBeforeOperationCompleted:
                400
            case .messageRejectedByModeration,
                 .messageRejectedByBeforePublishRule:
                422
            case .roomDiscontinuity:
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

    /// The ``ARTErrorInfo/code`` that should be returned for this error.
    internal var code: ErrorCode {
        switch self {
        case let .fixedStatusCode(code):
            code.toNumericErrorCode
        case let .variableStatusCode(code, _):
            code.toNumericErrorCode
        }
    }

    /// The ``ARTErrorInfo/statusCode`` that should be returned for this error.
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
    case nonErrorInfoInternalError(InternalError.Other)
    case inconsistentRoomOptions(requested: RoomOptions, existing: RoomOptions)
    case roomInFailedState
    case roomIsReleasing
    case roomIsReleased
    case roomReleasedBeforeOperationCompleted
    case presenceOperationRequiresRoomAttach(feature: RoomFeature)
    case roomTransitionedToInvalidStateForPresenceOperation(cause: ARTErrorInfo?)
    case roomDiscontinuity(cause: ARTErrorInfo?)
    case unableDeleteReactionWithoutName(reactionType: String)
    case cannotApplyEventForDifferentMessage
    case messageRejectedByBeforePublishRule
    case messageRejectedByModeration
    case attachSerialIsNotDefined
    case channelFailedToAttach(cause: ARTErrorInfo?)

    internal var codeAndStatusCode: ErrorCodeAndStatusCode {
        switch self {
        case .nonErrorInfoInternalError:
            // For now we just treat all errors that are not backed by an ARTErrorInfo as non-recoverable user errors
            .fixedStatusCode(.badRequest)
        case .inconsistentRoomOptions:
            .fixedStatusCode(.badRequest)
        case .roomInFailedState:
            .fixedStatusCode(.roomInFailedState)
        case .roomIsReleasing:
            .fixedStatusCode(.roomIsReleasing)
        case .roomIsReleased:
            .fixedStatusCode(.roomIsReleased)
        case .roomReleasedBeforeOperationCompleted:
            .fixedStatusCode(.roomReleasedBeforeOperationCompleted)
        case .roomTransitionedToInvalidStateForPresenceOperation:
            // CHA-RL9c
            .variableStatusCode(.roomInInvalidState, statusCode: 500)
        case .presenceOperationRequiresRoomAttach:
            // CHA-PR3h, CHA-PR10h, CHA-PR6h
            .variableStatusCode(.roomInInvalidState, statusCode: 400)
        case .roomDiscontinuity:
            .fixedStatusCode(.roomDiscontinuity)
        case .unableDeleteReactionWithoutName:
            .fixedStatusCode(.badRequest)
        case .cannotApplyEventForDifferentMessage:
            .fixedStatusCode(.badRequest)
        case .messageRejectedByBeforePublishRule:
            .fixedStatusCode(.messageRejectedByBeforePublishRule)
        case .messageRejectedByModeration:
            .fixedStatusCode(.messageRejectedByModeration)
        case .attachSerialIsNotDefined:
            .fixedStatusCode(.badRequest)
        case .channelFailedToAttach:
            .fixedStatusCode(.badRequest)
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

    /// The ``ARTErrorInfo/localizedDescription`` that should be returned for this error.
    internal var localizedDescription: String {
        switch self {
        case let .nonErrorInfoInternalError(otherInternalError):
            // This will contain the name of the underlying enum case (we have a test to verify this); this will do for now
            "\(otherInternalError)"
        case let .inconsistentRoomOptions(requested, existing):
            "Rooms.get(roomName:options:) was called with a different set of room options than was used on a previous call. You must first release the existing room instance using Rooms.release(roomName:). Requested options: \(requested), existing options: \(existing)"
        case .roomInFailedState:
            "Cannot perform operation because the room is in a failed state."
        case .roomIsReleasing:
            "Cannot perform operation because the room is in a releasing state."
        case .roomIsReleased:
            "Cannot perform operation because the room is in a released state."
        case .roomReleasedBeforeOperationCompleted:
            "Room was released before the operation could complete."
        case let .presenceOperationRequiresRoomAttach(feature):
            "To perform this \(Self.descriptionOfFeature(feature)) operation, you must first attach the room."
        case .roomTransitionedToInvalidStateForPresenceOperation:
            "The room operation failed because the room was in an invalid state."
        case .roomDiscontinuity:
            "The room has experienced a discontinuity."
        case let .unableDeleteReactionWithoutName(reactionType: reactionType):
            "Cannot delete reaction of type '\(reactionType)' without a reaction name."
        case .cannotApplyEventForDifferentMessage:
            "Cannot apply event for different message."
        case .messageRejectedByBeforePublishRule:
            "The message was rejected before publishing by a rule on the chat room."
        case .messageRejectedByModeration:
            "The message was rejected before publishing by a moderation rule on the chat room."
        case .attachSerialIsNotDefined:
            "Channel is attached, but attachSerial is not defined."
        case let .channelFailedToAttach(cause):
            "Channel failed to attach: \(String(describing: cause))"
        }
    }

    /// The ``ARTErrorInfo/cause`` that should be returned for this error.
    internal var cause: ARTErrorInfo? {
        switch self {
        case let .roomTransitionedToInvalidStateForPresenceOperation(cause):
            cause
        case let .roomDiscontinuity(cause):
            cause
        case let .channelFailedToAttach(cause):
            cause
        case .nonErrorInfoInternalError,
             .inconsistentRoomOptions,
             .roomInFailedState,
             .roomIsReleasing,
             .roomIsReleased,
             .roomReleasedBeforeOperationCompleted,
             .presenceOperationRequiresRoomAttach,
             .cannotApplyEventForDifferentMessage,
             .unableDeleteReactionWithoutName,
             .messageRejectedByBeforePublishRule,
             .messageRejectedByModeration,
             .attachSerialIsNotDefined:
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
            userInfo: userInfo,
        )
    }
}
