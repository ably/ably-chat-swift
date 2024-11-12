import Ably
import AblyChat

typealias JSON = [String: Any]

extension JSON {
    func stringValue(_ name: String) throws -> String {
        guard let value = self[name] as? String else {
            throw ChatAdapter.AdapterError.jsonValueNotFound(name)
        }
        return value
    }

    func jsonValue(_ name: String) throws -> JSON {
        guard let value = self[name] as? JSON else {
            throw ChatAdapter.AdapterError.jsonValueNotFound(name)
        }
        return value
    }

    func anyValue(_ name: String) throws -> Any {
        guard let value = self[name] else {
            throw ChatAdapter.AdapterError.jsonValueNotFound(name)
        }
        return value
    }
}

func jsonRpcResult(_ requestId: String, _ result: String) -> String {
    "{\"jsonrpc\":\"2.0\",\"id\":\"\(requestId)\",\"result\":\(result)}"
}

func jsonRpcCallback(_ callbackId: String, _ message: String) -> String {
    "{\"jsonrpc\":\"2.0\",\"id\":\"\(UUID().uuidString)\",\"method\":\"callback\",\"params\":{\"callbackId\":\"\(callbackId)\",\"args\":[\(message)]}}"
}

func jsonRpcError(_ requestId: String, error: Error) -> String {
    if let error = error as? ARTErrorInfo {
        "{\"jsonrpc\":\"2.0\",\"id\":\"\(requestId)\",\"error\":{\"message\": \"\(error.description)\", \"data\": {\"ablyError\": true, \"errorInfo\": \(error.jsonString())}}}"
    } else {
        "{\"jsonrpc\":\"2.0\",\"id\":\"\(requestId)\",\"error\":{\"message\": \"\(error)\", \"data\": {\"ablyError\": false}}}"
    }
}

enum RPCError: Error, CustomStringConvertible {
    case unknownWebsocketData
    case invalidWebsocketString
    case invalidJSON
    case invalidCallParams

    var description: String {
        switch self {
        case .invalidCallParams:
            "No valid RPC call fields in the provided JSON were found."
        case .invalidJSON:
            "Data provided is not a valid JSON dictionary."
        case .unknownWebsocketData:
            "Unknown websocket message (should be `String` or `Data`)."
        case .invalidWebsocketString:
            "Couldn't create data from string provided (utf8)."
        }
    }
}

extension URLSessionWebSocketTask.Message {
    func json() throws -> JSON {
        var json: JSON?

        switch self {
        case let .data(data):
            json = try JSONSerialization.jsonObject(with: data) as? JSON
        case let .string(string):
            guard let data = string.data(using: .utf8) else {
                throw RPCError.invalidWebsocketString
            }
            json = try JSONSerialization.jsonObject(with: data) as? JSON
        @unknown default:
            throw RPCError.unknownWebsocketData
        }

        guard let json else {
            throw RPCError.invalidJSON
        }
        if json["method"] == nil || json["jsonrpc"] == nil {
            throw RPCError.invalidCallParams
        }
        return json
    }
}

func generateId() -> String { NanoID.new() }

protocol JsonSerialisable {
    func jsonString() throws -> String
}

extension ClientOptions: JsonSerialisable {
    func jsonString() -> String {
        "{\"logLevel\": \"\(logLevel ?? .info)\"}"
    }
}

extension RoomOptions: JsonSerialisable {
    func jsonString() -> String {
        fatalError("Not implemented")
    }
}

extension ErrorInfo: JsonSerialisable {
    func jsonString() -> String {
        "{\"code\": \(code), \"statusCode\": \(statusCode), \"reason\": \"\(reason ?? description)\"}"
    }
}

extension OccupancyEvent: JsonSerialisable {
    func jsonString() -> String {
        fatalError("Not implemented")
    }
}

extension Message: JsonSerialisable {
    func jsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            fatalError("Failed to create string from data.")
        }
        return string
    }
}

extension ConnectionStatusChange: JsonSerialisable {
    func jsonString() -> String {
        fatalError("Not implemented")
    }
}

extension RoomStatusChange: JsonSerialisable {
    func jsonString() -> String {
        fatalError("Not implemented")
    }
}

extension TypingEvent: JsonSerialisable {
    func jsonString() -> String {
        fatalError("Not implemented")
    }
}

extension Reaction: JsonSerialisable {
    func jsonString() -> String {
        fatalError("Not implemented")
    }
}

extension PresenceEvent: JsonSerialisable {
    func jsonString() -> String {
        fatalError("Not implemented")
    }
}

