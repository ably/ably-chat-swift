import Ably

/// An error thrown by the Chat SDK itself (as opposed to a re-thrown ably-cocoa error).
///
/// Provides the rich error information that is stored inside an ``ErrorInfo``. `ErrorInfo` then maps these errors to its public properties (`code`, `statusCode` etc), but it also keeps hold of the original `InternalError` to aid with debugging.
///
/// This type does not conform to `Error` and cannot be thrown directly. It serves as the backing storage for ``ErrorInfo``, which is the actual error type thrown by the SDK.
internal enum InternalError {
    // MARK: Errors from the spec

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
    case roomIsReleasing(operation: AttachOrDetach)

    /// The user attempted to release a room whilst a release operation was already in progress, causing the release operation to fail per CHA-RC1g4.
    ///
    /// Error code is `roomReleasedBeforeOperationCompleted`.
    case roomReleasedBeforeOperationCompleted

    /// The user attempted to perform a presence operation whilst the room was not ATTACHED or ATTACHING, resulting in this error per CHA-PR3h, CHA-PR10h, CHA-PR6h.
    ///
    /// Error code is `roomInInvalidState`.
    case presenceOperationRequiresRoomAttach

    /// The user attempted to perform a presence operation whilst the room was ATTACHING, and after waiting for a room status change the next status was not ATTACHED, resulting in this error per CHA-RL9c.
    ///
    /// Error code is `roomInInvalidState`.
    case roomTransitionedToInvalidStateForPresenceOperation(newState: RoomStatus, cause: ErrorInfo?)

    /// The room's channel emitted an event representing a discontinuity, and so the room emitted this error per CHA-RL12b.
    ///
    /// Error code is `roomDiscontinuity`.
    case roomDiscontinuity(cause: ErrorInfo?)

    /// The user attempted to delete a reaction of type different than `unique`, without specifying the reaction identifier. This is not allowed per CHA-MR11b1a.
    ///
    /// Error code is `invalidArgument` (this is not specified by the spec, which does not make it explicit that the SDK should throw an error in this scenario).
    case unableDeleteReactionWithoutName(reactionType: String)

    // MARK: - Errors not from the spec

    // TODO: Revisit the non-specified errors as part of https://github.com/ably/ably-chat-swift/issues/438

    /// Unable to fetch `historyBeforeSubscribe` because the `DefaultMessages` instance that stores the subscription points has been deallocated.
    ///
    /// Error code is `badRequest` (this is our own error, which is not specified by the spec).
    case failedToResolveSubscriptionPointBecauseMessagesInstanceGone

    /// Unable to fetch `historyBeforeSubscribe` because a channel in the `ATTACHED` state has violated our expectations by its `attachSerial` not being populated, so we cannot resolve its "subscription point" per CHA-M5b.
    ///
    /// Error code is `badRequest` (this is not specified by the spec, which does not make it explicit that the SDK should throw an error in this scenario).
    case failedToResolveSubscriptionPointBecauseAttachSerialNotDefined

    /// Unable to fetch `historyBeforeSubscribe` because whilst waiting for a channel to become attached per CHA-M5b in order to resolve its "subscription point".
    ///
    /// Error code is `badRequest` (this is not specified by the spec, which does not make it explicit that the SDK should throw an error in this scenario).
    case failedToResolveSubscriptionPointBecauseChannelFailedToAttach(cause: ErrorInfo?)

    /// Attempted to load a resource from the given `path`, expecting to get a single item back, but the returned `PaginatedResult` is empty.
    ///
    /// Error code is `badRequest` (this is not specified by the spec, which does not make it explicit that the SDK should throw an error in this scenario).
    case noItemInResponse(path: String)

    /// An ably-cocoa `ARTHTTPPaginatedResponse` was received with the given non-200 status code.
    ///
    /// Error code is `badRequest` (this is not specified by the spec, which does not make it explicit that the SDK should throw an error in this scenario).
    case paginatedResultStatusCode(Int)

    // Failed to decode a `HeadersValue` from a `JSONValue`.
    ///
    /// Error code is `badRequest` (this is our own error, which is not specified by the spec).
    case headersValueJSONDecodingError(HeadersValue.JSONDecodingError)

