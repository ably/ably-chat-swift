@testable import AblyChat

actor MockRoomLifecycleContributor: RoomLifecycleContributor {
    nonisolated let feature: RoomFeature
    nonisolated let channel: MockRoomLifecycleContributorChannel

    init(feature: RoomFeature, channel: MockRoomLifecycleContributorChannel) {
        self.feature = feature
        self.channel = channel
    }
}
