import Ably
@testable import AblyChat

final actor MockFeatureChannel: FeatureChannel {
    let channel: RealtimeChannelProtocol
    // TODO: clean up old subscriptions (https://github.com/ably-labs/ably-chat-swift/issues/36)
    private var discontinuitySubscriptions: [Subscription<ARTErrorInfo>] = []

    init(channel: RealtimeChannelProtocol) {
        self.channel = channel
    }

    func subscribeToDiscontinuities() async -> Subscription<ARTErrorInfo> {
        let subscription = Subscription<ARTErrorInfo>(bufferingPolicy: .unbounded)
        discontinuitySubscriptions.append(subscription)
        return subscription
    }

    func emitDiscontinuity(_ discontinuity: ARTErrorInfo) {
        for subscription in discontinuitySubscriptions {
            subscription.emit(discontinuity)
        }
    }
}
