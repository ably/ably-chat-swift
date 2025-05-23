// CHA-ER3d
internal struct RoomReactionDTO {
    internal var data: Data
    internal var extras: Extras

    internal struct Data: Equatable {
        internal var type: String
        internal var metadata: ReactionMetadata?
    }

    internal struct Extras: Equatable {
        internal var headers: ReactionHeaders?
    }
}

internal extension RoomReactionDTO {
    init(type: String, metadata: ReactionMetadata?, headers: ReactionHeaders?) {
        data = .init(type: type, metadata: metadata)
        extras = .init(headers: headers)
    }

    var type: String {
        data.type
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
        case type
        case metadata
    }

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        type = try jsonObject.stringValueForKey(JSONKey.type.rawValue)
        metadata = try jsonObject.optionalObjectValueForKey(JSONKey.metadata.rawValue)
    }

    internal var toJSONObject: [String: JSONValue] {
        [
            JSONKey.type.rawValue: .string(type),
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
