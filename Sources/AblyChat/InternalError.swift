import Ably

/// An error thrown by the Chat SDK itself (as opposed to a re-thrown ably-cocoa error).
///
/// Provides the rich error information that is stored inside an ``ErrorInfo``. `ErrorInfo` then maps these errors to its public properties (`code`, `statusCode` etc), but it also keeps hold of the original `InternalError` to aid with debugging.
///
/// This type does not conform to `Error` and cannot be thrown directly. It serves as the backing storage for ``ErrorInfo``, which is the actual error type thrown by the SDK.
internal enum InternalError {
    /// Some other internal error that does not fall into any of the below cases.
    ///
    /// These are all errors for which the spec does not specify any particular handling.
    case other(Other)

    /// Not proceeding with `Room.attach()` because the room has the following invalid status, per CHA-RL1l.
    ///
    /// Error code is `roomInInvalidState`.
    case roomInInvalidStateForAttach(RoomStatus)

    /// Not proceeding with `Room.detach()` because the room has the following invalid status, per CHA-RL2l or CHA-RL2m.
    ///
    /// Error code is `roomInInvalidState`.
    case roomInInvalidStateForDetach(RoomStatus)

    /// Attempted to apply a `MessageEvent.created` event to a `Message`, which is not allowed per CHA-M11h.
    ///
    /// Error code is `invalidArgument`.
    case cannotApplyCreatedMessageEvent

    /// Attempted to apply a `MessageEvent` to a `Message` whose `serial` doesn't match the `messageSerial` of the event, which is not allowed per CHA-M11i.
    ///
    /// Error code is `invalidArgument`.
    case cannotApplyMessageEventForDifferentMessage

    /// Attempted to apply a `MessageReactionSummaryEvent` to a `Message` whose `serial` doesn't match the `messageSerial` of the event, which is not allowed per CHA-M11j.
    ///
    /// Error code is `invalidArgument`.
    case cannotApplyReactionSummaryEventForDifferentMessage

    /// The user passed an empty `messageSerial` when sending a reaction, which is not allowed per CHA-MR4a2.
    ///
    /// Error code is `invalidArgument`.
    case sendMessageReactionEmptyMessageSerial

    /// The user passed an empty `messageSerial` when deleting a reaction, which is not allowed per CHA-MR11a2.
    ///
    /// Error code is `invalidArgument`.
    case deleteMessageReactionEmptyMessageSerial

    /// The user tried to fetch a room which has already been requested with different options, which is not allowed per CHA-RC1f1.
    ///
    /// Error code is `roomExistsWithDifferentOptions`.
    case roomExistsWithDifferentOptions(requested: RoomOptions, existing: RoomOptions)

    /// The user tried to attach or detach a room which is in the RELEASING state, which is not allowed per CHA-RL1b or CHA-RL2b respectively.
    ///
    /// Error code is `roomInInvalidState` (note that the spec point said `roomIsReleasing`, but this spec point no longer exists and this error code no longer exists in the spec, so use `roomInInvalidState` instead).
    case roomIsReleasing

    /// The user attempted to release a room whilst a release operation was already in progress, causing the release operation to fail per CHA-RC1g4.
    ///
    /// Error code is `roomReleasedBeforeOperationCompleted`.
    case roomReleasedBeforeOperationCompleted

    /// The user attempted to perform a presence operation whilst the room was not ATTACHED or ATTACHING, resulting in this error per CHA-PR3h, CHA-PR10h, CHA-PR6h.
    ///
    /// Error code is `roomInInvalidState`.
    case presenceOperationRequiresRoomAttach(feature: RoomFeature)

    /// The user attempted to perform a presence operation whilst the room was ATTACHING, and after waiting for a room status change the next status was not ATTACHED, resulting in this error per CHA-RL9c.
    ///
    /// Error code is `roomInInvalidState`.
    case roomTransitionedToInvalidStateForPresenceOperation(cause: ErrorInfo?)

