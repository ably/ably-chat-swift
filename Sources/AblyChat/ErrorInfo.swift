import Ably
import Foundation

/// A generic Ably error object that contains an Ably-specific error code, and a generic status code.
public struct ErrorInfo: Error, CustomStringConvertible {
    /// The source of an `ErrorInfo`'s public properties (`code`, `statusCode` etc).
    internal indirect enum Source {
        /// An error thrown by ably-cocoa that we wish to re-throw as an `ErrorInfo`, or an error thrown by ably-cocoa that we wish to use for the `cause` of an `ErrorInfo`, or the `cause` of an error thrown by ably-cocoa that we wish to use for the `cause` of an `ErrorInfo`.
        case fromAblyCocoa(ARTErrorInfo)

        /// The public properties come from an `InternalError`.
        case internalError(InternalError)

        /// The public properties come from the public initializer.
        case initializer(InitializerArguments)

        internal struct InitializerArguments {
            internal var code: Int
            internal var href: String?
            internal var message: String
            internal var cause: ErrorInfo?
            internal var statusCode: Int
            internal var requestID: String?
        }

        internal var code: Int {
            switch self {
            case let .fromAblyCocoa(ablyCocoaError):
                ablyCocoaError.code
            case let .internalError(internalError):
                internalError.codeAndStatusCode.code.rawValue
            case let .initializer(args):
                args.code
            }
        }

        internal var href: String? {
            switch self {
            case let .fromAblyCocoa(ablyCocoaError):
                ablyCocoaError.href
            case .internalError:
                nil
            case let .initializer(args):
                args.href
            }
        }

        internal var message: String {
            switch self {
            case let .fromAblyCocoa(ablyCocoaError):
                ablyCocoaError.message
            case let .internalError(internalError):
                internalError.message
            case let .initializer(args):
                args.message
            }
        }

        internal var cause: ErrorInfo? {
            switch self {
            case let .fromAblyCocoa(ablyCocoaError):
                .init(optionalAblyCocoaError: ablyCocoaError.cause)
            case let .internalError(internalError):
                internalError.cause
            case let .initializer(args):
                args.cause
            }
        }

        internal var statusCode: Int {
            switch self {
            case let .fromAblyCocoa(ablyCocoaError):
                ablyCocoaError.statusCode
            case let .internalError(internalError):
                internalError.codeAndStatusCode.statusCode
            case let .initializer(args):
                args.statusCode
            }
        }

        internal var requestID: String? {
            switch self {
            case let .fromAblyCocoa(ablyCocoaError):
                ablyCocoaError.requestId
            case .internalError:
                nil
            case let .initializer(args):
                args.requestID
            }
        }
    }

    /// The source of this `ErrorInfo`'s public properties.
    internal var source: Source

    /// Creates an `ErrorInfo` from an `InternalError`.
    internal init(internalError: InternalError) {
        source = .internalError(internalError)
    }

    /// Creates an `ErrorInfo` from an `ARTErrorInfo`.
    internal init(ablyCocoaError: ARTErrorInfo) {
        source = .fromAblyCocoa(ablyCocoaError)
    }

    /// Creates an `ErrorInfo` from an optional `ARTErrorInfo`, returning `nil` if the ably-cocoa error is `nil`.
    ///
    /// - Warning: Only use this if you truly do not know or care whether the ably-cocoa error is nil; otherwise, favour ``init(ablyCocoaError:)``.
    internal init?(optionalAblyCocoaError: ARTErrorInfo?) {
        guard let ablyCocoaError = optionalAblyCocoaError else {
            return nil
        }

        self.init(ablyCocoaError: ablyCocoaError)
    }

    /// Memberwise initializer to create an `ErrorInfo`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(
        code: Int,
        href: String? = nil,
        message: String,
        cause: ErrorInfo? = nil,
        statusCode: Int,
        requestID: String? = nil,
    ) {
        source = .initializer(
            .init(
                code: code,
                href: href,
                message: message,
                cause: cause,
                statusCode: statusCode,
                requestID: requestID,
            ),
        )
    }

    /// Ably [error code](https://github.com/ably/ably-common/blob/main/protocol/errors.json).
    public var code: Int {
        source.code
    }

    /// This is included for REST responses to provide a URL for additional help on the error code.
    public var href: String? {
        source.href
    }

    /// Human-readable description of the error.
    public var message: String {
        source.message
    }

    /// Information pertaining to what caused the error where available.
    public var cause: ErrorInfo? {
        source.cause
    }

    /// HTTP Status Code corresponding to this error.
    public var statusCode: Int {
        source.statusCode
    }

    /// The ID associated with this REST request.
    public var requestID: String? {
        source.requestID
    }

    // MARK: - CustomStringConvertible

    /// Requirement of the `CustomStringConvertible` protocol.
    public var description: String {
        switch source {
        case let .fromAblyCocoa(ablyCocoaError):
            ablyCocoaError.localizedDescription
        case let .internalError(internalError):
            "(\(statusCode):\(code)) \(message). See \(helpHref). Full error: \(internalError)"
        case .initializer:
            "(\(statusCode):\(code)) \(message). See \(helpHref)."
        }
    }

    /// Overrides the default implementation of this property that Foundation provides for the `Error` protocol.
    ///
    /// Foundation's default implementation is not very useful; it just returns "The operation couldn't be completed. (AblyChat.ErrorInfo error 1.)" for all errors.
    public var localizedDescription: String {
        description
    }

    /// Returns the help URL that should be included in log messages that refer to this error, per TI5.
    ///
    /// - Note: This doesn't return a URL because we don't want to make any assumptions about whether a server-sent `href` property contains a valid URL.
    internal var helpHref: String {
        // TI5
        if let href {
            return href
        }

        return "https://help.ably.io/error/\(code)"
    }
}
