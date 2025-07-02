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
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                message.serial = "001"
                message.action = .messageSummary
                message.summary = [
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
                ]
                return message
            }()
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

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
                extras: nil
            )
        )
        let defaultMessages = DefaultMessages(channel: channel, chatAPI: chatAPI, roomName: "basketball", clientID: "clientId", logger: TestLogger())

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
