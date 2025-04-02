import Ably
@testable import AblyChat

class MockRoomLifecycleContributor: RoomLifecycleContributor {
    nonisolated let feature: RoomFeature
    /// Provides access to the non-type-erased underlying mock channel (so that you can call mocking-related methods on it).
    nonisolated let mockChannel: MockRealtimeChannel
    nonisolated var channel: any InternalRealtimeChannelProtocol {
        mockChannel
    }

    private(set) var emitDiscontinuityArguments: [DiscontinuityEvent] = []

    init(feature: RoomFeature, channel: MockRealtimeChannel) {
        self.feature = feature
        mockChannel = channel
    }

    func emitDiscontinuity(_ discontinuity: DiscontinuityEvent) {
        emitDiscontinuityArguments.append(discontinuity)
    }
}
