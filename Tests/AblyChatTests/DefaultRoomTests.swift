import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultRoomTests {
    // MARK: - Retrieving underlying channel

    @Test
    func channel() async throws {
        // Given: a DefaultRoom instance
        let channel = MockRealtimeChannel(name: "basketball::$chat")
        let channels = MockChannels(channels: [channel])
        let realtime = MockRealtime(channels: channels)
        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: Its `channel` property returns the user-facing ably-cocoa channel (i.e. as opposed to the proxy client created by `createWrapperSDKProxy(with:)` that the SDK uses internally)
        #expect(room.channel === channel.proxied)
    }

    // MARK: - Fetching channels

    // @spec CHA-RC3c
    @Test
    func channelName() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then
        #expect(room.testsOnly_internalChannel.name == "basketball::$chat")
    }

    // @spec CHA-GP2a
    @Test
    func disablesImplicitAttach() async throws {
        // Given: A DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: When it fetches a channel, it does so with the `attachOnSubscribe` channel option set to false
        let channelsGetArguments = channels.getArguments
        #expect(!channelsGetArguments.isEmpty)
        #expect(channelsGetArguments.allSatisfy { $0.options.attachOnSubscribe == false })
    }

    // @spec CHA-RC3a
    @Test
    func fetchesChannelOnce() async throws {
        // Given: A DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let roomOptions = RoomOptions(presence: .init(enableEvents: false), occupancy: .init(enableEvents: true))
        let realtime = MockRealtime(channels: channels)
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: It fetches the …$chat channel only once, and the options with which it does so are the result of merging the options used by the presence feature and those used by the occupancy feature
        let channelsGetArguments = channels.getArguments
        #expect(channelsGetArguments.map(\.name).sorted() == ["basketball::$chat"])

        let chatMessagesChannelGetOptions = try #require(channelsGetArguments.first { $0.name == "basketball::$chat" }?.options)
        #expect(chatMessagesChannelGetOptions.params?["occupancy"] == "metrics")
        #expect(chatMessagesChannelGetOptions.modes == [.publish, .subscribe, .presence, .annotationPublish])
    }

    // @spec CHA-O6a
    // @spec CHA-O6b
    @Test(arguments:
        [
            (
                enableEvents: true,
                expectedOccupancyChannelParam: "metrics",
            ),
            (
                enableEvents: false,
                expectedOccupancyChannelParam: nil,
            ),
        ])
    func occupancyEnableEvents(enableEvents: Bool, expectedOccupancyChannelParam: String?) async throws {
        // Given: A DefaultRoom instance, with the occupancy.enableEvents room option set per the test argument
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let roomOptions = RoomOptions(occupancy: .init(enableEvents: enableEvents))
        let realtime = MockRealtime(channels: channels)
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: When fetching the realtime channel, it sets the "occupancy" channel param accordingly
        let chatMessagesChannelGetOptions = try #require(channels.getArguments.first?.options)
        #expect(chatMessagesChannelGetOptions.params?["occupancy"] == expectedOccupancyChannelParam)
    }

    // @spec CHA-PR9c2
    @Test(arguments:
        [
            (
                enableEvents: true,
                // i.e. it doesn't explicitly set any modes (so that Realtime will use the default modes)
                expectedChannelModes: [.publish, .subscribe, .presence, .annotationPublish, .presenceSubscribe] as ARTChannelMode,
            ),
            (
                enableEvents: false,
                expectedChannelModes: [.publish, .subscribe, .presence, .annotationPublish] as ARTChannelMode,
            ),
        ])
    func presenceEnableEvents(enableEvents: Bool, expectedChannelModes: ARTChannelMode) async throws {
        // Given: A DefaultRoom instance, with the presence.enableEvents room option set per the test argument
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let roomOptions = RoomOptions(presence: .init(enableEvents: enableEvents))
        let realtime = MockRealtime(channels: channels)
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: When fetching the realtime channel, it sets the channel modes accordingly
        let chatMessagesChannelGetOptions = try #require(channels.getArguments.first?.options)
        #expect(chatMessagesChannelGetOptions.modes == expectedChannelModes)
    }

    // MARK: - Features

    @Test
    func passesChannelToLifecycleManager() async throws {
        // Given: a DefaultRoom instance
        let channel = MockRealtimeChannel(name: "basketball::$chat")
        let channels = MockChannels(channels: [channel])
        let realtime = MockRealtime(channels: channels)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory()
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // Then: It creates a lifecycle manager using the fetched channel
        let lifecycleManagerCreationArguments = try #require(lifecycleManagerFactory.createManagerArguments.first)
        #expect(lifecycleManagerCreationArguments.channel === channel)
    }

    // MARK: - Attach

    @Test(
        arguments: [
            .success(()),
            .failure(.createArbitraryError()),
        ] as[Result<Void, InternalError>],
    )
    func attach(managerAttachResult: Result<Void, InternalError>) async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager(attachResult: managerAttachResult)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: `attach()` is called on the room
        let result = await Result { @Sendable () async throws(ErrorInfo) in
            try await room.attach()
        }

        // Then: It calls through to the `performAttachOperation()` method on the room lifecycle manager
        #expect(result == managerAttachResult.mapError { .init(internalError: $0) })
        #expect(lifecycleManager.attachCallCount == 1)
    }

    // MARK: - Detach

    @Test(
        arguments: [
            .success(()),
            .failure(.createArbitraryError()),
        ] as[Result<Void, InternalError>],
    )
    func detach(managerDetachResult: Result<Void, InternalError>) async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager(detachResult: managerDetachResult)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: `detach()` is called on the room
        let result = await Result { @Sendable () async throws(ErrorInfo) in
            try await room.detach()
        }

        // Then: It calls through to the `performDetachOperation()` method on the room lifecycle manager
        #expect(result == managerDetachResult.mapError { .init(internalError: $0) })
        #expect(lifecycleManager.detachCallCount == 1)
    }

    // MARK: - Release

    // @spec CHA-RL3h - I haven’t explicitly tested that `performReleaseOperation()` happens _before_ releasing the channels (i.e. the “upon operation completion” part of the spec point), because it would require me to spend extra time on mock-writing which I can’t really afford to spend right now. I think we can live with it at least for the time being; I’m pretty sure there are other tests where the spec mentions or requires an order where I also haven’t tested the order.
    @Test
    func release() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager()
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: `release()` is called on the room
        await room.release()

        // Then: It:
        // 1. calls `performReleaseOperation()` on the room lifecycle manager
        // 2. calls `channels.release()` with the name of each of the features’ channels
        #expect(lifecycleManager.releaseCallCount == 1)
        #expect(Set(channels.releaseArguments) == Set(channelsList.map(\.name)))
    }

    // MARK: - Room status

    @Test
    func statusAndError() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManagerRoomStatus = RoomStatus.attached // arbitrary
        let lifecycleManagerError = ErrorInfo.createArbitraryError()

        let lifecycleManager = MockRoomLifecycleManager(roomStatus: lifecycleManagerRoomStatus, error: lifecycleManagerError)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // Then: The `status` and `error` properties return those of the room lifecycle manager
        #expect(room.status == lifecycleManagerRoomStatus)
        #expect(room.error == lifecycleManagerError)
    }

    @Test
    func onStatusChange() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager()
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: The room lifecycle manager emits a status change through `onRoomStatusChange`
        let managerStatusChange = RoomStatusChange(current: .detached, previous: .detaching) // arbitrary
        let roomStatusSubscription = room.onStatusChange()
        lifecycleManager.emitStatusChange(managerStatusChange)

        // Then: The room emits this status change through `onStatusChange`
        let roomStatusChange = try #require(await roomStatusSubscription.first { @Sendable _ in true })
        #expect(roomStatusChange == managerStatusChange)
    }

    // MARK: - Discontinuties

    // @spec CHA-RL15a
    @Test
    func onDiscontinuity() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager()
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), name: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: The room lifecycle manager emits a discontinuity event through `onDiscontinuity`
        let managerDiscontinuityError = ErrorInfo.createArbitraryError()
        let roomDiscontinuitiesSubscription = room.onDiscontinuity()
        lifecycleManager.emitDiscontinuity(managerDiscontinuityError)

        // Then: The room emits this discontinuity event through `onDiscontinuity`
        let roomDiscontinuityError = try #require(await roomDiscontinuitiesSubscription.first { @Sendable _ in true })
        #expect(roomDiscontinuityError == managerDiscontinuityError)
    }

    // @specNotApplicable CHA-RL15b - We do not have an explicit unsubscribe API, since we use AsyncSequence instead of listeners.
    // @specNotApplicable CHA-RL15c - We do not have an explicit unsubscribe API, since we use AsyncSequence instead of listeners.
}

private extension Result {
    /// An async equivalent of the initializer of the same name in the standard library.
    init(catching body: () async throws(Failure) -> Success) async {
        do {
            let success = try await body()
            self = .success(success)
        } catch {
            self = .failure(error)
        }
    }
}

private extension Result where Success == Void, Failure: Equatable {
    static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            true
        case let (.failure(lhsError), .failure(rhsError)):
            lhsError == rhsError
        default:
            false
        }
    }
}