    /// The room's channel emitted an event representing a discontinuity, and so the room emitted this error per CHA-RL12b.
    ///
    /// Error code is `roomDiscontinuity`.
    case roomDiscontinuity(cause: ErrorInfo?)

    // TODO: Revisit the non-specified errors as part of https://github.com/ably/ably-chat-swift/issues/438

    /// The user attempted to delete a reaction of type different than `unique`, without specifying the reaction identifier. This is not allowed per CHA-MR11b1.
    ///
    /// Error code is `badRequest` (this is not specified by the spec, which does not make it explicit that the SDK should throw an error in this scenario).
    case unableDeleteReactionWithoutName(reactionType: String)

    /// Unable to fetch `historyBeforeSubscribe` because a channel in the `ATTACHED` state has violated our expectations by its `attachSerial` not being populated, so we cannot resolve its "subscription point" per CHA-M5b.
    ///
    /// Error code is `badRequest` (this is not specified by the spec, which does not make it explicit that the SDK should throw an error in this scenario).
    case failedToResolveSubscriptionPointBecauseAttachSerialNotDefined

    /// Unable to fetch `historyBeforeSubscribe` because whilst waiting for a channel to become attached per CHA-M5b in order to resolve its "subscription point".
    ///
    /// Error code is `badRequest` (this is not specified by the spec, which does not make it explicit that the SDK should throw an error in this scenario).
    case failedToResolveSubscriptionPointBecauseChannelFailedToAttach(cause: ErrorInfo?)

    /// Returns the error that this should be converted to when exposed via the SDK's public API.
    internal func toErrorInfo() -> ErrorInfo {
        .init(internalError: self)
    }

    /// This was originally created to represent any of the various internal types that existed at the time of converting the public API of the SDK to throw ErrorInfo. We may rethink this when we do a broader rethink of the errors thrown by the SDK in https://github.com/ably/ably-chat-swift/issues/32. For now, feel free to introduce further internal error types and add them to the `Other` enum.
    internal enum Other {
        case chatAPIChatError(ChatAPI.ChatError)
        case headersValueJSONDecodingError(HeadersValue.JSONDecodingError)
        case jsonValueDecodingError(JSONValueDecodingError)
        case paginatedResultError(PaginatedResultError)
        case messagesError(DefaultMessages.MessagesError)
    }

    /// The ```ErrorInfo/code`` values used by `InternalError` cases.
    ///
    /// These values are taken from the "Common Error Codes used by Chat" and "Chat-specific Error Codes" section of the chat spec.
    internal enum ErrorCode: Int {
        case badRequest = 40000
        case invalidArgument = 40003
        case roomDiscontinuity = 102_100
        case roomReleasedBeforeOperationCompleted = 102_106
        case roomExistsWithDifferentOptions = 102_107
        case roomInInvalidState = 102_112

        /// Has a case for each of the ``ErrorCode`` cases that imply a fixed status code.
        internal enum CaseThatImpliesFixedStatusCode {
            case badRequest
            case invalidArgument
            case roomDiscontinuity
            case roomReleasedBeforeOperationCompleted
            case roomExistsWithDifferentOptions
            case roomInInvalidState

            internal var toNumericErrorCode: ErrorCode {
                switch self {
                case .badRequest:
                    .badRequest
                case .invalidArgument:
                    .invalidArgument
                case .roomReleasedBeforeOperationCompleted:
                    .roomReleasedBeforeOperationCompleted
                case .roomExistsWithDifferentOptions:
                    .roomExistsWithDifferentOptions
                case .roomInInvalidState:
                    .roomInInvalidState
                case .roomDiscontinuity:
                    .roomDiscontinuity
                }
            }

