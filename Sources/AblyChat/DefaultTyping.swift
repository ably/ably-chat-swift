import Ably

internal final class DefaultTyping: Typing {
    private let featureChannel: FeatureChannel
    private let implementation: Implementation

    // (CHA-T10a) A grace period shall be set by the client (the grace period on the CHA-T10 heartbeat interval when receiving heartbeats). The value shall be set to 2000ms.
    private let timeout: TimeInterval = 2

    internal init(featureChannel: FeatureChannel, roomID: String, clientID: String, logger: InternalLogger, heartbeatThrottle: TimeInterval = 10) {
        self.featureChannel = featureChannel
        implementation = .init(featureChannel: featureChannel, roomID: roomID, clientID: clientID, logger: logger, heartbeatThrottle: heartbeatThrottle, timeout: timeout)
    }

    internal nonisolated var channel: any RealtimeChannelProtocol {
        featureChannel.channel.underlying
    }

    // (CHA-T6) Users may subscribe to typing events – updates to a set of clientIDs that are typing. This operation, like all subscription operations, has no side-effects in relation to room lifecycle.
    internal func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<TypingEvent> {
        await implementation.subscribe(bufferingPolicy: bufferingPolicy)
    }

    // (CHA-T9) Users may retrieve a list of the currently typing client IDs.
    internal func get() async throws(ARTErrorInfo) -> Set<String> {
        try await implementation.get()
    }

    // (CHA-T4) Users may indicate that they have started typing using the keystroke method.
    internal func keystroke() async throws(ARTErrorInfo) {
        try await implementation.keystroke()
    }

    // (CHA-T5) Users may explicitly indicate that they have stopped typing using stop method.
    internal func stop() async throws(ARTErrorInfo) {
        try await implementation.stopTyping()
    }

    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent> {
        await implementation.onDiscontinuity(bufferingPolicy: bufferingPolicy)
    }

    /// This class exists to make sure that the internals of the SDK only access ably-cocoa via the `InternalRealtimeChannelProtocol` interface. It does this by removing access to the `channel` property that exists as part of the public API of the `Typing` protocol, making it unlikely that we accidentally try to call the `ARTRealtimeChannelProtocol` interface. We can remove this `Implementation` class when we remove the feature-level `channel` property in https://github.com/ably/ably-chat-swift/issues/242.
    private final class Implementation: Sendable {
        private let featureChannel: FeatureChannel
        private let roomID: String
        private let clientID: String
        private let logger: InternalLogger
        private let heartbeatThrottle: TimeInterval
        private let timeout: TimeInterval

        private let typingTimerManager: TypingTimerManager

        internal init(featureChannel: FeatureChannel, roomID: String, clientID: String, logger: InternalLogger, heartbeatThrottle: TimeInterval, timeout: TimeInterval) {
            self.roomID = roomID
            self.featureChannel = featureChannel
            self.clientID = clientID
            self.logger = logger
            self.heartbeatThrottle = heartbeatThrottle
            self.timeout = timeout

            typingTimerManager = TypingTimerManager(heartbeatThrottle: heartbeatThrottle, timeout: timeout, logger: logger)
        }

