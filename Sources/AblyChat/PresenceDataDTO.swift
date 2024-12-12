// (CHA-PR2a) The presence data format is a JSON object as described below. Customers may specify content of an arbitrary type to be placed in the userCustomData field.
internal struct PresenceDataDTO: Equatable {
    internal var userCustomData: PresenceData?
}

// MARK: - JSONCodable

extension PresenceDataDTO: JSONCodable {
    internal enum JSONKey: String {
        case userCustomData
    }

    internal enum DecodingError: Error {
        case valueHasWrongType(key: JSONKey)
    }

    internal init(jsonValue: JSONValue) throws {
        guard case let .object(jsonObject) = jsonValue else {
            throw DecodingError.valueHasWrongType(key: .userCustomData)
        }

        userCustomData = jsonObject[JSONKey.userCustomData.rawValue]
    }

    internal var toJSONObjectValue: [String: JSONValue] {
        var result: [String: JSONValue] = [:]

        if let userCustomData {
            result[JSONKey.userCustomData.rawValue] = userCustomData
        }

        return result
    }
}
