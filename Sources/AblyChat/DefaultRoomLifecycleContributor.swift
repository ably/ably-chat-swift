import Ably

internal actor DefaultRoomLifecycleContributor: RoomLifecycleContributor, EmitsDiscontinuities, CustomDebugStringConvertible {
    internal nonisolated let channel: DefaultRoomLifecycleContributorChannel
    internal nonisolated let feature: RoomFeature
    private var discontinuitySubscriptions = SubscriptionStorage<DiscontinuityEvent>()

    internal init(channel: DefaultRoomLifecycleContributorChannel, feature: RoomFeature) {
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

internal final class DefaultRoomLifecycleContributorChannel: RoomLifecycleContributorChannel, CustomDebugStringConvertible {
    private let underlyingChannel: any InternalRealtimeChannelProtocol

    internal init(underlyingChannel: any InternalRealtimeChannelProtocol) {
        self.underlyingChannel = underlyingChannel
    }

    internal func attach() async throws(InternalError) {
        try await underlyingChannel.attach()
    }

    internal func detach() async throws(InternalError) {
        try await underlyingChannel.detach()
    }

    internal var state: ARTRealtimeChannelState {
        underlyingChannel.state
    }

    internal var errorReason: ARTErrorInfo? {
        underlyingChannel.errorReason
    }

    internal func subscribeToState() async -> Subscription<ARTChannelStateChange> {
        let subscription = Subscription<ARTChannelStateChange>(bufferingPolicy: .unbounded)
        let eventListener = underlyingChannel.on { subscription.emit($0) }
        subscription.addTerminationHandler { [weak underlyingChannel] in
            underlyingChannel?.unsubscribe(eventListener)
        }
        return subscription
    }

    // MARK: - CustomDebugStringConvertible

    internal var debugDescription: String {
        "\(underlyingChannel)"
    }
}
