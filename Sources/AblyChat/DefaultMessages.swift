import Ably

internal final class DefaultMessages: Messages {
    internal let reactions: any MessageReactions

    private let channel: any InternalRealtimeChannelProtocol
    private let implementation: Implementation

    internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI, roomName: String, options: MessagesOptions = .init(), clientID: String, logger: InternalLogger) {
        self.channel = channel
        reactions = DefaultMessageReactions(channel: channel, chatAPI: chatAPI, roomName: roomName, options: options, clientID: clientID, logger: logger)
        implementation = .init(channel: channel, chatAPI: chatAPI, roomName: roomName, clientID: clientID, logger: logger)
    }

    internal func subscribe(_ callback: @escaping @MainActor (ChatMessageEvent) -> Void) -> MessageSubscriptionResponseProtocol {
        implementation.subscribe(callback)
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

        // Continuously updated channel's attach serial to pickup by a new subscription or a history call.
        private var currentSubscriptionPoint: String?

        // Keeps subscription start point to retrive upon user's history request. Defaults to currentSubscriptionPoint above.
        private var subscriptionPoints: [UUID: String] = [:]

        private func updateCurrentSubscriptionPoint() {
            currentSubscriptionPoint = channel.properties.attachSerial
            _ = channel.on { [weak self] stateChange in
                guard let self else {
                    return
                }
                if stateChange.current == .attached, !stateChange.resumed {
                    currentSubscriptionPoint = channel.properties.attachSerial
                    subscriptionPoints.removeAll()
                }
            }
        }

        internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI, roomName: String, clientID: String, logger: InternalLogger) {
            self.channel = channel
            self.chatAPI = chatAPI
            self.roomName = roomName
            self.clientID = clientID
            self.logger = logger
            updateCurrentSubscriptionPoint()
        }

        // (CHA-M4) Messages can be received via a subscription in realtime.
        internal func subscribe(_ callback: @escaping @MainActor (ChatMessageEvent) -> Void) -> MessageSubscriptionResponseProtocol {
            logger.log(message: "Subscribing to messages", level: .debug)
            // (CHA-M4c) When a realtime message with name set to message.created is received, it is translated into a message event, which contains a type field with the event type as well as a message field containing the Message Struct. This event is then broadcast to all subscribers.
            // (CHA-M4d) If a realtime message with an unknown name is received, the SDK shall silently discard the message, though it may log at DEBUG or TRACE level.
            // (CHA-M4k) Incoming realtime events that are malformed (unknown field should be ignored) shall not be emitted to subscribers.
            let eventListener = channel.subscribe(RealtimeMessageName.chatMessage.rawValue) { [logger] message in
                guard let action = MessageAction.fromRealtimeAction(message.action) else {
                    logger.log(message: "Received incoming message with unsupported action: \(message.action)", level: .info) // CHA-M4m5
                    return
                }

                let ablyCocoaData = message.data ?? [:] // CHA-M4k2
                let data = JSONValue(ablyCocoaData: ablyCocoaData).objectValue ?? [:] // CHA-M4k2

                let text = data["text"]?.stringValue ?? "" // CHA-M4k1
                let metadata = (try? data.optionalObjectValueForKey("metadata")) ?? [:] // CHA-M4k2

                let extras = if let ablyCocoaExtras = message.extras {
                    JSONValue.objectFromAblyCocoaExtras(ablyCocoaExtras)
                } else {
                    [String: JSONValue]() // CHA-M4k2
                }

                let headers = (try? extras.optionalObjectValueForKey("headers"))?.compactMapValues { try? HeadersValue(jsonValue: $0) } ?? [:] // CHA-M4k2

                let message = Message(
                    serial: message.serial ?? "", // CHA-M4k1
                    action: action,
                    clientID: message.clientId ?? "", // CHA-M4k1
                    text: text,
                    createdAt: message.timestamp ?? Date(timeIntervalSince1970: 0), // CHA-M4k4
                    metadata: metadata,
                    headers: headers,
                    version: message.version ?? "", // CHA-M4k1
                    timestamp: message.timestamp ?? Date(), // CHA-M4k3,
                    operation: message.operation?.toChatOperation()
                )

                let event = ChatMessageEvent(message: message)
                callback(event)
            }
            let uuid = UUID()
            // (CHA-M5a) If a subscription is added when the underlying realtime channel is ATTACHED, then the subscription point is the current channelSerial of the realtime channel.
            if channel.state == .attached {
                subscriptionPoints[uuid] = channel.properties.channelSerial
            }
            let subscription = MessageSubscriptionResponse(
                chatAPI: chatAPI,
                roomName: roomName,
                subscriptionStartSerial: { [weak self] () throws(InternalError) in
                    guard let self else {
                        throw MessagesError.noReferenceToSelf.toInternalError()
                    }
                    if channel.state == .attached, let startSerial = subscriptionPoints[uuid] {
                        return startSerial
                    }
                    let startSerial = try await resolveSubscriptionStart()
                    subscriptionPoints[uuid] = startSerial
                    return startSerial
                },
                unsubscribe: { [weak self, channel] in
                    channel.unsubscribe(eventListener)
                    self?.subscriptionPoints.removeValue(forKey: uuid)
                }
            )
            return subscription
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

        private func resolveSubscriptionStart() async throws(InternalError) -> String {
            logger.log(message: "Resolving subscription start serial", level: .debug)
            // (CHA-M5a) If a subscription is added when the underlying realtime channel is ATTACHED, then the subscription point is the current channelSerial of the realtime channel.
            if channel.state == .attached, let currentSubscriptionPoint {
                logger.log(message: "Channel is attached, returning subscription point serial: \(currentSubscriptionPoint)", level: .debug)
                return currentSubscriptionPoint
            }

            // (CHA-M5b) If a subscription is added when the underlying realtime channel is in any other state, then its subscription point becomes the attachSerial at the the point of channel attachment.
            return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, InternalError>, Never>) in
                _ = channel.once { [weak self] stateChange in
                    guard let self else {
                        return
                    }
                    switch stateChange.current {
                    case .attached:
                        // CHA-M5c If a channel leaves the ATTACHED state and then re-enters ATTACHED with resumed=false, then it must be assumed that messages have been missed. The subscription point of any subscribers must be reset to the attachSerial
                        // CHA-M5d If a channel UPDATE event is received and resumed=false, then it must be assumed that messages have been missed. The subscription point of any subscribers must be reset to the attachSerial
                        if let subscriptionPoint = stateChange.resumed ? channel.properties.channelSerial : channel.properties.attachSerial {
                            logger.log(message: "Channel is attached, returning serial: \(subscriptionPoint)", level: .debug)
                            continuation.resume(returning: .success(subscriptionPoint))
                        } else {
                            logger.log(message: "Channel is attached, but attachSerial is not defined", level: .error)
                            continuation.resume(returning: .failure(ARTErrorInfo.create(withCode: 40000, status: 400, message: "Channel is attached, but attachSerial is not defined").toInternalError()))
                        }
                    case .failed, .suspended:
                        // TODO: Revisit as part of https://github.com/ably-labs/ably-chat-swift/issues/32
                        logger.log(message: "Channel failed to attach", level: .error)
                        let errorCodeCase = ErrorCode.CaseThatImpliesFixedStatusCode.badRequest
                        continuation.resume(
                            returning: .failure(
                                ARTErrorInfo.create(
                                    withCode: errorCodeCase.toNumericErrorCode.rawValue,
                                    status: errorCodeCase.statusCode,
                                    message: "Channel failed to attach"
                                )
                                .toInternalError()
                            )
                        )
                    default:
                        break
                    }
                }
            }.get()
        }
    }
}

private extension ARTMessageOperation {
    func toChatOperation() -> MessageOperation {
        MessageOperation(
            clientID: clientId ?? "", // CHA-M4k1
            description: descriptionText,
            metadata: JSONValue(ablyCocoaData: metadata ?? [:]).objectValue // CHA-M4k2
        )
    }
}
