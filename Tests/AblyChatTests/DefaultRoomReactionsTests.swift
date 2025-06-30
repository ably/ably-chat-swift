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

    // @spec CHA-ER4
    @Test
    func subscribe_returnsSubscription() async throws {
        // all setup values here are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat")

        // When
        let defaultRoomReactions = DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let subscription: SubscriptionAsyncSequence<Reaction>? = defaultRoomReactions.subscribe()

        // Then
        #expect(subscription != nil)
    }
}
