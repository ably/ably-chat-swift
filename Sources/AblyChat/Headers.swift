// TODO: https://github.com/ably-labs/ably-chat-swift/issues/13 - try to improve this type

public enum HeadersValue: Sendable, Equatable {
    case string(String)
    case number(Double)
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

/**
 * Headers are a flat key-value map that can be attached to chat messages.
 *
 * The headers are a flat key-value map and are sent as part of the realtime
 * message's extras inside the `headers` property. They can serve similar
 * purposes as ``Metadata`` but as opposed to `Metadata` they are read by Ably and
 * can be used for features such as
 * [subscription filters](https://faqs.ably.com/subscription-filters).
 *
 * Do not use the headers for authoritative information. There is no
 * server-side validation. When reading the headers treat them like user
 * input.
 *
 */
public typealias Headers = [String: HeadersValue]
