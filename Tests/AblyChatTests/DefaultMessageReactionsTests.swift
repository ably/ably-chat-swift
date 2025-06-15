import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultMessageReactionsTests {
    // @spec CHA-MR6
    @Test
    func subscribeToMessageReactionSummaries() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            ),
            initialState: .attached,
            messageJSONToEmitOnSubscribe: [
                "serial": "01726585978590-001@abcdefghij:001",
                "roomId": "my-room",
                "clientId": "who-sent-the-message",
                "text": "my-message",
                "createdAt": "123456789",
                "metadata": [
                    "foo": [
                        "bar": 1,
                    ],
                ],
                "headers": [
                    "baz": "qux",
                ],
                "action": 4, // Summary
                "version": "01726585978590-001@abcdefghij:001",
                "timestamp": "123456789",
                "operation": [
                    "clientId": "who-performed-the-action",
                    "description": "why-the-action-was-performed",
                    "metadata": [
                        "foo": [
                            "bar": 1,
                        ],
                    ],
                ],
                "summary": [
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
            ]
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        defaultMessages.reactions.subscribe { event in
            // Then
            #expect(event.type == .summary)
            #expect(event.summary.unique["like"]?.total == 2)
            #expect(event.summary.unique["love"]?.total == 1)
            #expect(event.summary.distinct["like"]?.total == 2)
            #expect(event.summary.distinct["love"]?.total == 1)
            #expect(event.summary.multiple["like"]?.total == 5)
            #expect(event.summary.multiple["love"]?.total == 10)
        }
    }

    // @spec CHA-MR7
    @Test
    func subscribeToRawMessageReactions() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)

        let channel = MockRealtimeChannel(
            properties: .init(
                attachSerial: "001",
                channelSerial: "001"
            ),
            initialState: .attached,
            annotationJSONToEmitOnSubscribe: [
                "action": 0,
                "clientId": "U3BpZGVyd2Vi",
                "messageSerial": "0LHQtdC70YvQtSDRgNC+0LfRiw",
                "name": "🔥",
                "type": "reaction:multiple.v1",
                "count": 41,
            ]
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomID: "basketball", clientID: "clientId", logger: TestLogger())

        // When
        defaultMessages.reactions.subscribeRaw { event in
            // Then
            #expect(event.type == MessageReactionEvent.create)
            #expect(event.reaction.type == .multiple)
            #expect(event.reaction.name == "🔥")
            #expect(event.reaction.clientID == "U3BpZGVyd2Vi")
            #expect(event.reaction.messageSerial == "0LHQtdC70YvQtSDRgNC+0LfRiw")
            #expect(event.reaction.count == 41)
        }
    }
}
