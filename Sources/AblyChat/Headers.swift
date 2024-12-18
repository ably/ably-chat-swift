/// A value that can be used in ``Headers``. It is the same as ``JSONValue`` except it does not have the `object` or `array` cases.
public enum HeadersValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    // MARK: - Convenience getters for associated values

    /// If this `HeadersValue` has case `string`, this returns the associated value. Else, it returns `nil`.
    public var stringValue: String? {
        if case let .string(stringValue) = self {
            stringValue
        } else {
            nil
        }
    }

    /// If this `HeadersValue` has case `number`, this returns the associated value. Else, it returns `nil`.
    public var numberValue: Double? {
        if case let .number(numberValue) = self {
            numberValue
        } else {
            nil
        }
    }

    /// If this `HeadersValue` has case `bool`, this returns the associated value. Else, it returns `nil`.
    public var boolValue: Bool? {
        if case let .bool(boolValue) = self {
            boolValue
        } else {
            nil
        }
    }

    /// Returns true if and only if this `HeadersValue` has case `null`.
    public var isNull: Bool {
        if case .null = self {
            true
        } else {
            false
        }
    }
}

extension HeadersValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension HeadersValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension HeadersValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension HeadersValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
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