            /// The ``ErrorInfo/statusCode`` that should be returned for this error.
            internal var statusCode: Int {
                /// These status codes are taken from the "Common Error Codes used by Chat" and "Chat-specific Error Codes" sections of the chat spec.
                switch self {
                case .badRequest,
                     .invalidArgument,
                     .roomReleasedBeforeOperationCompleted,
                     .roomInInvalidState,
                     .roomExistsWithDifferentOptions:
                    400
                case .roomDiscontinuity:
                    500
                }
            }
        }

        /// Has a case for each of the ``ErrorCode`` cases that do not imply a fixed status code.
        internal enum CaseThatImpliesVariableStatusCode: Equatable {
            internal var toNumericErrorCode: Never {
                switch self {}
            }
        }
    }

    /**
     * Represents a case of ``ErrorCode`` plus a status code.
     */
    internal enum ErrorCodeAndStatusCode: Equatable {
        case fixedStatusCode(ErrorCode.CaseThatImpliesFixedStatusCode)
        case variableStatusCode(ErrorCode.CaseThatImpliesVariableStatusCode, statusCode: Int)

        /// The ``ErrorInfo/code`` that should be returned for this error.
        internal var code: ErrorCode {
            switch self {
            case let .fixedStatusCode(code):
                code.toNumericErrorCode
            case let .variableStatusCode(code, _):
                code.toNumericErrorCode
            }
        }

        /// The ``ErrorInfo/statusCode`` that should be returned for this error.
        internal var statusCode: Int {
            switch self {
            case let .fixedStatusCode(code):
                code.statusCode
            case let .variableStatusCode(_, statusCode):
                statusCode
            }
        }
    }

