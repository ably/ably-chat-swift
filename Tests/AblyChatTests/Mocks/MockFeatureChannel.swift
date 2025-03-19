import Ably
@testable import AblyChat

final actor MockFeatureChannel: FeatureChannel {
    let channel: any InternalRealtimeChannelProtocol
    private var discontinuitySubscriptions = SubscriptionStorage<DiscontinuityEvent>()
    private let resultOfWaitToBeAbleToPerformPresenceOperations: Result<Void, ARTErrorInfo>?

    init(
        channel: any InternalRealtimeChannelProtocol,
        resultOfWaitToBeAblePerformPresenceOperations: Result<Void, ARTErrorInfo>? = nil
    ) {
        self.channel = channel
        resultOfWaitToBeAbleToPerformPresenceOperations = resultOfWaitToBeAblePerformPresenceOperations
    }

    func onDiscontinuity(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent> {
        discontinuitySubscriptions.create(bufferingPolicy: bufferingPolicy)
    }

    func emitDiscontinuity(_ discontinuity: DiscontinuityEvent) {
        discontinuitySubscriptions.emit(discontinuity)
    }

    func waitToBeAbleToPerformPresenceOperations(requestedByFeature _: RoomFeature) async throws(InternalError) {
        guard let resultOfWaitToBeAbleToPerformPresenceOperations else {
            fatalError("resultOfWaitToBeAblePerformPresenceOperations must be set before waitToBeAbleToPerformPresenceOperations is called")
        }

        do {
            try resultOfWaitToBeAbleToPerformPresenceOperations.get()
        } catch {
            throw error.toInternalError()
        }
    }
}
