import Ably

internal final class DefaultTyping: Typing {
    private let implementation: Implementation

    // (CHA-T14) Multiple asynchronous calls to keystroke/stop typing must eventually converge to a consistent state.
    // (CHA-TM14a) When a call to keystroke or stop is made, it should attempt to acquire a mutex lock.
    // (CHA-TM14b) Once the lock is acquired, if another call is made to either function, the second call shall be queued and wait until it can acquire the lock before executing.
    // (CHA-TM14b1) During this time, each new subsequent call to either function shall abort the previously queued call. In doing so, there shall only ever be one pending call and while the mutex is held, thus the most recent call shall “win” and execute once the mutex is released.
    private let keyboardTaskQueue = TaskQueue(executionStyle: .latestOnly)

    // (CHA-T10a) A grace period shall be set by the client (the grace period on the CHA-T10 heartbeat interval when receiving events). The default value shall be set to 2000ms.
    private let gracePeriod: TimeInterval = 2

    internal init(channel: any InternalRealtimeChannelProtocol, roomID: String, clientID: String, logger: InternalLogger, heartbeatThrottle: TimeInterval) {
        implementation = .init(channel: channel, roomID: roomID, clientID: clientID, logger: logger, heartbeatThrottle: heartbeatThrottle, gracePeriod: gracePeriod)
    }

    // (CHA-T6) Users may subscribe to typing events – updates to a set of clientIDs that are typing. This operation, like all subscription operations, has no side-effects in relation to room lifecycle.
    internal func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<TypingEvent> {
        implementation.subscribe(bufferingPolicy: bufferingPolicy)
    }

    // (CHA-T9) Users may retrieve a list of the currently typing client IDs.
    internal func get() async throws(ARTErrorInfo) -> Set<String> {
        try await implementation.get()
    }

    // (CHA-T4) Users may indicate that they have started typing using the keystroke method.
    internal func keystroke() async throws(ARTErrorInfo) {
        keyboardTaskQueue.enqueue { [weak self] in
            try? await self?.implementation.keystroke()
        }
    }

    // (CHA-T5) Users may explicitly indicate that they have stopped typing using stop method.
    internal func stop() async throws(ARTErrorInfo) {
        keyboardTaskQueue.enqueue { [weak self] in
            try? await self?.implementation.stopTyping()
        }
    }

    /// This class exists to make sure that the internals of the SDK only access ably-cocoa via the `InternalRealtimeChannelProtocol` interface. It does this by removing access to the `channel` property that exists as part of the public API of the `Typing` protocol, making it unlikely that we accidentally try to call the `ARTRealtimeChannelProtocol` interface. We can remove this `Implementation` class when we remove the feature-level `channel` property in https://github.com/ably/ably-chat-swift/issues/242.
    @MainActor
    private final class Implementation {
        private let channel: any InternalRealtimeChannelProtocol
        private let roomID: String
        private let clientID: String
        private let logger: InternalLogger
        private let heartbeatThrottle: TimeInterval
        private let gracePeriod: TimeInterval

        private let typingTimerManager: TypingTimerManager

        internal init(channel: any InternalRealtimeChannelProtocol, roomID: String, clientID: String, logger: InternalLogger, heartbeatThrottle: TimeInterval, gracePeriod: TimeInterval) {
            self.channel = channel
            self.roomID = roomID
            self.clientID = clientID
            self.logger = logger
            self.heartbeatThrottle = heartbeatThrottle
            self.gracePeriod = gracePeriod

            typingTimerManager = TypingTimerManager(heartbeatThrottle: heartbeatThrottle, gracePeriod: gracePeriod, logger: logger)
        }

