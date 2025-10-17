import Ably

// MARK: - Error codes

/// The ```ErrorInfo/code`` values for errors thrown internally by the Chat SDK.
internal enum ErrorCode: Int {
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

        /// The ``ErrorInfo/statusCode`` that should be returned for this error.
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

// MARK: - InternalError

/// Either an error thrown by an ably-cocoa operation performed by the Chat SDK, or an error thrown by the Chat SDK itself.
///
/// Provides the rich error information that is stored inside an ``ErrorInfo``. `ErrorInfo` then maps these errors to its public properties (`code`, `statusCode` etc), but it also keeps hold of the original `InternalError` to aid with debugging.
///
/// This type does not conform to `Error` and cannot be thrown directly. It serves as the backing storage for ``ErrorInfo``, which is the actual error type thrown by the SDK.
internal enum InternalError {
    /// An error thrown by ably-cocoa that we wish to re-throw, or an error thrown by ably-cocoa that we wish to use for the `cause` of an ``ErrorInfo``, or the `cause` of an error thrown by ably-cocoa.
    case fromAblyCocoa(ARTErrorInfo)

    /// An error thrown by the Chat SDK itself.
    case internallyThrown(InternallyThrown)

    /// Returns the error that this should be converted to when exposed via the SDK's public API.
    internal func toErrorInfo() -> ErrorInfo {
        .init(internalError: self)
    }

    // Useful for logging
    internal var message: String {
        switch self {
        case let .fromAblyCocoa(ablyCocoaError):
            ablyCocoaError.message
        case let .internallyThrown(internallyThrown):
            internallyThrown.message
        }
    }

    /// A specific error thrown by the internals of the Chat SDK.
    ///
    /// This type exists in addition to ``ErrorCode`` to allow us to attach metadata which can be incorporated into the error's `message` and `cause`.
    internal enum InternallyThrown {
        case other(Other)
        case inconsistentRoomOptions(requested: RoomOptions, existing: RoomOptions)
        case roomInFailedState
        case roomIsReleasing
        case roomIsReleased
        case roomReleasedBeforeOperationCompleted
        case presenceOperationRequiresRoomAttach(feature: RoomFeature)
        case roomTransitionedToInvalidStateForPresenceOperation(cause: ErrorInfo?)
        case roomDiscontinuity(cause: ErrorInfo?)
        case unableDeleteReactionWithoutName(reactionType: String)
        case cannotApplyEventForDifferentMessage
        case cannotApplyCreatedMessageEvent
        case messageRejectedByBeforePublishRule
        case messageRejectedByModeration
        case attachSerialIsNotDefined
        case channelFailedToAttach(cause: ErrorInfo?)

        /// This was originally created to represent any of the various internal types that existed at the time of converting the public API of the SDK to throw ErrorInfo. We may rethink this when we do a broader rethink of the errors thrown by the SDK in https://github.com/ably/ably-chat-swift/issues/32. For now, feel free to introduce further internal error types and add them to the `Other` enum.
        internal enum Other {
            case chatAPIChatError(ChatAPI.ChatError)
            case headersValueJSONDecodingError(HeadersValue.JSONDecodingError)
            case jsonValueDecodingError(JSONValueDecodingError)
            case paginatedResultError(PaginatedResultError)
            case messagesError(DefaultMessages.MessagesError)
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
            case .cannotApplyCreatedMessageEvent:
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

        /// The ``ErrorInfo/message`` that should be returned for this error.
        internal var message: String {
            switch self {
            case let .other(otherInternalError):
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
            case .cannotApplyCreatedMessageEvent:
                "Cannot apply created message event."
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

        /// The ``ErrorInfo/cause`` that should be returned for this error.
        internal var cause: ErrorInfo? {
            switch self {
            case let .roomTransitionedToInvalidStateForPresenceOperation(cause):
                cause
            case let .roomDiscontinuity(cause):
                cause
            case let .channelFailedToAttach(cause):
                cause
            case .other,
                 .inconsistentRoomOptions,
                 .roomInFailedState,
                 .roomIsReleasing,
                 .roomIsReleased,
                 .roomReleasedBeforeOperationCompleted,
                 .presenceOperationRequiresRoomAttach,
                 .cannotApplyEventForDifferentMessage,
                 .cannotApplyCreatedMessageEvent,
                 .unableDeleteReactionWithoutName,
                 .messageRejectedByBeforePublishRule,
                 .messageRejectedByModeration,
                 .attachSerialIsNotDefined:
                nil
            }
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
        .internallyThrown(.other(.chatAPIChatError(self)))
    }
}

extension HeadersValue.JSONDecodingError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .internallyThrown(.other(.headersValueJSONDecodingError(self)))
    }
}

extension JSONValueDecodingError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .internallyThrown(.other(.jsonValueDecodingError(self)))
    }
}

extension PaginatedResultError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .internallyThrown(.other(.paginatedResultError(self)))
    }
}

extension DefaultMessages.MessagesError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .internallyThrown(.other(.messagesError(self)))
    }
}
