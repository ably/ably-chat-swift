import Ably
@testable import AblyChat
import Testing

struct DefaultMessagesTests {
    // MARK: CHA-M3

    // @spec CHA-M3f
    // @spec CHA-M3a
    @Test
    func clientMaySendMessageViaRESTChatAPI() async throws {
        // Given
        let realtime = MockRealtime.create { (MockHTTPPaginatedResponse(items: [["serial":"abc", "createdAt": Date().timeIntervalSince1970]]), nil) }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let message = try await defaultMessages.send(params: .init(text: "hey"))

        // Then
        #expect(message.text == "hey")
    }

    // @spec CHA-M3b
    @Test
    func whenMetadataAndHeadersAreNotSpecifiedByUserTheyAreOmittedFromRESTPayload() async throws {
        // Given
        let realtime = MockRealtime.create {
            (MockHTTPPaginatedResponse.successSendMessage, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)

        // When
        _ = try await chatAPI.sendMessage(
            roomId: "myroom", // arbitrary
            params: .init(
                text: "hey" // arbitrary
            )
        )

        // Then
        let requestBody = try #require(realtime.requestArguments.first?.body as? NSDictionary)
        #expect(requestBody["headers"] == nil)
        #expect(requestBody["metadata"] == nil)
    }

    // @spec CHA-M3e
    @Test
    func errorShouldBeThrownIfErrorIsReturnedFromRESTChatAPI() async throws {
        // Given
        let sendError = ARTErrorInfo(domain: "SomeDomain", code: 123)
        let realtime = MockRealtime.create { (nil, sendError) }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // Then
        await #expect(throws: sendError, performing: {
            _ = try await defaultMessages.send(params: .init(text: "hey"))
        })
    }

    // @spec CHA-M5a
    @Test
    func subscriptionPointIsChannelSerialWhenUnderlyingRealtimeChannelIsAttached() async throws {
        // Given
        let realtime = MockRealtime.create {
            (MockHTTPPaginatedResponse.successSendMessageWithNoItems, nil)
        }
        let channelSerial = "123"
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: nil, channelSerial: channelSerial), attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When: subscription is added when the underlying realtime channel is ATTACHED
        let subscription = try await defaultMessages.subscribe()
        let _ = try await subscription.getPreviousMessages(params: .init())
        
        // Then: subscription point is the current channelSerial of the realtime channel.
        let requestParams = try #require(realtime.requestArguments.first?.params)
        #expect(requestParams["fromSerial"] == channelSerial)
    }

    // @spec CHA-M5b
    @Test
    func subscriptionPointIsAttachSerialWhenUnderlyingRealtimeChannelIsNotAttached() async throws {
        // Given: A DefaultRoomLifecycleManager, with an ATTACH operation in progress and hence in the ATTACHING status
        let contributor = RoomLifecycleHelper.createContributor(feature: .messages, attachBehavior: .completeAndChangeState(.success, newState: .attached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay * 1000))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        let realtime = MockRealtime.create {
            (MockHTTPPaginatedResponse.successSendMessageWithNoItems, nil)
        }
        let attachSerial = "123"
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: attachSerial, channelSerial: nil), state: .attaching, attachResult: .success)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When: subscription is added when the underlying realtime channel is not ATTACHED
        let subscription = try await defaultMessages.subscribe()

        // Wait for room to become ATTACHING
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let _ = lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: UUID())
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: history get is called
        let _ = try await subscription.getPreviousMessages(params: .init())
        
        // Then: subscription point becomes the attachSerial at the the moment of channel attachment
        let requestParams = try #require(realtime.requestArguments.first?.params)
        #expect(requestParams["fromSerial"] == attachSerial)
    }

    @Test
    func get_getMessagesIsExposedFromChatAPI() async throws {
        // Message response of succcess with no items, and roomId are arbitrary

        // Given
        let realtime = MockRealtime.create { (MockHTTPPaginatedResponse.successGetMessagesWithNoItems, nil) }
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
        let realtime = MockRealtime.create { (MockHTTPPaginatedResponse.successGetMessagesWithNoItems, nil) }
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
        let realtime = MockRealtime.create()
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
                ]
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
        let realtime = MockRealtime.create()
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
                extras: [:]
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
        let realtime = MockRealtime.create()
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
