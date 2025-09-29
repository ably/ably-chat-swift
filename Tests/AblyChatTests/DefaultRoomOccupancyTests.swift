import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultRoomOccupancyTests {
    // @spec CHA-O3
    // @spec CHA-O7b
    @Test
    func occupancyGet() async throws {
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
            options: .init(enableEvents: true)
        )

        // When
        let occupancyInfo = try await defaultOccupancy.get()

        // Then
        #expect(occupancyInfo.connections == 5)
        #expect(occupancyInfo.presenceMembers == 2)

        let currentOccupancy = try defaultOccupancy.current()
        #expect(currentOccupancy == nil)
    }

    // @specUntested CHA-O4e - We chose to implement this failure with an idiomatic fatalError instead of throwing, but we can’t test this.

    // @spec CHA-O4a
    // @spec CHA-O4c
    // @spec CHA-O7a
    @Test
    func usersCanSubscribeToRealtimeOccupancyUpdates() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            name: "basketball::$chat",
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                message.action = .create // arbitrary
                message.serial = "" // arbitrary
                message.clientId = "" // arbitrary
                message.data = [
                    "metrics": [
                        "connections": 5, // arbitrary
                        "presenceMembers": 2, // arbitrary
                    ],
                ]
                message.version = .init(serial: "0") // arbitrary
                return message
            }()
        )
        let defaultOccupancy = DefaultOccupancy(
            channel: channel,
            chatAPI: chatAPI,
            roomName: "basketball",
            logger: TestLogger(),
            options: .init(enableEvents: true)
        )

        // CHA-O4a, CHA-O4c, CHA-O7a

        // When
        let subscription = defaultOccupancy.subscribe()

        // Then
        let occupancyEvent = try #require(await subscription.first { @Sendable _ in true })
        #expect(occupancyEvent.occupancy.connections == 5)
        #expect(occupancyEvent.occupancy.presenceMembers == 2)

        let currentOccupancy = try defaultOccupancy.current()
        #expect(currentOccupancy?.connections == 5)
        #expect(currentOccupancy?.presenceMembers == 2)
    }

    // @spec CHA-O4g
    @Test
    func ifInvalidOccupancyEventReceivedItMustBeEmittedWithZeroValues() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(
            name: "basketball::$chat",
            messageToEmitOnSubscribe: {
                let message = ARTMessage()
                return message
            }()
        )
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

        // Then
        let occupancyEvent = try #require(await subscription.first { @Sendable _ in true })
        #expect(occupancyEvent.occupancy.connections == 0)
        #expect(occupancyEvent.occupancy.presenceMembers == 0)
    }

    // @spec CHA-O7c
    @Test
    func occupancyCurrentThrowsError() async throws {
        // Given
        let realtime = MockRealtime()
        let chatAPI = ChatAPI(realtime: realtime)
        let channel = MockRealtimeChannel(name: "basketball::$chat")
        let defaultOccupancy = DefaultOccupancy(
            channel: channel,
            chatAPI: chatAPI,
            roomName: "basketball",
            logger: TestLogger(),
            // Wnen
            options: .init() // enableEvents: false
        )

        // Then
        // TODO: avoids compiler crash (https://github.com/ably/ably-chat-swift/issues/233), revert once Xcode 16.3 released
        let doIt = {
            _ = try defaultOccupancy.current()
        }
        await #expect {
            try await doIt()
        } throws: { error in
            error as? ARTErrorInfo == ARTErrorInfo(chatError: .occupancyEventsNotEnabled)
        }
    }
}
