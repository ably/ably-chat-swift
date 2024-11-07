@testable import AblyChat

actor MockRoomLifecycleManagerFactory: RoomLifecycleManagerFactory {
    private let manager: MockRoomLifecycleManager

    init(manager: MockRoomLifecycleManager = .init()) {
        self.manager = manager
    }

    func createManager(contributors _: [DefaultRoomLifecycleContributor], logger _: any InternalLogger) async -> MockRoomLifecycleManager {
        manager
    }
}
