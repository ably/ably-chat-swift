import os

public typealias LogContext = [String: JSONValue]

public protocol LogHandler: AnyObject, Sendable {
    /**
     * A function that can be used to handle log messages.
     *
     * - Parameters:
     *   - message: The message to log.
     *   - level: The log level of the message.
     *   - context: The context of the log message as key-value pairs.
     */
    func log(message: String, level: LogLevel, context: LogContext?)
}

/**
 * Represents the different levels of logging that can be used.
 */
public enum LogLevel: Sendable, Comparable {
    case trace
    case debug
    case info
    case warn
    case error
    case silent
}

/// A reference to a line within a source code file.
internal struct CodeLocation: Equatable {
    /// A file identifier in the format used by Swift’s `#fileID` macro. For example, `"AblyChat/Room.swift"`.
    internal var fileID: String
    /// The line number in the source code file referred to by ``fileID``.
    internal var line: Int
}

/// A log handler to be used by components of the Chat SDK.
///
/// This protocol exists to give internal SDK components access to a logging interface that allows them to provide rich and granular logging information, whilst giving us control over how much of this granularity we choose to expose to users of the SDK versus instead handling it for them by, say, interpolating it into a log message. It also allows us to evolve the logging interface used internally without introducing breaking changes for users of the SDK.
internal protocol InternalLogger: Sendable {
    /// Logs a message.
    /// - Parameters:
    ///   - message: The message to log.
    ///   - level: The log level of the message.
    ///   - codeLocation: The location in the code where the message was emitted.
    func log(message: String, level: LogLevel, codeLocation: CodeLocation)
}

extension InternalLogger {
    /// A convenience logging method that uses the call site’s #file and #line values.
    public func log(message: String, level: LogLevel, fileID: String = #fileID, line: Int = #line) {
        let codeLocation = CodeLocation(fileID: fileID, line: line)
        log(message: message, level: level, codeLocation: codeLocation)
    }
}

internal final class DefaultInternalLogger: InternalLogger {
    private let logHandler: LogHandler

    #if DEBUG
        internal var testsOnly_logHandler: LogHandler {
            logHandler
        }
    #endif

    private let logLevel: LogLevel

    #if DEBUG
        internal var testsOnly_logLevel: LogLevel {
            logLevel
        }
    #endif

    internal init(logHandler: LogHandler?, logLevel: LogLevel?) {
        self.logHandler = logHandler ?? DefaultLogHandler()
        self.logLevel = logLevel ?? .error
    }

    internal func log(message: String, level: LogLevel, codeLocation: CodeLocation) {
        guard level >= logLevel else {
            return
        }

        // I don’t yet know what `context` is for (will figure out in https://github.com/ably-labs/ably-chat-swift/issues/8) so passing nil for now
        logHandler.log(message: "(\(codeLocation.fileID):\(codeLocation.line)) \(message)", level: level, context: nil)
    }
}

/// The logging backend used by ``DefaultInternalLogHandler`` if the user has not provided their own. Uses Swift’s `Logger` type for logging.
internal final class DefaultLogHandler: LogHandler {
    private let logger = Logger()

    internal func log(message: String, level: LogLevel, context _: LogContext?) {
        guard let osLogType = level.toOSLogType else {
            // Treating .silent as meaning "don’t log it", will figure out the meaning of .silent in https://github.com/ably-labs/ably-chat-swift/issues/8
            return
        }

        logger.log(level: osLogType, "\(message)")
    }
}

private extension LogLevel {
    var toOSLogType: OSLogType? {
        switch self {
        case .debug, .trace:
            .debug
        case .info:
            .info
        case .warn, .error:
            .error
        case .silent:
            nil
        }
    }
}
