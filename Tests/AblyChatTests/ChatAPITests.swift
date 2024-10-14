import Ably
@testable import AblyChat
import Testing

struct ChatAPITests {
    // MARK: getChannel Tests

    // @spec CHA-M1
    @Test
    func getChannel_returnsChannel() {
        // Given
        let realtime = MockRealtime.create(
            channels: .init(channels: [.init(name: "basketball::$chat::$chatMessages")])
        )
        let chatAPI = ChatAPI(realtime: realtime)

        // When
        let channel = chatAPI.getChannel("basketball::$chat::$chatMessages")

        // Then
        #expect(channel.name == "basketball::$chat::$chatMessages")
    }

    // MARK: sendMessage Tests

    // @spec CHA-M3c
    @Test
    func sendMessage_whenMetadataHasAblyChatAsKey_throws40001() async {
        // Given
        let realtime = MockRealtime.create()
        let chatAPI = ChatAPI(realtime: realtime)
        let roomId = "basketball::$chat::$chatMessages"
        let expectedError = ARTErrorInfo.create(withCode: 40001, message: "metadata must not contain the key `ably-chat`")

        await #expect(
            performing: {
                // When
                try await chatAPI.sendMessage(roomId: roomId, params: .init(text: "hello", metadata: ["ably-chat": .null]))
            }, throws: { error in
                // Then
                error as? ARTErrorInfo == expectedError
            }
        )
    }

    // @specOneOf(1/2) CHA-M3d
    @Test
    func sendMessage_whenHeadersHasAnyKeyWithPrefixOfAblyChat_throws40001() async {
        // Given
        let realtime = MockRealtime.create {
            (MockHTTPPaginatedResponse.successSendMessage, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomId = "basketball::$chat::$chatMessages"
        let expectedError = ARTErrorInfo.create(withCode: 40001, message: "headers must not contain any key with a prefix of `ably-chat`")

        await #expect(
            performing: {
                // When
                try await chatAPI.sendMessage(roomId: roomId, params: .init(text: "hello", headers: ["ably-chat123": .null]))
            }, throws: { error in
                // then
                error as? ARTErrorInfo == expectedError
            }
        )
    }

    // @specOneOf(2/2) CHA-M3d
    @Test
    func sendMessage_whenHeadersHasAnyKeyWithSuffixOfAblyChat_doesNotThrowAnyError() async {
        // Given
        let realtime = MockRealtime.create {
            (MockHTTPPaginatedResponse.successSendMessage, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let roomId = "basketball::$chat::$chatMessages"

        // Then
        await #expect(throws: Never.self, performing: {
            // When
            try await chatAPI.sendMessage(roomId: roomId, params: .init(text: "hello", headers: ["123ably-chat": .null]))
        })
    }

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
            timeserial: "3446456",
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
                    timeserial: "3446456",
                    clientID: "random",
                    roomID: roomId,
                    text: "hello",
                    createdAt: nil,
                    metadata: [:],
                    headers: [:]
                ),
                Message(
                    timeserial: "3446457",
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
        let getMessages = try? await chatAPI.getMessages(roomId: roomId, params: .init()) as? PaginatedResultWrapper<Message>

        // Then
        #expect(getMessages == expectedPaginatedResult)
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
