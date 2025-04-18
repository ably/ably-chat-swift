import Ably

internal final class DefaultPresence: Presence, EmitsDiscontinuities {
    private let featureChannel: FeatureChannel
    private let implementation: Implementation

    internal init(featureChannel: FeatureChannel, roomID: String, clientID: String, logger: InternalLogger) {
        self.featureChannel = featureChannel
        implementation = .init(featureChannel: featureChannel, roomID: roomID, clientID: clientID, logger: logger)
    }

    internal nonisolated var channel: any RealtimeChannelProtocol {
        featureChannel.channel.underlying
    }

    internal func get() async throws(ARTErrorInfo) -> [PresenceMember] {
        try await implementation.get()
    }

    internal func get(params: PresenceParams) async throws(ARTErrorInfo) -> [PresenceMember] {
        try await implementation.get(params: params)
    }

    internal func isUserPresent(clientID: String) async throws(ARTErrorInfo) -> Bool {
        try await implementation.isUserPresent(clientID: clientID)
    }

    internal func enter(data: PresenceData) async throws(ARTErrorInfo) {
        try await implementation.enter(data: data)
    }

    internal func update(data: PresenceData) async throws(ARTErrorInfo) {
        try await implementation.update(data: data)
    }

    internal func leave(data: PresenceData) async throws(ARTErrorInfo) {
        try await implementation.leave(data: data)
    }

    internal func enter() async throws(ARTErrorInfo) {
        try await implementation.enter()
    }

    internal func update() async throws(ARTErrorInfo) {
        try await implementation.update()
    }

    internal func leave() async throws(ARTErrorInfo) {
        try await implementation.leave()
    }

    internal func subscribe(event: PresenceEventType, bufferingPolicy: BufferingPolicy) -> Subscription<PresenceEvent> {
        implementation.subscribe(event: event, bufferingPolicy: bufferingPolicy)
    }

