import Ably

final class MockHTTPPaginatedResponse: ARTHTTPPaginatedResponse, @unchecked Sendable {
    private let _items: [NSDictionary]
    private let _statusCode: Int
    private let _headers: [String: String]
    private let _hasNext: Bool

    init(
        items: [NSDictionary],
        statusCode: Int = 200,
        headers: [String: String] = [:],
        hasNext: Bool = false
    ) {
        _items = items
        _statusCode = statusCode
        _headers = headers
        _hasNext = hasNext
        super.init()
    }

    override var items: [NSDictionary] {
        _items
    }

    override var statusCode: Int {
        _statusCode
    }

    override var headers: [String: String] {
        _headers
    }

    override var success: Bool {
        (statusCode >= 200) && (statusCode < 300)
    }

    override var hasNext: Bool {
        _hasNext
    }

    override var isLast: Bool {
        !_hasNext
    }

    override func next(_ callback: @escaping ARTHTTPPaginatedCallback) {
        callback(hasNext ? MockHTTPPaginatedResponse.nextPage : nil, nil)
    }

    override func first(_ callback: @escaping ARTHTTPPaginatedCallback) {
        callback(self, nil)
    }
}

// MARK: ChatAPI.sendMessage mocked responses

extension MockHTTPPaginatedResponse {
    static let successSendMessage = MockHTTPPaginatedResponse(
        items: [
            [
                "serial": "3446456",
                "version": [
                    "serial": "3446456",
                ],
                "timestamp": 1_631_840_000_000,
                "createdAt": 1_631_840_000_000,
                "text": "hello",
            ],
        ],
        statusCode: 200,
        headers: [:]
    )

    static let failedSendMessage = MockHTTPPaginatedResponse(
        items: [],
        statusCode: 400,
        headers: [:]
    )

    static let successSendMessageWithNoItems = MockHTTPPaginatedResponse(
        items: [],
        statusCode: 200,
        headers: [:]
    )
}

// MARK: ChatAPI.getMessages mocked responses

extension MockHTTPPaginatedResponse {
    static let successGetMessagesWithNoItems = MockHTTPPaginatedResponse(
        items: [],
        statusCode: 200,
        headers: [:]
    )

    static let successGetMessagesWithItems = MockHTTPPaginatedResponse(
        items: [
            [
                "clientId": "random",
                "serial": "3446456",
                "action": "message.create",
                "text": "hello",
                "metadata": [:],
                "headers": [:],
                "version": [
                    "serial": "3446456",
                ],
                "timestamp": 1_730_943_049_269,
            ],
            [
                "clientId": "random",
                "serial": "3446457",
                "action": "message.create",
                "text": "hello response",
                "metadata": [:],
                "headers": [:],
                "version": [
                    "serial": "3446457",
                ],
                "timestamp": 1_730_943_051_269,
            ],
        ],
        statusCode: 200,
        headers: [:],
        hasNext: true
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
        hasNext: false
    )
}
