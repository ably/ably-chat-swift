import Ably
@testable import AblyChat

/**
 Tests whether a given optional `Error` is an `ARTErrorInfo` in the chat error domain with a given code and cause. Can optionally pass a message and it will check that it matches.
 */
func isChatError(_ maybeError: (any Error)?, withCodeAndStatusCode codeAndStatusCode: AblyChat.ErrorCodeAndStatusCode, cause: ARTErrorInfo? = nil, message: String? = nil) -> Bool {
    guard let ablyError = maybeError as? ARTErrorInfo else {
        return false
    }

    return ablyError.domain == AblyChat.errorDomain as String
        && ablyError.code == codeAndStatusCode.code.rawValue
        && ablyError.statusCode == codeAndStatusCode.statusCode
        && ablyError.cause == cause
        && {
            guard let message else {
                return true
            }

            return ablyError.message == message
        }()
}

extension ARTPresenceMessage {
    convenience init(clientId: String, data: Any? = [:], timestamp: Date = Date()) {
        self.init()
        self.clientId = clientId
        self.data = data
        self.timestamp = timestamp
    }
}

extension [PresenceEventType] {
    static let all = [
        PresenceEventType.present,
        PresenceEventType.enter,
        PresenceEventType.leave,
        PresenceEventType.update,
    ]
}

enum RoomLifecycleHelper {
    static let fakeNetworkDelay: UInt64 = 10 // milliseconds; without this delay (or with a very low value such as 1) most of the time attach happens before lifecycleManager has a chance to start waiting.

    static func createManager(
        forTestingWhatHappensWhenCurrentlyIn status: DefaultRoomLifecycleManager<MockRoomLifecycleContributor>.Status? = nil,
        forTestingWhatHappensWhenHasPendingDiscontinuityEvents pendingDiscontinuityEvents: [MockRoomLifecycleContributor.ID: DiscontinuityEvent]? = nil,
        forTestingWhatHappensWhenHasTransientDisconnectTimeoutForTheseContributorIDs idsOfContributorsWithTransientDisconnectTimeout: Set<MockRoomLifecycleContributor.ID>? = nil,
        contributors: [MockRoomLifecycleContributor] = [],
        clock: SimpleClock = MockSimpleClock()
    ) async -> DefaultRoomLifecycleManager<MockRoomLifecycleContributor> {
        await .init(
            testsOnly_status: status,
            testsOnly_pendingDiscontinuityEvents: pendingDiscontinuityEvents,
            testsOnly_idsOfContributorsWithTransientDisconnectTimeout: idsOfContributorsWithTransientDisconnectTimeout,
            contributors: contributors,
            logger: TestLogger(),
            clock: clock
        )
    }

    static func createContributor(
        initialState: ARTRealtimeChannelState = .initialized,
        initialErrorReason: ARTErrorInfo? = nil,
        feature: RoomFeature = .messages, // Arbitrarily chosen, its value only matters in test cases where we check which error is thrown
        underlyingChannel: MockRealtimeChannel? = nil,
        attachBehavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior? = nil,
        detachBehavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior? = nil,
        subscribeToStateBehavior: MockRoomLifecycleContributorChannel.SubscribeToStateBehavior? = nil
    ) -> MockRoomLifecycleContributor {
        .init(
            feature: feature,
            channel: .init(
                underlyingChannel: underlyingChannel,
                initialState: initialState,
                initialErrorReason: initialErrorReason,
                attachBehavior: attachBehavior,
                detachBehavior: detachBehavior,
                subscribeToStateBehavior: subscribeToStateBehavior
            )
        )
    }

    // TODO: replace duplicates of this func elsewhere
    /// Given a room lifecycle manager and a channel state change, this method will return once the manager has performed all of the side effects that it will perform as a result of receiving this state change. You can provide a function which will be called after ``waitForManager`` has started listening for the manager’s “state change handled” notifications.
    static func waitForManager(_ manager: DefaultRoomLifecycleManager<some RoomLifecycleContributor>, toHandleContributorStateChange stateChange: ARTChannelStateChange, during action: () async -> Void) async {
        let subscription = await manager.testsOnly_subscribeToHandledContributorStateChanges()
        async let handledSignal = subscription.first { $0 === stateChange }
        await action()
        _ = await handledSignal
    }
}

extension Double {
    func isEqual(to other: Double, tolerance: Double) -> Bool {
        self >= other && self < other + tolerance
    }
}
