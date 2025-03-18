import Ably
@testable import AblyChat

actor MockRoomLifecycleContributor: RoomLifecycleContributor {
    nonisolated let channel: MockRoomLifecycleContributorChannel

    private(set) var emitDiscontinuityArguments: [DiscontinuityEvent] = []

    init(channel: MockRoomLifecycleContributorChannel) {
        self.channel = channel
    }

    func emitDiscontinuity(_ discontinuity: DiscontinuityEvent) async {
        emitDiscontinuityArguments.append(discontinuity)
    }
}
