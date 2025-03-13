import Ably

/// An error thrown by the internals of the Chat SDK.
///
/// This was originally created to represent any of the various internal types that existed at the time of converting the public API of the SDK to throw ARTErrorInfo. We may rethink this when we do a broader rethink of the errors thrown by the SDK in https://github.com/ably/ably-chat-swift/issues/32. For now, feel free to introduce further internal error types and add them to the `Other` enum.
internal enum InternalError: Error {
    case errorInfo(ARTErrorInfo)
    case other(Other)

    internal enum Other {
        case chatAPIChatError(ChatAPI.ChatError)
        case headersValueJSONDecodingError(HeadersValue.JSONDecodingError)
        case jsonValueDecodingError(JSONValueDecodingError)
        case paginatedResultError(PaginatedResultError)
    }

    /// Returns the error that this should be converted to when exposed via the SDK's public API.
    internal func toARTErrorInfo() -> ARTErrorInfo {
        switch self {
        case let .errorInfo(errorInfo):
            errorInfo
        case let .other(other):
            .init(chatError: .nonErrorInfoInternalError(other))
        }
    }

    // Useful for logging
    internal var message: String {
        toARTErrorInfo().message
    }
}

internal extension ARTErrorInfo {
    func toInternalError() -> InternalError {
        .errorInfo(self)
    }
}

internal extension ChatAPI.ChatError {
    func toInternalError() -> InternalError {
        .other(.chatAPIChatError(self))
    }
}

internal extension HeadersValue.JSONDecodingError {
    func toInternalError() -> InternalError {
        .other(.headersValueJSONDecodingError(self))
    }
}

internal extension JSONValueDecodingError {
    func toInternalError() -> InternalError {
        .other(.jsonValueDecodingError(self))
    }
}

internal extension PaginatedResultError {
    func toInternalError() -> InternalError {
        .other(.paginatedResultError(self))
    }
}
