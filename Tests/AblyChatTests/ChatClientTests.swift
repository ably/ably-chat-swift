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

        @available(iOS 16.0, tvOS 16.0, *)
        func usingExistentials(_ chatClient: ChatClient) async throws {
            // The compiler won't let you write `[some Room<ARTRealtimeChannel>]` here, which I guess isn't a surprise.
            // Nor will it let you write `[ChatClient.Rooms.Room]`, which surprised me.
            // But luckily we can still use existentials.
            var rooms: [any Room<ARTRealtimeChannel>] = []
            for roomName in ["foo", "bar"] {
                try await rooms.append(chatClient.rooms.get(name: roomName))
            }

            // This crashes the compiler! (https://github.com/swiftlang/swift/issues/84744)
            // let _: [ARTRealtimeChannel] = rooms.map(\.channel)

            // Whereas this, which is functionally the same thing, does not.
            // swiftformat:disable:next preferKeyPath
            let _: [ARTRealtimeChannel] = rooms.map { $0.channel }

            // Nor this.
            var realtimeChannels: [ARTRealtimeChannel] = []
            for room in rooms {
                realtimeChannels.append(room.channel)
            }
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

        #expect(realtime.createWrapperSDKProxyOptionsArgument?.agents == ["chat-swift": ClientInformation.version])
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

        // Then: Its `rooms` property returns an instance of DefaultRooms with the wrapper SDK proxy realtime client
        #expect(internalRealtimeClientFactory.createInternalRealtimeClientArgument === proxyClient)

        let rooms = client.rooms

        let defaultRooms = try #require(rooms as? DefaultRooms<DefaultRoomFactory<InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime>>>)
        #expect(defaultRooms.testsOnly_realtime === internalRealtime)
    }
}
