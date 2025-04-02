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

    // @spec CHA-ER4
    @Test
    func subscribe_returnsSubscription() async throws {
        // all setup values here are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat::$reactions")
        let featureChannel = MockFeatureChannel(channel: channel)

        // When
        let defaultRoomReactions = DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let subscription: Subscription<Reaction>? = defaultRoomReactions.subscribe()

        // Then
        #expect(subscription != nil)
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
