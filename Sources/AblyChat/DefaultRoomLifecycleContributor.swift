import Ably

internal class DefaultRoomLifecycleContributor: RoomLifecycleContributor, EmitsDiscontinuities, CustomDebugStringConvertible {
    internal nonisolated let channel: any InternalRealtimeChannelProtocol
    internal nonisolated let feature: RoomFeature
    private var discontinuitySubscriptions = SubscriptionStorage<DiscontinuityEvent>()

    internal init(channel: any InternalRealtimeChannelProtocol, feature: RoomFeature) {
        self.channel = channel
        self.feature = feature
    }

    // MARK: - Discontinuities

    internal func emitDiscontinuity(_ discontinuity: DiscontinuityEvent) {
        discontinuitySubscriptions.emit(discontinuity)
    }

    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        discontinuitySubscriptions.create(bufferingPolicy: bufferingPolicy)
    }

    // MARK: - CustomDebugStringConvertible

    internal nonisolated var debugDescription: String {
        "(\(id): \(feature), \(channel))"
    }
}
