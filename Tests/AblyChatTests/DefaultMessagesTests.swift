import Ably
@testable import AblyChat
import Testing

struct DefaultMessagesTests {
    @Test
    func subscribe_whenChannelIsAttachedAndNoChannelSerial_throwsError() async throws {
        // roomId and clientId values are arbitrary

        // Given
        let realtime = MockRealtime.create()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel()
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId")

        // Then
        await #expect(throws: ARTErrorInfo.create(withCode: 40000, status: 400, message: "channel is attached, but channelSerial is not defined"), performing: {
            // When
            try await defaultMessages.subscribe(bufferingPolicy: .unbounded)
        })
    }

    @Test
    func get_getMessagesIsExposedFromChatAPI() async throws {
        // Message response of succcess with no items, and roomId are arbitrary

        // Given
        let realtime = MockRealtime.create { (MockHTTPPaginatedResponse.successGetMessagesWithNoItems, nil) }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel()
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId")

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
        let realtime = MockRealtime.create { (MockHTTPPaginatedResponse.successGetMessagesWithNoItems, nil) }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            )
        )
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId")
        let subscription = try await defaultMessages.subscribe(bufferingPolicy: .unbounded)
        let expectedPaginatedResult = PaginatedResultWrapper<Message>(
            paginatedResponse: MockHTTPPaginatedResponse.successGetMessagesWithNoItems,
            items: []
        )

        // When
        let previousMessages = try await subscription.getPreviousMessages(params: .init()) as? PaginatedResultWrapper<Message>

        // Then
        #expect(previousMessages == expectedPaginatedResult)
    }

    // @spec CHA-M7
    @Test
    func subscribeToDiscontinuities() async throws {
        // Given: A DefaultMessages instance
        let realtime = MockRealtime.create()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel()
        let featureChannel = MockFeatureChannel(channel: channel)
        let messages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId")

        // When: The feature channel emits a discontinuity through `subscribeToDiscontinuities`
        let featureChannelDiscontinuity = ARTErrorInfo.createUnknownError() // arbitrary
        let messagesDiscontinuitySubscription = await messages.subscribeToDiscontinuities()
        await featureChannel.emitDiscontinuity(featureChannelDiscontinuity)

        // Then: The DefaultMessages instance emits this discontinuity through `subscribeToDiscontinuities`
        let messagesDiscontinuity = try #require(await messagesDiscontinuitySubscription.first { _ in true })
        #expect(messagesDiscontinuity === featureChannelDiscontinuity)
    }
}