    /// Failed to decode a type from a `JSONValue`.
    ///
    /// Error code is `badRequest` (this is our own error, which is not specified by the spec).
    case jsonValueDecodingError(JSONValueDecodingError)

    // MARK: - Representation as ErrorInfo

    /// Returns the error that this should be converted to when exposed via the SDK's public API.
    internal func toErrorInfo() -> ErrorInfo {
        .init(internalError: self)
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

    internal var code: ErrorCode {
        switch self {
        case .roomExistsWithDifferentOptions:
            .roomExistsWithDifferentOptions
        case .roomIsReleasing:
            .roomInInvalidState
        case .roomReleasedBeforeOperationCompleted:
            .roomReleasedBeforeOperationCompleted
        case .roomInInvalidStateForAttach:
            .roomInInvalidState
        case .roomInInvalidStateForDetach:
            .roomInInvalidState
        case .sendMessageReactionEmptyMessageSerial:
            .invalidArgument
        case .deleteMessageReactionEmptyMessageSerial:
            .invalidArgument
        case .roomTransitionedToInvalidStateForPresenceOperation:
            // CHA-RL9c
            .roomInInvalidState
        case .presenceOperationRequiresRoomAttach:
            // CHA-PR3h, CHA-PR10h, CHA-PR6h
            .roomInInvalidState
        case .roomDiscontinuity:
            .roomDiscontinuity
        case .unableDeleteReactionWithoutName:
            .invalidArgument
        case .cannotApplyMessageEventForDifferentMessage:
            .invalidArgument
        case .cannotApplyReactionSummaryEventForDifferentMessage:
            .invalidArgument
        case .cannotApplyCreatedMessageEvent:
            .invalidArgument
        case .failedToResolveSubscriptionPointBecauseAttachSerialNotDefined:
            .badRequest
        case .failedToResolveSubscriptionPointBecauseChannelFailedToAttach:
            .badRequest
        case .noItemInResponse:
            .badRequest
        case .paginatedResultStatusCode:
            .badRequest
        case .failedToResolveSubscriptionPointBecauseMessagesInstanceGone:
            .badRequest
        case .headersValueJSONDecodingError:
            .badRequest
        case .jsonValueDecodingError:
            .badRequest
        }
    }

    private static func descriptionOfRoomStatus(_ roomStatus: RoomStatus) -> String {
        switch roomStatus {
        case .initialized:
            "INITIALIZED"
        case .attaching:
            "ATTACHING"
        case .attached:
            "ATTACHED"
        case .detaching:
            "DETACHING"
        case .detached:
            "DETACHED"
        case .suspended:
            "SUSPENDED"
        case .failed:
            "FAILED"
        case .releasing:
            "RELEASING"
        case .released:
            "RELEASED"
        }
    }

    /// A helper type for parameterising the construction of error messages.
    internal enum AttachOrDetach {
        case attach
        case detach

        /// The `op` to be inserted into an error message of CHA-GP6's prescribed format `"unable to <op>; <reason>"`.
        internal var opForMessage: String {
            switch self {
            case .attach:
                "attach room"
            case .detach:
                "detach room"
            }
        }
    }

    /// The ``ErrorInfo/message`` that should be returned for this error.
    ///
    /// This message follows the format specified by CHA-GP6 of `"unable to <op>; <reason>"`.
    internal var message: String {
        let op: String
        let reason: String

        switch self {
        case let .roomExistsWithDifferentOptions(requested, existing):
            op = "get room"
            reason = "room already exists with different options. You must release the existing room instance before requesting with different options. Requested: \(requested), existing: \(existing)"
        case let .roomInInvalidStateForAttach(roomStatus):
            op = "attach room"
            reason = "room is in \(Self.descriptionOfRoomStatus(roomStatus)) state"
        case let .roomInInvalidStateForDetach(roomStatus):
            op = "detach room"
            reason = "room is in \(Self.descriptionOfRoomStatus(roomStatus)) state"
        case let .roomIsReleasing(operation):
            op = operation.opForMessage
            reason = "room is releasing"
        case .roomReleasedBeforeOperationCompleted:
            op = "release room"
            reason = "another room release operation was started"
        case .presenceOperationRequiresRoomAttach:
            op = "perform presence operation"
            reason = "room must be in ATTACHED or ATTACHING status"
        case let .roomTransitionedToInvalidStateForPresenceOperation(newState: newState, cause: cause):
            op = "perform presence operation"
            reason = "room transitioned to invalid state \(newState): \(cause, default: "(nil cause)")"
        case let .roomDiscontinuity(cause):
            op = "maintain room message continuity"
            reason = "room experienced a discontinuity: \(cause, default: "(nil cause)")"
        case let .unableDeleteReactionWithoutName(reactionType: reactionType):
            op = "delete reaction"
            reason = "reaction of type '\(reactionType)' requires a name to be specified"
        case .cannotApplyMessageEventForDifferentMessage:
            op = "apply MessageEvent"
            reason = "message serial does not match the event's message serial"
        case .cannotApplyReactionSummaryEventForDifferentMessage:
            op = "apply ReactionSummaryEvent"
            reason = "message serial does not match the event's message serial"
        case .cannotApplyCreatedMessageEvent:
            op = "apply message event"
            reason = "cannot apply created event to existing message"
        case .failedToResolveSubscriptionPointBecauseMessagesInstanceGone:
            op = "fetch message history from before subscription"
            reason = "Messages instance has been deallocated"
        case .failedToResolveSubscriptionPointBecauseAttachSerialNotDefined:
            op = "fetch message history from before subscription"
            reason = "channel is attached but attachSerial is not defined"
        case let .failedToResolveSubscriptionPointBecauseChannelFailedToAttach(cause):
            op = "fetch message history from before subscription"
            reason = "channel failed to attach: \(cause, default: "(nil cause)")"
        case .sendMessageReactionEmptyMessageSerial:
            op = "send message reaction"
            reason = "message serial must not be empty"
        case .deleteMessageReactionEmptyMessageSerial:
            op = "delete message reaction"
            reason = "message serial must not be empty"
        case let .noItemInResponse(path):
            op = "load resource"
            reason = "paginated result from path \(path) is empty"
        case let .paginatedResultStatusCode(statusCode):
            op = "load resource"
            reason = "received status code \(statusCode)"
        case let .headersValueJSONDecodingError(error):
            op = "decode headers"
            switch error {
            case let .unsupportedJSONValue(jsonValue):
                reason = "unsupported JSON value \(jsonValue)"
            }
        case let .jsonValueDecodingError(error):
            op = "decode JSON"
            switch error {
            case .valueIsNotObject:
                reason = "value is not an object"
            case let .noValueForKey(key):
                reason = "no value for key '\(key)'"
            case let .wrongTypeForKey(key, actualValue: actualValue):
                reason = "wrong type for key '\(key)', got \(actualValue)"
            case let .failedToDecodeFromRawValue(type: type, rawValue: rawValue):
                reason = "could not decode \(type) from raw value \(rawValue)"
            }
        }

        return "unable to \(op); \(reason)"
    }

    /// The ``ErrorInfo/cause`` that should be returned for this error.
    internal var cause: ErrorInfo? {
        switch self {
        case let .roomTransitionedToInvalidStateForPresenceOperation(newState: _, cause: cause):
            cause
        case let .roomDiscontinuity(cause):
            cause
        case let .failedToResolveSubscriptionPointBecauseChannelFailedToAttach(cause):
            cause
        case .jsonValueDecodingError,
             .headersValueJSONDecodingError,
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
             .deleteMessageReactionEmptyMessageSerial,
             .noItemInResponse,
             .paginatedResultStatusCode,
             .failedToResolveSubscriptionPointBecauseMessagesInstanceGone:
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

extension HeadersValue.JSONDecodingError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .headersValueJSONDecodingError(self)
    }
}

extension JSONValueDecodingError: ConvertibleToInternalError {
    internal func toInternalError() -> InternalError {
        .jsonValueDecodingError(self)
    }
}
