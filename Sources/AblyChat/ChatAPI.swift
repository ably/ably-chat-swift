import Ably

@MainActor
internal final class ChatAPI {
    internal enum RequestBody {
        case jsonObject([String: JSONValue])
        /// Contains an object that can be used the same way as a value returned from `JSONValue.object(…).toAblyCocoaData`. Workaround for JSONValue not being able to indicate to ably-cocoa that a property should be serialized as a MessagePack integer type; TODO revisit in (create an issue for this)
        case ablyCocoaData(Any)
    }

    private let realtime: any InternalRealtimeClientProtocol
    private let apiVersionV4 = "/chat/v4"

    public init(realtime: any InternalRealtimeClientProtocol) {
        self.realtime = realtime
    }

    // (CHA-M6) Messages should be queryable from a paginated REST API.
    internal func getMessages(roomName: String, params: QueryOptions) async throws(InternalError) -> any PaginatedResult<Message> {
        let endpoint = "\(apiVersionV4)/rooms/\(roomName)/messages"
        return try await makePaginatedRequest(endpoint, params: params.asQueryItems())
    }

    internal struct SendMessageResponse: JSONObjectDecodable {
        internal let serial: String
        internal let timestamp: Int64

        internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
            serial = try jsonObject.stringValueForKey("serial")
            timestamp = try Int64(jsonObject.numberValueForKey("timestamp"))
        }
    }

    internal struct MessageOperationResponse: JSONObjectDecodable {
        internal let version: MessageVersion
        internal let timestamp: Int64

        internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
            timestamp = try Int64(jsonObject.numberValueForKey("timestamp"))
            let timestampInSeconds = Date(timeIntervalSince1970: TimeInterval(Double(timestamp) / 1000))
            version = try MessageVersion(jsonObject: jsonObject.objectValueForKey("version"), defaultTimestamp: timestampInSeconds)
        }
    }

    internal struct SendMessageReactionParams: Sendable {
        internal let type: MessageReactionType
        internal let name: String
        internal let count: Int?
    }

    internal struct DeleteMessageReactionParams: Sendable {
        internal let type: MessageReactionType
        internal let name: String?
    }

    internal struct MessageReactionResponse: JSONObjectDecodable {
        internal let serial: String

        internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
            serial = try jsonObject.stringValueForKey("serial")
        }
    }

    internal typealias UpdateMessageResponse = MessageOperationResponse
    internal typealias DeleteMessageResponse = MessageOperationResponse

    // (CHA-M3) Messages are sent to Ably via the Chat REST API, using the send method.
    // (CHA-M3a) When a message is sent successfully, the caller shall receive a struct representing the Message in response (as if it were received via Realtime event).
    internal func sendMessage(roomName: String, params: SendMessageParams) async throws(InternalError) -> Message {
        guard let clientID = realtime.clientId else {
            throw ARTErrorInfo(chatError: .clientIdRequired).toInternalError()
        }

        let endpoint = "\(apiVersionV4)/rooms/\(roomName)/messages"
        var body: [String: JSONValue] = ["text": .string(params.text)]

        // (CHA-M3b) A message may be sent without metadata or headers. When these are not specified by the user, they must be omitted from the REST payload.
        if let metadata = params.metadata {
            body["metadata"] = .object(metadata)
        }

        if let headers = params.headers {
            body["headers"] = .object(headers.mapValues(\.toJSONValue))
        }

        let response: SendMessageResponse = try await makeRequest(endpoint, method: "POST", body: .jsonObject(body))

        // response.timestamp is in milliseconds, convert it to seconds
        let timestampInSeconds = Date(timeIntervalSince1970: TimeInterval(Double(response.timestamp) / 1000))
        let message = Message(
            serial: response.serial,
            action: .create,
            clientID: clientID,
            text: params.text,
            metadata: params.metadata ?? [:],
            headers: params.headers ?? [:],
            version: .init(
                serial: response.serial,
                timestamp: timestampInSeconds,
                clientID: clientID,
            ),
            timestamp: timestampInSeconds,
        )
        return message
    }

    // (CHA-M8) A client must be able to update a message in a room.
    // (CHA-M8a) A client may update a message via the Chat REST API by calling the update method.
    internal func updateMessage(roomName: String, with modifiedMessage: Message, description: String?, metadata: OperationMetadata?) async throws(InternalError) -> Message {
        let endpoint = "\(apiVersionV4)/rooms/\(roomName)/messages/\(modifiedMessage.serial)"
        var body: [String: JSONValue] = [:]
        let messageObject: [String: JSONValue] = [
            "text": .string(modifiedMessage.text),
            "metadata": .object(modifiedMessage.metadata),
            "headers": .object(modifiedMessage.headers.mapValues(\.toJSONValue)),
        ]

        body["message"] = .object(messageObject)

        if let description {
            body["description"] = .string(description)
        }

        if let metadata {
            body["metadata"] = .object(metadata)
        }

        // (CHA-M8c) An update operation has PUT semantics. If a field is not specified in the update, it is assumed to be removed.
        // CHA-M8c is not actually respected here, see https://github.com/ably/ably-chat-swift/issues/333
        let response: UpdateMessageResponse = try await makeRequest(endpoint, method: "PUT", body: .jsonObject(body))

        // (CHA-M8b) When a message is updated successfully via the REST API, the caller shall receive a struct representing the Message in response, as if it were received via Realtime event.
        let message = Message(
            serial: modifiedMessage.serial,
            action: .update,
            clientID: modifiedMessage.clientID,
            text: modifiedMessage.text,
            metadata: modifiedMessage.metadata,
            headers: modifiedMessage.headers,
            version: response.version,
            timestamp: modifiedMessage.timestamp,
        )
        return message
    }

    // (CHA-M9) A client must be able to delete a message in a room.
    // (CHA-M9a) A client may delete a message via the Chat REST API by calling the delete method.
    internal func deleteMessage(roomName: String, message: Message, params: DeleteMessageParams) async throws(InternalError) -> Message {
        let endpoint = "\(apiVersionV4)/rooms/\(roomName)/messages/\(message.serial)/delete"
        var body: [String: JSONValue] = [:]

        if let description = params.description {
            body["description"] = .string(description)
        }

        if let metadata = params.metadata {
            body["metadata"] = .object(metadata)
        }

        let response: DeleteMessageResponse = try await makeRequest(endpoint, method: "POST", body: .jsonObject(body))

        // response.timestamp is in milliseconds, convert it to seconds
        let timestampInSeconds = TimeInterval(Double(response.timestamp) / 1000)

        // (CHA-M9b) When a message is deleted successfully via the REST API, the caller shall receive a struct representing the Message in response, as if it were received via Realtime event.
        let message = Message(
            serial: message.serial,
            action: .delete,
            clientID: message.clientID,
            text: "", // CHA-M9b (When a message is deleted successfully via the REST API, the caller shall receive a struct representing the Message in response, as if it were received via Realtime event.) Currently realtime sends an empty text for deleted message, so set it to empty text here as well.
            metadata: [:], // CHA-M9b
            headers: [:], // CHA-M9b
            version: response.version,
            timestamp: Date(timeIntervalSince1970: timestampInSeconds),
        )
        return message
    }

    internal func getOccupancy(roomName: String) async throws(InternalError) -> OccupancyData {
        let endpoint = "\(apiVersionV4)/rooms/\(roomName)/occupancy"
        return try await makeRequest(endpoint, method: "GET")
    }

    // (CHA-MR4) Users should be able to send a reaction to a message via the `send` method of the `MessagesReactions` object
    internal func sendReactionToMessage(_ messageSerial: String, roomName: String, params: SendMessageReactionParams) async throws(InternalError) -> MessageReactionResponse {
        // (CHA-MR4a1) If the serial passed to this method is invalid: undefined, null, empty string, an error with code 40000 must be thrown.
        guard !messageSerial.isEmpty else {
            throw ChatError.messageReactionInvalidMessageSerial.toInternalError()
        }

        let endpoint = "\(apiVersionV4)/rooms/\(roomName)/messages/\(messageSerial)/reactions"

        let ablyCocoaBody: [String: Any] = [
            "type": params.type.rawValue,
            "name": params.name,
            "count": params.count ?? 1,
        ]

        return try await makeRequest(endpoint, method: "POST", body: .ablyCocoaData(ablyCocoaBody))
    }

    // (CHA-MR11) Users should be able to delete a reaction from a message via the `delete` method of the `MessagesReactions` object
    internal func deleteReactionFromMessage(_ messageSerial: String, roomName: String, params: DeleteMessageReactionParams) async throws(InternalError) -> MessageReactionResponse {
        // (CHA-MR11a1) If the serial passed to this method is invalid: undefined, null, empty string, an error with code 40000 must be thrown.
        guard !messageSerial.isEmpty else {
            throw ChatError.messageReactionInvalidMessageSerial.toInternalError()
        }

        let endpoint = "\(apiVersionV4)/rooms/\(roomName)/messages/\(messageSerial)/reactions"

        var httpParams: [String: String] = [
            "type": params.type.rawValue,
        ]
        httpParams["name"] = params.name

        return try await makeRequest(endpoint, method: "DELETE", params: httpParams)
    }

    private func makeRequest<Response: JSONDecodable>(_ url: String, method: String, params: [String: String]? = nil, body: RequestBody? = nil) async throws(InternalError) -> Response {
        let ablyCocoaBody: Any? = if let body {
            switch body {
            case let .jsonObject(jsonObject):
                jsonObject.toAblyCocoaDataDictionary
            case let .ablyCocoaData(ablyCocoaData):
                ablyCocoaData
            }
        } else {
            nil
        }

        // (CHA-M3e & CHA-M8d & CHA-M9c) If an error is returned from the REST API, its ErrorInfo representation shall be thrown as the result of the send call.
        let paginatedResponse = try await realtime.request(method, path: url, params: params, body: ablyCocoaBody, headers: [:])

        guard let firstItem = paginatedResponse.items.first else {
            throw ChatError.noItemInResponse.toInternalError()
        }

        let jsonValue = JSONValue(ablyCocoaData: firstItem)
        return try Response(jsonValue: jsonValue)
    }

    private func makePaginatedRequest<Response: JSONDecodable & Sendable & Equatable>(
        _ url: String,
        params: [String: String]? = nil,
    ) async throws(InternalError) -> any PaginatedResult<Response> {
        let paginatedResponse = try await realtime.request("GET", path: url, params: params, body: nil, headers: [:])
        let jsonValues = paginatedResponse.items.map { JSONValue(ablyCocoaData: $0) }
        let items = try jsonValues.map { jsonValue throws(InternalError) in
            try Response(jsonValue: jsonValue)
        }
        return paginatedResponse.toPaginatedResult(items: items)
    }

    internal enum ChatError: Error {
        case noItemInResponse
        case messageReactionInvalidMessageSerial
        case messageReactionTypeRequired
        case messageReactionNameRequired
    }
}
