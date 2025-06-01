import Foundation

internal extension MessageReactionSummary {
    enum JSONKey: String {
        case messageSerial
        case unique
        case distinct
        case multiple
    }

    init(messageSerial: String, values jsonObject: [String: JSONValue]) throws(InternalError) {
        self.messageSerial = messageSerial

        let uniqueJson = try? jsonObject.optionalObjectValueForKey(MessageReactionType.unique.rawValue) ??
            jsonObject.optionalObjectValueForKey("unique")
        if let uniqueJson {
            do {
                unique = try uniqueJson.mapValues { value in
                    guard let uniqueJsonItem = value.objectValue else {
                        throw JSONValueDecodingError.noValueForKey("unique.<key>").toInternalError()
                    }
                    return try MessageReactionSummary.ClientIdList(jsonObject: uniqueJsonItem)
                }
            } catch {
                throw JSONValueDecodingError.failedToDecodeFromRawValue("unique: \(uniqueJson)").toInternalError()
            }
        } else {
            unique = [:]
        }

        let distinctJson = try? jsonObject.optionalObjectValueForKey(MessageReactionType.distinct.rawValue) ??
            jsonObject.optionalObjectValueForKey("distinct")
        if let distinctJson {
            do {
                distinct = try distinctJson.mapValues { value in
                    guard let distinctJsonItem = value.objectValue else {
                        throw JSONValueDecodingError.noValueForKey("unique.<key>").toInternalError()
                    }
                    return try MessageReactionSummary.ClientIdList(jsonObject: distinctJsonItem)
                }
            } catch {
                throw JSONValueDecodingError.failedToDecodeFromRawValue("unique: \(distinctJson)").toInternalError()
            }
        } else {
            distinct = [:]
        }

        let multipleJson = try? jsonObject.optionalObjectValueForKey(MessageReactionType.multiple.rawValue) ??
            jsonObject.optionalObjectValueForKey("multiple")
        if let multipleJson {
            do {
                multiple = try multipleJson.mapValues { value in
                    guard let multipleJsonItem = value.objectValue else {
                        throw JSONValueDecodingError.noValueForKey("unique.<key>").toInternalError()
                    }
                    return try MessageReactionSummary.ClientIdCounts(jsonObject: multipleJsonItem)
                }
            } catch {
                throw JSONValueDecodingError.failedToDecodeFromRawValue("unique: \(multipleJson)").toInternalError()
            }
        } else {
            multiple = [:]
        }
    }
}

extension MessageReactionSummary.ClientIdList: JSONObjectCodable {
    internal enum JSONKey: String {
        case total
        case clientIds
    }

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        total = try UInt(jsonObject.numberValueForKey(JSONKey.total.rawValue))
        clientIds = try jsonObject.arrayValueForKey(JSONKey.clientIds.rawValue).compactMap(\.stringValue)
    }

    internal var toJSONObject: [String: JSONValue] {
        fatalError("Should not be constructed on the client side.")
    }
}

extension MessageReactionSummary.ClientIdCounts: JSONObjectCodable {
    internal enum JSONKey: String {
        case total
        case clientIds
    }

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        total = try UInt(jsonObject.numberValueForKey(JSONKey.total.rawValue))
        clientIds = try jsonObject.objectValueForKey(JSONKey.clientIds.rawValue).mapValues { UInt($0.numberValue ?? 0) }
    }

    internal var toJSONObject: [String: JSONValue] {
        fatalError("Should not be constructed on the client side.")
    }
}
