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

    internal init(realtime: any InternalRealtimeClientProtocol) {
        self.realtime = realtime
    }

    private func escapePathSegment(_ segment: String) -> String {
        segment.encodePathSegment()
    }

    private func roomUrl(roomName: String, suffix: String = "") -> String {
        "\(apiVersionV4)/rooms/\(escapePathSegment(roomName))\(suffix)" // CHA-RST6
    }

    private func messageUrl(roomName: String, serial: String, suffix: String = "") -> String {
        "\(roomUrl(roomName: roomName, suffix: "/messages/"))\(escapePathSegment(serial))\(suffix)"
    }

    // (CHA-M6) Messages should be queryable from a paginated REST API.
    internal func getMessages(roomName: String, params: HistoryParams) async throws(ErrorInfo) -> some PaginatedResult<Message> {
        let endpoint = roomUrl(roomName: roomName, suffix: "/messages")
        return try await makePaginatedRequest(endpoint, params: params.asQueryItems())
    }

    // (CHA-M13) Get a single message by its serial
    internal func getMessage(roomName: String, serial: String) async throws(ErrorInfo) -> Message {
        let endpoint = messageUrl(roomName: roomName, serial: serial)
        return try await makeRequest(endpoint, method: "GET")
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

        internal init(jsonObject: [String: JSONValue]) throws(ErrorInfo) {
            serial = try jsonObject.stringValueForKey("serial")
        }
    }

    // (CHA-M3) Messages are sent to Ably via the Chat REST API, using the send method.
    // (CHA-M3a) When a message is sent successfully, the caller shall receive a struct representing the Message in response (as if it were received via Realtime event).
    internal func sendMessage(roomName: String, params: SendMessageParams) async throws(ErrorInfo) -> Message {
        let endpoint = roomUrl(roomName: roomName, suffix: "/messages")
        var body: [String: JSONValue] = ["text": .string(params.text)]

        // (CHA-M3b) A message may be sent without metadata or headers. When these are not specified by the user, they must be omitted from the REST payload.
        if let metadata = params.metadata {
            body["metadata"] = .object(metadata)
        }

        if let headers = params.headers {
            body["headers"] = .object(headers.mapValues(\.toJSONValue))
        }

        // The server returns a complete Message object with all necessary fields
        return try await makeRequest(endpoint, method: "POST", body: .jsonObject(body))
    }

    // (CHA-M8) A client must be able to update a message in a room.
    // (CHA-M8a) A client may update a message via the Chat REST API by calling the update method.
    internal func updateMessage(roomName: String, serial: String, updateParams: UpdateMessageParams, details: OperationDetails?) async throws(ErrorInfo) -> Message {
        let endpoint = messageUrl(roomName: roomName, serial: serial)
        var body: [String: JSONValue] = [:]

        var messageObject: [String: JSONValue] = [
            "text": .string(updateParams.text),
        ]

        if let metadata = updateParams.metadata {
            messageObject["metadata"] = .object(metadata)
        }

        if let headers = updateParams.headers {
            messageObject["headers"] = .object(headers.mapValues(\.toJSONValue))
        }

        body["message"] = .object(messageObject)

        if let description = details?.description {
            body["description"] = .string(description)
        }

        if let metadata = details?.metadata {
            body["metadata"] = .object(metadata.mapValues { .string($0) })
        }

        // (CHA-M8c) An update operation has PUT semantics. If a field is not specified in the update, it is assumed to be removed.
        // CHA-M8c is not actually respected here, see https://github.com/ably/ably-chat-swift/issues/333
        // (CHA-M8b) When a message is updated successfully via the REST API, the caller shall receive a struct representing the Message in response, as if it were received via Realtime event.
        // (CHA-M8b1) The server returns a complete Message object with all necessary fields
        return try await makeRequest(endpoint, method: "PUT", body: .jsonObject(body))
    }

    // (CHA-M9) A client must be able to delete a message in a room.
    // (CHA-M9a) A client may delete a message via the Chat REST API by calling the delete method.
    internal func deleteMessage(roomName: String, serial: String, details: OperationDetails?) async throws(ErrorInfo) -> Message {
        let endpoint = messageUrl(roomName: roomName, serial: serial, suffix: "/delete")
        var body: [String: JSONValue] = [:]

        if let description = details?.description {
            body["description"] = .string(description)
        }

        if let metadata = details?.metadata {
            body["metadata"] = .object(metadata.mapValues { .string($0) })
        }

        // (CHA-M9b) When a message is deleted successfully via the REST API, the caller shall receive a struct representing the Message in response, as if it were received via Realtime event.
        // (CHA-M9b1) The server returns a complete Message object with all necessary fields
        return try await makeRequest(endpoint, method: "POST", body: .jsonObject(body))
    }

    internal func getOccupancy(roomName: String) async throws(ErrorInfo) -> OccupancyData {
        let endpoint = roomUrl(roomName: roomName, suffix: "/occupancy")
        return try await makeRequest(endpoint, method: "GET")
    }

    // (CHA-MR4) Users should be able to send a reaction to a message via the `send` method of the `MessagesReactions` object
    internal func sendReactionToMessage(_ messageSerial: String, roomName: String, params: SendMessageReactionParams) async throws(ErrorInfo) -> MessageReactionResponse {
        // (CHA-MR4a2) If the serial passed to this method is invalid: undefined, null, empty string, an error with code InvalidArgument must be thrown.
        guard !messageSerial.isEmpty else {
            throw InternalError.sendMessageReactionEmptyMessageSerial.toErrorInfo()
        }

        let endpoint = messageUrl(roomName: roomName, serial: messageSerial, suffix: "/reactions")

        let ablyCocoaBody: [String: Any] = [
            "type": params.type.rawValue,
            "name": params.name,
            "count": params.count ?? 1,
        ]

        return try await makeRequest(endpoint, method: "POST", body: .ablyCocoaData(ablyCocoaBody))
    }

    // (CHA-MR11) Users should be able to delete a reaction from a message via the `delete` method of the `MessagesReactions` object
    internal func deleteReactionFromMessage(_ messageSerial: String, roomName: String, params: DeleteMessageReactionParams) async throws(ErrorInfo) -> MessageReactionResponse {
        // (CHA-MR11a2) If the serial passed to this method is invalid: undefined, null, empty string, an error with code InvalidArgument must be thrown.
        guard !messageSerial.isEmpty else {
            throw InternalError.deleteMessageReactionEmptyMessageSerial.toErrorInfo()
        }

        let endpoint = messageUrl(roomName: roomName, serial: messageSerial, suffix: "/reactions")

        var httpParams: [String: String] = [
            "type": params.type.rawValue,
        ]
        httpParams["name"] = params.name

        return try await makeRequest(endpoint, method: "DELETE", params: httpParams)
    }

    // CHA-MR13
    internal func getClientReactions(forMessageWithSerial messageSerial: String, roomName: String, clientID: String?) async throws(ErrorInfo) -> MessageReactionSummary {
        // CHA-MR13b
        let endpoint = messageUrl(roomName: roomName, serial: messageSerial, suffix: "/client-reactions")

        var params: [String: String]?
        if let clientID {
            params = ["forClientId": clientID]
        }

        let response: MessageReactionSummaryResponse = try await makeRequest(endpoint, method: "GET", params: params)
        return response.reactions
    }

    internal struct MessageReactionSummaryResponse: JSONObjectDecodable {
        internal let reactions: MessageReactionSummary

        internal init(jsonObject: [String: JSONValue]) throws(ErrorInfo) {
            reactions = MessageReactionSummary(values: jsonObject)
        }
    }

    private func makeRequest<Response: JSONDecodable>(_ path: String, method: String, params: [String: String]? = nil, body: RequestBody? = nil) async throws(ErrorInfo) -> Response {
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
        let paginatedResponse = try await realtime.request(method, path: path, params: params, body: ablyCocoaBody, headers: [:])

        guard let firstItem = paginatedResponse.items.first else {
            throw InternalError.noItemInResponse(path: path).toErrorInfo()
        }

        let jsonValue = JSONValue(ablyCocoaData: firstItem)
        return try Response(jsonValue: jsonValue)
    }

    private func makePaginatedRequest<Response: JSONDecodable & Sendable & Equatable>(
        _ url: String,
        params: [String: String]? = nil,
    ) async throws(ErrorInfo) -> some PaginatedResult<Response> {
        let paginatedResponse = try await realtime.request("GET", path: url, params: params, body: nil, headers: [:])
        let jsonValues = paginatedResponse.items.map { JSONValue(ablyCocoaData: $0) }
        let items = try jsonValues.map { jsonValue throws(ErrorInfo) in
            try Response(jsonValue: jsonValue)
        }
        return paginatedResponse.toPaginatedResult(items: items)
    }
}