    internal var codeAndStatusCode: ErrorCodeAndStatusCode {
        switch self {
        case .other:
            // For now we just treat all miscellaneous internally-thrown errors as non-recoverable user errors
            .fixedStatusCode(.badRequest)
        case .roomExistsWithDifferentOptions:
            .fixedStatusCode(.roomExistsWithDifferentOptions)
        case .roomIsReleasing:
            .fixedStatusCode(.roomInInvalidState)
        case .roomReleasedBeforeOperationCompleted:
            .fixedStatusCode(.roomReleasedBeforeOperationCompleted)
        case .roomInInvalidStateForAttach:
            .fixedStatusCode(.roomInInvalidState)
        case .roomInInvalidStateForDetach:
            .fixedStatusCode(.roomInInvalidState)
        case .sendMessageReactionEmptyMessageSerial:
            .fixedStatusCode(.invalidArgument)
        case .deleteMessageReactionEmptyMessageSerial:
            .fixedStatusCode(.invalidArgument)
        case .roomTransitionedToInvalidStateForPresenceOperation:
            // CHA-RL9c
            .fixedStatusCode(.roomInInvalidState)
        case .presenceOperationRequiresRoomAttach:
            // CHA-PR3h, CHA-PR10h, CHA-PR6h
            .fixedStatusCode(.roomInInvalidState)
        case .roomDiscontinuity:
            .fixedStatusCode(.roomDiscontinuity)
        case .unableDeleteReactionWithoutName:
            .fixedStatusCode(.badRequest)
        case .cannotApplyMessageEventForDifferentMessage:
            .fixedStatusCode(.invalidArgument)
        case .cannotApplyReactionSummaryEventForDifferentMessage:
            .fixedStatusCode(.invalidArgument)
        case .cannotApplyCreatedMessageEvent:
            .fixedStatusCode(.invalidArgument)
        case .failedToResolveSubscriptionPointBecauseAttachSerialNotDefined:
            .fixedStatusCode(.badRequest)
        case .failedToResolveSubscriptionPointBecauseChannelFailedToAttach:
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

    private static func descriptionOfRoomStatus(_ roomStatus: RoomStatus) -> String {
        switch roomStatus {
        case .initialized:
            "initialized"
        case .attaching:
            "attaching"
        case .attached:
            "attached"
        case .detaching:
            "detaching"
        case .detached:
            "detached"
        case .suspended:
            "suspended"
        case .failed:
            "failed"
        case .releasing:
            "releasing"
        case .released:
            "released"
        }
    }

    /// A helper type for parameterising the construction of error messages.
    private enum AttachOrDetach {
        case attach
        case detach
    }

    /// The ``ErrorInfo/message`` that should be returned for this error.
    internal var message: String {
        switch self {
        case let .other(otherInternalError):
            // This will contain the name of the underlying enum case (we have a test to verify this); this will do for now
            "\(otherInternalError)"
        case let .roomExistsWithDifferentOptions(requested, existing):
            "Rooms.get(roomName:options:) was called with a different set of room options than was used on a previous call. You must first release the existing room instance using Rooms.release(roomName:). Requested options: \(requested), existing options: \(existing)"
        case let .roomInInvalidStateForAttach(roomStatus):
            "Cannot attach room because the room is in a \(Self.descriptionOfRoomStatus(roomStatus)) state."
        case let .roomInInvalidStateForDetach(roomStatus):
            "Cannot detach room because the room is in a \(Self.descriptionOfRoomStatus(roomStatus)) state."
        case .roomIsReleasing:
            "Cannot perform operation because the room is in a releasing state."
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
        case .cannotApplyMessageEventForDifferentMessage:
            "Cannot apply MessageEvent for a different message."
        case .cannotApplyReactionSummaryEventForDifferentMessage:
            "Cannot apply MessageReactionSummaryEvent for a different message."
        case .cannotApplyCreatedMessageEvent:
            "Cannot apply created message event."
        case .failedToResolveSubscriptionPointBecauseAttachSerialNotDefined:
            "Channel is attached, but attachSerial is not defined."
        case let .failedToResolveSubscriptionPointBecauseChannelFailedToAttach(cause):
            "Channel failed to attach: \(String(describing: cause))"
        case .sendMessageReactionEmptyMessageSerial:
            "Failed to send message reaction: message serial must not be empty"
        case .deleteMessageReactionEmptyMessageSerial:
            "Failed to delete message reaction: message serial must not be empty"
        }
    }

    /// The ``ErrorInfo/cause`` that should be returned for this error.
    internal var cause: ErrorInfo? {
        switch self {
        case let .roomTransitionedToInvalidStateForPresenceOperation(cause):
            cause
        case let .roomDiscontinuity(cause):
            cause
        case let .failedToResolveSubscriptionPointBecauseChannelFailedToAttach(cause):
            cause
        case .other,
             .roomExistsWithDifferentOptions,
             .roomIsReleasing,
             .roomReleasedBeforeOperationCompleted,
             .presenceOperationRequiresRoomAttach,
             .cannotApplyCreatedMessageEvent,
             .unableDeleteReactionWithoutName,
             .failedToResolveSubscriptionPointBecauseAttachSerialNotDefined,
             .roomInInvalidStateForAttach,
             .roomInInvalidStateForDetach,
             .cannotApplyMessageEventForDifferentMessage,
             .cannotApplyReactionSummaryEventForDifferentMessage,
             .sendMessageReactionEmptyMessageSerial,
             .deleteMessageReactionEmptyMessageSerial:
            nil
        }
    }
}

// MARK: - Convenience conversions to InternalError

internal protocol ConvertibleToInternalError {
    func toInternalError() -> InternalError
}

internal extension ConvertibleToInternalError {
    /// Convenience method to convert directly to an `ErrorInfo`.
    func toErrorInfo() -> ErrorInfo {
        toInternalError().toErrorInfo()
    }
}

extension ChatAPI.ChatError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .other(.chatAPIChatError(self))
    }
}

extension HeadersValue.JSONDecodingError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .other(.headersValueJSONDecodingError(self))
    }
}

extension JSONValueDecodingError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .other(.jsonValueDecodingError(self))
    }
}

extension PaginatedResultError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .other(.paginatedResultError(self))
    }
}

extension DefaultMessages.MessagesError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .other(.messagesError(self))
    }
}
