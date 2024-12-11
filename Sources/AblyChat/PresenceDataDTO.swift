// (CHA-PR2a) The presence data format is a JSON object as described below. Customers may specify content of an arbitrary type to be placed in the userCustomData field.
internal struct PresenceDataDTO: Equatable {
    internal var userCustomData: PresenceData?
}

// MARK: - Conversion to and from JSONValue

internal extension PresenceDataDTO {
    enum JSONKey: String {
        case userCustomData
    }

    enum DecodingError: Error {
        case valueHasWrongType(key: JSONKey)
    }

    init(jsonValue: JSONValue) throws {
        guard case let .object(jsonObject) = jsonValue else {
            throw DecodingError.valueHasWrongType(key: .userCustomData)
        }

        userCustomData = jsonObject[JSONKey.userCustomData.rawValue]
    }

    var toJSONObjectValue: [String: JSONValue] {
        var result: [String: JSONValue] = [:]

        if let userCustomData {
            result[JSONKey.userCustomData.rawValue] = userCustomData
        }

        return result
    }
}
