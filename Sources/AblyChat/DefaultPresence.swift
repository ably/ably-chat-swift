import Ably

internal final class DefaultPresence: Presence {
    private let channel: any InternalRealtimeChannelProtocol
    private let roomLifecycleManager: any RoomLifecycleManager
    private let roomName: String
    private let clientID: String
    private let logger: InternalLogger
    private let options: PresenceOptions

    internal init(channel: any InternalRealtimeChannelProtocol, roomLifecycleManager: any RoomLifecycleManager, roomName: String, clientID: String, logger: InternalLogger, options: PresenceOptions) {
        self.channel = channel
        self.roomLifecycleManager = roomLifecycleManager
        self.roomName = roomName
        self.clientID = clientID
        self.logger = logger
        self.options = options
    }

    internal func get() async throws(ARTErrorInfo) -> [PresenceMember] {
        do throws(InternalError) {
            logger.log(message: "Getting presence", level: .debug)

            // CHA-PR6b to CHA-PR6f
            do {
                try await roomLifecycleManager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .presence)
            } catch {
                logger.log(message: "Error waiting to be able to perform presence get operation: \(error)", level: .error)
                throw error
            }

            let members: [PresenceMessage]
            do {
                members = try await channel.presence.get()
            } catch {
                logger.log(message: error.message, level: .error)
                throw error
            }
            return try processPresenceGet(members: members)
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    internal func get(params: PresenceParams) async throws(ARTErrorInfo) -> [PresenceMember] {
        do throws(InternalError) {
            logger.log(message: "Getting presence with params: \(params)", level: .debug)

            // CHA-PR6b to CHA-PR6f
            do {
                try await roomLifecycleManager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .presence)
            } catch {
                logger.log(message: "Error waiting to be able to perform presence get operation: \(error)", level: .error)
                throw error
            }

            let members: [PresenceMessage]
            do {
                members = try await channel.presence.get(params.asARTRealtimePresenceQuery())
            } catch {
                logger.log(message: error.message, level: .error)
                throw error
            }
            return try processPresenceGet(members: members)
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    // (CHA-PR5) It must be possible to query if a given clientId is in the presence set.
    internal func isUserPresent(clientID: String) async throws(ARTErrorInfo) -> Bool {
        do throws(InternalError) {
            logger.log(message: "Checking if user is present with clientID: \(clientID)", level: .debug)

            // CHA-PR6b to CHA-PR6f
            do {
                try await roomLifecycleManager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .presence)
            } catch {
                logger.log(message: "Error waiting to be able to perform presence get operation: \(error)", level: .error)
                throw error
            }

            let members: [PresenceMessage]
            do {
                members = try await channel.presence.get(ARTRealtimePresenceQuery(clientId: clientID, connectionId: nil))
            } catch {
                logger.log(message: error.message, level: .error)
                throw error
            }

            return !members.isEmpty
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    internal func enter(data: PresenceData) async throws(ARTErrorInfo) {
        try await enter(optionalData: data)
    }

    internal func enter() async throws(ARTErrorInfo) {
        try await enter(optionalData: nil)
    }

    // (CHA-PR3a) Users may choose to enter presence, optionally providing custom data to enter with. The overall presence data must retain the format specified in CHA-PR2.
    private func enter(optionalData data: PresenceData?) async throws(ARTErrorInfo) {
        do throws(InternalError) {
            logger.log(message: "Entering presence", level: .debug)

            // CHA-PR3c to CHA-PR3g
            do {
                try await roomLifecycleManager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .presence)
            } catch {
                logger.log(message: "Error waiting to be able to perform presence enter operation: \(error)", level: .error)
                throw error
            }

            do {
                try await channel.presence.enterClient(clientID, data: data)
            } catch {
                logger.log(message: "Error entering presence: \(error)", level: .error)
                throw error
            }
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    internal func update(data: PresenceData) async throws(ARTErrorInfo) {
        try await update(optionalData: data)
    }

    internal func update() async throws(ARTErrorInfo) {
        try await update(optionalData: nil)
    }

    // (CHA-PR10a) Users may choose to update their presence data, optionally providing custom data to update with. The overall presence data must retain the format specified in CHA-PR2.
    private func update(optionalData data: PresenceData?) async throws(ARTErrorInfo) {
        do throws(InternalError) {
            logger.log(message: "Updating presence", level: .debug)

            // CHA-PR10c to CHA-PR10g
            do {
                try await roomLifecycleManager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .presence)
            } catch {
                logger.log(message: "Error waiting to be able to perform presence update operation: \(error)", level: .error)
                throw error
            }

            do {
                try await channel.presence.update(data)
            } catch {
                logger.log(message: "Error updating presence: \(error)", level: .error)
                throw error
            }
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    internal func leave(data: PresenceData) async throws(ARTErrorInfo) {
        try await leave(optionalData: data)
    }

    internal func leave() async throws(ARTErrorInfo) {
        try await leave(optionalData: nil)
    }

    // (CHA-PR4a) Users may choose to leave presence, which results in them being removed from the Realtime presence set.
    internal func leave(optionalData data: PresenceData?) async throws(ARTErrorInfo) {
        do throws(InternalError) {
            logger.log(message: "Leaving presence", level: .debug)

            // CHA-PR6b to CHA-PR6f
            do {
                try await roomLifecycleManager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: .presence)
            } catch {
                logger.log(message: "Error waiting to be able to perform presence leave operation: \(error)", level: .error)
                throw error
            }

            do {
                try await channel.presence.leave(data)
            } catch {
                logger.log(message: "Error leaving presence: \(error)", level: .error)
                throw error
            }
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    private func fatalErrorIfEnableEventsDisabled() {
        // CHA-PR7d (we use a fatalError for this programmer error, which is the idiomatic thing to do for Swift)
        guard options.enableEvents else {
            fatalError("In order to be able to subscribe to presence events, please set enableEvents to true in the room's presence options.")
        }
    }

    // (CHA-PR7a) Users may provide a listener to subscribe to all presence events in a room.
    // (CHA-PR7b) Users may provide a listener and a list of selected presence events, to subscribe to just those events in a room.
    internal func subscribe(event: PresenceEventType, _ callback: @escaping @MainActor (PresenceEvent) -> Void) -> SubscriptionProtocol {
        fatalErrorIfEnableEventsDisabled()

        logger.log(message: "Subscribing to presence events", level: .debug)

        let eventListener = channel.presence.subscribe(event.toARTPresenceAction()) { [processPresenceSubscribe, logger] message in
            logger.log(message: "Received presence message: \(message)", level: .debug)
            do {
                // processPresenceSubscribe is logging so we don't need to log here
                let presenceEvent = try processPresenceSubscribe(PresenceMessage(ablyCocoaPresenceMessage: message), event)
                callback(presenceEvent)
            } catch {
                // note: this replaces some existing code that also didn't handle the processPresenceSubscribe error; I suspect not intentional, will leave whoever writes the tests for this class to see what's going on
            }
        }

        return Subscription { [weak self] in
            if let eventListener {
                self?.channel.presence.unsubscribe(eventListener)
            }
        }
    }

    internal func subscribe(events: [PresenceEventType], _ callback: @escaping @MainActor (PresenceEvent) -> Void) -> SubscriptionProtocol {
        fatalErrorIfEnableEventsDisabled()

        logger.log(message: "Subscribing to presence events", level: .debug)

        let eventListeners = events.map { event in
            channel.presence.subscribe(event.toARTPresenceAction()) { [processPresenceSubscribe, logger] message in
                logger.log(message: "Received presence message: \(message)", level: .debug)
                do {
                    let presenceEvent = try processPresenceSubscribe(PresenceMessage(ablyCocoaPresenceMessage: message), event)
                    callback(presenceEvent)
                } catch {
                    // note: this replaces some existing code that also didn't handle the processPresenceSubscribe error; I suspect not intentional, will leave whoever writes the tests for this class to see what's going on
                }
            }
        }

        return Subscription { [weak self] in
            for eventListener in eventListeners {
                if let eventListener {
                    self?.channel.presence.unsubscribe(eventListener)
                }
            }
        }
    }

    private func processPresenceGet(members: [PresenceMessage]) throws(InternalError) -> [PresenceMember] {
        let presenceMembers = try members.map { member throws(InternalError) in
            let presenceMember = PresenceMember(
                clientID: member.clientId ?? "", // CHA-M4k1
                data: member.data,
                extras: member.extras,
                updatedAt: member.timestamp ?? Date() // CHA-M4k3
            )

            logger.log(message: "Returning presence member: \(presenceMember)", level: .debug)
            return presenceMember
        }
        return presenceMembers
    }

    private func processPresenceSubscribe(_ message: PresenceMessage, for event: PresenceEventType) throws -> PresenceEvent {
        let member = PresenceMember(
            clientID: message.clientId ?? "", // CHA-M4k1
            data: message.data,
            extras: message.extras,
            updatedAt: message.timestamp ?? Date() // CHA-M4k3
        )

        let presenceEvent = PresenceEvent(
            type: event,
            member: member
        )

        logger.log(message: "Returning presence event: \(presenceEvent)", level: .debug)
        return presenceEvent
    }
}
