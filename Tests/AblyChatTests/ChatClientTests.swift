import Ably
@testable import AblyChat
import Testing

@MainActor
struct ChatClientTests {
    @Test
    func init_withoutClientOptions() {
        // Given: An instance of ChatClient is created with nil clientOptions
        let proxyClient = MockConcreteAblyCocoaRealtime.ProxyHelper.createProxy()
        let internalRealtime = InternalRealtimeClientAdapter(underlying: proxyClient)
        let client = ChatClient(
            realtime: MockConcreteAblyCocoaRealtime(createWrapperSDKProxyReturnValue: proxyClient),
            clientOptions: nil,
            internalRealtimeClientFactory: MockInternalRealtimeClientFactory(createInternalRealtimeClientReturnValue: internalRealtime),
        )

        // Then: It uses the default client options
        let defaultOptions = ChatClientOptions()
        #expect(client.clientOptions.isEqualForTestPurposes(defaultOptions))
    }

    @Test
    func test_realtime() {
        // Given: An instance of ChatClient
        let proxyClient = MockConcreteAblyCocoaRealtime.ProxyHelper.createProxy()
        let realtime = MockConcreteAblyCocoaRealtime(createWrapperSDKProxyReturnValue: proxyClient)
        let internalRealtime = InternalRealtimeClientAdapter(underlying: proxyClient)
        let options = ChatClientOptions()
        let client = ChatClient(
            realtime: realtime,
            clientOptions: options,
            internalRealtimeClientFactory: MockInternalRealtimeClientFactory(createInternalRealtimeClientReturnValue: internalRealtime),
        )

        // Then: Its `realtime` property returns the client that was passed to the initializer (i.e. as opposed to the proxy client created by `createWrapperSDKProxy(with:)`
        #expect(client.realtime === realtime)
    }

    @Test
    func preservesStaticTypeInformation() {
        // This test doesn't have any assertions; it's just to test that the type system gives you ARTRealtime and ARTRealtimeChannel
        func withChatClient(_ chatClient: ChatClient) async throws {
            let _: ARTRealtime = chatClient.realtime
            let room = try await chatClient.rooms.get(name: "room")
            let _: ARTRealtimeChannel = room.channel
        }
    }

    // @spec CHA-IN1a
    // @spec CHA-IN1b
    @Test
    func createsWrapperSDKProxyRealtimeClientWithAgents() throws {
        let proxyClient = MockConcreteAblyCocoaRealtime.ProxyHelper.createProxy()
        let realtime = MockConcreteAblyCocoaRealtime(createWrapperSDKProxyReturnValue: proxyClient)
        let internalRealtine = InternalRealtimeClientAdapter(underlying: proxyClient)
        let options = ChatClientOptions()
        _ = ChatClient(
            realtime: realtime,
            clientOptions: options,
            internalRealtimeClientFactory: MockInternalRealtimeClientFactory(createInternalRealtimeClientReturnValue: internalRealtine),
        )

        #expect(realtime.createWrapperSDKProxyOptionsArgument?.agents == ["chat-swift": AblyChat.version])
    }

    // @spec CHA-IN1d
    @Test
    func rooms() throws {
        // Given: An instance of ChatClient
        let proxyClient = MockConcreteAblyCocoaRealtime.ProxyHelper.createProxy()
        let realtime = MockConcreteAblyCocoaRealtime(createWrapperSDKProxyReturnValue: proxyClient)
        let internalRealtime = InternalRealtimeClientAdapter(underlying: proxyClient)
        let internalRealtimeClientFactory = MockInternalRealtimeClientFactory(createInternalRealtimeClientReturnValue: internalRealtime)
        let options = ChatClientOptions()
        let client = ChatClient(
            realtime: realtime,
            clientOptions: options,
            internalRealtimeClientFactory: internalRealtimeClientFactory,
        )

        // Then: Its `rooms` property returns an instance of DefaultRooms with the wrapper SDK proxy realtime client and same client options
        #expect(internalRealtimeClientFactory.createInternalRealtimeClientArgument === proxyClient)

        let rooms = client.rooms

        let defaultRooms = try #require(rooms as? DefaultRooms<DefaultRoomFactory<InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime>>>)
        #expect(defaultRooms.testsOnly_realtime === internalRealtime)
        #expect(defaultRooms.clientOptions.isEqualForTestPurposes(options))
    }
}
