import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultRoomReactionsTests {
    // @spec CHA-ER3d
    @Test
    func reactionsAreSentInTheCorrectFormat() async throws {
        // channel name and roomID values are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat")

        // When
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        let sendReactionParams = SendReactionParams(
            type: "like",
            metadata: ["someMetadataKey": "someMetadataValue"],
            headers: ["someHeadersKey": "someHeadersValue"]
        )

        // When
        try await defaultRoomReactions.send(params: sendReactionParams)

        // Then
        #expect(channel.publishedMessages.last?.name == RoomReactionEvents.reaction.rawValue)
        #expect(channel.publishedMessages.last?.data == ["type": "like", "metadata": ["someMetadataKey": "someMetadataValue"]])
        #expect(channel.publishedMessages.last?.extras == ["headers": ["someHeadersKey": "someHeadersValue"], "ephemeral": true])
    }

    // @spec CHA-ER4a
    // @spec CHA-ER4b
    @Test
    func subscriptionCanBeRegisteredToReceiveReactionEvents() async throws {
        // Given
        func generateMessage(serial: String, reactionType: String) -> ARTMessage {
            let message = ARTMessage()
            message.action = .create // arbitrary
            message.serial = serial // arbitrary
            message.clientId = "" // arbitrary
            message.data = [
                "type": reactionType,
            ]
            message.version = "0"
            return message
        }

        let channel = MockRealtimeChannel(
            messageToEmitOnSubscribe: generateMessage(serial: "1", reactionType: ":like:")
        )
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let subscriptionHandle = defaultRoomReactions.subscribe { reaction in
            // Then
            #expect(reaction.type == ":like:")
        }

        // CHA-ER4b
        subscriptionHandle.unsubscribe()

        // will not be received and expectations above will not fail
        channel.simulateIncomingMessage(
            generateMessage(serial: "2", reactionType: ":dislike:"),
            for: RoomReactionEvents.reaction.rawValue
        )
    }

    // CHA-ER4c is currently untestable due to not subscribing to those events on lower level
    // @spec CHA-ER4d
    @Test
    func malformedRealtimeEventsShallNotBeEmittedToSubscribers() async throws {
        // Given
        let channel = MockRealtimeChannel(
            messageJSONToEmitOnSubscribe: [
                "foo": "bar", // malformed reaction message
            ],
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                message.action = .create // arbitrary
                message.serial = "123" // arbitrary
                message.clientId = "" // arbitrary
                message.data = [
                    "type": ":like:",
                ]
                message.extras = [:] as any ARTJsonCompatible
                message.version = "0"
                return message
            }()
        )
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        defaultRoomReactions.subscribe { reaction in
            // Then: `messageJSONToEmitOnSubscribe` is processed ahead of `messageToEmitOnSubscribe` in the mock, but the first message is not the malformed one
            #expect(reaction.type == ":like:")
        }
    }
}
