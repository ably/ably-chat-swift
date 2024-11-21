import Ably

internal actor DefaultRoomLifecycleContributor: RoomLifecycleContributor, EmitsDiscontinuities {
    internal nonisolated let channel: DefaultRoomLifecycleContributorChannel
    internal nonisolated let feature: RoomFeature
    private var discontinuitySubscriptions: [Subscription<ARTErrorInfo>] = []

    internal init(channel: DefaultRoomLifecycleContributorChannel, feature: RoomFeature) {
        self.channel = channel
        self.feature = feature
    }

    // MARK: - Discontinuities

    internal func emitDiscontinuity(_ error: ARTErrorInfo) {
        for subscription in discontinuitySubscriptions {
            subscription.emit(error)
        }
    }

    internal func subscribeToDiscontinuities() -> Subscription<ARTErrorInfo> {
        let subscription = Subscription<ARTErrorInfo>(bufferingPolicy: .unbounded)
        // TODO: clean up old subscriptions (https://github.com/ably-labs/ably-chat-swift/issues/36)
        discontinuitySubscriptions.append(subscription)
        return subscription
    }
}

internal final class DefaultRoomLifecycleContributorChannel: RoomLifecycleContributorChannel {
    private let underlyingChannel: any RealtimeChannelProtocol

    internal init(underlyingChannel: any RealtimeChannelProtocol) {
        self.underlyingChannel = underlyingChannel
    }

    internal func attach() async throws(ARTErrorInfo) {
        try await underlyingChannel.attachAsync()
    }

    internal func detach() async throws(ARTErrorInfo) {
        try await underlyingChannel.detachAsync()
    }

    internal var state: ARTRealtimeChannelState {
        underlyingChannel.state
    }

    internal var errorReason: ARTErrorInfo? {
        underlyingChannel.errorReason
    }

    internal func subscribeToState() async -> Subscription<ARTChannelStateChange> {
        // TODO: clean up old subscriptions (https://github.com/ably-labs/ably-chat-swift/issues/36)
        let subscription = Subscription<ARTChannelStateChange>(bufferingPolicy: .unbounded)
        underlyingChannel.on { subscription.emit($0) }
        return subscription
    }
}
