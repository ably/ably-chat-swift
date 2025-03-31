import Foundation

// (CHA-T14) Multiple asynchronous calls to keystroke/stop typing must eventually converge to a consistent state.
// (CHA-TM14a) When a call to keystroke or stop is made, it should attempt to acquire a mutex lock.
// (CHA-TM14b) Once the lock is acquired, if another call is made to either function, the second call shall be queued and wait until it can acquire the lock before executing.
// (CHA-TM14b1) During this time, each new subsequent call to either function shall abort the previously queued call. In doing so, there shall only ever be one pending call and while the mutex is held, thus the most recent call shall “win” and execute once the mutex is released.

/** The above spec points are handled implicitly because we use an actor `TypingTimerManager`, which in turn uses another actor `TimerManager`. This results in function calls to `TimerManager` needing to be awaited, which in turn require function calls from `TypingTimerManager` to be awaited. These awaited functions e.g. `startTypingTimer` ensure a "lock" is in place and subsequent calls are ignored, alleviating any concerns for race conditions and/or hammering. */
internal final actor TypingTimerManager {
    private let heartbeatThrottle: TimeInterval
    private let timeout: TimeInterval
    private let logger: InternalLogger

    // Stores all the active timers for each client, where String is the clientID.
    private var timers = [String: TimerManager]()

    // Stores only the current user's last typing time
    private var lastTypingTime: Date?

    internal init(heartbeatThrottle: TimeInterval = 10, timeout: TimeInterval = 2, logger: InternalLogger) {
        self.heartbeatThrottle = heartbeatThrottle
        self.timeout = timeout
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

    internal func startTypingTimer(for clientID: String, isSelf: Bool = false, handler: (@Sendable () -> Void)? = nil) async {
        let timerManager = timers[clientID] ?? TimerManager()
        timers[clientID] = timerManager

        // Set the last typing time only if it's the current user.
        if isSelf {
            let currentTime = Date()
            lastTypingTime = currentTime
            logger.log(message: "Set last typing time: \(currentTime)", level: .debug)
        }

        logger.log(message: "Starting timer with interval: \(heartbeatThrottle + timeout)", level: .debug)

        // (CHA-T13b2) Each additional typing heartbeat from the same client shall reset the (CHA-T13b1) timeout.
        await timerManager.setTimer(interval: heartbeatThrottle + timeout) { [weak self] in
            Task {
                // (CHA-T10a1) If a typing.start event is not received within this period, the client shall assume that the user has stopped typing. For example, if the client has not received a typing.start event within 12000ms of the last heartbeat (10s heartbeat interval plus 2s grace period), the client shall assume that the user has stopped typing.
                guard let self else {
                    return
                }
                self.logger.log(message: "Typing timer expired for clientID: \(clientID)", level: .debug)

                // (CHA-T13b3) (1/2) If the (CHA-T13b1) timeout expires, the client shall remove the clientId from the typing set and emit a synthetic typing stop event for the given client.
                await self.cancelTypingTimer(for: clientID, isSelf: isSelf)
                handler?()
            }
        }
    }

    internal func cancelTypingTimer(for clientID: String, isSelf: Bool = false) async {
        // Reset the last typing time only if it's the current user.
        if isSelf {
            logger.log(message: "Resetting last typing time", level: .debug)
            lastTypingTime = nil
        }

        guard let timer = timers[clientID] else {
            // (CHA-T13b5) If the event represents that a client has stopped typing, but the clientId for that client is not present in the typing set, then the event is ignored.
            logger.log(message: "No typing timer to cancel for clientID: \(clientID)", level: .debug)
            return
        }

        logger.log(message: "Cancelling typing timer for clientID: \(clientID)", level: .debug)
        await timer.cancelTimer()
        timers[clientID] = nil
    }

    internal func isTypingTimerActive(for clientID: String) async -> Bool {
        guard let timer = timers[clientID] else {
            logger.log(message: "No typing timer to check for clientID: \(clientID)", level: .debug)
            return false
        }
        logger.log(message: "Checking if typing timer is active for clientID: \(clientID)", level: .debug)
        return await timer.hasRunningTask()
    }

    internal func currentlyTypingClients() -> Set<String> {
        Set(timers.keys)
    }
}
