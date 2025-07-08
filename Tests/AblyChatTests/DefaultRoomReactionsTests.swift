import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultRoomReactionsTests {
    // @spec CHA-ER3d
    @Test
    func reactionsAreSentInTheCorrectFormat() async throws {
        // channel name and roomName values are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat")

        // When
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomName: "basketball", logger: TestLogger())

        let sendReactionParams = SendReactionParams(
            name: "like",
            metadata: ["someMetadataKey": "someMetadataValue"],
            headers: ["someHeadersKey": "someHeadersValue"]
        )

        // When
        try await defaultRoomReactions.send(params: sendReactionParams)

        // Then
        #expect(channel.publishedMessages.last?.name == RoomReactionEvents.reaction.rawValue)
        #expect(channel.publishedMessages.last?.data == ["name": "like", "metadata": ["someMetadataKey": "someMetadataValue"]])
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
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomName: "basketball", logger: TestLogger())

        // When
        let subscription = defaultRoomReactions.subscribe { event in
            // Then
            #expect(event.reaction.name == ":like:")
        }

        // CHA-ER4b
        subscription.unsubscribe()

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
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomName: "basketball", logger: TestLogger())

        // When
        defaultRoomReactions.subscribe { event in
            #expect(event.reaction.name == ":like:")
        }
        // will not be received and expectations above will not fail
        channel.simulateIncomingMessage(
            ARTMessage(), // malformed message
            for: RealtimeMessageName.chatMessage.rawValue
        )
    }
}
