import Foundation

// TODO: document; taken from https://www.douggregor.net/posts/swift-for-cxx-practitioners-literals/
public enum JSONValue: Sendable {
    case null
    // TODO: this doesn't really match the JSON spec; align with names there. needs bools, object, string (why is string called object?)
    case object(String)
    case number(Double)
    case array([JSONValue])
    case dictionary([String: JSONValue])

    /// Returns a value that can be serialized by `JSONSerialization`.
    ///
    /// TODO is that right? see JSONSerialization documentation; I don't think that `FragmentsAllowed` is true
    internal var asJSONSerializable: Any {
        switch self {
        case .null:
            NSNull()
        case let .object(object):
            object
        case let .number(number):
            number
        case let .array(array):
            array.map(\.asJSONSerializable)
        case let .dictionary(dictionary):
            // TODO: what happens if nil is here? I guess you get `NSNull`
            dictionary.mapValues(\.asJSONSerializable)
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) {
        self = .null
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .object(value)
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

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}
