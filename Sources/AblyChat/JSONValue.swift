import Foundation

/// A JSON value (where "value" has the meaning defined by the [JSON specification](https://www.json.org)).
///
/// `JSONValue` provides a type-safe API for working with JSON values. It implements Swift’s `ExpressibleBy*Literal` protocols. This allows you to write type-safe JSON values using familiar syntax. For example:
///
/// ```swift
/// let jsonValue: JSONValue = [
///     "someArray": [
///         [
///             "someStringKey": "someString",
///             "someIntegerKey": 123,
///             "someFloatKey": 123.456,
///             "someTrueKey": true,
///             "someFalseKey": false,
///             "someNullKey": .null,
///         ],
///         "someOtherArrayElement",
///     ],
///     "someNestedObject": [
///         "someOtherKey": "someOtherValue",
///     ],
/// ]
///  ```
///
/// > Note: To write a `JSONValue` that corresponds to the `null` JSON value, you must explicitly write `.null`. `JSONValue` deliberately does not implement the `ExpressibleByNilLiteral` protocol in order to avoid confusion between a value of type `JSONValue?` and a `JSONValue` with case `.null`.
public indirect enum JSONValue: Sendable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    // MARK: - Convenience getters for associated values

    /// If this `JSONValue` has case `object`, this returns the associated value. Else, it returns `nil`.
    public var objectValue: [String: JSONValue]? {
        if case let .object(objectValue) = self {
            objectValue
        } else {
            nil
        }
    }

    /// If this `JSONValue` has case `array`, this returns the associated value. Else, it returns `nil`.
    public var arrayValue: [JSONValue]? {
        if case let .array(arrayValue) = self {
            arrayValue
        } else {
            nil
        }
    }

    /// If this `JSONValue` has case `string`, this returns the associated value. Else, it returns `nil`.
    public var stringValue: String? {
        if case let .string(stringValue) = self {
            stringValue
        } else {
            nil
        }
    }

    /// If this `JSONValue` has case `number`, this returns the associated value. Else, it returns `nil`.
    public var numberValue: Double? {
        if case let .number(numberValue) = self {
            numberValue
        } else {
            nil
        }
    }

    /// If this `JSONValue` has case `bool`, this returns the associated value. Else, it returns `nil`.
    public var boolValue: Bool? {
        if case let .bool(boolValue) = self {
            boolValue
        } else {
            nil
        }
    }

    /// Returns true if and only if this `JSONValue` has case `null`.
    public var isNull: Bool {
        if case .null = self {
            true
        } else {
            false
        }
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(.init(uniqueKeysWithValues: elements))
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

// MARK: - Bridging with ably-cocoa

internal extension JSONValue {
    /// Creates a `JSONValue` from an ably-cocoa deserialized JSON object.
    ///
    /// Specifically, `ablyCocoaData` can be:
    ///
    /// - a non-`nil` value of `ARTPresenceMessage`’s `data` property
    /// - a non-`nil` value of `ARTMessage`’s `data` property
    /// - the return value of the `toJSON()` method of a non-`nil` value of `ARTMessage`’s `extras` property
    init(ablyCocoaData: Any) {
        switch ablyCocoaData {
        case let dictionary as [String: Any]:
            self = .object(dictionary.mapValues { .init(ablyCocoaData: $0) })
        case let array as [Any]:
            self = .array(array.map { .init(ablyCocoaData: $0) })
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            // We need to be careful to distinguish booleans from numbers of value 0 or 1; technique taken from https://forums.swift.org/t/jsonserialization-turns-bool-value-to-nsnumber/31909/3
            if number === kCFBooleanTrue {
                self = .bool(true)
            } else if number === kCFBooleanFalse {
                self = .bool(false)
            } else {
                self = .number(number.doubleValue)
            }
        case is NSNull:
            self = .null
        default:
            // ably-cocoa is not conforming to our assumptions; either its behaviour is wrong or our assumptions are wrong. Either way, bring this loudly to our attention instead of trying to carry on
            preconditionFailure("JSONValue(ablyCocoaData:) was given \(ablyCocoaData)")
        }
    }

    /// Creates an ably-cocoa deserialized JSON object from a `JSONValue`.
    ///
    /// Specifically, the value of this property can be used as:
    ///
    /// - `ARTPresenceMessage`’s `data` property
    /// - the `data` argument that’s passed to `ARTRealtime`’s `request(…)` method
    var toAblyCocoaData: Any {
        switch self {
        case let .object(underlying):
            underlying.toAblyCocoaDataDictionary
        case let .array(underlying):
            underlying.map(\.toAblyCocoaData)
        case let .string(underlying):
            underlying
        case let .number(underlying):
            underlying
        case let .bool(underlying):
            underlying
        case .null:
            NSNull()
        }
    }
}

internal extension [String: JSONValue] {
    /// Creates an ably-cocoa deserialized JSON object from a dictionary that has string keys and `JSONValue` values.
    ///
    /// Specifically, the value of this property can be used as:
    ///
    /// - `ARTPresenceMessage`’s `data` property
    /// - the `data` argument that’s passed to `ARTRealtime`’s `request(…)` method
    var toAblyCocoaDataDictionary: [String: Any] {
        mapValues(\.toAblyCocoaData)
    }
}
