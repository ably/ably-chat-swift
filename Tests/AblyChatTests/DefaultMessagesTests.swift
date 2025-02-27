import Ably
@testable import AblyChat
import Testing

struct DefaultMessagesTests {
    @Test
    func subscribe_whenChannelIsAttachedAndNoChannelSerial_throwsError() async throws {
        // roomId and clientId values are arbitrary

        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // Then
        await #expect(throws: ARTErrorInfo.create(withCode: 40000, status: 400, message: "channel is attached, but channelSerial is not defined"), performing: {
            // When
            try await defaultMessages.subscribe()
        })
    }

    @Test
    func get_getMessagesIsExposedFromChatAPI() async throws {
        // Message response of succcess with no items, and roomId are arbitrary

        // Given
        let realtime = MockRealtime { (MockHTTPPaginatedResponse.successGetMessagesWithNoItems, nil) }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // Then
        await #expect(throws: Never.self, performing: {
            // When
            // `_ =` is required to avoid needing iOS 16 to run this test
            // Error: Runtime support for parameterized protocol types is only available in iOS 16.0.0 or newer
            _ = try await defaultMessages.get(options: .init())
        })
    }

    @Test
    func subscribe_returnsSubscription() async throws {
        // all setup values here are arbitrary

        // Given
        let realtime = MockRealtime { (MockHTTPPaginatedResponse.successGetMessagesWithNoItems, nil) }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            ),
            attachResult: .success
        )
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())
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
            attachResult: .success,
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
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let messagesSubscription = try await defaultMessages.subscribe()

        // Then
        let receivedMessage = try #require(await messagesSubscription.first { _ in true })
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
            attachResult: .success,
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
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let messagesSubscription = try await defaultMessages.subscribe()

        // Then
        let receivedMessage = try #require(await messagesSubscription.first { _ in true })
        #expect(receivedMessage.metadata == ["numberKey": .number(10), "stringKey": .string("hello")])
    }

    // @spec CHA-M7
    @Test
    func onDiscontinuity() async throws {
        // Given: A DefaultMessages instance
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let messages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When: The feature channel emits a discontinuity through `onDiscontinuity`
        let featureChannelDiscontinuity = DiscontinuityEvent(error: ARTErrorInfo.createUnknownError() /* arbitrary */ )
        let messagesDiscontinuitySubscription = await messages.onDiscontinuity()
        await featureChannel.emitDiscontinuity(featureChannelDiscontinuity)

        // Then: The DefaultMessages instance emits this discontinuity through `onDiscontinuity`
        let messagesDiscontinuity = try #require(await messagesDiscontinuitySubscription.first { _ in true })
        #expect(messagesDiscontinuity == featureChannelDiscontinuity)
    }
}
