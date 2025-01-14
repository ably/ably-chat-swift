@testable import AblyChat
import Testing

struct DefaultChatClientTests {
    @Test
    func init_withoutClientOptions() {
        // Given: An instance of DefaultChatClient is created with nil clientOptions
        let client = DefaultChatClient(
            realtime: MockRealtime(createWrapperSDKProxyReturnValue: .init()),
            clientOptions: nil
        )

        // Then: It uses the default client options
        let defaultOptions = ClientOptions()
        #expect(client.clientOptions.isEqualForTestPurposes(defaultOptions))
    }

    @Test
    func test_realtime() {
        // Given: An instance of DefaultChatClient
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init())
        let options = ClientOptions()
        let client = DefaultChatClient(realtime: realtime, clientOptions: options)

        // Then: Its `realtime` property returns the client that was passed to the initializer (i.e. as opposed to the proxy client created by `createWrapperSDKProxy(with:)`
        #expect(client.realtime === realtime)
    }

    @Test
    func createsWrapperSDKProxyRealtimeClientWithAgents() throws {
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: .init())
        let options = ClientOptions()
        _ = DefaultChatClient(realtime: realtime, clientOptions: options)

        #expect(realtime.createWrapperSDKProxyOptionsArgument?.agents == ["chat-swift": AblyChat.version])
    }

    @Test
    func rooms() throws {
        // Given: An instance of DefaultChatClient
        let proxyClient = MockRealtime()
        let realtime = MockRealtime(createWrapperSDKProxyReturnValue: proxyClient)
        let options = ClientOptions()
        let client = DefaultChatClient(realtime: realtime, clientOptions: options)

        // Then: Its `rooms` property returns an instance of DefaultRooms with the wrapper SDK proxy realtime client and same client options
        let rooms = client.rooms

        let defaultRooms = try #require(rooms as? DefaultRooms<DefaultRoomFactory>)
        #expect(defaultRooms.testsOnly_realtime === proxyClient)
        #expect(defaultRooms.clientOptions.isEqualForTestPurposes(options))
    }
}
