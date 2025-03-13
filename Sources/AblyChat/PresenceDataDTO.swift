// (CHA-PR2a) The presence data format is a JSON object as described below. Customers may specify content of an arbitrary type to be placed in the userCustomData field.
internal struct PresenceDataDTO: Equatable {
    internal var userCustomData: PresenceData?
}

// MARK: - JSONObjectCodable

extension PresenceDataDTO: JSONObjectCodable {
    internal enum JSONKey: String {
        case userCustomData
    }

    internal init(jsonObject: [String: JSONValue]) {
        userCustomData = jsonObject[JSONKey.userCustomData.rawValue]
    }

    internal var toJSONObject: [String: JSONValue] {
        var result: [String: JSONValue] = [:]

        if let userCustomData {
            result[JSONKey.userCustomData.rawValue] = userCustomData
        }

        return result
    }
}
