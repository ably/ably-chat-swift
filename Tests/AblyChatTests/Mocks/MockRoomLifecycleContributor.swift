import Ably
@testable import AblyChat

actor MockRoomLifecycleContributor: RoomLifecycleContributor {
    nonisolated let feature: RoomFeature
    nonisolated let channel: MockRoomLifecycleContributorChannel

    private(set) var emitDiscontinuityArguments: [ARTErrorInfo?] = []

    init(feature: RoomFeature, channel: MockRoomLifecycleContributorChannel) {
        self.feature = feature
        self.channel = channel
    }

    func emitDiscontinuity(_ error: ARTErrorInfo?) async {
        emitDiscontinuityArguments.append(error)
    }
}
