@testable import AblyChat

class MockRoomLifecycleManagerFactory: RoomLifecycleManagerFactory {
    private let manager: MockRoomLifecycleManager
    private(set) var createManagerArguments: [(channel: any InternalRealtimeChannelProtocol, logger: any InternalLogger)] = []

    init(manager: MockRoomLifecycleManager = .init()) {
        self.manager = manager
    }

    func createManager(channel: any InternalRealtimeChannelProtocol, logger: any InternalLogger) -> MockRoomLifecycleManager {
        createManagerArguments.append((channel: channel, logger: logger))
        return manager
    }
}
