// CHA-ER3d
internal struct RoomReactionDTO {
    internal var data: Data
    internal var extras: Extras

    internal struct Data: Equatable {
        internal var name: String
        internal var metadata: RoomReactionMetadata?
    }

    internal struct Extras: Equatable {
        internal var headers: RoomReactionHeaders?
    }
}

internal extension RoomReactionDTO {
    init(name: String, metadata: RoomReactionMetadata?, headers: RoomReactionHeaders?) {
        data = .init(name: name, metadata: metadata)
        extras = .init(headers: headers)
    }

    var name: String {
        data.name
    }

    var metadata: RoomReactionMetadata? {
        data.metadata
    }

    var headers: RoomReactionHeaders? {
        extras.headers
    }
}

// MARK: - JSONCodable

extension RoomReactionDTO.Data: JSONObjectCodable {
    internal enum JSONKey: String {
        case name
        case metadata
    }

    internal init(jsonObject: [String: JSONValue]) throws(ErrorInfo) {
        name = try jsonObject.stringValueForKey(JSONKey.name.rawValue)
        metadata = try jsonObject.optionalObjectValueForKey(JSONKey.metadata.rawValue)
    }

    internal var toJSONObject: [String: JSONValue] {
        [
            JSONKey.name.rawValue: .string(name),
            JSONKey.metadata.rawValue: .object(metadata ?? [:]),
        ]
    }
}

extension RoomReactionDTO.Extras: JSONObjectCodable {
    internal enum JSONKey: String {
        case headers
        case ephemeral
    }

    internal init(jsonObject: [String: JSONValue]) throws(ErrorInfo) {
        headers = try jsonObject.optionalObjectValueForKey(JSONKey.headers.rawValue)?.ablyChat_mapValuesWithTypedThrow { jsonValue throws(ErrorInfo) in
            try .init(jsonValue: jsonValue)
        }
    }

    internal var toJSONObject: [String: JSONValue] {
        [
            JSONKey.headers.rawValue: .object(headers?.mapValues(\.toJSONValue) ?? [:]),
            // CHA-ER3d
            JSONKey.ephemeral.rawValue: true,
        ]
    }
}
