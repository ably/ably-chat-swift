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

extension ARTPresenceMessage {
    convenience init(clientId: String, data: Any? = [:], timestamp: Date = Date()) {
        self.init()
        self.clientId = clientId
        self.data = data
        self.timestamp = timestamp
    }
}

extension [PresenceEventType] {
    static let all = [
        PresenceEventType.present,
        PresenceEventType.enter,
        PresenceEventType.leave,
        PresenceEventType.update,
    ]
}

/// Compares Any to another Any which is unavailable by default in swift for type safety, but useful to have in tests.
func compareAny(_ any1: Any?, with any2: Any?) -> Bool {
    guard let any1, let any2 else {
        return any1 == nil && any2 == nil
    }
    if let any1 = any1 as? Int, let any2 = any2 as? Int {
        return any1 == any2
    } else if let any1 = any1 as? Bool, let any2 = any2 as? Bool {
        return any1 == any2
    } else if let any1 = any1 as? String, let any2 = any2 as? String {
        return any1 == any2
    } else if let any1 = any1 as? JSONValue, let any2 = any2 as? JSONValue {
        return any1 == any2
    } else if let any1 = any1 as? [String: Any], let any2 = any2 as? [String: Any] {
        return NSDictionary(dictionary: any1).isEqual(to: any2)
    } else if let any1 = any1 as? [Any], let any2 = any2 as? [Any] {
        guard any1.count == any2.count else {
            return false
        }
        for i in 0 ..< any1.count where !compareAny(any1[i], with: any2[i]) {
            return false
        }
        return true
    }
    return false
}

/// A threadsafe mock methods call logger.
class MockMethodCallRecorder: @unchecked Sendable {
    struct MethodArgument: Equatable {
        let name: String
        let value: Any?

        static func == (lhs: Self, rhs: Self) -> Bool {
            guard lhs.name == rhs.name else {
                return false
            }
            return compareAny(lhs.value, with: rhs.value)
        }
    }

    struct CallRecord {
        let signature: String
        let arguments: [MethodArgument]
    }

    private var mutex = NSLock()
    private var records = [CallRecord]()

    func addRecord(signature: String, arguments: [String: Any?]) { // chose Any to not to deal with types in the test's code
        mutex.withLock {
            records.append(CallRecord(signature: signature, arguments: arguments.map { MethodArgument(name: $0.key, value: $0.value) }))
        }
    }

    func hasRecord(matching signature: String, arguments: [String: Any]) -> Bool {
        mutex.lock()
        let result = records.contains { record in
            guard record.signature == signature else {
                return false
            }
            let args1 = record.arguments.sorted()
            let args2 = arguments.map { MethodArgument(name: $0.key, value: $0.value) }.sorted()
            return args1 == args2
        }
        mutex.unlock()
        return result
    }
}

private extension [MockMethodCallRecorder.MethodArgument] {
    func sorted() -> [MockMethodCallRecorder.MethodArgument] {
        sorted { $0.name < $1.name }
    }
}

extension [String: Any] {
    func toAblyCocoaData() -> Any {
        // Probaly there is a better way of doing this
        PresenceDataDTO(userCustomData: JSONValue(ablyCocoaData: self)).toJSONValue.toAblyCocoaData
    }
}
