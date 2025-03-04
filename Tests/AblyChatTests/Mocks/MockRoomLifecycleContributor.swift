import Ably
@testable import AblyChat

actor MockRoomLifecycleContributor: RoomLifecycleContributor, EmitsDiscontinuities {
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

    func onDiscontinuity(bufferingPolicy _: AblyChat.BufferingPolicy) async -> AblyChat.Subscription<AblyChat.DiscontinuityEvent> {
        fatalError("Not implemented")
    }
}
