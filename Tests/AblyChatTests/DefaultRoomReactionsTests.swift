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
            headers: ["someHeadersKey": "someHeadersValue"],
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
        func generateMessage(serial: String, reaction: String) -> ARTMessage {
            let message = ARTMessage()
            message.action = .create // arbitrary
            message.serial = serial // arbitrary
            message.clientId = "" // arbitrary
            message.data = [
                "name": reaction,
            ]
            message.version = .init(serial: "0")
            message.extras = [String: String]() as (any ARTJsonCompatible)
            return message
        }

        let channel = MockRealtimeChannel(
            messageToEmitOnSubscribe: generateMessage(serial: "1", reaction: ":like:"),
        )
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomName: "basketball", logger: TestLogger())

        // When
        var callbackCalls = 0
        let subscription = defaultRoomReactions.subscribe { event in
            // Then
            #expect(event.reaction.name == ":like:")
            callbackCalls += 1
        }
        #expect(callbackCalls == 1)

        // CHA-ER4b
        subscription.unsubscribe()

        // will not be received (because unsubscribed) and expectations above will not fail
        channel.simulateIncomingMessage(
            generateMessage(serial: "2", reaction: ":dislike:"),
            for: RoomReactionEvents.reaction.rawValue,
        )
    }

    // CHA-ER4c is currently untestable due to not subscribing to those events on lower level
    // @spec CHA-ER4e
    // @spec CHA-ER4e1
    // @spec CHA-ER4e2
    // @spec CHA-ER4e3
    // @spec CHA-ER4e4
    @Test
    func malformedEventsWithIncompleteDataStillEmittedWithDefaultValues() async throws {
        // Given
        let channel = MockRealtimeChannel(
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                message.action = .create // arbitrary
                message.name = "roomReaction"
                message.serial = "123" // arbitrary
                message.clientId = "c1" // arbitrary
                message.data = [
                    "name": ":like:", // arbitrary
                    "metadata": ["someKey1": "someValue1"], // arbitrary
                ]
                message.extras = [
                    "headers": ["someKey2": "someValue2"], // arbitrary
                ] as any ARTJsonCompatible
                message.timestamp = Date(timeIntervalSinceReferenceDate: 0) // arbitrary
                return message
            }(),
        )
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomName: "basketball", logger: TestLogger())

        // When
        let ts = Date()
        var callbackCalls = 0
        defaultRoomReactions.subscribe { event in
            #expect(event.type == .reaction)
            // Then
            if callbackCalls == 0 {
                #expect(event.reaction.name == ":like:")
                #expect(event.reaction.clientID == "c1")
                #expect(event.reaction.metadata == ["someKey1": "someValue1"])
                #expect(event.reaction.headers == ["someKey2": "someValue2"])
                #expect(event.reaction.createdAt == Date(timeIntervalSinceReferenceDate: 0))
            } else {
                #expect(event.reaction.name.isEmpty)
                #expect(event.reaction.clientID.isEmpty)
                #expect(event.reaction.metadata.isEmpty)
                #expect(event.reaction.headers.isEmpty)
                #expect(event.reaction.createdAt.timeIntervalSince(ts) < 1.0)
            }
            callbackCalls += 1
        }
        channel.simulateIncomingMessage(
            ARTMessage(), // malformed message
            for: RoomReactionEvents.reaction.rawValue,
        )
        #expect(callbackCalls == 2)
    }
}
