import Ably
@testable import AblyChat
import Testing

@MainActor
struct ChatAPITests {
    // MARK: sendMessage Tests

    @Test
    func sendMessage_whenSendMessageReturnsNoItems_throwsNoItemInResponse() async {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessageWithNoItems
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomName = "basketball"

        await #expect(
            performing: {
                // When
                try await chatAPI.sendMessage(roomName: roomName, params: .init(text: "hello", headers: [:]))
            }, throws: { error in
                // Then
                if let internalError = error as? InternalError, case .other(.chatAPIChatError(.noItemInResponse)) = internalError {
                    true
                } else {
                    false
                }
            },
        )
    }

    // @spec CHA-M3a
    // @spec CHA-M3a1
    @Test
    func sendMessage_returnsMessage() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomName = "basketball"

        // When
        let message = try await chatAPI.sendMessage(roomName: roomName, params: .init(text: "hello", headers: [:]))

        // Then
        let expectedMessage = Message(
            serial: "123456789-000@123456789:000",
            action: .messageCreate,
            clientID: "mockClientId",
            text: "hello",
            metadata: [:],
            headers: [:],
            version: .init(serial: "123456789-000@123456789:000", timestamp: Date(timeIntervalSince1970: 1_631_840_000)),
            timestamp: Date(timeIntervalSince1970: 1_631_840_000),
            reactions: .empty,
        )
        #expect(message == expectedMessage)
    }

    @Test
    func sendMessage_includesHeadersInBody() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let chatAPI = ChatAPI(realtime: realtime)

        // When
        _ = try await chatAPI.sendMessage(
            roomName: "", // arbitrary
            params: .init(
                text: "", // arbitrary
                // The exact value here is arbitrary, just want to check it gets serialized
                headers: ["numberKey": 10, "stringKey": "hello"],
            ),
        )

        // Then
        let requestBody = try #require(realtime.requestArguments.first?.body as? NSDictionary)
        #expect(try #require(requestBody["headers"] as? NSObject) == ["numberKey": 10, "stringKey": "hello"] as NSObject)
    }

    @Test
    func sendMessage_includesMetadataInBody() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let chatAPI = ChatAPI(realtime: realtime)

        // When
        _ = try await chatAPI.sendMessage(
            roomName: "", // arbitrary
            params: .init(
                text: "", // arbitrary
                // The exact value here is arbitrary, just want to check it gets serialized
                metadata: ["numberKey": 10, "stringKey": "hello"],
            ),
        )

        // Then
        let requestBody = try #require(realtime.requestArguments.first?.body as? NSDictionary)
        #expect(try #require(requestBody["metadata"] as? NSObject) == ["numberKey": 10, "stringKey": "hello"] as NSObject)
    }

    // MARK: getMessages Tests

    // @specOneOf(1/2) CHA-M6
    @Test
    func getMessages_whenGetMessagesReturnsNoItems_returnsEmptyPaginatedResult() async {
        // Given
        let paginatedResponse = MockHTTPPaginatedResponse.successGetMessagesWithNoItems
        let realtime = MockRealtime {
            paginatedResponse
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomName = "basketball"
        let expectedPaginatedResult = PaginatedResultWrapper<Message>(
            paginatedResponse: paginatedResponse,
            items: [],
        )

        // When
        let getMessages = try? await chatAPI.getMessages(roomName: roomName, params: .init()) as? PaginatedResultWrapper<Message>

        // Then
        #expect(getMessages == expectedPaginatedResult)
    }

    // @specOneOf(2/2) CHA-M6
    @Test
    func getMessages_whenGetMessagesReturnsItems_returnsItemsInPaginatedResult() async throws {
        // Given
        let paginatedResponse = MockHTTPPaginatedResponse.successGetMessagesWithItems
        let realtime = MockRealtime {
            paginatedResponse
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomName = "basketball"
        let expectedPaginatedResult = PaginatedResultWrapper<Message>(
            paginatedResponse: paginatedResponse,
            items: [
                Message(
                    serial: "3446456",
                    action: .messageCreate,
                    clientID: "random",
                    text: "hello",
                    metadata: [:],
                    headers: [:],
                    version: .init(serial: "3446456", timestamp: Date(timeIntervalSince1970: 1_730_943_049.269)), // from successGetMessagesWithItems
                    timestamp: Date(timeIntervalSince1970: 1_730_943_049.269),
                    reactions: .empty,
                ),
                Message(
                    serial: "3446457",
                    action: .messageCreate,
                    clientID: "random",
                    text: "hello response",
                    metadata: [:],
                    headers: [:],
                    version: .init(serial: "3446457", timestamp: Date(timeIntervalSince1970: 1_730_943_051.269)),
                    timestamp: Date(timeIntervalSince1970: 1_730_943_051.269),
                    reactions: .empty,
                ),
            ],
        )

        // When
        let getMessagesResult = try #require(await chatAPI.getMessages(roomName: roomName, params: .init()) as? PaginatedResultWrapper<Message>)

        // Then
        #expect(getMessagesResult.items == expectedPaginatedResult.items)
    }

    // @spec CHA-M5i
    @Test
    func getMessages_whenGetMessagesReturnsServerError_throwsARTError() async {
        // Given
        let artError = ARTErrorInfo.create(withCode: 50000, message: "Internal server error")
        let realtime = MockRealtime { () throws(ARTErrorInfo) in
            throw artError
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomName = "basketball"

        await #expect(
            performing: {
                // When
                try await chatAPI.getMessages(roomName: roomName, params: .init()) as? PaginatedResultWrapper<Message>
            }, throws: { error in
                // Then
                isInternalErrorWrappingErrorInfo(error, artError)
            },
        )
    }
}
