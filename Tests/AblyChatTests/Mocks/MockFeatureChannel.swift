import Ably
@testable import AblyChat

final actor MockFeatureChannel: FeatureChannel {
    let callRecorder = MockMethodCallRecorder()

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

    func waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature) async throws(InternalError) {
        guard let resultOfWaitToBeAbleToPerformPresenceOperations else {
            fatalError("resultOfWaitToBeAblePerformPresenceOperations must be set before waitToBeAbleToPerformPresenceOperations is called")
        }
        callRecorder.addRecord(
            signature: "waitToBeAbleToPerformPresenceOperations(requestedByFeature:)",
            arguments: ["requestedByFeature": "\(requestedByFeature)"]
        )
        do {
            try resultOfWaitToBeAbleToPerformPresenceOperations.get()
        } catch {
            throw error.toInternalError()
        }
    }
}
