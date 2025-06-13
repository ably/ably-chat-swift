import AblyChat
import Testing

struct RoomOptionsTests {
    // @spec CHA-PR9c1
    @Test
    func defaultValue_presence_enableEvents() async throws {
        #expect(RoomOptions().presence.enableEvents)
    }

    // @spec CHA-O6c
    @Test
    func defaultValue_occupancy_enableEvents() async throws {
        #expect(!RoomOptions().occupancy.enableEvents)
    }
}
