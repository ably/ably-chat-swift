import Ably

// Wraps the MessageSubscription with the message serial of when the subscription was attached or resumed.
private struct MessageSubscriptionWrapper {
    let subscription: MessageSubscriptionResponse
    var serial: String
}

internal final class DefaultMessages: Messages {
    internal let reactions: any MessageReactions

    private let channel: any InternalRealtimeChannelProtocol
    private let implementation: Implementation

    internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI, roomName: String, options: MessagesOptions = .init(), clientID: String, logger: InternalLogger) {
        self.channel = channel
        reactions = DefaultMessageReactions(channel: channel, chatAPI: chatAPI, roomName: roomName, options: options, clientID: clientID, logger: logger)
        implementation = .init(channel: channel, chatAPI: chatAPI, roomName: roomName, clientID: clientID, logger: logger)
    }

    internal func subscribe(_ callback: @escaping @MainActor (ChatMessageEvent) -> Void) async throws(ARTErrorInfo) -> MessageSubscriptionResponseProtocol {
        try await implementation.subscribe(callback)
    }

    internal func history(options: QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message> {
        try await implementation.history(options: options)
    }

    internal func send(params: SendMessageParams) async throws(ARTErrorInfo) -> Message {
        try await implementation.send(params: params)
    }

    internal func update(newMessage: Message, description: String?, metadata: OperationMetadata?) async throws(ARTErrorInfo) -> Message {
        try await implementation.update(newMessage: newMessage, description: description, metadata: metadata)
    }

    internal func delete(message: Message, params: DeleteMessageParams) async throws(ARTErrorInfo) -> Message {
        try await implementation.delete(message: message, params: params)
    }

    internal enum MessagesError: Error {
        case noReferenceToSelf
    }

    /// This class exists to make sure that the internals of the SDK only access ably-cocoa via the `InternalRealtimeChannelProtocol` interface. It does this by removing access to the `channel` property that exists as part of the public API of the `Messages` protocol, making it unlikely that we accidentally try to call the `ARTRealtimeChannelProtocol` interface. We can remove this `Implementation` class when we remove the feature-level `channel` property in https://github.com/ably/ably-chat-swift/issues/242.
    @MainActor
    private final class Implementation: Sendable {
        private let roomName: String
        private let channel: any InternalRealtimeChannelProtocol
        private let chatAPI: ChatAPI
        private let clientID: String
        private let logger: InternalLogger

        // UUID acts as a unique identifier for each listener/subscription. MessageSubscriptionWrapper houses the subscription and the serial of when it was attached or resumed.
        private var subscriptionPoints: [UUID: MessageSubscriptionWrapper] = [:]

        internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI, roomName: String, clientID: String, logger: InternalLogger) {
            self.channel = channel
            self.chatAPI = chatAPI
            self.roomName = roomName
            self.clientID = clientID
            self.logger = logger

            // Implicitly handles channel events and therefore listners within this class. Alternative is to explicitly call something like `DefaultMessages.start()` which makes the SDK more cumbersome to interact with. This class is useless without kicking off this flow so I think leaving it here is suitable.
            handleChannelEvents(roomName: roomName)
        }

        // (CHA-M4) Messages can be received via a subscription in realtime.
        internal func subscribe(_ callback: @escaping @MainActor (ChatMessageEvent) -> Void) async throws(ARTErrorInfo) -> MessageSubscriptionResponseProtocol {
            do {
                logger.log(message: "Subscribing to messages", level: .debug)

                // (CHA-M4c) When a realtime message with name set to message.created is received, it is translated into a message event, which contains a type field with the event type as well as a message field containing the Message Struct. This event is then broadcast to all subscribers.
                // (CHA-M4d) If a realtime message with an unknown name is received, the SDK shall silently discard the message, though it may log at DEBUG or TRACE level.
                // (CHA-M5k) Incoming realtime events that are malformed (unknown field should be ignored) shall not be emitted to subscribers.
                let eventListener = channel.subscribe(RealtimeMessageName.chatMessage.rawValue) { message in
                    do {
                        // TODO: Revisit errors thrown as part of https://github.com/ably-labs/ably-chat-swift/issues/32
                        guard let ablyCocoaData = message.data,
                              let data = JSONValue(ablyCocoaData: ablyCocoaData).objectValue,
                              let text = data["text"]?.stringValue
                        else {
                            throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without data or text")
                        }

                        guard let ablyCocoaExtras = message.extras else {
                            throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without extras")
                        }

                        let extras = JSONValue.objectFromAblyCocoaExtras(ablyCocoaExtras)

                        guard let serial = message.serial else {
                            throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without serial")
                        }

                        guard let clientID = message.clientId else {
                            throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without clientId")
                        }

                        guard let version = message.version else {
                            throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message without version")
                        }

                        let metadata = try data.optionalObjectValueForKey("metadata")

                        let headers: Headers? = if let headersJSONObject = try extras.optionalObjectValueForKey("headers") {
                            try headersJSONObject.mapValues { try HeadersValue(jsonValue: $0) }
                        } else {
                            nil
                        }

                        guard let action = MessageAction.fromRealtimeAction(message.action) else {
                            return
                        }

                        // `message.operation?.toChatOperation()` is throwing but the linter prefers putting the `try` on Message initialization instead of having it nested.
                        let message = try Message(
                            serial: serial,
                            action: action,
                            clientID: clientID,
                            text: text,
                            createdAt: message.timestamp,
                            metadata: metadata ?? .init(),
                            headers: headers ?? .init(),
                            version: version,
                            timestamp: message.timestamp,
                            operation: message.operation?.toChatOperation()
                        )

                        let event = ChatMessageEvent(message: message)
                        callback(event)
                    } catch {
                        // note: this replaces some existing code that also didn't handle any thrown error; I suspect not intentional, will leave whoever writes the tests for this class to see what's going on
                    }
                }

                let uuid = UUID()
                let serial = try await resolveSubscriptionStart()

                // coderabbitai suggestion (remove "guard let self" and hold ref to channel):
                // > If DefaultMessages is deallocated before the client calls unsubscribe(), the listener remains registered because the closure early-returns. Store the eventListener and always call channel.unsubscribe regardless of self
                let messageSubscriptionResponse = MessageSubscriptionResponse { [weak self, channel] in
                    channel.unsubscribe(eventListener)
                    self?.subscriptionPoints.removeValue(forKey: uuid)
                } historyBeforeSubscribe: { [weak self] queryOptions throws(ARTErrorInfo) in
                    guard let self else { throw MessagesError.noReferenceToSelf.toInternalError().toARTErrorInfo() }
                    do throws(InternalError) {
                        return try await getBeforeSubscriptionStart(uuid, params: queryOptions)
                    } catch {
                        throw error.toARTErrorInfo()
                    }
                }

                // (CHA-M4a) A subscription can be registered to receive incoming messages. Adding a subscription has no side effects on the status of the room or the underlying realtime channel.
                subscriptionPoints[uuid] = .init(subscription: messageSubscriptionResponse, serial: serial)

                return messageSubscriptionResponse
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        // (CHA-M6a) A method must be exposed that accepts the standard Ably REST API query parameters. It shall call the "REST API"#rest-fetching-messages and return a PaginatedResult containing messages, which can then be paginated through.
        internal func history(options: QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message> {
            do {
                return try await chatAPI.getMessages(roomName: roomName, params: options)
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        internal func send(params: SendMessageParams) async throws(ARTErrorInfo) -> Message {
            do {
                return try await chatAPI.sendMessage(roomName: roomName, params: params)
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        internal func update(newMessage: Message, description: String?, metadata: OperationMetadata?) async throws(ARTErrorInfo) -> Message {
            do {
                return try await chatAPI.updateMessage(roomName: roomName, with: newMessage, description: description, metadata: metadata)
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        internal func delete(message: Message, params: DeleteMessageParams) async throws(ARTErrorInfo) -> Message {
            do {
                return try await chatAPI.deleteMessage(roomName: roomName, message: message, params: params)
            } catch {
                throw error.toARTErrorInfo()
            }
        }

        private func getBeforeSubscriptionStart(_ uuid: UUID, params: QueryOptions) async throws(InternalError) -> any PaginatedResult<Message> {
            guard let subscriptionPoint = subscriptionPoints[uuid]?.serial else {
                throw ARTErrorInfo.create(
                    withCode: 40000,
                    status: 400,
                    message: "cannot query history; listener has not been subscribed yet"
                )
                .toInternalError()
            }

            // (CHA-M5f) This method must accept any of the standard history query options, except for direction, which must always be backwards.
            var queryOptions = params
            queryOptions.orderBy = .newestFirst // newestFirst is equivalent to backwards

            // (CHA-M5g) The subscribers subscription point must be additionally specified (internally, by us) in the fromSerial query parameter.
            queryOptions.fromSerial = subscriptionPoint

            return try await chatAPI.getMessages(roomName: roomName, params: queryOptions)
        }

        private func handleChannelEvents(roomName _: String) {
            // (CHA-M5c) If a channel leaves the ATTACHED state and then re-enters ATTACHED with resumed=false, then it must be assumed that messages have been missed. The subscription point of any subscribers must be reset to the attachSerial.
            _ = channel.on(.attached) { [weak self] stateChange in
                Task {
                    do {
                        try await self?.handleAttach(fromResume: stateChange.resumed)
                    } catch {
                        throw ARTErrorInfo.create(from: error)
                    }
                }
            }

            // (CHA-M4d) If a channel UPDATE event is received and resumed=false, then it must be assumed that messages have been missed. The subscription point of any subscribers must be reset to the attachSerial.
            _ = channel.on(.update) { [weak self] stateChange in
                Task {
                    do {
                        try await self?.handleAttach(fromResume: stateChange.resumed)
                    } catch {
                        throw ARTErrorInfo.create(from: error)
                    }
                }
            }
        }

        private func handleAttach(fromResume: Bool) async throws {
            logger.log(message: "Handling attach", level: .debug)
            // Do nothing if we have resumed as there is no discontinuity in the message stream
            if fromResume {
                logger.log(message: "Channel has resumed, no need to handle attach", level: .debug)
                return
            }

            do {
                let serialOnChannelAttach = try await serialOnChannelAttach()

                for uuid in subscriptionPoints.keys {
                    logger.log(message: "Resetting subscription point for listener: \(uuid)", level: .debug)
                    subscriptionPoints[uuid]?.serial = serialOnChannelAttach
                }
            } catch {
                logger.log(message: "Error handling attach: \(error)", level: .error)
                throw ARTErrorInfo.create(from: error)
            }
        }

        private func resolveSubscriptionStart() async throws(InternalError) -> String {
            logger.log(message: "Resolving subscription start", level: .debug)
            // (CHA-M5a) If a subscription is added when the underlying realtime channel is ATTACHED, then the subscription point is the current channelSerial of the realtime channel.
            if await channel.state == .attached {
                if let channelSerial = channel.properties.channelSerial {
                    logger.log(message: "Channel is attached, returning channelSerial: \(channelSerial)", level: .debug)
                    return channelSerial
                } else {
                    let error = ARTErrorInfo.create(withCode: 40000, status: 400, message: "channel is attached, but channelSerial is not defined")
                    logger.log(message: "Error resolving subscription start: \(error)", level: .error)
                    throw error.toInternalError()
                }
            }

            // (CHA-M5b) If a subscription is added when the underlying realtime channel is in any other state, then its subscription point becomes the attachSerial at the the point of channel attachment.
            return try await serialOnChannelAttach()
        }

        // Always returns the attachSerial and not the channelSerial to also serve (CHA-M5c) - If a channel leaves the ATTACHED state and then re-enters ATTACHED with resumed=false, then it must be assumed that messages have been missed. The subscription point of any subscribers must be reset to the attachSerial.
        private func serialOnChannelAttach() async throws(InternalError) -> String {
            logger.log(message: "Resolving serial on channel attach", level: .debug)
            // If the state is already 'attached', return the attachSerial immediately
            if await channel.state == .attached {
                if let attachSerial = channel.properties.attachSerial {
                    logger.log(message: "Channel is attached, returning attachSerial: \(attachSerial)", level: .debug)
                    return attachSerial
                } else {
                    let error = ARTErrorInfo.create(withCode: 40000, status: 400, message: "Channel is attached, but attachSerial is not defined")
                    logger.log(message: "Error resolving serial on channel attach: \(error)", level: .error)
                    throw error.toInternalError()
                }
            }

            // (CHA-M5b) If a subscription is added when the underlying realtime channel is in any other state, then its subscription point becomes the attachSerial at the the point of channel attachment.
            return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, InternalError>, Never>) in
                // avoids multiple invocations of the continuation
                var nillableContinuation: CheckedContinuation<Result<String, InternalError>, Never>? = continuation

                _ = channel.on { [weak self] stateChange in
                    guard let self else {
                        return
                    }

                    switch stateChange.current {
                    case .attached:
                        // Handle successful attachment
                        if let attachSerial = channel.properties.attachSerial {
                            logger.log(message: "Channel is attached, returning attachSerial: \(attachSerial)", level: .debug)
                            nillableContinuation?.resume(returning: .success(attachSerial))
                        } else {
                            logger.log(message: "Channel is attached, but attachSerial is not defined", level: .error)
                            nillableContinuation?.resume(returning: .failure(ARTErrorInfo.create(withCode: 40000, status: 400, message: "Channel is attached, but attachSerial is not defined").toInternalError()))
                        }
                        nillableContinuation = nil
                    case .failed, .suspended:
                        // TODO: Revisit as part of https://github.com/ably-labs/ably-chat-swift/issues/32
                        logger.log(message: "Channel failed to attach", level: .error)
                        let errorCodeCase = ErrorCode.CaseThatImpliesFixedStatusCode.badRequest
                        nillableContinuation?.resume(
                            returning: .failure(
                                ARTErrorInfo.create(
                                    withCode: errorCodeCase.toNumericErrorCode.rawValue,
                                    status: errorCodeCase.statusCode,
                                    message: "Channel failed to attach"
                                )
                                .toInternalError()
                            )
                        )
                        nillableContinuation = nil
                    default:
                        break
                    }
                }
            }.get()
        }
    }
}

private extension ARTMessageOperation {
    func toChatOperation() throws -> MessageOperation {
        guard let clientId else {
            throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming message where Operation clientId is nil")
        }
        return MessageOperation(
            clientID: clientId,
            description: descriptionText,
            metadata: metadata != nil ? JSONValue(ablyCocoaData: metadata!).objectValue : nil
        )
    }
}
