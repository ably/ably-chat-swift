import Ably
@testable import AblyChat
import Testing

@MainActor
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
        let channel = MockRealtimeChannel(name: "basketball::$chat")
        let defaultOccupancy = DefaultOccupancy(
            channel: channel,
            chatAPI: chatAPI,
            roomName: "basketball",
            logger: TestLogger(),
            options: .init()
        )

        // When
        let occupancyInfo = try await defaultOccupancy.get()

        // Then
        #expect(occupancyInfo.connections == 5)
        #expect(occupancyInfo.presenceMembers == 2)
    }

    // @specUntested CHA-O4e - We chose to implement this failure with an idiomatic fatalError instead of throwing, but we can’t test this.

    // @spec CHA-O4a
    // @spec CHA-O4c
    @Test
    func usersCanSubscribeToRealtimeOccupancyUpdates() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(name: "basketball::$chat")
        let defaultOccupancy = DefaultOccupancy(
            channel: channel,
            chatAPI: chatAPI,
            roomName: "basketball",
            logger: TestLogger(),
            options: .init(enableEvents: true)
        )

        // CHA-O4a, CHA-O4c

        // When
        let subscription = defaultOccupancy.subscribe()
        let occupancyData = OccupancyData(connections: 5, presenceMembers: 2)
        subscription.emit(OccupancyEvent(type: .updated, occupancy: occupancyData))

        // Then
        let occupancyEvent = try #require(await subscription.first { @Sendable _ in true })
        #expect(occupancyEvent.occupancy.connections == 5)
        #expect(occupancyEvent.occupancy.presenceMembers == 2)
    }
}