    internal func subscribe(events: [PresenceEventType], bufferingPolicy: BufferingPolicy) -> Subscription<PresenceEvent> {
        implementation.subscribe(events: events, bufferingPolicy: bufferingPolicy)
    }

    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        implementation.onDiscontinuity(bufferingPolicy: bufferingPolicy)
    }

    /// This class exists to make sure that the internals of the SDK only access ably-cocoa via the `InternalRealtimeChannelProtocol` interface. It does this by removing access to the `channel` property that exists as part of the public API of the `Presence` protocol, making it unlikely that we accidentally try to call the `ARTRealtimeChannelProtocol` interface. We can remove this `Implementation` class when we remove the feature-level `channel` property in https://github.com/ably/ably-chat-swift/issues/242.
    @MainActor
    private final class Implementation: Sendable {
        private let featureChannel: FeatureChannel
        private let roomID: String
        private let clientID: String
        private let logger: InternalLogger

        internal init(featureChannel: FeatureChannel, roomID: String, clientID: String, logger: InternalLogger) {
            self.roomID = roomID
            self.featureChannel = featureChannel
            self.clientID = clientID
            self.logger = logger
        }

        // (CHA-PR6) It must be possible to retrieve all the @Members of the presence set. The behaviour depends on the current room status, as presence operations in a Realtime Client cause implicit attaches.
        internal func get() async throws(ARTErrorInfo) -> [PresenceMember] {
            do throws(InternalError) {
                logger.log(message: "Getting presence", level: .debug)

                // CHA-PR6b to CHA-PR6f
                do {
                    try await featureChannel.waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature.presence)
                } catch {
                    logger.log(message: "Error waiting to be able to perform presence get operation: \(error)", level: .error)
                    throw error
                }

                let members: [PresenceMessage]
                do {
                    members = try await featureChannel.channel.presence.get()
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
                    try await featureChannel.waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature.presence)
                } catch {
                    logger.log(message: "Error waiting to be able to perform presence get operation: \(error)", level: .error)
                    throw error
                }

                let members: [PresenceMessage]
                do {
                    members = try await featureChannel.channel.presence.get(params.asARTRealtimePresenceQuery())
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
                    try await featureChannel.waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature.presence)
                } catch {
                    logger.log(message: "Error waiting to be able to perform presence get operation: \(error)", level: .error)
                    throw error
                }

                let members: [PresenceMessage]
                do {
                    members = try await featureChannel.channel.presence.get(ARTRealtimePresenceQuery(clientId: clientID, connectionId: nil))
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
                    try await featureChannel.waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature.presence)
                } catch {
                    logger.log(message: "Error waiting to be able to perform presence enter operation: \(error)", level: .error)
                    throw error
                }

                let dto = PresenceDataDTO(userCustomData: data)

                do {
                    try await featureChannel.channel.presence.enterClient(clientID, data: dto.toJSONValue)
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
                    try await featureChannel.waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature.presence)
                } catch {
                    logger.log(message: "Error waiting to be able to perform presence update operation: \(error)", level: .error)
                    throw error
                }

                let dto = PresenceDataDTO(userCustomData: data)

                do {
                    try await featureChannel.channel.presence.update(dto.toJSONValue)
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
                    try await featureChannel.waitToBeAbleToPerformPresenceOperations(requestedByFeature: RoomFeature.presence)
                } catch {
                    logger.log(message: "Error waiting to be able to perform presence leave operation: \(error)", level: .error)
                    throw error
                }

                let dto = PresenceDataDTO(userCustomData: data)

                do {
                    try await featureChannel.channel.presence.leave(dto.toJSONValue)
                } catch {
                    logger.log(message: "Error leaving presence: \(error)", level: .error)
                    throw error
                }
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        // (CHA-PR7a) Users may provide a listener to subscribe to all presence events in a room.
        // (CHA-PR7b) Users may provide a listener and a list of selected presence events, to subscribe to just those events in a room.
        internal func subscribe(event: PresenceEventType, bufferingPolicy: BufferingPolicy) -> Subscription<PresenceEvent> {
            logger.log(message: "Subscribing to presence events", level: .debug)
            let subscription = Subscription<PresenceEvent>(bufferingPolicy: bufferingPolicy)
            let eventListener = featureChannel.channel.presence.subscribe(event.toARTPresenceAction()) { [processPresenceSubscribe, logger] message in
                logger.log(message: "Received presence message: \(message)", level: .debug)
                do {
                    // processPresenceSubscribe is logging so we don't need to log here
                    let presenceEvent = try processPresenceSubscribe(PresenceMessage(ablyCocoaPresenceMessage: message), event)
                    subscription.emit(presenceEvent)
                } catch {
                    // note: this replaces some existing code that also didn't handle the processPresenceSubscribe error; I suspect not intentional, will leave whoever writes the tests for this class to see what's going on
                }
            }
            subscription.addTerminationHandler { [weak self] in
                if let eventListener {
                    Task { @MainActor in
                        self?.featureChannel.channel.presence.unsubscribe(eventListener)
                    }
                }
            }
            return subscription
        }

        internal func subscribe(events: [PresenceEventType], bufferingPolicy: BufferingPolicy) -> Subscription<PresenceEvent> {
            logger.log(message: "Subscribing to presence events", level: .debug)
            let subscription = Subscription<PresenceEvent>(bufferingPolicy: bufferingPolicy)

            let eventListeners = events.map { event in
                featureChannel.channel.presence.subscribe(event.toARTPresenceAction()) { [processPresenceSubscribe, logger] message in
                    logger.log(message: "Received presence message: \(message)", level: .debug)
                    do {
                        let presenceEvent = try processPresenceSubscribe(PresenceMessage(ablyCocoaPresenceMessage: message), event)
                        subscription.emit(presenceEvent)
                    } catch {
                        // note: this replaces some existing code that also didn't handle the processPresenceSubscribe error; I suspect not intentional, will leave whoever writes the tests for this class to see what's going on
                    }
                }
            }

            subscription.addTerminationHandler { [weak self] in
                Task { @MainActor in
                    for eventListener in eventListeners {
                        if let eventListener {
                            self?.featureChannel.channel.presence.unsubscribe(eventListener)
                        }
                    }
                }
            }

            return subscription
        }

        // (CHA-PR8) Users may subscribe to discontinuity events to know when there’s been a break in presence. Their listener will be called when a discontinuity event is triggered from the room lifecycle. For presence, there shouldn’t need to be user action as the underlying core SDK will heal the presence set.
        internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
            featureChannel.onDiscontinuity(bufferingPolicy: bufferingPolicy)
        }

        private func decodePresenceDataDTO(from presenceData: JSONValue?) throws(InternalError) -> PresenceDataDTO {
            guard let presenceData else {
                let error = ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without data")
                logger.log(message: error.message, level: .error)
                throw error.toInternalError()
            }

            do {
                return try PresenceDataDTO(jsonValue: presenceData)
            } catch {
                logger.log(message: "Failed to decode presence data DTO from \(presenceData), error \(error)", level: .error)
                throw error
            }
        }

        private func processPresenceGet(members: [PresenceMessage]) throws(InternalError) -> [PresenceMember] {
            let presenceMembers = try members.map { member throws(InternalError) in
                let presenceDataDTO = try decodePresenceDataDTO(from: member.data)

                guard let clientID = member.clientId else {
                    let error = ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without clientId")
                    logger.log(message: error.message, level: .error)
                    throw error.toInternalError()
                }

                guard let timestamp = member.timestamp else {
                    let error = ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without timestamp")
                    logger.log(message: error.message, level: .error)
                    throw error.toInternalError()
                }

                let presenceMember = PresenceMember(
                    clientID: clientID,
                    data: presenceDataDTO.userCustomData,
                    action: PresenceMember.Action(from: member.action),
                    extras: member.extras,
                    updatedAt: timestamp
                )

                logger.log(message: "Returning presence member: \(presenceMember)", level: .debug)
                return presenceMember
            }
            return presenceMembers
        }

        private func processPresenceSubscribe(_ message: PresenceMessage, for event: PresenceEventType) throws -> PresenceEvent {
            guard let clientID = message.clientId else {
                let error = ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without clientId")
                logger.log(message: error.message, level: .error)
                throw error
            }

            guard let timestamp = message.timestamp else {
                let error = ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without timestamp")
                logger.log(message: error.message, level: .error)
                throw error
            }

            let presenceDataDTO = try decodePresenceDataDTO(from: message.data)

            let presenceEvent = PresenceEvent(
                action: event,
                clientID: clientID,
                timestamp: timestamp,
                data: presenceDataDTO.userCustomData
            )

            logger.log(message: "Returning presence event: \(presenceEvent)", level: .debug)
            return presenceEvent
        }
    }
}
