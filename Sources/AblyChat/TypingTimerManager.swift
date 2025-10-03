import Foundation

@MainActor
internal final class TypingTimerManager<AnyClock: ClockProtocol>: TypingTimerManagerProtocol {
    private let heartbeatThrottle: TimeInterval
    private let gracePeriod: TimeInterval
    private let logger: any InternalLogger
    private let clock: AnyClock

    /// Stores the CHA-T13b1 "is somebody typing" timers. Keys are clientID.
    private var whoIsTypingTimers = [String: TimerManager<AnyClock>]()

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
    internal func startTypingTimer(for clientID: String, handler: (@MainActor () -> Void)? = nil) {
        let timerManager = whoIsTypingTimers[clientID] ?? TimerManager(clock: clock)
        whoIsTypingTimers[clientID] = timerManager

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
            cancelTypingTimer(for: clientID)
            handler?()
        }
    }

    /// Per CHA-T13b4, cancels the CHA-T13b1 "is this person typing", thus removing this clientID from the typing set.
    internal func cancelTypingTimer(for clientID: String) {
        guard let timer = whoIsTypingTimers[clientID] else {
            logger.log(message: "No typing timer to cancel for clientID: \(clientID)", level: .debug)
            return
        }

        logger.log(message: "Cancelling typing timer for clientID: \(clientID)", level: .debug)
        timer.cancelTimer()
        whoIsTypingTimers[clientID] = nil
    }

    /// Returns whether this client is present in the set of users who we consider to currently be typing. This is what should be used for the CHA-T13b1 "represents a new client typing" and CHA-T13b5 "is not present in the typing set" checks.
    internal func isCurrentlyTyping(clientID: String) -> Bool {
        currentlyTypingClientIDs().contains(clientID)
    }

    /// Returns the set of client IDs that we consider to currently be typing (also referred to in the spec as the "typing set").
    internal func currentlyTypingClientIDs() -> Set<String> {
        Set(whoIsTypingTimers.keys)
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
    func startTypingTimer(for clientID: String, handler: (@MainActor () -> Void)?)
    /// Per CHA-T13b4, cancels the CHA-T13b1 "is this person typing" timer, thus removing this clientID from the typing set.
    func cancelTypingTimer(for clientID: String)
    /// Returns whether this client is present in the set of users who we consider to currently be typing. This is what should be used for the CHA-T13b1 "represents a new client typing" and CHA-T13b5 "is not present in the typing set" checks.
    func isCurrentlyTyping(clientID: String) -> Bool
    /// Returns the set of client IDs that we consider to currently be typing (also referred to in the spec as the "typing set").
    func currentlyTypingClientIDs() -> Set<String>
}
