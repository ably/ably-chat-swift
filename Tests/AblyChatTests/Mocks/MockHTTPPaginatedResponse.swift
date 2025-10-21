import Ably
@testable import AblyChat

final class MockHTTPPaginatedResponse: InternalHTTPPaginatedResponseProtocol {
    let items: [JSONValue]
    let statusCode: Int
    let headers: [String: String]
    let hasNext: Bool

    init(
        items: [[String: JSONValue]],
        statusCode: Int = 200,
        headers: [String: String] = [:],
        hasNext: Bool = false,
    ) {
        self.items = items.map { .object($0) }
        self.statusCode = statusCode
        self.headers = headers
        self.hasNext = hasNext
    }

    var isLast: Bool {
        !hasNext
    }

    func next() async throws(ErrorInfo) -> MockHTTPPaginatedResponse? {
        hasNext ? MockHTTPPaginatedResponse.nextPage : nil
    }

    func first() async throws(ErrorInfo) -> MockHTTPPaginatedResponse {
        self
    }
}

// MARK: ChatAPI.sendMessage mocked responses

extension MockHTTPPaginatedResponse {
    static let successSendMessage = MockHTTPPaginatedResponse(
        items: [
            [
                "clientId": "mockClientId",
                "serial": "123456789-000@123456789:000",
                "action": "message.create",
                "text": "hello",
                "metadata": [:],
                "headers": [:],
                "version": [
                    "serial": "123456789-000@123456789:000",
                    "timestamp": 1_631_840_000_000,
                ],
                "timestamp": 1_631_840_000_000,
            ],
        ],
        statusCode: 200,
        headers: [:],
    )

    static let failedSendMessage = MockHTTPPaginatedResponse(
        items: [],
        statusCode: 400,
        headers: [:],
    )

    static let successSendMessageWithNoItems = MockHTTPPaginatedResponse(
        items: [],
        statusCode: 200,
        headers: [:],
    )
}

// MARK: ChatAPI.getMessages mocked responses

extension MockHTTPPaginatedResponse {
    static let successGetMessagesWithNoItems = MockHTTPPaginatedResponse(
        items: [],
        statusCode: 200,
        headers: [:],
    )

    static let successGetMessagesWithItems = MockHTTPPaginatedResponse(
        items: [
            [
                "clientId": "random",
                "serial": "123456789-000@123456789:000",
                "action": "message.create",
                "text": "hello",
                "metadata": [:],
                "headers": [:],
                "version": [
                    "serial": "123456789-000@123456789:000",
                ],
                "timestamp": 1_730_943_049_269,
            ],
            [
                "clientId": "random",
                "serial": "123456789-000@123456789:001",
                "action": "message.create",
                "text": "hello response",
                "metadata": [:],
                "headers": [:],
                "version": [
                    "serial": "123456789-000@123456789:001",
                ],
                "timestamp": 1_730_943_051_269,
            ],
        ],
        statusCode: 200,
        headers: [:],
        hasNext: true,
    )
}

// MARK: Mock next page

extension MockHTTPPaginatedResponse {
    static let nextPage = MockHTTPPaginatedResponse(
        items: [
            [
                "clientId": "random",
                "serial": "3446458",
                "action": "message.create",
                "timestamp": 1_730_943_053_269,
                "text": "next hello",
                "metadata": [:],
                "headers": [:],
                "version": [
                    "serial": "3446458",
                ],
            ],
            [
                "clientId": "random",
                "serial": "3446459",
                "action": "message.create",
                "text": "next hello response",
                "metadata": [:],
                "headers": [:],
                "version": [
                    "serial": "3446459",
                ],
                "timestamp": 1_730_943_055_269,
            ],
        ],
        statusCode: 200,
        headers: [:],
        hasNext: false,
    )
}
