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

extension Array where Element == PresenceEventType {
    static let all = [
        PresenceEventType.present,
        PresenceEventType.enter,
        PresenceEventType.leave,
        PresenceEventType.update
    ]
}

struct RoomLifecycleHelper {

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
        attachBehavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior? = nil,
        detachBehavior: MockRoomLifecycleContributorChannel.AttachOrDetachBehavior? = nil,
        subscribeToStateBehavior: MockRoomLifecycleContributorChannel.SubscribeToStateBehavior? = nil
    ) -> MockRoomLifecycleContributor {
        .init(
            feature: feature,
            channel: .init(
                initialState: initialState,
                initialErrorReason: initialErrorReason,
                attachBehavior: attachBehavior,
                detachBehavior: detachBehavior,
                subscribeToStateBehavior: subscribeToStateBehavior
            )
        )
    }
}

extension Double {
    func isEqual(to other: Double, tolerance: Double) -> Bool {
        self >= other && self < other + tolerance
    }
}
