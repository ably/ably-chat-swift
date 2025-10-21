import Ably
import Foundation

internal protocol JSONEncodable {
    var toJSONValue: JSONValue { get }
}

internal protocol JSONDecodable {
    init(jsonValue: JSONValue) throws(ErrorInfo)
}

internal typealias JSONCodable = JSONDecodable & JSONEncodable

internal protocol JSONObjectEncodable: JSONEncodable {
    var toJSONObject: [String: JSONValue] { get }
}

// Default implementation of `JSONEncodable` conformance for `JSONObjectEncodable`
internal extension JSONObjectEncodable {
    var toJSONValue: JSONValue {
        .object(toJSONObject)
    }
}

internal protocol JSONObjectDecodable: JSONDecodable {
    init(jsonObject: [String: JSONValue]) throws(ErrorInfo)
}

internal enum JSONValueDecodingError: Error {
    case valueIsNotObject
    case noValueForKey(String)
    case wrongTypeForKey(String, actualValue: JSONValue)
    case failedToDecodeFromRawValue(type: Any.Type, rawValue: String)
}

// Default implementation of `JSONDecodable` conformance for `JSONObjectDecodable`
internal extension JSONObjectDecodable {
    init(jsonValue: JSONValue) throws(ErrorInfo) {
        guard case let .object(jsonObject) = jsonValue else {
            throw JSONValueDecodingError.valueIsNotObject.toErrorInfo()
        }

        self = try .init(jsonObject: jsonObject)
    }
}

internal typealias JSONObjectCodable = JSONObjectDecodable & JSONObjectEncodable

// MARK: - Extracting primitive values from a dictionary

