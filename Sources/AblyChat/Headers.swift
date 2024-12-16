// TODO: https://github.com/ably-labs/ably-chat-swift/issues/13 - try to improve this type

public enum HeadersValue: Sendable, Codable, Equatable {
    case string(String)
    case number(Double) // Changed from NSNumber to Double to conform to Codable. Address in linked issue above.
    case bool(Bool)
    case null
}

extension HeadersValue: JSONDecodable {
    internal enum JSONDecodingError: Error {
        case unsupportedJSONValue(JSONValue)
    }

    internal init(jsonValue: JSONValue) throws {
        self = switch jsonValue {
        case let .string(value):
            .string(value)
        case let .number(value):
            .number(value)
        case let .bool(value):
            .bool(value)
        case .null:
            .null
        default:
            throw JSONDecodingError.unsupportedJSONValue(jsonValue)
        }
    }
}

extension HeadersValue: JSONEncodable {
    internal var toJSONValue: JSONValue {
        switch self {
        case let .string(value):
            .string(value)
        case let .number(value):
            .number(Double(value))
        case let .bool(value):
            .bool(value)
        case .null:
            .null
        }
    }
}

// The corresponding type in TypeScript is
// Record<string, number | string | boolean | null | undefined>
// There may be a better way to represent it in Swift; this will do for now. Have omitted `undefined` because I don’t know how that would occur.
public typealias Headers = [String: HeadersValue]
