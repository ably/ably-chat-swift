import Ably
@testable import AblyChat
import Testing

struct DefaultRoomOccupancyTests {
    // @spec CHA-O3
    @Test
    func requestOccupancyCheck() async throws {
        // Given
        let realtime = MockRealtime {
            MockHTTPPaginatedResponse(
                items: [
                    [
                        "connections": 5,
                        "presenceMembers": 2,
                    ],
                ]
            )
        }
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultOccupancy = DefaultOccupancy(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", logger: TestLogger())

        // When
        let occupancyInfo = try await defaultOccupancy.get()

        // Then
        #expect(occupancyInfo.connections == 5)
        #expect(occupancyInfo.presenceMembers == 2)
    }

    // @spec CHA-O4a
    // @spec CHA-O4c
    @Test
    func usersCanSubscribeToRealtimeOccupancyUpdates() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(name: "basketball::$chat::$chatMessages")
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultOccupancy = DefaultOccupancy(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", logger: TestLogger())

        // CHA-O4a, CHA-O4c

        // When
        let subscription = await defaultOccupancy.subscribe()
        subscription.emit(OccupancyEvent(connections: 5, presenceMembers: 2))

        // Then
        let occupancyInfo = try #require(await subscription.first { _ in true })
        #expect(occupancyInfo.connections == 5)
        #expect(occupancyInfo.presenceMembers == 2)
    }

    // @spec CHA-O5
    @Test
    func onDiscontinuity() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel()
        let featureChannel = MockFeatureChannel(channel: channel)
        let defaultOccupancy = DefaultOccupancy(featureChannel: featureChannel, chatAPI: chatAPI, roomID: "basketball", logger: TestLogger())

        // When: The feature channel emits a discontinuity through `onDiscontinuity`
        let featureChannelDiscontinuity = DiscontinuityEvent(error: ARTErrorInfo.createUnknownError()) // arbitrary error
        let discontinuitySubscription = await defaultOccupancy.onDiscontinuity()
        await featureChannel.emitDiscontinuity(featureChannelDiscontinuity)

        // Then: The DefaultOccupancy instance emits this discontinuity through `onDiscontinuity`
        let discontinuity = try #require(await discontinuitySubscription.first { _ in true })
        #expect(discontinuity == featureChannelDiscontinuity)
    }
}