extension String: JsonSerialisable {
    func jsonString() -> String {
        self
    }
}

func jsonString(_ value: Any) throws -> String {
    // swiftlint:disable force_cast
    if value is JsonSerialisable {
        return try (value as! JsonSerialisable).jsonString()
    } else if value is [JsonSerialisable] {
        return try "[" + (value as! [JsonSerialisable]).map { try $0.jsonString() }.joined(separator: ",\n") + "]"
    }
    // swiftlint:enable force_cast
    fatalError("Not implemented")
}

extension Message {
    static func from(_: Any?) -> Self {
        fatalError("Not implemented")
    }
}

extension QueryOptions {
    static func from(_ value: Any?) -> Self {
        guard let json = value as? JSON else {
            fatalError("Not compatible data for creating QueryOptions. Expected JSON.")
        }
        return QueryOptions(
            limit: json["limit"] as? Int,
            orderBy: (json["direction"] as? String ?? "forwards") == "forwards" ? .newestFirst : .oldestFirst
        )
    }
}

extension SendMessageParams {
    static func from(_ value: Any?) throws -> Self {
        guard let json = value as? JSON, let text = json["text"] as? String else {
            fatalError("Not compatible data for creating SendMessageParams. Expected JSON with string `text` value.")
        }
        return SendMessageParams(text: text)
    }
}

extension String {
    static func from(_ value: Any?) -> Self {
        guard let string = value as? String else {
            fatalError("Value is not a string.")
        }
        return string
    }
}

extension RealtimePresenceParams {
    static func from(_: Any?) -> Self {
        fatalError("Not implemented")
    }
}

extension SendReactionParams {
    static func from(_: Any?) -> Self {
        fatalError("Not implemented")
    }
}

extension RoomOptions {
    static func from(_ value: Any?) -> Self {
        guard let json = value as? JSON else {
            fatalError("Not compatible data for creating RoomOptions. Expected JSON.")
        }
        var presence = PresenceOptions()
        if let presenceJson = json["presence"] as? JSON {
            presence.enter = presenceJson["enter"] as? Bool ?? false
            presence.subscribe = presenceJson["subscribe"] as? Bool ?? false
        }
        var typing = TypingOptions()
        if let typingJson = json["typing"] as? JSON, let timeoutMs = typingJson["timeoutMs"] as? Double {
            typing.timeout = timeoutMs / 1000
        }
        let reactions = RoomReactionsOptions()
        let occupancy = OccupancyOptions()
        return RoomOptions(presence: presence, typing: typing, reactions: reactions, occupancy: occupancy)
    }
}

// This should be replaced with `LogLevel` conforming to `String`.
extension LogLevel {
    static func from(string: String) -> Self {
        switch string {
        case "trace":
            .trace
        case "debug":
            .debug
        case "info":
            .info
        case "warn":
            .warn
        case "error":
            .error
        case "silent":
            .silent
        default:
            .debug
        }
    }
}

extension ClientOptions {
    static func from(_ value: Any?) -> Self {
        guard let json = value as? JSON, let logLevel = json["logLevel"] as? String else {
            fatalError("Not compatible data for creating ClientOptions. Expected JSON with `logLevel` string.")
        }
        var options = ClientOptions()
        options.logLevel = .from(string: logLevel)
        return options
    }
}

extension ARTClientOptions {
    static func from(_ value: Any?) -> ARTClientOptions {
        guard let json = value as? JSON else {
            fatalError("Not compatible data for creating ClientOptions. Expected JSON.")
        }
        let options = ARTClientOptions()
        options.clientId = json["clientId"] as? String
        options.environment = json["environment"] as? String ?? "production"
        options.key = json["key"] as? String
        options.logLevel = .init(rawValue: json["logLevel"] as? UInt ?? ARTLogLevel.debug.rawValue) ?? .debug
        options.token = json["token"] as? String
        options.useBinaryProtocol = json["useBinaryProtocol"] as? Bool ?? false
        options.useTokenAuth = json["useTokenAuth"] as? Bool ?? false
        return options
    }
}

extension PresenceDataWrapper {
    static func from(_ value: Any?) -> PresenceData {
        // swiftlint:disable force_cast
        if value is [String: Int64] {
            return value as! [String: Int64]
        }
        if value is [String: String] {
            return value as! [String: String]
        }
        if value is String {
            return value as! String
        }
        // swiftlint:enable force_cast
        fatalError("Not implemented")
    }
}

extension PresenceEventType {
    static func from(_: Any?) -> Self {
        fatalError("Not implemented")
    }
}
