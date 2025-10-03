@testable import AblyChat
import Testing

@MainActor
struct DefaultChatClientTests {
    @Test
    func init_withoutClientOptions() {
        // Given: An instance of DefaultChatClient is created with nil clientOptions
        let client = DefaultChatClient(
            realtime: MockSuppliedRealtime(createWrapperSDKProxyReturnValue: .init()),
            clientOptions: nil,
            internalRealtimeClientFactory: MockInternalRealtimeClientFactory(createInternalRealtimeClientReturnValue: MockRealtime()),
        )

        // Then: It uses the default client options
        let defaultOptions = ChatClientOptions()
        #expect(client.clientOptions.isEqualForTestPurposes(defaultOptions))
    }

    @Test
    func test_realtime() {
        // Given: An instance of DefaultChatClient
        let realtime = MockSuppliedRealtime(createWrapperSDKProxyReturnValue: .init())
        let options = ChatClientOptions()
        let client = DefaultChatClient(
            realtime: realtime,
            clientOptions: options,
            internalRealtimeClientFactory: MockInternalRealtimeClientFactory(createInternalRealtimeClientReturnValue: MockRealtime()),
        )

        // Then: Its `realtime` property returns the client that was passed to the initializer (i.e. as opposed to the proxy client created by `createWrapperSDKProxy(with:)`
        #expect(client.realtime === realtime)
    }

    // @spec CHA-IN1a
    // @spec CHA-IN1b
    @Test
    func createsWrapperSDKProxyRealtimeClientWithAgents() throws {
        let realtime = MockSuppliedRealtime(createWrapperSDKProxyReturnValue: .init())
        let options = ChatClientOptions()
        _ = DefaultChatClient(
            realtime: realtime,
            clientOptions: options,
            internalRealtimeClientFactory: MockInternalRealtimeClientFactory(createInternalRealtimeClientReturnValue: MockRealtime()),
        )

        #expect(realtime.createWrapperSDKProxyOptionsArgument?.agents == ["chat-swift": AblyChat.version])
    }

    // @spec CHA-IN1d
    @Test
    func rooms() throws {
        // Given: An instance of DefaultChatClient
        let proxyClient = MockSuppliedRealtime()
        let realtime = MockSuppliedRealtime(createWrapperSDKProxyReturnValue: proxyClient)
        let internalRealtime = MockRealtime()
        let internalRealtimeClientFactory = MockInternalRealtimeClientFactory(createInternalRealtimeClientReturnValue: internalRealtime)
        let options = ChatClientOptions()
        let client = DefaultChatClient(
            realtime: realtime,
            clientOptions: options,
            internalRealtimeClientFactory: internalRealtimeClientFactory,
        )

        // Then: Its `rooms` property returns an instance of DefaultRooms with the wrapper SDK proxy realtime client and same client options
        #expect(internalRealtimeClientFactory.createInternalRealtimeClientArgument === proxyClient)

        let rooms = client.rooms

        let defaultRooms = try #require(rooms as? DefaultRooms<DefaultRoomFactory>)
        #expect(defaultRooms.testsOnly_realtime === internalRealtime)
        #expect(defaultRooms.clientOptions.isEqualForTestPurposes(options))
    }
}
