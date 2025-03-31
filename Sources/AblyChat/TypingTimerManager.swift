import Foundation

@MainActor
internal final class TypingTimerManager {
    private let heartbeatThrottle: TimeInterval
    private let gracePeriod: TimeInterval
    private let logger: InternalLogger

    // Stores all the active timers for each client, where String is the clientID.
    private var timers = [String: TimerManager]()

    // Stores only the current user's last typing time
    private var lastTypingTime: Date?

    internal init(heartbeatThrottle: TimeInterval, gracePeriod: TimeInterval, logger: InternalLogger) {
        self.heartbeatThrottle = heartbeatThrottle
        self.gracePeriod = gracePeriod
        self.logger = logger
    }

    /// Checks if the user is allowed to publish a typing indicator based on the last typing time. This needs to be later than the heartbeat throttle, but it can be earlier than the heartbeatThrottle + any additonal timeout provided.
    internal func shouldPublishTyping() -> Bool {
        let currentTime = Date()

        if let lastTime = lastTypingTime, currentTime.timeIntervalSince(lastTime) < heartbeatThrottle {
            logger.log(message: "Should not publish typing indicator. Last typing time: \(lastTime), current time: \(currentTime)", level: .debug)
            return false
        }
        logger.log(message: "Should publish typing indicator. Last typing time: \(String(describing: lastTypingTime)), current time: \(currentTime)", level: .debug)
        return true
    }

    internal func startTypingTimer(for clientID: String, isSelf: Bool = false, handler: (@MainActor () -> Void)? = nil) {
        let timerManager = timers[clientID] ?? TimerManager()
        timers[clientID] = timerManager

        // (CHA-T10a1) This grace period is used to determine how long to wait, beyond the heartbeat interval, before removing a client from the typing set. This is used to prevent flickering when a user is typing and stops typing for a short period of time. See CHA-T13b1 for a detailed description of how this is used.
        let timerDuration = isSelf ? heartbeatThrottle : heartbeatThrottle + gracePeriod

        // Set the last typing time only if it's the current user.
        if isSelf {
            let currentTime = Date()
            lastTypingTime = currentTime
            logger.log(message: "Set last typing time: \(currentTime)", level: .debug)
        }

        logger.log(message: "Starting timer for clientID: \(clientID) with interval: \(timerDuration)", level: .debug)

        // (CHA-T13b2) Each additional typing heartbeat from the same client shall reset the (CHA-T13b1) timeout.
        timerManager.setTimer(interval: timerDuration) { [weak self] in
            guard let self else {
                return
            }
            logger.log(message: "Typing timer expired for clientID: \(clientID)", level: .debug)

            // (CHA-T13b3) (1/2) If the (CHA-T13b1) timeout expires, the client shall remove the clientId from the typing set and emit a synthetic typing stop event for the given client.
            cancelTypingTimer(for: clientID, isSelf: isSelf)
            handler?()
        }
    }

    internal func cancelTypingTimer(for clientID: String, isSelf: Bool = false) {
        // Reset the last typing time only if it's the current user.
        if isSelf {
            logger.log(message: "Resetting last typing time", level: .debug)
            lastTypingTime = nil
        }

        guard let timer = timers[clientID] else {
            logger.log(message: "No typing timer to cancel for clientID: \(clientID)", level: .debug)
            return
        }

        logger.log(message: "Cancelling typing timer for clientID: \(clientID)", level: .debug)
        timer.cancelTimer()
        timers[clientID] = nil
    }

    internal func isTypingTimerActive(for clientID: String) -> Bool {
        guard let timer = timers[clientID] else {
            logger.log(message: "No typing timer to check for clientID: \(clientID)", level: .debug)
            return false
        }
        logger.log(message: "Checking if typing timer is active for clientID: \(clientID)", level: .debug)
        return timer.hasRunningTask()
    }

    internal func currentlyTypingClients() -> Set<String> {
        Set(timers.keys)
    }
}
