import Ably
@testable import AblyChat
import Testing

struct DefaultRoomTests {
    // MARK: - Fetching channels

    // @spec CHA-GP2a
    @Test
    func disablesImplicitAttach() async throws {
        // Given: A DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)
        _ = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: When it fetches a channel, it does so with the `attachOnSubscribe` channel option set to false
        let channelsGetArguments = channels.getArguments
        #expect(!channelsGetArguments.isEmpty)
        #expect(channelsGetArguments.allSatisfy { $0.options.attachOnSubscribe == false })
    }

    // @spec CHA-RC3a
    @Test
    func fetchesEachChannelOnce() async throws {
        // Given: A DefaultRoom instance, configured to use presence and occupancy
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)
        let roomOptions = RoomOptions(presence: PresenceOptions(), occupancy: OccupancyOptions())
        _ = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: It fetches the …$chatMessages channel (which is used by messages, presence, and occupancy) only once, and the options with which it does so are the result of merging the options used by the presence feature and those used by the occupancy feature
        let channelsGetArguments = channels.getArguments
        #expect(channelsGetArguments.map(\.name).sorted() == ["basketball::$chat::$chatMessages", "basketball::$chat::$reactions"])

        let chatMessagesChannelGetOptions = try #require(channelsGetArguments.first { $0.name == "basketball::$chat::$chatMessages" }?.options)
        #expect(chatMessagesChannelGetOptions.params?["occupancy"] == "metrics")
        // TODO: Restore this code once we understand weird Realtime behaviour and spec points (https://github.com/ably-labs/ably-chat-swift/issues/133)
//        #expect(chatMessagesChannelGetOptions.modes == [.presence, .presenceSubscribe])
    }

    // MARK: - Features

    // @spec CHA-M1
    @Test
    func messagesChannelName() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"), // required as DefaultRoom attaches reactions implicitly for now
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)
        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then
        #expect(room.messages.channel.name == "basketball::$chat::$chatMessages")
    }

    // @specUntested CHA-RC2b - We chose to implement this failure with an idiomatic fatalError instead of throwing, but we can’t test this.

    // This is just a basic sense check to make sure the room getters are working as expected, since we don’t have unit tests for some of the features at the moment.
    @Test(arguments: [.messages, .presence, .reactions, .occupancy] as[RoomFeature])
    func whenFeatureEnabled_propertyGetterReturns(feature: RoomFeature) async throws {
        // Given: A RoomOptions with the (test argument `feature`) feature enabled in the room options
        let roomOptions: RoomOptions = switch feature {
        case .messages:
            // Messages should always be enabled without needing any special options
            .init()
        case .presence:
            .init(presence: .init())
        case .reactions:
            .init(reactions: .init())
        case .occupancy:
            .init(occupancy: .init())
        default:
            fatalError("Unexpected feature \(feature)")
        }

        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)
        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // When: We call the room’s getter for that feature
        // Then: It returns an object (i.e. does not `fatalError()`)
        switch feature {
        case .messages:
            #expect(room.messages is DefaultMessages)
        case .presence:
            #expect(room.presence is DefaultPresence)
        case .reactions:
            #expect(room.reactions is DefaultRoomReactions)
        case .occupancy:
            #expect(room.occupancy is DefaultOccupancy)
        default:
            fatalError("Unexpected feature \(feature)")
        }
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
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"), // required as DefaultRoom attaches reactions implicitly for now
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager(attachResult: managerAttachResult)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: `attach()` is called on the room
        let result = await Result { () async throws(ARTErrorInfo) in
            do {
                try await room.attach()
            } catch {
                // swiftlint:disable:next force_cast
                throw error as! ARTErrorInfo
            }
        }

        // Then: It calls through to the `performAttachOperation()` method on the room lifecycle manager
        #expect(Result.areIdentical(result, managerAttachResult))
        #expect(await lifecycleManager.attachCallCount == 1)
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
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"), // required as DefaultRoom attaches reactions implicitly for now
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager(detachResult: managerDetachResult)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: `detach()` is called on the room
        let result = await Result { () async throws(ARTErrorInfo) in
            do {
                try await room.detach()
            } catch {
                // swiftlint:disable:next force_cast
                throw error as! ARTErrorInfo
            }
        }

        // Then: It calls through to the `performDetachOperation()` method on the room lifecycle manager
        #expect(Result.areIdentical(result, managerDetachResult))
        #expect(await lifecycleManager.detachCallCount == 1)
    }

    // MARK: - Release

    // @spec CHA-RL3h - I haven’t explicitly tested that `performReleaseOperation()` happens _before_ releasing the channels (i.e. the “upon operation completion” part of the spec point), because it would require me to spend extra time on mock-writing which I can’t really afford to spend right now. I think we can live with it at least for the time being; I’m pretty sure there are other tests where the spec mentions or requires an order where I also haven’t tested the order.
    @Test
    func release() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"), // required as DefaultRoom attaches reactions implicitly for now
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager()
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: `release()` is called on the room
        await room.release()

        // Then: It:
        // 1. calls `performReleaseOperation()` on the room lifecycle manager
        // 2. calls `channels.release()` with the name of each of the features’ channels
        #expect(await lifecycleManager.releaseCallCount == 1)
        #expect(Set(channels.releaseArguments) == Set(channelsList.map(\.name)))
    }

    // MARK: - Room status

    @Test
    func status() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"), // required as DefaultRoom attaches reactions implicitly for now
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)

        let lifecycleManagerRoomStatus = RoomStatus.attached // arbitrary

        let lifecycleManager = MockRoomLifecycleManager(roomStatus: lifecycleManagerRoomStatus)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // Then: The `status` property returns that of the room lifecycle manager
        #expect(await room.status == lifecycleManagerRoomStatus)
    }

    @Test
    func onStatusChange() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"), // required as DefaultRoom attaches reactions implicitly for now
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager()
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: The room lifecycle manager emits a status change through `subscribeToState`
        let managerStatusChange = RoomStatusChange(current: .detached, previous: .detaching) // arbitrary
        let roomStatusSubscription = await room.onStatusChange(bufferingPolicy: .unbounded)
        await lifecycleManager.emitStatusChange(managerStatusChange)

        // Then: The room emits this status change through `onStatusChange`
        let roomStatusChange = try #require(await roomStatusSubscription.first { _ in true })
        #expect(roomStatusChange == managerStatusChange)
    }
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