        internal func subscribe(bufferingPolicy: BufferingPolicy) -> Subscription<TypingEvent> {
            // (CHA-T6a) Users may provide a listener to subscribe to typing event V2 in a chat room.
            let subscription = Subscription<TypingEvent>(bufferingPolicy: bufferingPolicy)

            let startedEventListener = channel.subscribe(TypingEvents.started.rawValue) { [weak self] message in
                guard let self, let messageClientID = message.clientId else {
                    return
                }

                logger.log(message: "Received started typing message: \(message)", level: .debug)

                if !typingTimerManager.isTypingTimerActive(for: messageClientID) {
                    // (CHA-T13b1) If the event represents a new client typing, then the chat client shall add the typer to the typing set and a emit the updated set to any subscribers. It shall also begin a timeout that is the sum of the CHA-T10 heartbeat interval and the CHA-T10a graсe period.
                    // (CHA-T4a4) Upon successful publish, a heartbeat timer shall be set according to the CHA-T10 timeout interval.
                    typingTimerManager.startTypingTimer(
                        for: messageClientID,
                        isSelf: messageClientID == clientID
                    ) { [weak self] in
                        guard let self else {
                            return
                        }
                        // (CHA-T13b3) (2/2) If the (CHA-T13b1) timeout expires, the client shall remove the clientId from the typing set and emit a synthetic typing stop event for the given client.
                        subscription.emit(
                            TypingEvent(currentlyTyping: typingTimerManager.currentlyTypingClients(), change: .init(clientId: messageClientID, type: .stopped))
                        )
                    }

                    // (CHA-T13) When a typing event (typing.start or typing.stop) is received from the realtime client, the Chat client shall emit appropriate events to the user.
                    subscription.emit(
                        TypingEvent(
                            currentlyTyping: typingTimerManager.currentlyTypingClients(),
                            change: .init(clientId: messageClientID, type: .started)
                        )
                    )
                }
            }

            let stoppedEventListener = channel.subscribe(TypingEvents.stopped.rawValue) { [weak self] message in
                guard let self, let messageClientID = message.clientId else {
                    return
                }

                logger.log(message: "Received stopped typing message: \(message)", level: .debug)

                // (CHA-T13b5) If the event represents that a client has stopped typing, but the clientId for that client is not present in the typing set, then the event is ignored.
                if typingTimerManager.isTypingTimerActive(for: messageClientID) {
                    // (CHA-T13b4) If the event represents a client that has stopped typing, then the chat client shall remove the clientId from the typing set and emit the updated set to any subscribers. It shall also cancel the (CHA-T13b1) timeout for the typing client.
                    typingTimerManager.cancelTypingTimer(for: messageClientID)

                    // (CHA-T13) When a typing event (typing.start or typing.stop) is received from the realtime client, the Chat client shall emit appropriate events to the user.
                    subscription.emit(
                        TypingEvent(
                            currentlyTyping: typingTimerManager.currentlyTypingClients(),
                            change: .init(clientId: messageClientID, type: .stopped)
                        )
                    )
                }
            }

            // (CHA-T6b) A subscription to typing may be removed, after which it shall receive no further events.
            subscription.addTerminationHandler { [weak self] in
                Task { @MainActor in
                    if let startedEventListener {
                        self?.channel.unsubscribe(startedEventListener)
                    }
                    if let stoppedEventListener {
                        self?.channel.unsubscribe(stoppedEventListener)
                    }
                }
            }
            return subscription
        }

        internal func get() async throws(ARTErrorInfo) -> Set<String> {
            typingTimerManager.currentlyTypingClients()
        }

        internal func keystroke() async throws(ARTErrorInfo) {
            let shouldPublish = typingTimerManager.shouldPublishTyping()

            guard shouldPublish else {
                // (CHA-T4c) If typing is already in progress (i.e. a heartbeat timer set according to CHA-T4a4 exists and has not expired):
                // (CHA-T4c1) The client must not send a typing.started event.
                logger.log(message: "Throttle time hasn't passed, skipping typing event.", level: .debug)
                return
            }

            try await publishStartedEvent()
        }

        private func publishStartedEvent() async throws(ARTErrorInfo) {
            logger.log(message: "Starting typing indicator for client: \(clientID)", level: .debug)
            do {
                // (CHA-T4a3) The client shall publish an ephemeral message to the channel with the name field set to typing.started, the format of which is detailed here.
                try await channel.publish(
                    TypingEvents.started.rawValue,
                    data: nil,
                    extras: ["ephemeral": true]
                )
            } catch {
                // (CHA-T4a5) The client must wait for the publish to succeed or fail before returning the result to the caller. If the publish fails, the client must throw an ErrorInfo.
                throw error.toARTErrorInfo()
            }
        }

        internal func stopTyping() async throws(ARTErrorInfo) {
            do throws(InternalError) {
                logger.log(message: "Stopping typing indicator for client: \(clientID)", level: .debug)
                if typingTimerManager.isTypingTimerActive(for: clientID) {
                    // (CHA-T5d) The client shall publish an ephemeral message to the channel with the name field set to typing.stopped, the format of which is detailed here.
                    try await channel.publish(
                        TypingEvents.stopped.rawValue,
                        data: nil,
                        extras: ["ephemeral": true]
                    )

                    // (CHA-T5e) On successfully publishing the message in (CHA-T5d), the CHA-T10 timer shall be unset.
                    typingTimerManager.cancelTypingTimer(for: clientID, isSelf: true)
                } else {
                    // (CHA-T5a) If typing is not in progress, this operation is a no-op.
                    logger.log(message: "User is not typing. No need to stop timer.", level: .debug)
                    return
                }
            } catch {
                // (CHA-T5d1) The client must wait for the publish to succeed or fail before returning the result to the caller. If the publish fails, the client must throw an ErrorInfo.
                throw error.toARTErrorInfo()
            }
        }
    }
}
