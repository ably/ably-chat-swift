import AblyChat
import Testing

struct RoomOptionsTests {
    // @spec CHA-PR9c1
    @Test
    func defaultValue_presence_receivePresenceEvents() async throws {
        #expect(RoomOptions().presence.receivePresenceEvents)
    }

    // @spec CHA-O6c
    @Test
    func defaultValue_occupancy_enableInboundOccupancy() async throws {
        #expect(!RoomOptions().occupancy.enableInboundOccupancy)
    }
}
