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
        let realtime = MockRealtime { (MockHTTPPaginatedResponse(items: [["serial": "abc", "createdAt": Date().timeIntervalSince1970]]), nil) }
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
        let realtime = MockRealtime {
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
        let realtime = MockRealtime { (nil, sendError) }
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
        let realtime = MockRealtime {
            (MockHTTPPaginatedResponse.successSendMessageWithNoItems, nil)
        }
        let channelSerial = "123"
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: nil, channelSerial: channelSerial), attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When: subscription is added when the underlying realtime channel is ATTACHED
        let subscription = try await defaultMessages.subscribe()
        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: subscription point is the current channelSerial of the realtime channel.
        let requestParams = try #require(realtime.requestArguments.first?.params)
        #expect(requestParams["fromSerial"] == channelSerial)
    }

    // @spec CHA-M5b
    @Test
    func subscriptionPointIsAttachSerialWhenUnderlyingRealtimeChannelIsNotAttached() async throws {
        // Given
        let attachSerial = "123"
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: attachSerial, channelSerial: nil), state: .attaching, attachResult: .success)
        let contributor = RoomLifecycleHelper.createContributor(feature: .messages, underlyingChannel: channel, attachBehavior: .completeAndChangeState(.success, newState: .attached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay), detachBehavior: .completeAndChangeState(.success, newState: .detached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        let realtime = MockRealtime {
            (MockHTTPPaginatedResponse.successSendMessageWithNoItems, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // Wait for room to become ATTACHING
        let roomStatusSubscription = await lifecycleManager.onRoomStatusChange(bufferingPolicy: .unbounded)
        async let _ = lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: UUID())
        _ = try #require(await roomStatusSubscription.attachingElements().first { _ in true })

        // When: subscription is added when the underlying realtime channel is not ATTACHED
        let subscription = try await defaultMessages.subscribe()

        // When: history get is called
        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: subscription point becomes the attachSerial at the the moment of channel attachment
        let requestParams = try #require(realtime.requestArguments.first?.params)
        #expect(requestParams["fromSerial"] == attachSerial)
    }

    // @spec CHA-M5c
    @Test
    func whenChannelReentersATTACHEDWithResumedFalseThenSubscriptionPointResetsToAttachSerial() async throws {
        // Given
        let attachSerial = "attach123"
        let channelSerial = "channel456"
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: attachSerial, channelSerial: channelSerial), state: .attached, attachResult: .success, detachResult: .success)
        let contributor = RoomLifecycleHelper.createContributor(feature: .messages, underlyingChannel: channel, attachBehavior: .completeAndChangeState(.success, newState: .attached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay * 2), detachBehavior: .completeAndChangeState(.success, newState: .detached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay * 2))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        let realtime = MockRealtime {
            (MockHTTPPaginatedResponse.successSendMessageWithNoItems, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // Wait for room to become ATTACHED
        try await lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: UUID())

        // When: subscription is added
        let subscription = try await defaultMessages.subscribe()

        // When: history get is called
        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: subscription point is the channelSerial
        let requestParams1 = try #require(realtime.requestArguments.first?.params)
        #expect(requestParams1["fromSerial"] == channelSerial)

        // Wait for room to become DETACHED
        try await lifecycleManager.performDetachOperation(testsOnly_forcingOperationID: UUID())

        // And then to become ATTACHED again
        try await lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: UUID())

        // When: history get is called
        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: The subscription point of any subscribers must be reset to the attachSerial
        let requestParams2 = try #require(realtime.requestArguments.last?.params)
        #expect(requestParams2["fromSerial"] == attachSerial)
    }

    // @spec CHA-M5d
    @Test
    func whenChannelUPDATEReceivedWithResumedFalseThenSubscriptionPointResetsToAttachSerial() async throws {
        // Given
        let attachSerial = "attach123"
        let channelSerial = "channel456"
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: attachSerial, channelSerial: channelSerial), state: .attached, attachResult: .success, detachResult: .success)
        let contributor = RoomLifecycleHelper.createContributor(feature: .messages, underlyingChannel: channel, attachBehavior: .completeAndChangeState(.success, newState: .attached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay * 2), detachBehavior: .completeAndChangeState(.success, newState: .detached, delayInMilliseconds: RoomLifecycleHelper.fakeNetworkDelay * 2))
        let lifecycleManager = await RoomLifecycleHelper.createManager(contributors: [contributor])

        let realtime = MockRealtime {
            (MockHTTPPaginatedResponse.successSendMessageWithNoItems, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let featureChannel = DefaultFeatureChannel(channel: channel, contributor: contributor, roomLifecycleManager: lifecycleManager)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // Wait for room to become ATTACHED
        try await lifecycleManager.performAttachOperation(testsOnly_forcingOperationID: UUID())

        // When: subscription is added
        let subscription = try await defaultMessages.subscribe()

        // When: history get is called
        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: subscription point is the channelSerial
        let requestParams1 = try #require(realtime.requestArguments.first?.params)
        #expect(requestParams1["fromSerial"] == channelSerial)

        // When: This contributor emits an UPDATE event with `resumed` flag set to false
        let contributorStateChange = ARTChannelStateChange(
            current: .attached, // arbitrary
            previous: .attached, // arbitrary
            event: .update,
            reason: ARTErrorInfo(domain: "SomeDomain", code: 123), // arbitrary
            resumed: false
        )

        await RoomLifecycleHelper.waitForManager(lifecycleManager, toHandleContributorStateChange: contributorStateChange) {
            await contributor.channel.emitStateChange(contributorStateChange)
        }

        // When: history get is called
        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: The subscription point of any subscribers must be reset to the attachSerial
        let requestParams2 = try #require(realtime.requestArguments.last?.params)
        #expect(requestParams2["fromSerial"] == attachSerial)
    }

    // @spec CHA-M5f
    // @spec CHA-M5g
    // @spec CHA-M5h
    @available(iOS 16.0.0, tvOS 16.0.0, *) // To avoid "Runtime support for parameterized protocol types is only available in iOS 16.0.0 or newer" compile error
    @Test
    func subscriptionGetPreviousMessagesAcceptsStandardHistoryQueryOptionsExceptForDirection() async throws {
        // Given
        let realtime = MockRealtime {
            (MockHTTPPaginatedResponse.successGetMessagesWithItems, nil)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: nil, channelSerial: "123"), attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When: subscription is added when the underlying realtime channel is ATTACHED
        let subscription = try await defaultMessages.subscribe()
        let paginatedResult = try await subscription.getPreviousMessages(params: .init(orderBy: .oldestFirst)) // CHA-M5f, try to set unsupported direction

        let requestParams = try #require(realtime.requestArguments.first?.params)

        // Then

        // CHA-M5g: the subscription point must be additionally specified (internally, by us) in the "fromSerial" query parameter
        #expect(requestParams["fromSerial"] == "123")

        // CHA-M5f: method must accept any of the standard history query options, except for direction, which must always be backwards (`OrderBy.newestFirst` is equivalent to "backwards", see `getBeforeSubscriptionStart` func)
        #expect(requestParams["direction"] == "backwards")

        // CHA-M5h: The method must return a standard PaginatedResult
        #expect(paginatedResult.items.count == 2)
        #expect(paginatedResult.hasNext == true)

        // CHA-M5h: which can be further inspected to paginate across results
        let nextPage = try #require(await paginatedResult.next)
        #expect(nextPage.hasNext == false)
    }

    // @spec CHA-M5i
    @Test
    func subscriptionGetPreviousMessagesThrowsErrorInfoInCaseOfServerError() async throws {
        // Given
        let paginatedResponse = MockHTTPPaginatedResponse.successGetMessagesWithItems
        let artError = ARTErrorInfo.create(withCode: 50000, message: "Internal server error")
        let realtime = MockRealtime {
            (paginatedResponse, artError)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: nil, channelSerial: "123"), attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        let subscription = try await defaultMessages.subscribe()

        await #expect(throws: artError, performing: {
            _ = try await subscription.getPreviousMessages(params: .init())
        })
    }

    // @spec CHA-M6a
    @available(iOS 16.0.0, tvOS 16.0.0, *) // To avoid "Runtime support for parameterized protocol types is only available in iOS 16.0.0 or newer" compile error
    @Test
    func getMessagesAcceptsStandardHistoryQueryOptions() async throws {
        // Message response of succcess with no items, and roomId are arbitrary

        // Given
        let realtime = MockRealtime { (MockHTTPPaginatedResponse.successGetMessagesWithItems, nil) }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        let paginatedResult = try await defaultMessages.get(options: .init())

        // CHA-M6a: The method return a PaginatedResult containing messages
        #expect(paginatedResult.items.count == 2)
        #expect(paginatedResult.hasNext == true)

        // CHA-M6a: which can then be paginated through
        let nextPage = try #require(await paginatedResult.next)
        #expect(nextPage.hasNext == false)
    }

    // @spec CHA-M6b
    @Test
    func getMessagesThrowsErrorInfoInCaseOfServerError() async throws {
        // Given
        let paginatedResponse = MockHTTPPaginatedResponse.successGetMessagesWithItems
        let artError = ARTErrorInfo.create(withCode: 50000, message: "Internal server error")
        let realtime = MockRealtime {
            (paginatedResponse, artError)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(properties: ARTChannelProperties(attachSerial: nil, channelSerial: "123"), attachResult: .success)
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        await #expect(throws: artError, performing: {
            _ = try await defaultMessages.get(options: .init())
        })
    }

    // CHA-M4b is currently untestable due to subscription is removed once the object is removed from memory
    // CHA-M4d is currently untestable due to not subscribing to those events on lower level
    // @spec CHA-M4a
    // @spec CHA-M4m
    @Test
    func subscriptionCanBeRegisteredToReceiveIncomingMessages() async throws {
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
                extras: [
                    "headers": ["numberKey": 10, "stringKey": "hello"],
                ],
                version: "0"
            )
        )
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let messagesSubscription = try await defaultMessages.subscribe()

        // Then
        let receivedMessage = try #require(await messagesSubscription.first { _ in true })
        #expect(receivedMessage.headers == ["numberKey": .number(10), "stringKey": .string("hello")])
        #expect(receivedMessage.metadata == ["numberKey": .number(10), "stringKey": .string("hello")])
    }

    // Wrong name, should be CHA-M4k
    // @spec CHA-M5k
    @Test
    func malformedRealtimeEventsShallNotBeEmittedToSubscribers() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            ),
            attachResult: .success,
            messageJSONToEmitOnSubscribe: ["foo": "bar"] // malformed realtime message
        )
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultMessages = await DefaultMessages(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let malformedMessagesSubscription = await defaultMessages.testsOnly_subscribeToMalformedMessageEvents()
        _ = try await defaultMessages.subscribe()

        // Then
        _ = try #require(await malformedMessagesSubscription.first { _ in true })
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
