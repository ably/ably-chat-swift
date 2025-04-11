@testable import AblyChat

class MockRoomLifecycleManagerFactory: RoomLifecycleManagerFactory {
    private let manager: MockRoomLifecycleManager
    private(set) var createManagerArguments: [(contributors: [DefaultRoomLifecycleContributor], logger: any InternalLogger)] = []

    init(manager: MockRoomLifecycleManager = .init()) {
        self.manager = manager
    }

    func createManager(contributors: [DefaultRoomLifecycleContributor], logger: any InternalLogger) -> MockRoomLifecycleManager {
        createManagerArguments.append((contributors: contributors, logger: logger))
        return manager
    }
}
