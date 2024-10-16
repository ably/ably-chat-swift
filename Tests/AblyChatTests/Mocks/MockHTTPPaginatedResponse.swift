import Ably

final class MockHTTPPaginatedResponse: ARTHTTPPaginatedResponse, @unchecked Sendable {
    private let _items: [NSDictionary]
    private let _statusCode: Int
    private let _headers: [String: String]
    private let _hasNext: Bool
    private let _isLast: Bool

    init(
        items: [NSDictionary],
        statusCode: Int = 200,
        headers: [String: String] = [:],
        hasNext: Bool = false,
        isLast: Bool = true
    ) {
        _items = items
        _statusCode = statusCode
        _headers = headers
        _hasNext = hasNext
        _isLast = isLast
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
        _isLast
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
                "timeserial": "3446456",
                "createdAt": 1_631_840_000_000,
                "text": "hello",
            ],
        ],
        statusCode: 500,
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
    private static let messagesRoomId = "basketball::$chat::$chatMessages"

    static let successGetMessagesWithNoItems = MockHTTPPaginatedResponse(
        items: [],
        statusCode: 200,
        headers: [:]
    )

    static let successGetMessagesWithItems = MockHTTPPaginatedResponse(
        items: [
            [
                "clientId": "random",
                "timeserial": "3446456",
                "roomId": "basketball::$chat::$chatMessages",
                "text": "hello",
                "metadata": [:],
                "headers": [:],
            ],
            [
                "clientId": "random",
                "timeserial": "3446457",
                "roomId": "basketball::$chat::$chatMessages",
                "text": "hello response",
                "metadata": [:],
                "headers": [:],
            ],
        ],
        statusCode: 200,
        headers: [:]
    )
}

// MARK: Mock next page

extension MockHTTPPaginatedResponse {
    static let nextPage = MockHTTPPaginatedResponse(
        items: [
            [
                "timeserial": "3446450",
                "roomId": "basketball::$chat::$chatMessages",
                "text": "previous message",
                "metadata": [:],
                "headers": [:],
            ],
            [
                "timeserial": "3446451",
                "roomId": "basketball::$chat::$chatMessages",
                "text": "previous response",
                "metadata": [:],
                "headers": [:],
            ],
        ],
        statusCode: 200,
        headers: [:]
    )
}
