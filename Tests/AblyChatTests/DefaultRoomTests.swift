import Ably
@testable import AblyChat
import Testing

struct DefaultRoomTests {
    // MARK: - Features

    // @spec CHA-M1
    @Test
    func messagesChannelName() async throws {
        // Given: a DefaultRoom instance
        let channelsList = [
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages", attachResult: .success),
        ]
        let channels = MockChannels(channels: channelsList)
        let realtime = MockRealtime.create(channels: channels)
        let room = try await DefaultRoom(realtime: realtime, chatAPI: ChatAPI(realtime: realtime), roomID: "basketball", options: .init(), logger: TestLogger(), lifecycleManagerFactory: MockRoomLifecycleManagerFactory())

        // Then
        #expect(room.messages.channel.name == "basketball::$chat::$chatMessages")
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
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages", attachResult: .success),
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
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages", detachResult: .success),
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
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages", detachResult: .success),
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
            MockRealtimeChannel(name: "basketball::$chat::$chatMessages", detachResult: .success),
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