/// This extension adds some helper methods for extracting values from a dictionary of `JSONValue` values; you may find them helpful when implementing `JSONCodable`.
internal extension [String: JSONValue] {
    /// If this dictionary contains a value for `key`, and this value has case `object`, this returns the associated value.
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.noValueForKey` if the key is absent
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `object`
    func objectValueForKey(_ key: String) throws(ErrorInfo) -> [String: JSONValue] {
        guard let value = self[key] else {
            throw JSONValueDecodingError.noValueForKey(key).toErrorInfo()
        }

        guard case let .object(objectValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return objectValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `object`, this returns the associated value. If this dictionary does not contain a value for `key`, or if the value for `key` has case `null`, it returns `nil`.
    ///
    /// - Throws: `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `object` or `null`
    func optionalObjectValueForKey(_ key: String) throws(ErrorInfo) -> [String: JSONValue]? {
        guard let value = self[key] else {
            return nil
        }

        if case .null = value {
            return nil
        }

        guard case let .object(objectValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return objectValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `array`, this returns the associated value.
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.noValueForKey` if the key is absent
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `array`
    func arrayValueForKey(_ key: String) throws(ErrorInfo) -> [JSONValue] {
        guard let value = self[key] else {
            throw JSONValueDecodingError.noValueForKey(key).toErrorInfo()
        }

        guard case let .array(arrayValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return arrayValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `array`, this returns the associated value. If this dictionary does not contain a value for `key`, or if the value for `key` has case `null`, it returns `nil`.
    ///
    /// - Throws: `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `array` or `null`
    func optionalArrayValueForKey(_ key: String) throws(ErrorInfo) -> [JSONValue]? {
        guard let value = self[key] else {
            return nil
        }

        if case .null = value {
            return nil
        }

        guard case let .array(arrayValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return arrayValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `string`, this returns the associated value.
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.noValueForKey` if the key is absent
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `string`
    func stringValueForKey(_ key: String) throws(ErrorInfo) -> String {
        guard let value = self[key] else {
            throw JSONValueDecodingError.noValueForKey(key).toErrorInfo()
        }

        guard case let .string(stringValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return stringValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `string`, this returns the associated value. If this dictionary does not contain a value for `key`, or if the value for `key` has case `null`, it returns `nil`.
    ///
    /// - Throws: `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `string` or `null`
    func optionalStringValueForKey(_ key: String) throws(ErrorInfo) -> String? {
        guard let value = self[key] else {
            return nil
        }

        if case .null = value {
            return nil
        }

        guard case let .string(stringValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return stringValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `number`, this returns the associated value.
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.noValueForKey` if the key is absent
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `number`
    func numberValueForKey(_ key: String) throws(ErrorInfo) -> Double {
        guard let value = self[key] else {
            throw JSONValueDecodingError.noValueForKey(key).toErrorInfo()
        }

        guard case let .number(numberValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return numberValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `number`, this returns the associated value. If this dictionary does not contain a value for `key`, or if the value for `key` has case `null`, it returns `nil`.
    ///
    /// - Throws: `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `number` or `null`
    func optionalNumberValueForKey(_ key: String) throws(ErrorInfo) -> Double? {
        guard let value = self[key] else {
            return nil
        }

        if case .null = value {
            return nil
        }

        guard case let .number(numberValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return numberValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `bool`, this returns the associated value.
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.noValueForKey` if the key is absent
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `bool`
    func boolValueForKey(_ key: String) throws(ErrorInfo) -> Bool {
        guard let value = self[key] else {
            throw JSONValueDecodingError.noValueForKey(key).toErrorInfo()
        }

        guard case let .bool(boolValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return boolValue
    }

    /// If this dictionary contains a value for `key`, and this value has case `bool`, this returns the associated value.
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.noValueForKey` if the key is absent
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `bool`
    func optionalBoolValueForKey(_ key: String) throws(ErrorInfo) -> Bool? {
        guard let value = self[key] else {
            return nil
        }

        if case .null = value {
            return nil
        }

        guard case let .bool(boolValue) = value else {
            throw JSONValueDecodingError.wrongTypeForKey(key, actualValue: value).toErrorInfo()
        }

        return boolValue
    }
}

// MARK: - Extracting dates from a dictionary

internal extension [String: JSONValue] {
    /// If this dictionary contains a value for `key`, and this value has case `number`, this returns a date created by interpreting this value as the number of milliseconds since the Unix epoch (which is the format used by Ably).
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.noValueForKey` if the key is absent
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `number`
    func ablyProtocolDateValueForKey(_ key: String) throws(ErrorInfo) -> Date {
        let millisecondsSinceEpoch = try numberValueForKey(key)

        return dateFromMillisecondsSinceEpoch(millisecondsSinceEpoch)
    }

    /// If this dictionary contains a value for `key`, and this value has case `number`, this returns a date created by interpreting this value as the number of milliseconds since the Unix epoch (which is the format used by Ably). If this dictionary does not contain a value for `key`, or if the value for `key` has case `null`, it returns `nil`.
    ///
    /// - Throws: `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `number` or `null`
    func optionalAblyProtocolDateValueForKey(_ key: String) throws(ErrorInfo) -> Date? {
        guard let millisecondsSinceEpoch = try optionalNumberValueForKey(key) else {
            return nil
        }

        return dateFromMillisecondsSinceEpoch(millisecondsSinceEpoch)
    }

    private func dateFromMillisecondsSinceEpoch(_ millisecondsSinceEpoch: Double) -> Date {
        .init(timeIntervalSince1970: millisecondsSinceEpoch / 1000)
    }
}

// MARK: - Extracting RawRepresentable values from a dictionary

internal extension [String: JSONValue] {
    /// If this dictionary contains a value for `key`, and this value has case `string`, this creates an instance of `T` using its `init(rawValue:)` initializer.
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.noValueForKey` if the key is absent
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `string`
    ///   - `JSONValueDecodingError.failedToDecodeFromRawValue` if `init(rawValue:)` returns `nil`
    func rawRepresentableValueForKey<T: RawRepresentable>(_ key: String, type _: T.Type = T.self) throws(ErrorInfo) -> T where T.RawValue == String {
        let rawValue = try stringValueForKey(key)

        return try rawRepresentableValueFromRawValue(rawValue, type: T.self)
    }

    /// If this dictionary contains a value for `key`, and this value has case `string`, this creates an instance of `T` using its `init(rawValue:)` initializer. If this dictionary does not contain a value for `key`, or if the value for `key` has case `null`, it returns `nil`.
    ///
    /// - Throws:
    ///   - `JSONValueDecodingError.wrongTypeForKey` if the value does not have case `string` or `null`
    ///   - `JSONValueDecodingError.failedToDecodeFromRawValue` if `init(rawValue:)` returns `nil`
    func optionalRawRepresentableValueForKey<T: RawRepresentable>(_ key: String, type _: T.Type = T.self) throws(ErrorInfo) -> T? where T.RawValue == String {
        guard let rawValue = try optionalStringValueForKey(key) else {
            return nil
        }

        return try rawRepresentableValueFromRawValue(rawValue, type: T.self)
    }

    private func rawRepresentableValueFromRawValue<T: RawRepresentable>(_ rawValue: String, type _: T.Type = T.self) throws(ErrorInfo) -> T where T.RawValue == String {
        guard let value = T(rawValue: rawValue) else {
            throw JSONValueDecodingError.failedToDecodeFromRawValue(type: T.self, rawValue: rawValue).toErrorInfo()
        }

        return value
    }
}
