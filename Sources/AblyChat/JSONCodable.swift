internal protocol JSONEncodable {
    var toJSONValue: JSONValue { get }
}

internal protocol JSONDecodable {
    init(jsonValue: JSONValue) throws
}

internal typealias JSONCodable = JSONDecodable & JSONEncodable

internal protocol JSONObjectEncodable: JSONEncodable {
    var toJSONObject: [String: JSONValue] { get }
}

// Default implementation of `JSONEncodable` conformance for `JSONObjectEncodable`
internal extension JSONObjectEncodable {
    var toJSONValue: JSONValue {
        .object(toJSONObject)
    }
}

internal protocol JSONObjectDecodable: JSONDecodable {
    init(jsonObject: [String: JSONValue]) throws
}

internal enum JSONValueDecodingError: Error {
    case valueIsNotObject
}

// Default implementation of `JSONDecodable` conformance for `JSONObjectDecodable`
internal extension JSONObjectDecodable {
    init(jsonValue: JSONValue) throws {
        guard case let .object(jsonObject) = jsonValue else {
            throw JSONValueDecodingError.valueIsNotObject
        }

        self = try .init(jsonObject: jsonObject)
    }
}

internal typealias JSONObjectCodable = JSONObjectDecodable & JSONObjectEncodable