        internal func subscribe(bufferingPolicy: BufferingPolicy) async -> Subscription<TypingEvent> {
            // (CHA-T6a) Users may provide a listener to subscribe to typing event V2 in a chat room.
            let subscription = Subscription<TypingEvent>(bufferingPolicy: bufferingPolicy)

            let startedEventListener = featureChannel.channel.subscribe(TypingEvents.started.rawValue) { [weak self] message in
                guard let self, let messageClientID = message.clientId else {
                    return
                }

                logger.log(message: "Received started typing message: \(message)", level: .debug)

                Task {
                    // (CHA-T13b1) If the event represents a new client typing, then the chat client shall add the typer to the typing set and a emit the updated set to any subscribers. It shall also begin a timeout that is the sum of the CHA-T10 heartbeat interval and the CHA-T10a graсe period.
                    // // (CHA-T4a4) Upon successful publish, a heartbeat timer shall be set according to the CHA-T10 timeout interval.
                    await typingTimerManager.startTypingTimer(
                        for: messageClientID,
                        isSelf: messageClientID == clientID
                    ) { [weak self] in
                        guard let self else {
                            return
                        }
                        Task {
                            // (CHA-T13b3) (2/2) If the (CHA-T13b1) timeout expires, the client shall remove the clientId from the typing set and emit a synthetic typing stop event for the given client.
                            await subscription.emit(
                                TypingEvent(currentlyTyping: typingTimerManager.currentlyTypingClients(), change: .init(clientId: messageClientID, type: .stopped))
                            )
                        }
                    }

                    // (CHA-T13) When a typing event (typing.start or typing.stop) is received from the realtime client, the Chat client shall emit appropriate events to the user.
                    await subscription.emit(
                        TypingEvent(
                            currentlyTyping: typingTimerManager.currentlyTypingClients(),
                            change: .init(clientId: messageClientID, type: .started)
                        )
                    )
                }
            }

            let stoppedEventListener = featureChannel.channel.subscribe(TypingEvents.stopped.rawValue) { [weak self] message in
                guard let self, let messageClientID = message.clientId else {
                    return
                }

                logger.log(message: "Received stopped typing message: \(message)", level: .debug)

                Task {
                    // (CHA-T13b4) If the event represents a client that has stopped typing, then the chat client shall remove the clientId from the typing set and emit the updated set to any subscribers. It shall also cancel the (CHA-T13b1) timeout for the typing client.
                    await typingTimerManager.cancelTypingTimer(for: messageClientID)

                    // (CHA-T13) When a typing event (typing.start or typing.stop) is received from the realtime client, the Chat client shall emit appropriate events to the user.
                    await subscription.emit(
                        TypingEvent(
                            currentlyTyping: typingTimerManager.currentlyTypingClients(),
                            change: .init(clientId: messageClientID, type: .stopped)
                        )
                    )
                }
            }

            // (CHA-T6b) A subscription to typing may be removed, after which it shall receive no further events.
            subscription.addTerminationHandler { [weak self] in
                if let startedEventListener {
                    self?.featureChannel.channel.unsubscribe(startedEventListener)
                }
                if let stoppedEventListener {
                    self?.featureChannel.channel.unsubscribe(stoppedEventListener)
                }
            }
            return subscription
        }

        internal func get() async throws(ARTErrorInfo) -> Set<String> {
            await typingTimerManager.currentlyTypingClients()
        }

        internal func keystroke() async throws(ARTErrorInfo) {
            let shouldPublish = await typingTimerManager.shouldPublishTyping()

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
                try await featureChannel.channel.publish(
                    TypingEvents.started.rawValue,
                    data: nil,
                    extras: ["ephemeral": true]
                )
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        internal func stopTyping() async throws(ARTErrorInfo) {
            do throws(InternalError) {
                logger.log(message: "Stopping typing indicator for client: \(clientID)", level: .debug)
                if await typingTimerManager.isTypingTimerActive(for: clientID) {
                    // (CHA-T5d) The client shall publish an ephemeral message to the channel with the name field set to typing.stopped, the format of which is detailed here.
                    try await featureChannel.channel.publish(
                        TypingEvents.stopped.rawValue,
                        data: nil,
                        extras: ["ephemeral": true]
                    )

                    // (CHA-T5e) On successfully publishing the message in (CHA-T5d), the CHA-T10 timer shall be unset.
                    await typingTimerManager.cancelTypingTimer(for: clientID, isSelf: true)
                } else {
                    // (CHA-T5a) If typing is not in progress, this operation is a no-op.
                    logger.log(message: "User is not typing. No need to stop timer.", level: .debug)
                    return
                }
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        // (CHA-T7) Users may subscribe to discontinuity events to know when there’s been a break in typing indicators. Their listener will be called when a discontinuity event is triggered from the room lifecycle. For typing, there shouldn’t need to be user action as the underlying core SDK will heal the presence set.
        internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent> {
            await featureChannel.onDiscontinuity(bufferingPolicy: bufferingPolicy)
        }
    }
}

private final actor EventTracker {
    private var latestEventID: UUID = .init()

    func updateEventID() -> UUID {
        let newID = UUID()
        latestEventID = newID
        return newID
    }

    func isLatestEvent(_ eventID: UUID) -> Bool {
        latestEventID == eventID
    }
}
