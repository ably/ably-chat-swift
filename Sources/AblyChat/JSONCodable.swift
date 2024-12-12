internal protocol JSONEncodable {
    var toJSONObjectValue: [String: JSONValue] { get }
}

internal protocol JSONDecodable {
    init(jsonValue: JSONValue) throws
}

internal typealias JSONCodable = JSONDecodable & JSONEncodable
