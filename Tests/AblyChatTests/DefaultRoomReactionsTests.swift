import Ably
@testable import AblyChat
import Testing

struct DefaultRoomReactionsTests {
    // @spec CHA-ER1
    @Test
    func init_channelNameIsSetAsReactionsChannelName() async throws {
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat::$reactions")
        let featureChannel = MockFeatureChannel(channel: channel)

        // When
        let defaultRoomReactions = await DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // Then
        #expect(defaultRoomReactions.channel.name == "basketball::$chat::$reactions")
    }

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
            metadata: ["test": MetadataValue.string("test")],
            headers: ["test": HeadersValue.string("test")]
        )

        // When
        try await defaultRoomReactions.send(params: sendReactionParams)

        // Then
        #expect(channel.lastMessagePublishedName == RoomReactionEvents.reaction.rawValue)
        #expect(channel.lastMessagePublishedData as? [String: String] == sendReactionParams.asQueryItems())
        #expect(channel.lastMessagePublishedExtras as? Dictionary == ["headers": sendReactionParams.headers])
    }

    // @spec CHA-ER4
    @Test
    func subscribe_returnsSubscription() async throws {
        // all setup values here are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat::$reactions")
        let featureChannel = MockFeatureChannel(channel: channel)

        // When
        let defaultRoomReactions = await DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let subscription: Subscription<Reaction>? = await defaultRoomReactions.subscribe(bufferingPolicy: .unbounded)

        // Then
        #expect(subscription != nil)
    }

    // @spec CHA-ER5
    @Test
    func subscribeToDiscontinuities() async throws {
        // all setup values here are arbitrary
        // Given: A DefaultRoomReactions instance
        let channel = MockRealtimeChannel()
        let featureChannel = MockFeatureChannel(channel: channel)
        let roomReactions = await DefaultRoomReactions(featureChannel: featureChannel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When: The feature channel emits a discontinuity through `subscribeToDiscontinuities`
        let featureChannelDiscontinuity = DiscontinuityEvent(error: ARTErrorInfo.createUnknownError() /* arbitrary */ )
        let messagesDiscontinuitySubscription = await roomReactions.subscribeToDiscontinuities()
        await featureChannel.emitDiscontinuity(featureChannelDiscontinuity)

        // Then: The DefaultRoomReactions instance emits this discontinuity through `subscribeToDiscontinuities`
        let messagesDiscontinuity = try #require(await messagesDiscontinuitySubscription.first { _ in true })
        #expect(messagesDiscontinuity == featureChannelDiscontinuity)
    }
}
