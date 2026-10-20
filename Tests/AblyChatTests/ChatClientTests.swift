@testable import AblyChat
import AblyPubSubDevice
import Testing

@MainActor
struct ChatClientTests {
    @Test
    func init_withoutClientOptions() {
        // Given: An instance of ChatClient is created with nil clientOptions
        let proxyClient = MockConcreteAblyCocoaPubSubClient.ProxyHelper.createProxy()
        let internalPubSubClient = InternalPubSubClientAdapter(underlying: proxyClient)
        let client = ChatClient(
            pubSubClient: MockConcreteAblyCocoaPubSubClient(createWrapperSDKProxyReturnValue: proxyClient),
            clientOptions: nil,
            internalPubSubClientFactory: MockInternalPubSubClientFactory(createInternalPubSubClientReturnValue: internalPubSubClient),
        )

        // Then: It uses the default client options
        let defaultOptions = ChatClientOptions()
        #expect(client.clientOptions.isEqualForTestPurposes(defaultOptions))
    }

    @Test
    func test_pubSubClient() {
        // Given: An instance of ChatClient
        let proxyClient = MockConcreteAblyCocoaPubSubClient.ProxyHelper.createProxy()
        let pubSubClient = MockConcreteAblyCocoaPubSubClient(createWrapperSDKProxyReturnValue: proxyClient)
        let internalPubSubClient = InternalPubSubClientAdapter(underlying: proxyClient)
        let options = ChatClientOptions()
        let client = ChatClient(
            pubSubClient: pubSubClient,
            clientOptions: options,
            internalPubSubClientFactory: MockInternalPubSubClientFactory(createInternalPubSubClientReturnValue: internalPubSubClient),
        )

        // Then: Its `pubSubClient` property returns the client that was passed to the initializer (i.e. as opposed to the proxy client created by `createWrapperSDKProxy(with:)`
        #expect(client.pubSubClient === pubSubClient)
    }

    @Test
    func preservesStaticTypeInformation() {
        // This test doesn't have any assertions; it's just to test that the type system gives you PubSubClient and RealtimeChannel

        func withChatClient(_ chatClient: ChatClient) async throws {
            let _: PubSubClient = chatClient.pubSubClient
            let room = try await chatClient.rooms.get(named: "room")
            let _: RealtimeChannel = room.channel
        }

        @available(iOS 16.0, tvOS 16.0, *)
        func usingExistentials(_ chatClient: ChatClient) async throws {
            // The compiler won't let you write `[some Room<RealtimeChannel>]` here, which I guess isn't a surprise.
            // Nor will it let you write `[ChatClient.Rooms.Room]`, which surprised me.
            // But luckily we can still use existentials.
            var rooms: [any Room<RealtimeChannel>] = []
            for roomName in ["foo", "bar"] {
                try await rooms.append(chatClient.rooms.get(named: roomName))
            }

            // This crashes the compiler! (https://github.com/swiftlang/swift/issues/84744)
            // let _: [RealtimeChannel] = rooms.map(\.channel)

            // Whereas this, which is functionally the same thing, does not.
            // swiftformat:disable:next preferKeyPath
            let _: [RealtimeChannel] = rooms.map { $0.channel }

            // Nor this.
            var realtimeChannels: [RealtimeChannel] = []
            for room in rooms {
                realtimeChannels.append(room.channel)
            }
        }
    }

    // @spec CHA-IN1a
    // @spec CHA-IN1b
    @Test
    func createsWrapperSDKProxyPubSubClientWithAgents() throws {
        let proxyClient = MockConcreteAblyCocoaPubSubClient.ProxyHelper.createProxy()
        let pubSubClient = MockConcreteAblyCocoaPubSubClient(createWrapperSDKProxyReturnValue: proxyClient)
        let internalRealtine = InternalPubSubClientAdapter(underlying: proxyClient)
        let options = ChatClientOptions()
        _ = ChatClient(
            pubSubClient: pubSubClient,
            clientOptions: options,
            internalPubSubClientFactory: MockInternalPubSubClientFactory(createInternalPubSubClientReturnValue: internalRealtine),
        )

        #expect(pubSubClient.createWrapperSDKProxyOptionsArgument?.agents == ["chat-swift": ClientInformation.version])
    }

    // @spec CHA-IN1d
    @Test
    func rooms() throws {
        // Given: An instance of ChatClient
        let proxyClient = MockConcreteAblyCocoaPubSubClient.ProxyHelper.createProxy()
        let pubSubClient = MockConcreteAblyCocoaPubSubClient(createWrapperSDKProxyReturnValue: proxyClient)
        let internalPubSubClient = InternalPubSubClientAdapter(underlying: proxyClient)
        let internalPubSubClientFactory = MockInternalPubSubClientFactory(createInternalPubSubClientReturnValue: internalPubSubClient)
        let options = ChatClientOptions()
        let client = ChatClient(
            pubSubClient: pubSubClient,
            clientOptions: options,
            internalPubSubClientFactory: internalPubSubClientFactory,
        )

        // Then: Its `rooms` property returns an instance of DefaultRooms with the wrapper SDK proxy Pub/Sub client
        #expect(internalPubSubClientFactory.createInternalPubSubClientArgument === proxyClient)

        let rooms = client.rooms

        let defaultRooms = try #require(rooms as? DefaultRooms<DefaultRoomFactory<InternalPubSubClientAdapter<WrapperSDKProxyRealtime>>>)
        #expect(defaultRooms.testsOnly_pubSubClient === internalPubSubClient)
    }
}
