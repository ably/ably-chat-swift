internal protocol JSONEncodable {
    var toJSONValue: JSONValue { get }
}

internal protocol JSONDecodable {
    init(jsonValue: JSONValue) throws
}

internal typealias JSONCodable = JSONDecodable & JSONEncodable
