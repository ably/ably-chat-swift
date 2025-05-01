import Ably

@MainActor
internal final class ChatAPI: Sendable {
    private let realtime: any InternalRealtimeClientProtocol
    private let apiVersionV3 = "/chat/v3"

    public init(realtime: any InternalRealtimeClientProtocol) {
        self.realtime = realtime
    }

    // (CHA-M6) Messages should be queryable from a paginated REST API.
    internal func getMessages(roomId: String, params: QueryOptions) async throws(InternalError) -> any PaginatedResult<Message> {
        let endpoint = "\(apiVersionV3)/rooms/\(roomId)/messages"
        let result: Result<PaginatedResultWrapper<Message>, InternalError> = await makePaginatedRequest(endpoint, params: params.asQueryItems())
        return try result.get()
    }

    internal struct SendMessageResponse: JSONObjectDecodable {
        internal let serial: String
        internal let createdAt: Int64

        internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
            serial = try jsonObject.stringValueForKey("serial")
            createdAt = try Int64(jsonObject.numberValueForKey("createdAt"))
        }
    }

    internal struct MessageOperationResponse: JSONObjectDecodable {
        internal let version: String
        internal let timestamp: Int64

        internal init(jsonObject: [String: JSONValue]) throws(InternalError) {
            version = try jsonObject.stringValueForKey("version")
            timestamp = try Int64(jsonObject.numberValueForKey("timestamp"))
        }
    }

    internal typealias UpdateMessageResponse = MessageOperationResponse
    internal typealias DeleteMessageResponse = MessageOperationResponse

    // (CHA-M3) Messages are sent to Ably via the Chat REST API, using the send method.
    // (CHA-M3a) When a message is sent successfully, the caller shall receive a struct representing the Message in response (as if it were received via Realtime event).
    internal func sendMessage(roomId: String, params: SendMessageParams) async throws(InternalError) -> Message {
        guard let clientId = realtime.clientId else {
            throw ARTErrorInfo.create(withCode: 40000, message: "Ensure your Realtime instance is initialized with a clientId.").toInternalError()
        }

        let endpoint = "\(apiVersionV3)/rooms/\(roomId)/messages"
        var body: [String: JSONValue] = ["text": .string(params.text)]

        // (CHA-M3b) A message may be sent without metadata or headers. When these are not specified by the user, they must be omitted from the REST payload.
        if let metadata = params.metadata {
            body["metadata"] = .object(metadata)
        }

        if let headers = params.headers {
            body["headers"] = .object(headers.mapValues(\.toJSONValue))
        }

        let response: SendMessageResponse = try await makeRequest(endpoint, method: "POST", body: body)

        // response.createdAt is in milliseconds, convert it to seconds
        let createdAtInSeconds = TimeInterval(Double(response.createdAt) / 1000)
        let createdAtDate = Date(timeIntervalSince1970: createdAtInSeconds)
        let message = Message(
            serial: response.serial,
            action: .create,
            clientID: clientId,
            roomID: roomId,
            text: params.text,
            createdAt: createdAtDate,
            metadata: params.metadata ?? [:],
            headers: params.headers ?? [:],
            version: response.serial,
            timestamp: createdAtDate
        )
        return message
    }

    // (CHA-M8) A client must be able to update a message in a room.
    // (CHA-M8a) A client may update a message via the Chat REST API by calling the update method.
    internal func updateMessage(with modifiedMessage: Message, description: String?, metadata: OperationMetadata?) async throws(InternalError) -> Message {
        guard let clientID = realtime.clientId else {
            throw ARTErrorInfo.create(withCode: 40000, message: "Ensure your Realtime instance is initialized with a clientId.").toInternalError()
        }

        let endpoint = "\(apiVersionV3)/rooms/\(modifiedMessage.roomID)/messages/\(modifiedMessage.serial)"
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
        let response: UpdateMessageResponse = try await makeRequest(endpoint, method: "PUT", body: body)

        // response.timestamp is in milliseconds, convert it to seconds
        let timestampInSeconds = TimeInterval(Double(response.timestamp) / 1000)

        // (CHA-M8b) When a message is updated successfully via the REST API, the caller shall receive a struct representing the Message in response, as if it were received via Realtime event.
        let message = Message(
            serial: modifiedMessage.serial,
            action: .update,
            clientID: modifiedMessage.clientID,
            roomID: modifiedMessage.roomID,
            text: modifiedMessage.text,
            createdAt: modifiedMessage.createdAt,
            metadata: modifiedMessage.metadata,
            headers: modifiedMessage.headers,
            version: response.version,
            timestamp: Date(timeIntervalSince1970: timestampInSeconds),
            operation: .init(
                clientID: clientID,
                description: description,
                metadata: metadata
            )
        )
        return message
    }

    // (CHA-M9) A client must be able to delete a message in a room.
    // (CHA-M9a) A client may delete a message via the Chat REST API by calling the delete method.
    internal func deleteMessage(message: Message, params: DeleteMessageParams) async throws(InternalError) -> Message {
        let endpoint = "\(apiVersionV3)/rooms/\(message.roomID)/messages/\(message.serial)/delete"
        var body: [String: JSONValue] = [:]

        if let description = params.description {
            body["description"] = .string(description)
        }

        if let metadata = params.metadata {
            body["metadata"] = .object(metadata)
        }

        let response: DeleteMessageResponse = try await makeRequest(endpoint, method: "POST", body: body)

        // response.timestamp is in milliseconds, convert it to seconds
        let timestampInSeconds = TimeInterval(Double(response.timestamp) / 1000)

        // (CHA-M9b) When a message is deleted successfully via the REST API, the caller shall receive a struct representing the Message in response, as if it were received via Realtime event.
        let message = Message(
            serial: message.serial,
            action: .delete,
            clientID: message.clientID,
            roomID: message.roomID,
            text: message.text,
            createdAt: message.createdAt,
            metadata: message.metadata,
            headers: message.headers,
            version: response.version,
            timestamp: Date(timeIntervalSince1970: timestampInSeconds),
            operation: .init(
                clientID: message.clientID,
                description: params.description,
                metadata: params.metadata
            )
        )
        return message
    }

    internal func getOccupancy(roomId: String) async throws(InternalError) -> OccupancyEvent {
        let endpoint = "\(apiVersionV3)/rooms/\(roomId)/occupancy"
        return try await makeRequest(endpoint, method: "GET")
    }

    private func makeRequest<Response: JSONDecodable>(_ url: String, method: String, body: [String: JSONValue]? = nil) async throws(InternalError) -> Response {
        let ablyCocoaBody: Any? = if let body {
            JSONValue.object(body).toAblyCocoaData
        } else {
            nil
        }

        // (CHA-M3e & CHA-M8d & CHA-M9c) If an error is returned from the REST API, its ErrorInfo representation shall be thrown as the result of the send call.
        let paginatedResponse = try await realtime.request(method, path: url, params: [:], body: ablyCocoaBody, headers: [:])

        guard let firstItem = paginatedResponse.items.first else {
            throw ChatError.noItemInResponse.toInternalError()
        }

        let jsonValue = JSONValue(ablyCocoaData: firstItem)
        return try Response(jsonValue: jsonValue)
    }

    // TODO: (https://github.com/ably/ably-chat-swift/issues/267) switch this back to use `throws` once Xcode 16.3 typed throw crashes are fixed
    private func makePaginatedRequest<Response: JSONDecodable & Sendable & Equatable>(
        _ url: String,
        params: [String: String]? = nil
    ) async -> Result<PaginatedResultWrapper<Response>, InternalError> {
        do {
            let paginatedResponse = try await realtime.request("GET", path: url, params: params, body: nil, headers: [:])
            let jsonValues = paginatedResponse.items.map { JSONValue(ablyCocoaData: $0) }
            let items = try jsonValues.map { jsonValue throws(InternalError) in
                try Response(jsonValue: jsonValue)
            }
            return .success(paginatedResponse.toPaginatedResult(items: items))
        } catch {
            return .failure(error)
        }
    }

    internal enum ChatError: Error {
        case noItemInResponse
    }
}
