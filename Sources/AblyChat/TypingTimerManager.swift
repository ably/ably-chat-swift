import Foundation

@MainActor
internal final class TypingTimerManager<AnyClock: ClockProtocol>: TypingTimerManagerProtocol {
    private let heartbeatThrottle: TimeInterval
    private let gracePeriod: TimeInterval
    private let logger: any InternalLogger
    private let clock: AnyClock

    /// Stores per-client typing state including the CHA-T13b1 "is somebody typing" timer and the CHA-T13a1 userClaim.
    private struct TypingClientState {
        var timer: TimerManager<AnyClock>
        var userClaim: String?
    }

    /// Stores the CHA-T13b1 "is somebody typing" state. Keys are clientID.
    private var whoIsTypingState = [String: TypingClientState]()

    /// Stores the moment when the CHA-T4a4 heartbeat timer (which we use for deciding whether to publish another typing event for the current user) was started. If `nil`, then there is no active heartbeat timer.
    private var heartbeatTimerStartedAt: AnyClock.Instant?

    internal init(heartbeatThrottle: TimeInterval, gracePeriod: TimeInterval, logger: any InternalLogger, clock: AnyClock) {
        self.heartbeatThrottle = heartbeatThrottle
        self.gracePeriod = gracePeriod
        self.logger = logger
        self.clock = clock
    }

    // MARK: Managing the CHA-T4a4 heartbeat timer

    internal func startHeartbeatTimer() {
        heartbeatTimerStartedAt = clock.now
    }

    internal var isHeartbeatTimerActive: Bool {
        guard let heartbeatTimerStartedAt else {
            return false
        }

        return heartbeatTimerStartedAt.advanced(byTimeInterval: heartbeatThrottle) > clock.now
    }

    internal func cancelHeartbeatTimer() {
        heartbeatTimerStartedAt = nil
    }

    // MARK: Managing CHA-T13b1 "is this person typing" timers

    /// Starts a CHA-T13b1 "is this person typing" timer, thus adding this clientID to the typing set.
    /// If the clientID is already in the typing set, this will reset the timer (CHA-T13b2).
    /// (CHA-T13a1) The `userClaim` is always set to the value from the incoming event. If the event lacks a `userClaim`, the stored value is cleared to `nil`.
    /// The `handler` receives the userClaim that was stored for the client at the time of timer expiry.
    internal func startTypingTimer(for clientID: String, userClaim: String? = nil, handler: (@MainActor (_ userClaim: String?) -> Void)? = nil) {
        let existingState = whoIsTypingState[clientID]
        let timerManager = existingState?.timer ?? TimerManager(clock: clock)
        // (CHA-T13a1) Always use the incoming event's userClaim, even if nil — the spec requires the entry to be updated to reflect the incoming event.
        whoIsTypingState[clientID] = TypingClientState(timer: timerManager, userClaim: userClaim)

        // (CHA-T10a1) This grace period is used to determine how long to wait, beyond the heartbeat interval, before removing a client from the typing set. This is used to prevent flickering when a user is typing and stops typing for a short period of time. See CHA-T13b1 for a detailed description of how this is used.
        let timerDuration = heartbeatThrottle + gracePeriod

        logger.log(message: "Starting timer for clientID: \(clientID) with interval: \(timerDuration)", level: .debug)

        // (CHA-T13b2) Each additional typing heartbeat from the same client shall reset the (CHA-T13b1) timeout.
        timerManager.setTimer(interval: timerDuration) { [weak self] in
            guard let self else {
                return
            }
            logger.log(message: "Typing timer expired for clientID: \(clientID)", level: .debug)

            // (CHA-T13b3) (1/2) If the (CHA-T13b1) timeout expires, the client shall remove the clientId from the typing set and emit a synthetic typing stop event for the given client.
            // (CHA-T13a1) Preserve the userClaim before cancelling the timer state
            let expiredUserClaim = whoIsTypingState[clientID]?.userClaim
            cancelTypingTimer(for: clientID)
            handler?(expiredUserClaim)
        }
    }

    /// Per CHA-T13b4, cancels the CHA-T13b1 "is this person typing", thus removing this clientID from the typing set.
    internal func cancelTypingTimer(for clientID: String) {
        guard let state = whoIsTypingState[clientID] else {
            logger.log(message: "No typing timer to cancel for clientID: \(clientID)", level: .debug)
            return
        }

        logger.log(message: "Cancelling typing timer for clientID: \(clientID)", level: .debug)
        state.timer.cancelTimer()
        whoIsTypingState[clientID] = nil
    }

    /// Returns whether this client is present in the set of users who we consider to currently be typing. This is what should be used for the CHA-T13b1 "represents a new client typing" and CHA-T13b5 "is not present in the typing set" checks.
    internal func isCurrentlyTyping(clientID: String) -> Bool {
        currentlyTypingClientIDs().contains(clientID)
    }

    /// Returns the set of client IDs that we consider to currently be typing (also referred to in the spec as the "typing set").
    internal func currentlyTypingClientIDs() -> Set<String> {
        Set(whoIsTypingState.keys)
    }

    /// Returns the currently typing users with associated metadata.
    internal func currentlyTypingMembers() -> [TypingMember] {
        whoIsTypingState.map { clientID, state in
            TypingMember(clientID: clientID, userClaim: state.userClaim)
        }
    }

    /// Returns the stored `userClaim` for a given client, if any (CHA-T13a1).
    internal func userClaimForClient(_ clientID: String) -> String? {
        whoIsTypingState[clientID]?.userClaim
    }
}

// Whilst this protocol seems redundant seeing as there's only a single implementation,
// it is useful as a property in other classes without then needing to also make them generic to specify the Clock type.
@MainActor
internal protocol TypingTimerManagerProtocol {
    /// Starts a CHA-T4a4 heartbeat timer.
    func startHeartbeatTimer()
    /// Returns whether there is an active CHA-T4a4 heartbeat timer.
    var isHeartbeatTimerActive: Bool { get }
    /// Clears any active CHA-T4a4 heartbeat timer.
    func cancelHeartbeatTimer()
    /// Starts a CHA-T13b1 "is this person typing" timer, thus adding this clientID to the typing set.
    /// If the clientID is already in the typing set, this will reset the timer (CHA-T13b2).
    /// (CHA-T13a1) The `userClaim` is always set to the incoming event's value.
    /// The `handler` receives the userClaim that was stored for the client at the time of timer expiry.
    func startTypingTimer(for clientID: String, userClaim: String?, handler: (@MainActor (_ userClaim: String?) -> Void)?)
    /// Per CHA-T13b4, cancels the CHA-T13b1 "is this person typing" timer, thus removing this clientID from the typing set.
    func cancelTypingTimer(for clientID: String)
    /// Returns whether this client is present in the set of users who we consider to currently be typing. This is what should be used for the CHA-T13b1 "represents a new client typing" and CHA-T13b5 "is not present in the typing set" checks.
    func isCurrentlyTyping(clientID: String) -> Bool
    /// Returns the set of client IDs that we consider to currently be typing (also referred to in the spec as the "typing set").
    func currentlyTypingClientIDs() -> Set<String>
    /// Returns the currently typing users with associated metadata.
    func currentlyTypingMembers() -> [TypingMember]
    /// Returns the stored `userClaim` for a given client, if any (CHA-T13a1).
    func userClaimForClient(_ clientID: String) -> String?
}
