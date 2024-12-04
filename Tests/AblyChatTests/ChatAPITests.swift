import Ably
@testable import AblyChat
import Testing

struct ChatAPITests {
    // MARK: sendMessage Tests

    @Test
    func sendMessage_whenSendMessageReturnsNoItems_throwsNoItemInResponse() async {
        // Given
        let realtime = MockRealtime.create {
            (MockHTTPPaginatedResponse.successSendMessageWithNoItems, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomId = "basketball::$chat::$chatMessages"

        await #expect(
            performing: {
                // When
                try await chatAPI.sendMessage(roomId: roomId, params: .init(text: "hello", headers: [:]))
            }, throws: { error in
                // Then
                error as? ChatAPI.ChatError == ChatAPI.ChatError.noItemInResponse
            }
        )
    }

    // @spec CHA-M3a
    @Test
    func sendMessage_returnsMessage() async throws {
        // Given
        let realtime = MockRealtime.create {
            (MockHTTPPaginatedResponse.successSendMessage, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomId = "basketball::$chat::$chatMessages"

        // When
        let message = try await chatAPI.sendMessage(roomId: roomId, params: .init(text: "hello", headers: [:]))

        // Then
        let expectedMessage = Message(
            serial: "3446456",
            action: .create,
            clientID: "mockClientId",
            roomID: roomId,
            text: "hello",
            createdAt: Date(timeIntervalSince1970: 1_631_840_000),
            metadata: [:],
            headers: [:]
        )
        #expect(message == expectedMessage)
    }

    // MARK: getMessages Tests

    // @specOneOf(1/2) CHA-M6
    @Test
    func getMessages_whenGetMessagesReturnsNoItems_returnsEmptyPaginatedResult() async {
        // Given
        let paginatedResponse = MockHTTPPaginatedResponse.successGetMessagesWithNoItems
        let realtime = MockRealtime.create {
            (paginatedResponse, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomId = "basketball::$chat::$chatMessages"
        let expectedPaginatedResult = PaginatedResultWrapper<Message>(
            paginatedResponse: paginatedResponse,
            items: []
        )

        // When
        let getMessages = try? await chatAPI.getMessages(roomId: roomId, params: .init()) as? PaginatedResultWrapper<Message>

        // Then
        #expect(getMessages == expectedPaginatedResult)
    }

    // @specOneOf(2/2) CHA-M6
    @Test
    func getMessages_whenGetMessagesReturnsItems_returnsItemsInPaginatedResult() async {
        // Given
        let paginatedResponse = MockHTTPPaginatedResponse.successGetMessagesWithItems
        let realtime = MockRealtime.create {
            (paginatedResponse, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomId = "basketball::$chat::$chatMessages"
        let expectedPaginatedResult = PaginatedResultWrapper<Message>(
            paginatedResponse: paginatedResponse,
            items: [
                Message(
                    serial: "3446456",
                    action: .create,
                    clientID: "random",
                    roomID: roomId,
                    text: "hello",
                    createdAt: .init(timeIntervalSince1970: 1_730_943_049.269),
                    metadata: [:],
                    headers: [:]
                ),
                Message(
                    serial: "3446457",
                    action: .create,
                    clientID: "random",
                    roomID: roomId,
                    text: "hello response",
                    createdAt: nil,
                    metadata: [:],
                    headers: [:]
                ),
            ]
        )

        // When
        let getMessagesResult = try? await chatAPI.getMessages(roomId: roomId, params: .init()) as? PaginatedResultWrapper<Message>

        // Then
        #expect(getMessagesResult == expectedPaginatedResult)
    }

    // @spec CHA-M5i
    @Test
    func getMessages_whenGetMessagesReturnsServerError_throwsARTError() async {
        // Given
        let paginatedResponse = MockHTTPPaginatedResponse.successGetMessagesWithNoItems
        let artError = ARTErrorInfo.create(withCode: 50000, message: "Internal server error")
        let realtime = MockRealtime.create {
            (paginatedResponse, artError)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomId = "basketball::$chat::$chatMessages"

        await #expect(
            performing: {
                // When
                try await chatAPI.getMessages(roomId: roomId, params: .init()) as? PaginatedResultWrapper<Message>
            }, throws: { error in
                // Then
                error as? ARTErrorInfo == artError
            }
        )
    }
}
