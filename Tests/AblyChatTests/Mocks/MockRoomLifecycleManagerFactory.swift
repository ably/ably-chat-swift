@testable import AblyChat

actor MockRoomLifecycleManagerFactory: RoomLifecycleManagerFactory {
    private let manager: MockRoomLifecycleManager
    private(set) var createManagerArguments: [(channel: any InternalRealtimeChannelProtocol, logger: any InternalLogger)] = []

    init(manager: MockRoomLifecycleManager = .init()) {
        self.manager = manager
    }

    func createManager(channel: any InternalRealtimeChannelProtocol, logger: any InternalLogger) async -> MockRoomLifecycleManager {
        createManagerArguments.append((channel: channel, logger: logger))
        return manager
    }
}
