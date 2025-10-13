import Foundation

internal extension MessageReactionSummary {
    enum JSONKey: String {
        case unique
        case distinct
        case multiple
    }

    init(values jsonObject: [String: JSONValue]) {
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
                    return try MessageReactionSummary.ClientIDList(jsonObject: uniqueJsonItem)
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
                    return try MessageReactionSummary.ClientIDList(jsonObject: distinctJsonItem)
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
                    return try MessageReactionSummary.ClientIDCounts(jsonObject: multipleJsonItem)
                }
            } catch {
                multiple = [:] // CHA-MR6a
            }
        } else {
            multiple = [:] // CHA-MR6a3
        }
    }
}

extension MessageReactionSummary.ClientIDList: JSONObjectDecodable {
    internal enum JSONKey: String {
        case total
        case clientIds
        case clipped
    }

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        total = try Int(jsonObject.numberValueForKey(JSONKey.total.rawValue))
        clientIDs = try jsonObject.arrayValueForKey(JSONKey.clientIds.rawValue).compactMap(\.stringValue)
        clipped = try jsonObject.optionalBoolValueForKey(JSONKey.clipped.rawValue) ?? false
    }
}

extension MessageReactionSummary.ClientIDCounts: JSONObjectDecodable {
    internal enum JSONKey: String {
        case total
        case clientIds
        case totalUnidentified
        case clipped
        case totalClientIds
    }

    internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
        total = try Int(jsonObject.numberValueForKey(JSONKey.total.rawValue))
        clientIDs = try jsonObject.objectValueForKey(JSONKey.clientIds.rawValue).mapValues { Int($0.numberValue ?? 0) }
        totalUnidentified = try jsonObject.optionalNumberValueForKey(JSONKey.totalUnidentified.rawValue).map(Int.init) ?? 0
        clipped = try jsonObject.optionalBoolValueForKey(JSONKey.clipped.rawValue) ?? false
        totalClientIDs = try jsonObject.optionalNumberValueForKey(JSONKey.totalClientIds.rawValue).map(Int.init) ?? total
    }
}
