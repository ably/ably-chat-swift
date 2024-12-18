import Ably

internal final class ChatAPI: Sendable {
    private let realtime: RealtimeClient
    private let apiVersion = "/chat/v1"
    private let apiVersionV2 = "/chat/v2" // TODO: remove v1 after full transition to v2

    public init(realtime: RealtimeClient) {
        self.realtime = realtime
    }

    // (CHA-M6) Messages should be queryable from a paginated REST API.
    internal func getMessages(roomId: String, params: QueryOptions) async throws -> any PaginatedResult<Message> {
        let endpoint = "\(apiVersionV2)/rooms/\(roomId)/messages"
        return try await makePaginatedRequest(endpoint, params: params.asQueryItems())
    }

    internal struct SendMessageResponse: JSONObjectDecodable {
        internal let serial: String
        internal let createdAt: Int64

        internal init(jsonObject: [String: JSONValue]) throws {
            serial = try jsonObject.stringValueForKey("serial")
            createdAt = try Int64(jsonObject.numberValueForKey("createdAt"))
        }
    }

    // (CHA-M3) Messages are sent to Ably via the Chat REST API, using the send method.
    // (CHA-M3a) When a message is sent successfully, the caller shall receive a struct representing the Message in response (as if it were received via Realtime event).
    internal func sendMessage(roomId: String, params: SendMessageParams) async throws -> Message {
        guard let clientId = realtime.clientId else {
            throw ARTErrorInfo.create(withCode: 40000, message: "Ensure your Realtime instance is initialized with a clientId.")
        }

        let endpoint = "\(apiVersionV2)/rooms/\(roomId)/messages"
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

        let message = Message(
            serial: response.serial,
            action: .create,
            clientID: clientId,
            roomID: roomId,
            text: params.text,
            createdAt: Date(timeIntervalSince1970: createdAtInSeconds),
            metadata: params.metadata ?? [:],
            headers: params.headers ?? [:]
        )
        return message
    }

    internal func getOccupancy(roomId: String) async throws -> OccupancyEvent {
        let endpoint = "\(apiVersion)/rooms/\(roomId)/occupancy"
        return try await makeRequest(endpoint, method: "GET")
    }

    private func makeRequest<Response: JSONDecodable>(_ url: String, method: String, body: [String: JSONValue]? = nil) async throws -> Response {
        let ablyCocoaBody: Any? = if let body {
            JSONValue.object(body).toAblyCocoaData
        } else {
            nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try realtime.request(method, path: url, params: [:], body: ablyCocoaBody, headers: [:]) { paginatedResponse, error in
                    if let error {
                        // (CHA-M3e) If an error is returned from the REST API, its ErrorInfo representation shall be thrown as the result of the send call.
                        continuation.resume(throwing: ARTErrorInfo.create(from: error))
                        return
                    }

                    guard let firstItem = paginatedResponse?.items.first else {
                        continuation.resume(throwing: ChatError.noItemInResponse)
                        return
                    }

                    do {
                        let jsonValue = JSONValue(ablyCocoaData: firstItem)
                        let decodedResponse = try Response(jsonValue: jsonValue)
                        continuation.resume(returning: decodedResponse)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func makePaginatedRequest<Response: JSONDecodable & Sendable & Equatable>(
        _ url: String,
        params: [String: String]? = nil
    ) async throws -> any PaginatedResult<Response> {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PaginatedResultWrapper<Response>, _>) in
            do {
                try realtime.request("GET", path: url, params: params, body: nil, headers: [:]) { paginatedResponse, error in
                    ARTHTTPPaginatedCallbackWrapper<Response>(callbackResult: (paginatedResponse, error)).handleResponse(continuation: continuation)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    internal enum ChatError: Error {
        case noItemInResponse
    }
}
