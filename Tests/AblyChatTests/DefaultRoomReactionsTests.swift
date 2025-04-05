import Ably
@testable import AblyChat
import Testing

struct DefaultRoomReactionsTests {
    // @spec CHA-ER3a
    @Test
    func reactionsAreSentInTheCorrectFormat() async throws {
        // channel name and roomID values are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat::$reactions")
        let featureChannel = MockFeatureChannel(channel: channel)

        // When
        let defaultRoomReactions = await DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        let sendReactionParams = SendReactionParams(
            type: "like",
            metadata: ["someMetadataKey": "someMetadataValue"],
            headers: ["someHeadersKey": "someHeadersValue"]
        )

        // When
        try await defaultRoomReactions.send(params: sendReactionParams)

        // Then
        #expect(await channel.lastMessagePublishedName == RoomReactionEvents.reaction.rawValue)
        #expect(await channel.lastMessagePublishedData == ["type": "like", "metadata": ["someMetadataKey": "someMetadataValue"]])
        #expect(await channel.lastMessagePublishedExtras == ["headers": ["someHeadersKey": "someHeadersValue"]])
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
        let defaultRoomReactions = await DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let reactionSubscription = await defaultRoomReactions.subscribe()

        // Then
        let reaction = try #require(await reactionSubscription.first { _ in true })
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
            messageToEmitOnSubscribe: .init(
                action: .create,
                serial: "123",
                clientID: "",
                data: [
                    "type": ":like:",
                ],
                extras: [:],
                version: "0",
                timestamp: Date()
            )
        )
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultRoomReactions = await DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let subscription = await defaultRoomReactions.subscribe()

        // Then: `messageJSONToEmitOnSubscribe` is processed ahead of `messageToEmitOnSubscribe` in the mock, but the first message is not the malformed one
        let reaction = try #require(await subscription.first { _ in true })
        #expect(reaction.type == ":like:")
    }

    // @spec CHA-ER5
    @Test
    func onDiscontinuity() async throws {
        // all setup values here are arbitrary
        // Given: A DefaultRoomReactions instance
        let channel = MockRealtimeChannel()
        let featureChannel = MockFeatureChannel(channel: channel)
        let roomReactions = await DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When: The feature channel emits a discontinuity through `onDiscontinuity`
        let featureChannelDiscontinuity = DiscontinuityEvent(error: ARTErrorInfo.createUnknownError() /* arbitrary */ )
        let messagesDiscontinuitySubscription = await roomReactions.onDiscontinuity()
        await featureChannel.emitDiscontinuity(featureChannelDiscontinuity)

        // Then: The DefaultRoomReactions instance emits this discontinuity through `onDiscontinuity`
        let messagesDiscontinuity = try #require(await messagesDiscontinuitySubscription.first { _ in true })
        #expect(messagesDiscontinuity == featureChannelDiscontinuity)
    }
}
