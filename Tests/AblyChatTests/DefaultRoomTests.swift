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
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
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
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
        let roomOptions = RoomOptions(presence: PresenceOptions(), occupancy: OccupancyOptions())
        _ = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then: It fetches the …$chatMessages channel (which is used by messages, presence, and occupancy) only once, and the options with which it does so are the result of merging the options used by the presence feature and those used by the occupancy feature
        let channelsGetArguments = channels.getArguments
        #expect(channelsGetArguments.map(\.name).sorted() == ["basketball::$chat::$chatMessages"])

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
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then
        let defaultMessages = try #require(room.messages as? DefaultMessages)
        #expect(defaultMessages.testsOnly_internalChannel.name == "basketball::$chat::$chatMessages")
    }

    // @spec CHA-ER1
    @Test
    func reactionsChannelName() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(reactions: .init()), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then
        let defaultReactions = try #require(room.reactions as? DefaultRoomReactions)
        #expect(defaultReactions.testsOnly_internalChannel.name == "basketball::$chat::$reactions")
    }

    // @spec CHA-RC2c
    // @spec CHA-RC2d
    // @spec CHA-RC2f
    // @spec CHA-RL5a1 - We implement this spec point by _not allowing multiple contributors to share a channel_; this is an approach that I’ve suggested in https://github.com/ably/specification/issues/240.
    @Test
    func fetchesChannelAndCreatesLifecycleContributorForEnabledFeatures() async throws {
        // Given: a DefaultRoom instance, initialized with options that request that the room use a strict subset of the possible features
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
        let roomOptions = RoomOptions(
            presence: .init(),
            // Note that typing indicators are not enabled, to give us the aforementioned strict subset of features
            reactions: .init()
        )
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory()
        _ = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: roomOptions, logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // Then: It:
        // - fetches the channel that corresponds to each feature requested by the room options, plus the messages feature
        // - initializes the RoomLifecycleManager with a contributor for each fetched channel, and the feature assigned to each contributor is the feature, of the enabled features that correspond to that channel, which appears first in the CHA-RC2e list
        // - initializes the RoomLifecycleManager with a contributor for each feature requested by the room options, plus the messages feature
        let lifecycleManagerCreationArguments = try #require(await lifecycleManagerFactory.createManagerArguments.first)
        let expectedFeatures: [RoomFeature] = [.messages, .reactions] // i.e. since messages and presence share a channel, we create a single contributor for this channel and its assigned feature is messages
        #expect(lifecycleManagerCreationArguments.contributors.count == expectedFeatures.count)
        #expect(Set(lifecycleManagerCreationArguments.contributors.map(\.feature)) == Set(expectedFeatures))

        let channelsGetArguments = channels.getArguments
        let expectedFetchedChannelNames = [
            "basketball::$chat::$chatMessages", // This is the channel used by the messages and presence features
            "basketball::$chat::$reactions",
        ]
        #expect(channelsGetArguments.count == expectedFetchedChannelNames.count)
        #expect(Set(channelsGetArguments.map(\.name)) == Set(expectedFetchedChannelNames))
    }

    // @spec CHA-RC2e
    // @spec CHA-RL10
    @Test
    func lifecycleContributorOrder() async throws {
        // Given: a DefaultRoom, instance, with all room features enabled
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages"),
            MockRealtimeChannel(name: "basketball::$chat::$reactions"),
            MockRealtimeChannel(name: "basketball::$chat::$typingIndicators"),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory()
        _ = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .allFeaturesEnabled, logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // Then: The array of contributors with which it initializes the RoomLifecycleManager are in the same order as the following list:
        //
        // messages, presence, typing, reactions, occupancy
        //
        // (note that we do not say that it is the _same_ list, because we combine multiple features into a single contributor)
        let lifecycleManagerCreationArguments = try #require(await lifecycleManagerFactory.createManagerArguments.first)
        #expect(lifecycleManagerCreationArguments.contributors.map(\.feature) == [.messages, .typing, .reactions])
    }

    // @specUntested CHA-RC2b - We chose to implement this failure with an idiomatic fatalError instead of throwing, but we can’t test this.

    // This is just a basic sense check to make sure the room getters are working as expected, since we don’t have unit tests for some of the features at the moment.
    @Test(arguments: [.messages, .presence, .reactions, .occupancy, .typing] as[RoomFeature])
    func whenFeatureEnabled_propertyGetterReturns(feature: RoomFeature) async throws {
        // Given: A RoomOptions with the (test argument `feature`) feature enabled in the room options
        let roomOptions: RoomOptions
        var namesOfChannelsToMock = ["basketball::$chat::$chatMessages"]
        switch feature {
        case .messages:
            // Messages should always be enabled without needing any special options
            roomOptions = .init()
        case .presence:
            roomOptions = .init(presence: .init())
        case .reactions:
            roomOptions = .init(reactions: .init())
            namesOfChannelsToMock.append("basketball::$chat::$reactions")
        case .occupancy:
            roomOptions = .init(occupancy: .init())
        case .typing:
            roomOptions = .init(typing: .init())
            namesOfChannelsToMock.append("basketball::$chat::$typingIndicators")
        }

        let channelsList = namesOfChannelsToMock.map { name in
            MockRealtimeChannel(name: name)
        }
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)
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
        case .typing:
            #expect(room.typing is DefaultTyping)
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
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

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
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

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
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

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
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

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
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime(channels: channels)

        let lifecycleManager = MockRoomLifecycleManager()
        let lifecycleManagerFactory = MockRoomLifecycleManagerFactory(manager: lifecycleManager)

        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: lifecycleManagerFactory)

        // When: The room lifecycle manager emits a status change through `subscribeToState`
        let managerStatusChange = RoomStatusChange(current: .detached, previous: .detaching) // arbitrary
        let roomStatusSubscription = await room.onStatusChange()
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
