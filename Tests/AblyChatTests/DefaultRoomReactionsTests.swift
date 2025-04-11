import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultRoomReactionsTests {
    // @spec CHA-ER3a
    @Test
    func reactionsAreSentInTheCorrectFormat() async throws {
        // channel name and roomID values are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat::$reactions")
        let featureChannel = MockFeatureChannel(channel: channel)

        // When
        let defaultRoomReactions = DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        let sendReactionParams = SendReactionParams(
            type: "like",
            metadata: ["someMetadataKey": "someMetadataValue"],
            headers: ["someHeadersKey": "someHeadersValue"]
        )

        // When
        try await defaultRoomReactions.send(params: sendReactionParams)

        // Then
        #expect(channel.lastMessagePublishedName == RoomReactionEvents.reaction.rawValue)
        #expect(channel.lastMessagePublishedData == ["type": "like", "metadata": ["someMetadataKey": "someMetadataValue"]])
        #expect(channel.lastMessagePublishedExtras == ["headers": ["someHeadersKey": "someHeadersValue"]])
    }

    // @spec CHA-ER4a
    @Test
    func subscriptionCanBeRegisteredToReceiveReactionEvents() async throws {
        // Given
        let channel = MockRealtimeChannel(
            messageJSONToEmitOnSubscribe: [
                "name": "roomReaction",
                "clientId": "who-sent-the-message",
                "data": [
                    "type": ":like:",
                    "metadata": [
                        "foo": "bar",
                    ],
                ],
                "timestamp": "1726232498871",
                "extras": [
                    "headers": [
                        "baz": "qux",
                    ],
                ],
            ] as? [String: any Sendable]
        )
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultRoomReactions = DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let reactionSubscription = defaultRoomReactions.subscribe()

        // Then
        let reaction = try #require(await reactionSubscription.first { @Sendable _ in true })
        #expect(reaction.type == ":like:")
    }

    // CHA-ER4c is currently untestable due to not subscribing to those events on lower level
    // @spec CHA-ER4d
    @Test
    func malformedRealtimeEventsShallNotBeEmittedToSubscribers() async throws {
        // Given
        let channel = MockRealtimeChannel(
            messageJSONToEmitOnSubscribe: [
                "foo": "bar" // malformed reaction message
            ],
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                message.action = .create // arbitrary
                message.serial = "123" // arbitrary
                message.clientId = "" // arbitrary
                message.data = [
                    "type": ":like:",
                ]
                message.extras = [:] as ARTJsonCompatible
                message.operation = nil
                message.version = ""
                message.timestamp = Date()
                return message
            }()
        )
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultRoomReactions = DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let subscription = defaultRoomReactions.subscribe()

        // Then: `messageJSONToEmitOnSubscribe` is processed ahead of `messageToEmitOnSubscribe` in the mock, but the first message is not the malformed one
        let reaction = try #require(await subscription.first { @Sendable _ in true })
        #expect(reaction.type == ":like:")
    }

    // @spec CHA-ER5
    @Test
    func onDiscontinuity() async throws {
        // all setup values here are arbitrary
        // Given: A DefaultRoomReactions instance
        let channel = MockRealtimeChannel()
        let featureChannel = MockFeatureChannel(channel: channel)
        let roomReactions = DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When: The feature channel emits a discontinuity through `onDiscontinuity`
        let featureChannelDiscontinuity = DiscontinuityEvent(error: ARTErrorInfo.createUnknownError() /* arbitrary */ )
        let messagesDiscontinuitySubscription = roomReactions.onDiscontinuity()
        featureChannel.emitDiscontinuity(featureChannelDiscontinuity)

        // Then: The DefaultRoomReactions instance emits this discontinuity through `onDiscontinuity`
        let messagesDiscontinuity = try #require(await messagesDiscontinuitySubscription.first { @Sendable _ in true })
        #expect(messagesDiscontinuity == featureChannelDiscontinuity)
    }
}
