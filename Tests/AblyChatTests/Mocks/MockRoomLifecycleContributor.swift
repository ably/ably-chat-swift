import Ably
@testable import AblyChat

actor MockRoomLifecycleContributor: RoomLifecycleContributor {
    nonisolated let feature: RoomFeature
    nonisolated let channel: MockRoomLifecycleContributorChannel

    private(set) var emitDiscontinuityArguments: [DiscontinuityEvent] = []

    init(feature: RoomFeature, channel: MockRoomLifecycleContributorChannel) {
        self.feature = feature
        self.channel = channel
    }

    func emitDiscontinuity(_ discontinuity: DiscontinuityEvent) async {
        emitDiscontinuityArguments.append(discontinuity)
    }
}
