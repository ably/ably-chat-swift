import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultMessageReactionsTests {
    // @spec CHA-MR4
    // @spec CHA-MR4a
    // @spec CHA-MR4b
    // @spec CHA-MR11
    // @spec CHA-MR11a
    // @spec CHA-MR11b
    // @spec CHA-MR11b1
    // @spec CHA-MR11b2
    // @specOneOf(5/6) CHA-RST6 - Escaping room name for API send/delete reaction
    @Test
    func sendAndDeleteReactionForMessage() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(initialState: .attached)
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basket/ball", logger: TestLogger())

        // When
        let message = try await defaultMessages.send(withParams: .init(text: "a joke"))
        try await defaultMessages.reactions.send(forMessageWithSerial: message.serial, params: .init(name: "😆", type: .multiple, count: 10))
        try await defaultMessages.reactions.delete(forMessageWithSerial: message.serial, params: .init(name: "😆", type: .multiple))

        // Then
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: [
                "method": "POST",
                "path": "/chat/v4/rooms/basket%2Fball/messages/123456789-000@123456789:000/reactions",
                "body": [
                    "name": "😆",
                    "type": "reaction:multiple.v1",
                    "count": 10,
                ],
                "params": [:],
                "headers": [:],
            ],
        ))
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: [
                "method": "DELETE",
                "path": "/chat/v4/rooms/basket%2Fball/messages/123456789-000@123456789:000/reactions",
                "body": [:],
                "params": [
                    "name": "😆",
                    "type": "reaction:multiple.v1",
                ],
                "headers": [:],
            ],
        ))
    }

    // @spec CHA-MR4a1
    @Test
    func errorShouldBeThrownIfMessageSerialIsEmptyWhenSend() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(initialState: .attached)
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", logger: TestLogger())

        let thrownError = await #expect(throws: ARTErrorInfo.self) {
            // When
            try await defaultMessages.reactions.send(forMessageWithSerial: "", params: .init(name: "😐", type: .distinct))
        }

        // Then
        #expect(thrownError == ARTErrorInfo(chatError: .nonErrorInfoInternalError(.chatAPIChatError(.messageReactionInvalidMessageSerial))))
    }

    // @spec CHA-MR11a1
    @Test
    func errorShouldBeThrownIfMessageSerialIsEmptyWhenDelete() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(initialState: .attached)
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", logger: TestLogger())

        let thrownError = await #expect(throws: ARTErrorInfo.self) {
            // When
            try await defaultMessages.reactions.delete(forMessageWithSerial: "", params: .init(name: "😐", type: .distinct))
        }

        // Then
        #expect(thrownError == ARTErrorInfo(chatError: .nonErrorInfoInternalError(.chatAPIChatError(.messageReactionInvalidMessageSerial))))
    }

    // @spec CHA-MR3
    // @spec CHA-MR3b
    // @spec CHA-MR3b2
    // @spec CHA-MR3b3
    // @spec CHA-MR6
    @Test
    func subscribeToMessageReactionSummaries() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let channel = MockRealtimeChannel(
            initialState: .attached,
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                message.serial = "001"
                message.action = .messageSummary
                message.annotations = .init(
                    summary: [
                        "reaction:unique.v1": [
                            "like": ["total": 2, "clientIds": ["userOne", "userTwo"]],
                            "love": ["total": 1, "clientIds": ["userThree"]],
                        ],
                        "reaction:distinct.v1": [
                            "like": ["total": 2, "clientIds": ["userOne", "userTwo"]],
                            "love": ["total": 1, "clientIds": ["userOne"]],
                        ],
                        "reaction:multiple.v1": [
                            "like": ["total": 5, "clientIds": ["userOne": 3, "userTwo": 2]],
                            "love": ["total": 10, "clientIds": ["userOne": 10]],
                        ],
                    ],
                )
                return message
            }(),
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", logger: TestLogger())

        // When
        var callbackCalls = 0
        defaultMessages.reactions.subscribe { event in
            // Then
            #expect(event.type == .summary)
            #expect(type(of: event.reactions.unique) == [String: MessageReactionSummary.ClientIDList].self)
            #expect(event.reactions.unique["like"]?.total == 2)
            #expect(event.reactions.unique["love"]?.total == 1)
            #expect(event.reactions.unique["like"]?.clientIDs.count == 2)
            #expect(event.reactions.unique["love"]?.clientIDs.count == 1)
            #expect(type(of: event.reactions.distinct) == [String: MessageReactionSummary.ClientIDList].self)
            #expect(event.reactions.distinct["like"]?.total == 2)
            #expect(event.reactions.distinct["love"]?.total == 1)
            #expect(event.reactions.distinct["like"]?.clientIDs.count == 2)
            #expect(event.reactions.distinct["love"]?.clientIDs.count == 1)
            #expect(type(of: event.reactions.multiple) == [String: MessageReactionSummary.ClientIDCounts].self)
            #expect(event.reactions.multiple["like"]?.total == 5)
            #expect(event.reactions.multiple["love"]?.total == 10)
            #expect(event.reactions.multiple["like"]?.clientIDs.count == 2)
            #expect(event.reactions.multiple["love"]?.clientIDs.count == 1)
            callbackCalls += 1
        }
        #expect(callbackCalls == 1)
    }

    // @spec CHA-MR6a
    // @spec CHA-MR6a3
    @Test
    func invalidReactionSummaryEventsMustStillProduceEventWithDefaultValues() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let channel = MockRealtimeChannel(
            initialState: .attached,
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                message.serial = "001"
                message.action = .messageSummary
                return message
            }(),
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", logger: TestLogger())

        // When
        var callbackCalls = 0
        defaultMessages.reactions.subscribe { event in
            // Then
            #expect(event.type == .summary)
            #expect(event.reactions.unique.isEmpty)
            #expect(event.reactions.distinct.isEmpty)
            #expect(event.reactions.multiple.isEmpty)
            callbackCalls += 1
        }
        #expect(callbackCalls == 1)
    }

    // @spec CHA-MR7
    @Test
    func subscribeToRawMessageReactions() async throws {
        // Given
        let channel = MockRealtimeChannel(
            name: "basketball::$chat",
            initialState: .attached,
            annotationToEmitOnSubscribe: .init(
                id: nil,
                action: .create,
                clientId: "U3BpZGVyd2Vi",
                name: "🔥",
                count: 41,
                data: nil,
                encoding: nil,
                timestamp: Date(),
                serial: "",
                messageSerial: "0LHQtdC70YvQtSDRgNC+0LfRiw",
                type: "reaction:multiple.v1",
                extras: nil,
            ),
        )
        let channels = MockChannels(channels: [channel])
        let realtime = MockRealtime(channels: channels) {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let roomOptions = RoomOptions(messages: .init(rawMessageReactions: true))
        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        let defaultMessages = room.messages

        // When
        var callbackCalls = 0
        defaultMessages.reactions.subscribeRaw { event in
            // Then
            #expect(event.type == MessageReactionRawEventType.create)
            #expect(event.reaction.type == .multiple)
            #expect(event.reaction.name == "🔥")
            #expect(event.reaction.clientID == "U3BpZGVyd2Vi")
            #expect(event.reaction.messageSerial == "0LHQtdC70YvQtSDRgNC+0LfRiw")
            #expect(event.reaction.count == 41)
            callbackCalls += 1
        }
        #expect(callbackCalls == 1)
    }

    // @spec CHA-MR7b
    // @spec CHA-MR7b3
    @Test
    func invalidReactionEventsMustStillProduceEventWithDefaultValues() async throws {
        // Given
        let channel = MockRealtimeChannel(
            name: "basketball::$chat",
            initialState: .attached,
            annotationToEmitOnSubscribe: .init(
                id: nil,
                action: .create,
                clientId: nil,
                name: nil,
                count: nil,
                data: nil,
                encoding: nil,
                timestamp: Date(),
                serial: "",
                messageSerial: "",
                type: "reaction:multiple.v1",
                extras: nil,
            ),
        )
        let channels = MockChannels(channels: [channel])
        let realtime = MockRealtime(channels: channels) {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let roomOptions = RoomOptions(messages: .init(rawMessageReactions: true))
        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        let defaultMessages = room.messages

        // When
        var callbackCalls = 0
        defaultMessages.reactions.subscribeRaw { event in
            // Then
            #expect(event.reaction.name.isEmpty)
            #expect(event.reaction.clientID.isEmpty)
            callbackCalls += 1
        }
        #expect(callbackCalls == 1)
    }

    // @spec CHA-MR7b1
    @Test
    func ifReactionTypeIsUnknownTheEventShallBeIgnored() async throws {
        // Given
        let channel = MockRealtimeChannel(
            name: "basketball::$chat",
            initialState: .attached,
            annotationToEmitOnSubscribe: .init(
                id: nil,
                action: .create,
                clientId: nil,
                name: nil,
                count: nil,
                data: nil,
                encoding: nil,
                timestamp: Date(),
                serial: "",
                messageSerial: "",
                type: "not-a-reaction", // invalid type
                extras: nil,
            ),
        )
        let channels = MockChannels(channels: [channel])
        let realtime = MockRealtime(channels: channels) {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let roomOptions = RoomOptions(messages: .init(rawMessageReactions: true))
        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        let defaultMessages = room.messages

        // When
        var callbackCalls = 0
        defaultMessages.reactions.subscribeRaw { _ in
            callbackCalls += 1
        }
        // Then
        #expect(callbackCalls == 0)
    }

    // @specOneOf(1/2) CHA-MR5
    @Test
    func configureDefaultMessageReactionTypeForRoom() async throws {
        // Given
        let channel = MockRealtimeChannel(
            name: "basketball::$chat",
            initialState: .attached,
        )
        let channels = MockChannels(channels: [channel])
        let realtime = MockRealtime(channels: channels) {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let roomOptions = RoomOptions(messages: .init(defaultMessageReactionType: .multiple))
        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        let defaultMessages = room.messages

        // When
        let message = try await defaultMessages.send(withParams: .init(text: "a joke"))
        try await defaultMessages.reactions.send(forMessageWithSerial: message.serial, params: .init(name: "😆"))

        // Then
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: [
                "method": "POST",
                "path": "/chat/v4/rooms/basketball/messages/123456789-000@123456789:000/reactions",
                "body": [
                    "name": "😆",
                    "type": "reaction:multiple.v1",
                    "count": 1,
                ],
                "params": [:],
                "headers": [:],
            ],
        ))
    }

    // @specOneOf(2/2) CHA-MR5
    @Test
    func reactionTypeForRoomIsDistinctByDefault() async throws {
        // Given: a DefaultRoom instance
        let channel = MockRealtimeChannel(
            name: "basketball::$chat",
            initialState: .attached,
        )
        let channels = MockChannels(channels: [channel])
        let realtime = MockRealtime(channels: channels) {
            MockHTTPPaginatedResponse.successSendMessage
        }
        let roomOptions = RoomOptions()
        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then
        let defaultMessages = room.messages

        // When
        let message = try await defaultMessages.send(withParams: .init(text: "a joke"))
        try await defaultMessages.reactions.send(forMessageWithSerial: message.serial, params: .init(name: "😆"))

        // Then
        #expect(realtime.callRecorder.hasRecord(
            matching: "request(_:path:params:body:headers:)",
            arguments: [
                "method": "POST",
                "path": "/chat/v4/rooms/basketball/messages/123456789-000@123456789:000/reactions",
                "body": [
                    "name": "😆",
                    "type": "reaction:distinct.v1",
                    "count": 1,
                ],
                "params": [:],
                "headers": [:],
            ],
        ))
    }

    // @specNotApplicable CHA-MR7a - It's a programmer error to call `Room.messages.reactions.subscribeRaw` without `MessageOptions.rawMessageReactions` being set to `true`.

    // @specNotApplicable CHA-MR3a - Summary is a `NSDictionary` of wire values in the cocoa SDK.

    // Tests for CHA-MR13
    @MainActor
    struct ClientReactions {
        // @specOneOf(1/3) CHA-MR13
        // @specOneOf(1/2) CHA-MR13b
        // @spec CHA-MR13b1
        @Test
        func getClientReactionsForMessage() async throws {
            // Given
            let realtime = MockRealtime {
                MockHTTPPaginatedResponse(
                    items: [
                        [
                            "reaction:unique.v1": [
                                "like": ["total": 1, "clientIds": ["testClientId"]],
                            ],
                            "reaction:distinct.v1": [
                                "love": ["total": 1, "clientIds": ["testClientId"]],
                            ],
                            "reaction:multiple.v1": [
                                "fire": ["total": 5, "clientIds": ["testClientId": 5]],
                            ],
                        ],
                    ],
                    statusCode: 200,
                    headers: [:],
                )
            }
            let chatAPI = ChatAPI(realtime: realtime)
            let channel = MockRealtimeChannel(initialState: .attached)
            let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", logger: TestLogger())

            // When - using nil clientID should not pass forClientId parameter (server uses current client implicitly)
            let summary = try await defaultMessages.reactions.clientReactions(forMessageWithSerial: "123456789-000@123456789:000", clientID: nil)

            // Then
            #expect(summary.unique["like"]?.total == 1)
            #expect(summary.distinct["love"]?.total == 1)
            #expect(summary.multiple["fire"]?.total == 5)
            #expect(realtime.callRecorder.hasRecord(
                matching: "request(_:path:params:body:headers:)",
                arguments: [
                    "method": "GET",
                    "path": "/chat/v4/rooms/basketball/messages/123456789-000@123456789:000/client-reactions",
                    "body": [:],
                    "params": [:],
                    "headers": [:],
                ],
            ))
        }

        // @specOneOf(2/3) CHA-MR13
        // @specOneOf(2/2) CHA-MR13b
        @Test
        func getClientReactionsForMessageWithSpecificClientID() async throws {
            // Given
            let realtime = MockRealtime {
                MockHTTPPaginatedResponse(
                    items: [
                        [
                            "reaction:unique.v1": [
                                "like": ["total": 1, "clientIds": ["otherClientId"]],
                            ],
                        ],
                    ],
                    statusCode: 200,
                    headers: [:],
                )
            }
            let chatAPI = ChatAPI(realtime: realtime)
            let channel = MockRealtimeChannel(initialState: .attached)
            let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", logger: TestLogger())

            // When
            let summary = try await defaultMessages.reactions.clientReactions(forMessageWithSerial: "123456789-000@123456789:000", clientID: "otherClientId")

            // Then
            #expect(summary.unique["like"]?.total == 1)
            #expect(realtime.callRecorder.hasRecord(
                matching: "request(_:path:params:body:headers:)",
                arguments: [
                    "method": "GET",
                    "path": "/chat/v4/rooms/basketball/messages/123456789-000@123456789:000/client-reactions",
                    "body": [:],
                    "params": ["forClientId": "otherClientId"],
                    "headers": [:],
                ],
            ))
        }

        // @specOneOf(3/3) CHA-MR13
        // @spec CHA-MR13c
        @Test
        func getClientReactionsThrowsErrorOnAPIFailure() async throws {
            // Given
            let realtime = MockRealtime { @Sendable () throws(ARTErrorInfo) in
                throw ARTErrorInfo(domain: "SomeDomain", code: 404)
            }
            let chatAPI = ChatAPI(realtime: realtime)
            let channel = MockRealtimeChannel(initialState: .attached)
            let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", logger: TestLogger())

            // When/Then
            let thrownError = await #expect(throws: ARTErrorInfo.self) {
                _ = try await defaultMessages.reactions.clientReactions(forMessageWithSerial: "123456789-000@123456789:000", clientID: nil)
            }
            #expect(thrownError?.domain == "SomeDomain" && thrownError?.code == 404)
        }
    }
}
