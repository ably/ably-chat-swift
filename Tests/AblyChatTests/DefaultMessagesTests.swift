import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultMessagesTests {
    @Test
    func subscribe_whenChannelIsAttachedAndNoChannelSerial_throwsError() async throws {
        // roomId and clientId values are arbitrary

        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(initialState: .attached)
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            // When
            try await defaultMessages.subscribe()
        }
        await #expect(throws: ARTErrorInfo.create(withCode: 40000, status: 400, message: "channel is attached, but channelSerial is not defined"), performing: {
            try await doIt()
        })
    }

    @Test
    func get_getMessagesIsExposedFromChatAPI() async throws {
        // Message response of succcess with no items, and roomId are arbitrary

        // Given
        let realtime = MockRealtime { MockHTTPPaginatedResponse.successGetMessagesWithNoItems }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel()
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            // When
            // `_ =` is required to avoid needing iOS 16 to run this test
            // Error: Runtime support for parameterized protocol types is only available in iOS 16.0.0 or newer
            _ = try await defaultMessages.get(options: .init())
        }
        await #expect(throws: Never.self, performing: {
            try await doIt()
        })
    }

    @Test
    func subscribe_returnsSubscription() async throws {
        // all setup values here are arbitrary

        // Given
        let realtime = MockRealtime { MockHTTPPaginatedResponse.successGetMessagesWithNoItems }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            ),
            initialState: .attached
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())
        let subscription = try await defaultMessages.subscribe()
        let expectedPaginatedResult = PaginatedResultWrapper<Message>(
            paginatedResponse: MockHTTPPaginatedResponse.successGetMessagesWithNoItems,
            items: []
        )

        // When
        let previousMessages = try await subscription.getPreviousMessages(params: .init()) as? PaginatedResultWrapper<Message>

        // Then
        #expect(previousMessages == expectedPaginatedResult)
    }

    @Test
    func subscribe_extractsHeadersFromChannelMessage() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            ),
            initialState: .attached,
            messageToEmitOnSubscribe: .init(
                action: .create, // arbitrary
                serial: "", // arbitrary
                clientID: "", // arbitrary
                data: [
                    "text": "", // arbitrary
                ],
                extras: [
                    "headers": ["numberKey": 10, "stringKey": "hello"],
                ],
                operation: nil,
                version: ""
            )
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let messagesSubscription = try await defaultMessages.subscribe()

        // Then
        let receivedMessage = try #require(await messagesSubscription.first { @Sendable _ in true })
        #expect(receivedMessage.headers == ["numberKey": .number(10), "stringKey": .string("hello")])
    }

    @Test
    func subscribe_extractsMetadataFromChannelMessage() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            ),
            initialState: .attached,
            messageToEmitOnSubscribe: .init(
                action: .create, // arbitrary
                serial: "", // arbitrary
                clientID: "", // arbitrary
                data: [
                    "text": "", // arbitrary
                    "metadata": ["numberKey": 10, "stringKey": "hello"],
                ],
                extras: [:],
                operation: nil,
                version: ""
            )
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let messagesSubscription = try await defaultMessages.subscribe()

        // Then
        let receivedMessage = try #require(await messagesSubscription.first { @Sendable _ in true })
        #expect(receivedMessage.metadata == ["numberKey": .number(10), "stringKey": .string("hello")])
    }
}
