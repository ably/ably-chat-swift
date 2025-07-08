// CHA-ER3d
internal struct RoomReactionDTO {
    internal var data: Data
    internal var extras: Extras

    internal struct Data: Equatable {
        internal var name: String
        internal var metadata: ReactionMetadata?
    }

    internal struct Extras: Equatable {
        internal var headers: ReactionHeaders?
    }
}

internal extension RoomReactionDTO {
    init(name: String, metadata: ReactionMetadata?, headers: ReactionHeaders?) {
        data = .init(name: name, metadata: metadata)
        extras = .init(headers: headers)
    }

    var name: String {
        data.name
    }

    var metadata: ReactionMetadata? {
        data.metadata
    }

    var headers: ReactionHeaders? {
        extras.headers
    }
}

// MARK: - JSONCodable

extension RoomReactionDTO.Data: JSONObjectCodable {
    internal enum JSONKey: String {
        case name
        case metadata
    }

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
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

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        headers = try jsonObject.optionalObjectValueForKey(JSONKey.headers.rawValue)?.ablyChat_mapValuesWithTypedThrow { jsonValue throws(InternalError) in
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
