import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultMessagesTests {
    // MARK: CHA-M3

    // @spec CHA-M3a
    // @spec CHA-M3b
    // @spec CHA-M3f
    @Test
    func clientMaySendMessageViaRESTChatAPI() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(initialState: .attached)
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        _ = try await defaultMessages.send(params: .init(text: "hey"))

        // Then
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: ["method": "POST", "path": "/chat/v3/rooms/basketball/messages", "body": ["text": "hey"], "params": [:], "headers": [:]]
        )
        )
    }

    // @spec CHA-M3e
    @Test
    func errorShouldBeThrownIfErrorIsReturnedFromRESTChatAPI() async throws {
        // Given
        let realtime = MockRealtime { @Sendable () throws(ARTErrorInfo) in
            throw ARTErrorInfo(domain: "SomeDomain", code: 123)
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel()
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultMessages.send(params: .init(text: "hey"))
        }
        await #expect {
            try await doIt()
        } throws: { error in
            error as? ARTErrorInfo == ARTErrorInfo(domain: "SomeDomain", code: 123)
        }
    }

    // @spec CHA-M5a
    @Test
    func subscriptionPointIsChannelSerialWhenUnderlyingRealtimeChannelIsAttached() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessageWithNoItems
        }
        let channelSerial = "123"
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: ARTChannelProperties(attachSerial: nil, channelSerial: channelSerial),
            initialState: .attached
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())
        let subscription = try await defaultMessages.subscribe()
        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: subscription point is the current channelSerial of the realtime channel
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: ["method": "GET", "path": "/chat/v3/rooms/basketball/messages", "body": [:], "params": ["direction": "backwards", "fromSerial": "\(channelSerial)"], "headers": [:]]
        )
        )
    }

    // @spec CHA-M5b
    @Test
    func subscriptionPointIsAttachSerialWhenUnderlyingRealtimeChannelIsNotAttached() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessageWithNoItems
        }
        let attachSerial = "123"
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: ARTChannelProperties(attachSerial: attachSerial, channelSerial: nil),
            initialState: .attaching,
            stateChangeToEmitForListener: ARTChannelStateChange(current: .attached, previous: .attaching, event: .attached, reason: nil)
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // When: subscription is added when the underlying realtime channel is ATTACHING
        let subscription = try await defaultMessages.subscribe()
        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: subscription point is the attachSerial of the realtime channel
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: ["method": "GET", "path": "/chat/v3/rooms/basketball/messages", "body": [:], "params": ["direction": "backwards", "fromSerial": "\(attachSerial)"], "headers": [:]]
        )
        )
    }

    // @spec CHA-M5c
    @Test
    func whenChannelReentersATTACHEDWithResumedFalseThenSubscriptionPointResetsToAttachSerial() async throws {
        // Given
        let attachSerial = "attach123"
        let channelSerial = "channel456"
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessageWithNoItems
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: ARTChannelProperties(attachSerial: attachSerial, channelSerial: channelSerial),
            initialState: .attached
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // When: subscription is added when the underlying realtime channel is ATTACHING
        let subscription = try await defaultMessages.subscribe()
        _ = try await subscription.getPreviousMessages(params: .init())

        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: ["method": "GET", "path": "/chat/v3/rooms/basketball/messages", "body": [:], "params": ["direction": "backwards", "fromSerial": "\(channelSerial)"], "headers": [:]]
        )
        )

        channel.emitEvent(
            ARTChannelStateChange(current: .detached, previous: .attached, event: .detached, reason: ARTErrorInfo(domain: "Some", code: 123))
        )

        channel.emitEvent(
            ARTChannelStateChange(current: .attached, previous: .detached, event: .attached, reason: nil, resumed: false)
        )

        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: subscription point is the attachSerial of the realtime channel
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: ["method": "GET", "path": "/chat/v3/rooms/basketball/messages", "body": [:], "params": ["direction": "backwards", "fromSerial": "\(attachSerial)"], "headers": [:]]
        )
        )
    }

    // @spec CHA-M5d
    @Test
    func whenChannelUPDATEReceivedWithResumedFalseThenSubscriptionPointResetsToAttachSerial() async throws {
        // Given
        let attachSerial = "attach123"
        let channelSerial = "channel456"
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessageWithNoItems
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: ARTChannelProperties(attachSerial: attachSerial, channelSerial: channelSerial),
            initialState: .attached
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // When: subscription is added when the underlying realtime channel is ATTACHING
        let subscription = try await defaultMessages.subscribe()
        _ = try await subscription.getPreviousMessages(params: .init())

        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: ["method": "GET", "path": "/chat/v3/rooms/basketball/messages", "body": [:], "params": ["direction": "backwards", "fromSerial": "\(channelSerial)"], "headers": [:]]
        )
        )

        channel.emitEvent(
            ARTChannelStateChange(current: .attached, previous: .attached, event: .update, reason: nil, resumed: false)
        )

        _ = try await subscription.getPreviousMessages(params: .init())

        // Then: subscription point is the attachSerial of the realtime channel
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: ["method": "GET", "path": "/chat/v3/rooms/basketball/messages", "body": [:], "params": ["direction": "backwards", "fromSerial": "\(attachSerial)"], "headers": [:]]
        )
        )
    }

    // @spec CHA-M5f
    // @spec CHA-M5g
    // @spec CHA-M5h
    @available(iOS 16.0.0, tvOS 16.0.0, *) // To avoid "Runtime support for parameterized protocol types is only available in iOS 16.0.0 or newer" compile error
    @Test
    func subscriptionGetPreviousMessagesAcceptsStandardHistoryQueryOptionsExceptForDirection() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successGetMessagesWithItems
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: ARTChannelProperties(attachSerial: nil, channelSerial: "123"),
            initialState: .attached
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

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
        let artError = ARTErrorInfo.create(withCode: 50000, message: "Internal server error")
        let realtime = MockRealtime { @Sendable () throws(ARTErrorInfo) in
            throw artError
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: ARTChannelProperties(attachSerial: nil, channelSerial: "123"),
            initialState: .attached
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let subscription = try await defaultMessages.subscribe()

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await subscription.getPreviousMessages(params: .init())
        }
        // Then
        await #expect {
            try await doIt()
        } throws: { error in
            error as? ARTErrorInfo == artError
        }
    }

    // @spec CHA-M6a
    @available(iOS 16.0.0, tvOS 16.0.0, *) // To avoid "Runtime support for parameterized protocol types is only available in iOS 16.0.0 or newer" compile error
    @Test
    func getMessagesAcceptsStandardHistoryQueryOptions() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successGetMessagesWithItems
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: ARTChannelProperties(attachSerial: nil, channelSerial: "123"),
            initialState: .attached
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        let paginatedResult = try await defaultMessages.get(options: .init())

        // Then
        // CHA-M6a: The method return a PaginatedResult containing messages
        #expect(paginatedResult.items.count == 2)
        #expect(paginatedResult.hasNext == true)

        // Then
        // CHA-M6a: which can then be paginated through
        let nextPage = try #require(await paginatedResult.next)
        #expect(nextPage.hasNext == false)
    }

    // @spec CHA-M6b
    @Test
    func getMessagesThrowsErrorInfoInCaseOfServerError() async throws {
        // Given
        let artError = ARTErrorInfo.create(withCode: 50000, message: "Internal server error")
        let realtime = MockRealtime { @Sendable () throws(ARTErrorInfo) in
            throw artError
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            properties: ARTChannelProperties(attachSerial: nil, channelSerial: "123"),
            initialState: .attached
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try await defaultMessages.get(options: .init())
        }
        // Then
        await #expect {
            try await doIt()
        } throws: { error in
            error as? ARTErrorInfo == artError
        }
    }

    // CHA-M4d is currently untestable due to not subscribing to those events on lower level
    // @spec CHA-M4a
    // @spec CHA-M4m
    // @spec CHA-M4b
    @Test
    func subscriptionCanBeRegisteredToReceiveIncomingMessages() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        func generateMessage(serial: String, numberKey: Int, stringKey: String) -> ARTMessage {
            let message = ARTMessage()
            message.action = .create // arbitrary
            message.serial = serial // arbitrary
            message.clientId = "" // arbitrary
            message.data = [
                "text": "", // arbitrary
                "metadata": ["numberKey": numberKey, "stringKey": stringKey],
            ]
            message.extras = [
                "headers": ["numberKey": numberKey, "stringKey": stringKey],
            ] as any ARTJsonCompatible
            message.version = "0"
            return message
        }

        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            ),
            initialState: .attached,
            messageToEmitOnSubscribe: generateMessage(serial: "1", numberKey: 10, stringKey: "hello")
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // Notes:
        // When using `AsyncSequence` variant of `subscribe` it gives a compile error (Xcode 16.2): "sending main actor-isolated value of type '(MessageSubscription.Element) async -> Bool' (aka '(Message) async -> Bool') with later accesses to nonisolated context risks causing data races". So I used callback one.
        // When the expectation are not met test crashes with "Fatal error: Internal inconsistency: No test reporter for test AblyChatTests.DefaultMessagesTests/subscriptionCanBeRegisteredToReceiveIncomingMessages()/DefaultMessagesTests.swift:326:6 and test case argumentIDs: Optional([])". I guess this could be avoided by using `withCheckedContinuation`, but it doesn't accept async functions in its closure body (await subscribe).

        // When
        let subscriptionHandle = try await defaultMessages.subscribe { message in
            // Then
            #expect(message.headers == ["numberKey": .number(10), "stringKey": .string("hello")])
            #expect(message.metadata == ["numberKey": .number(10), "stringKey": .string("hello")])
        }

        // CHA-M4b
        subscriptionHandle.unsubscribe()

        // will not be received and expectations above will not fail
        channel.simulateIncomingMessage(
            generateMessage(serial: "2", numberKey: 11, stringKey: "hello there"),
            for: RealtimeMessageName.chatMessage.rawValue
        )
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
            initialState: .attached,
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                message.action = .create // arbitrary
                message.serial = "123" // arbitrary
                message.clientId = "" // arbitrary
                message.data = [
                    "text": "", // arbitrary
                ]
                message.extras = [:] as any ARTJsonCompatible
                message.version = "0"
                return message
            }()
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        _ = try await defaultMessages.subscribe { message in
            // Then
            #expect(message.serial == "123")
        }

        // will not be received and expectations above will not fail
        channel.simulateIncomingMessage(
            ARTMessage(), // malformed message
            for: RealtimeMessageName.chatMessage.rawValue
        )
    }
}
