import Foundation

internal extension MessageReactionSummary {
    enum JSONKey: String {
        case messageSerial
        case unique
        case distinct
        case multiple
    }

    init(messageSerial: String, values jsonObject: [String: JSONValue]) {
        self.messageSerial = messageSerial

        // Two different key are used for now until fixed. Internal discussion:
        // https://ably-real-time.slack.com/archives/C02NY1VT3LY/p1749924228762039?thread_ts=1749655305.091679&cid=C02NY1VT3LY
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
                unique = [:] // CHA-MR6a
            }
        } else {
            unique = [:] // CHA-MR6a3
        }

        let distinctJson = try? jsonObject.optionalObjectValueForKey(MessageReactionType.distinct.rawValue) ??
            jsonObject.optionalObjectValueForKey("distinct")
        if let distinctJson {
            do {
                distinct = try distinctJson.mapValues { value in
                    guard let distinctJsonItem = value.objectValue else {
                        throw JSONValueDecodingError.noValueForKey("distinct.<key>").toInternalError()
                    }
                    return try MessageReactionSummary.ClientIdList(jsonObject: distinctJsonItem)
                }
            } catch {
                distinct = [:] // CHA-MR6a
            }
        } else {
            distinct = [:] // CHA-MR6a3
        }

        let multipleJson = try? jsonObject.optionalObjectValueForKey(MessageReactionType.multiple.rawValue) ??
            jsonObject.optionalObjectValueForKey("multiple")
        if let multipleJson {
            do {
                multiple = try multipleJson.mapValues { value in
                    guard let multipleJsonItem = value.objectValue else {
                        throw JSONValueDecodingError.noValueForKey("multiple.<key>").toInternalError()
                    }
                    return try MessageReactionSummary.ClientIdCounts(jsonObject: multipleJsonItem)
                }
            } catch {
                multiple = [:] // CHA-MR6a
            }
        } else {
            multiple = [:] // CHA-MR6a3
        }
    }
}

extension MessageReactionSummary.ClientIdList: JSONObjectDecodable {
    internal enum JSONKey: String {
        case total
        case clientIds
    }

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        total = try UInt(jsonObject.numberValueForKey(JSONKey.total.rawValue))
        clientIds = try jsonObject.arrayValueForKey(JSONKey.clientIds.rawValue).compactMap(\.stringValue)
    }
}

extension MessageReactionSummary.ClientIdCounts: JSONObjectDecodable {
    internal enum JSONKey: String {
        case total
        case clientIds
    }

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        total = try UInt(jsonObject.numberValueForKey(JSONKey.total.rawValue))
        clientIds = try jsonObject.objectValueForKey(JSONKey.clientIds.rawValue).mapValues { UInt($0.numberValue ?? 0) }
    }
}
