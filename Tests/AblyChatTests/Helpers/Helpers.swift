import Ably
@testable import AblyChat

/**
 Tests whether a given optional `Error` is an `ARTErrorInfo` in the chat error domain with a given code and cause, or an `InternalError` that wraps such an `ARTErrorInfo`. Can optionally pass a message and it will check that it matches.
 */
func isChatError(_ maybeError: (any Error)?, withCodeAndStatusCode codeAndStatusCode: AblyChat.ErrorCodeAndStatusCode, cause: ARTErrorInfo? = nil, message: String? = nil) -> Bool {
    // Is it an ARTErrorInfo?
    var ablyError = maybeError as? ARTErrorInfo

    // Is it an InternalError wrapping an ARTErrorInfo?
    if ablyError == nil {
        if let internalError = maybeError as? InternalError, case let .errorInfo(errorInfo) = internalError {
            ablyError = errorInfo
        }
    }

    guard let ablyError else {
        return false
    }

    return ablyError.domain == AblyChat.errorDomain as String
        && ablyError.code == codeAndStatusCode.code.rawValue
        && ablyError.statusCode == codeAndStatusCode.statusCode
        && ablyError.cause == cause
        && {
            guard let message else {
                return true
            }

            return ablyError.message == message
        }()
}

func isInternalErrorWrappingErrorInfo(_ error: any Error, _ expectedErrorInfo: ARTErrorInfo) -> Bool {
    if let internalError = error as? InternalError, case let .errorInfo(actualErrorInfo) = internalError, expectedErrorInfo == actualErrorInfo {
        true
    } else {
        false
    }
}

extension InternalError {
    enum Case {
        case errorInfo
        case chatAPIChatError
        case headersValueJSONDecodingError
        case jsonValueDecodingError
        case paginatedResultError
        case messagesError
    }

    var enumCase: Case {
        switch self {
        case .errorInfo:
            .errorInfo
        case .other(.chatAPIChatError):
            .chatAPIChatError
        case .other(.headersValueJSONDecodingError):
            .headersValueJSONDecodingError
        case .other(.jsonValueDecodingError):
            .jsonValueDecodingError
        case .other(.paginatedResultError):
            .paginatedResultError
        case .other(.messagesError):
            .messagesError
        }
    }
}

func isInternalErrorWithCase(_ error: any Error, _ expectedCase: InternalError.Case) -> Bool {
    if let internalError = error as? InternalError, internalError.enumCase == expectedCase {
        true
    } else {
        false
    }
}
