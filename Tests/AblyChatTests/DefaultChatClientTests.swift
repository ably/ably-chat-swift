@testable import AblyChat
import Testing

struct DefaultChatClientTests {
    @Test
    func init_withoutClientOptions() {
        // Given: An instance of DefaultChatClient is created with nil clientOptions
        let client = DefaultChatClient(realtime: MockRealtime.create(), clientOptions: nil)

        // Then: It uses the default client options
        let defaultOptions = ClientOptions()
        #expect(client.clientOptions.isEqualForTestPurposes(defaultOptions))
    }

    @Test
    func rooms() throws {
        // Given: An instance of DefaultChatClient
        let realtime = MockRealtime.create()
        let options = ClientOptions()
        let client = DefaultChatClient(realtime: realtime, clientOptions: options)

        // Then: Its `rooms` property returns an instance of DefaultRooms with the same realtime client and client options
        let rooms = client.rooms

        let defaultRooms = try #require(rooms as? DefaultRooms<DefaultRoomLifecycleManagerFactory>)
        #expect(defaultRooms.testsOnly_realtime === realtime)
        #expect(defaultRooms.clientOptions.isEqualForTestPurposes(options))
    }
}
