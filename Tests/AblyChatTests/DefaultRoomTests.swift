import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultRoomTests {
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
        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

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
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

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
        let roomOptions = RoomOptions(presence: .init(receivePresenceEvents: false), occupancy: .init(enableInboundOccupancy: true))
        let realtime = MockRealtime(channels: channels)
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: It fetches the …$chat channel only once, and the options with which it does so are the result of merging the options used by the presence feature and those used by the occupancy feature
        let channelsGetArguments = channels.getArguments
        #expect(channelsGetArguments.map(\.name).sorted() == ["basketball::$chat"])

        let chatMessagesChannelGetOptions = try #require(channelsGetArguments.first { $0.name == "basketball::$chat" }?.options)
        #expect(chatMessagesChannelGetOptions.params?["occupancy"] == "metrics")
        #expect(chatMessagesChannelGetOptions.modes == [.publish, .subscribe, .presence])
    }

    // @spec CHA-O6a
    // @spec CHA-O6b
    @Test(arguments:
        [
            (
                enableInboundOccupancy: true,
                expectedOccupancyChannelParam: "metrics"
            ),
            (
                enableInboundOccupancy: false,
                expectedOccupancyChannelParam: nil
            ),
        ]
    )
    func enableInboundOccupancy(enableInboundOccupancy: Bool, expectedOccupancyChannelParam: String?) async throws {
        // Given: A DefaultRoom instance, with the occupancy.enableInboundOccupancy room option set per the test argument
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let roomOptions = RoomOptions(occupancy: .init(enableInboundOccupancy: enableInboundOccupancy))
        let realtime = MockRealtime(channels: channels)
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: When fetching the realtime channel, it sets the "occupancy" channel param accordingly
        let chatMessagesChannelGetOptions = try #require(channels.getArguments.first?.options)
        #expect(chatMessagesChannelGetOptions.params?["occupancy"] == expectedOccupancyChannelParam)
    }

    // @spec CHA-PR9c2
    @Test(arguments:
        [
            (
                receivePresenceEvents: true,
                // i.e. it doesn't explicitly set any modes (so that Realtime will use the default modes)
                expectedChannelModes: [] as ARTChannelMode
            ),
            (
                receivePresenceEvents: false,
                expectedChannelModes: [.publish, .subscribe, .presence] as ARTChannelMode
            ),
        ]
    )
    func receivePresenceEvents(receivePresenceEvents: Bool, expectedChannelModes: ARTChannelMode) async throws {
        // Given: A DefaultRoom instance, with the presence.receivePresenceEvents room option set per the test argument
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let roomOptions = RoomOptions(presence: .init(receivePresenceEvents: receivePresenceEvents))
        let realtime = MockRealtime(channels: channels)
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

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
        _ = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // Then: It creates a lifecycle manager using the fetched channel
        let lifecycleManagerCreationArguments = try #require(lifecycleManagerFactory.createManagerArguments.first)
        #expect(lifecycleManagerCreationArguments.channel === channel)
    }

    // MARK: - Attach

    @Test(
        arguments: [
            .success(()),
            .failure(ARTErrorInfo.createUnknownError() /* arbitrary */ ),
        ] as[Result<Void, ARTErrorInfo>]
    )
    func attach(managerAttachResult: Result<Void, ARTErrorInfo>) async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager(attachResult: managerAttachResult)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: `attach()` is called on the room
        let result = await Result { @Sendable () async throws(ARTErrorInfo) in
            do {
                try await room.attach()
            } catch {
                // swiftlint:disable:next force_cast
                throw error as! ARTErrorInfo
            }
        }

        // Then: It calls through to the `performAttachOperation()` method on the room lifecycle manager
        #expect(Result.areIdentical(result, managerAttachResult))
        #expect(lifecycleManager.attachCallCount == 1)
    }

    // MARK: - Detach

    @Test(
        arguments: [
            .success(()),
            .failure(ARTErrorInfo.createUnknownError() /* arbitrary */ ),
        ] as[Result<Void, ARTErrorInfo>]
    )
    func detach(managerDetachResult: Result<Void, ARTErrorInfo>) async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager(detachResult: managerDetachResult)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: `detach()` is called on the room
        let result = await Result { @Sendable () async throws(ARTErrorInfo) in
            do {
                try await room.detach()
            } catch {
                // swiftlint:disable:next force_cast
                throw error as! ARTErrorInfo
            }
        }

        // Then: It calls through to the `performDetachOperation()` method on the room lifecycle manager
        #expect(Result.areIdentical(result, managerDetachResult))
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

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

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
    func status() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManagerRoomStatus = RoomStatus.attached(error: nil) // arbitrary

        let lifecycleManager = MockRoomLifecycleManager(roomStatus: lifecycleManagerRoomStatus)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // Then: The `status` property returns that of the room lifecycle manager
        #expect(room.status == lifecycleManagerRoomStatus)
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

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: The room lifecycle manager emits a status change through `subscribeToState`
        let managerStatusChange = RoomStatusChange(current: .detached(error: nil), previous: .detaching(error: nil)) // arbitrary
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

        let room = try DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: The room lifecycle manager emits a status change through `subscribeToState`
        let managerDiscontinuity = DiscontinuityEvent(error: ARTErrorInfo.createUnknownError() /* arbitrary */ )
        let roomDiscontinuitiesSubscription = room.onDiscontinuity()
        lifecycleManager.emitDiscontinuity(managerDiscontinuity)

        // Then: The room emits this discontinuity through `onDiscontinuity`
        let roomDiscontinuity = try #require(await roomDiscontinuitiesSubscription.first { @Sendable _ in true })
        #expect(roomDiscontinuity == managerDiscontinuity)
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

private extension Result where Success == Void, Failure == ARTErrorInfo {
    static func areIdentical(_ lhs: Result<Void, ARTErrorInfo>, _ rhs: Result<Void, ARTErrorInfo>) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            true
        case let (.failure(lhsError), .failure(rhsError)):
            lhsError === rhsError
        default:
            fatalError("Mis-implemented")
        }
    }
}
