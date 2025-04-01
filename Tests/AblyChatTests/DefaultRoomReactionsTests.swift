import Ably
@testable import AblyChat
import Testing

struct DefaultRoomReactionsTests {
    // @spec CHA-ER3d
    @Test
    func reactionsAreSentInTheCorrectFormat() async throws {
        // channel name and roomID values are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat")

        // When
        let defaultRoomReactions = await DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

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
        #expect(await channel.lastMessagePublishedExtras == ["headers": ["someHeadersKey": "someHeadersValue"], "ephemeral": true])
    }

    // @spec CHA-ER4
    @Test
    func subscribe_returnsSubscription() async throws {
        // all setup values here are arbitrary
        // Given
        let channel = MockRealtimeChannel(name: "basketball::$chat")

        // When
        let defaultRoomReactions = await DefaultRoomReactions(channel: channel, clientID: "mockClientId", roomID: "basketball", logger: TestLogger())

        // When
        let subscription: Subscription<Reaction>? = await defaultRoomReactions.subscribe()

        // Then
        #expect(subscription != nil)
    }
}
