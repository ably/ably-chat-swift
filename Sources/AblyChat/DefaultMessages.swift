import Ably

internal final class DefaultMessages: Messages {
    internal let reactions: DefaultMessageReactions

    private let channel: any InternalRealtimeChannelProtocol

    private let roomName: String
    private let chatAPI: ChatAPI
    private let logger: any InternalLogger

    private var currentSubscriptionPoint: String?
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

    internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI, roomName: String, options: MessagesOptions = .init(), logger: any InternalLogger) {
        self.channel = channel
        self.chatAPI = chatAPI
        self.roomName = roomName
        self.logger = logger
        reactions = DefaultMessageReactions(channel: channel, chatAPI: chatAPI, roomName: roomName, options: options, logger: logger)
        updateCurrentSubscriptionPoint()
    }

    internal func subscribe(_ callback: @escaping @MainActor (ChatMessageEvent) -> Void) -> some MessageSubscriptionResponse {
        logger.log(message: "Subscribing to messages", level: .debug)
        // (CHA-M4c) When a realtime message with name set to message.created is received, it is translated into a message event, which contains a type field with the event type as well as a message field containing the Message Struct. This event is then broadcast to all subscribers.
        // (CHA-M4d) If a realtime message with an unknown name is received, the SDK shall silently discard the message, though it may log at DEBUG or TRACE level.
        // (CHA-M4k) Incoming realtime events that are malformed (unknown field should be ignored) shall not be emitted to subscribers.
        let eventListener = channel.subscribe(RealtimeMessageName.chatMessage.rawValue) { [weak self] message in
            guard let self else {
                return
            }
            guard let action = ChatMessageAction.fromRealtimeAction(message.action) else {
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
            let version = message.version ?? .init()
            let timestamp = message.timestamp ?? Date(timeIntervalSince1970: 0) // CHA-M4k5
            let serial = message.serial ?? "" // CHA-M4k1

            let message = Message(
                serial: serial,
                action: action,
                clientID: message.clientId ?? "", // CHA-M4k1
                text: text,
                metadata: metadata,
                headers: headers,
                version: .init(
                    serial: version.serial ?? serial, // CHA-M4k6
                    timestamp: version.timestamp ?? timestamp, // CHA-M4k7
                    clientID: version.clientId ?? "", // CHA-M4k1
                    description: version.descriptionText,
                    metadata: version.metadata ?? [:], // CHA-M4k2
                ),
                timestamp: timestamp,
                // TODO: Not sure of correct behaviour here, see https://github.com/ably/ably-chat-swift/issues/391
                reactions: .empty,
            )

            let event = ChatMessageEvent(message: message)
            callback(event)
        }
        let uuid = UUID()
        // (CHA-M5a) If a subscription is added when the underlying realtime channel is ATTACHED, then the subscription point is the current channelSerial of the realtime channel.
        if channel.state == .attached {
            subscriptionPoints[uuid] = channel.properties.channelSerial
        }
        let subscription = DefaultMessageSubscriptionResponse(
            chatAPI: chatAPI,
            roomName: roomName,
            subscriptionStartSerial: { [weak self] () throws(ErrorInfo) in
                guard let self else {
                    throw InternalError.failedToResolveSubscriptionPointBecauseMessagesInstanceGone.toErrorInfo()
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
            },
        )
        return subscription
    }

    // (CHA-M6a) A method must be exposed that accepts the standard Ably REST API query parameters. It shall call the "REST API"#rest-fetching-messages and return a PaginatedResult containing messages, which can then be paginated through.
    internal func history(withParams params: HistoryParams) async throws(ErrorInfo) -> some PaginatedResult<Message> {
        try await chatAPI.getMessages(roomName: roomName, params: params)
    }

    internal func send(withParams params: SendMessageParams) async throws(ErrorInfo) -> Message {
        try await chatAPI.sendMessage(roomName: roomName, params: params)
    }

    internal func update(withSerial serial: String, params: UpdateMessageParams, details: OperationDetails?) async throws(ErrorInfo) -> Message {
        try await chatAPI.updateMessage(roomName: roomName, serial: serial, updateParams: params, details: details)
    }

    internal func delete(withSerial serial: String, details: OperationDetails?) async throws(ErrorInfo) -> Message {
        try await chatAPI.deleteMessage(roomName: roomName, serial: serial, details: details)
    }

    // (CHA-M13) A single message must be retrievable from the REST API.
    internal func get(withSerial serial: String) async throws(ErrorInfo) -> Message {
        try await chatAPI.getMessage(roomName: roomName, serial: serial)
    }

    private func resolveSubscriptionStart() async throws(ErrorInfo) -> String {
        logger.log(message: "Resolving subscription start serial", level: .debug)
        // (CHA-M5a) If a subscription is added when the underlying realtime channel is ATTACHED, then the subscription point is the current channelSerial of the realtime channel.
        if channel.state == .attached, let currentSubscriptionPoint {
            logger.log(message: "Channel is attached, returning subscription point serial: \(currentSubscriptionPoint)", level: .debug)
            return currentSubscriptionPoint
        }

        // (CHA-M5b) If a subscription is added when the underlying realtime channel is in any other state, then its subscription point becomes the attachSerial at the the point of channel attachment.
        return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, ErrorInfo>, Never>) in
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
                        continuation.resume(returning: .failure(InternalError.failedToResolveSubscriptionPointBecauseAttachSerialNotDefined.toErrorInfo()))
                    }
                case .failed, .suspended:
                    let error = InternalError.failedToResolveSubscriptionPointBecauseChannelFailedToAttach(cause: stateChange.reason)
                    logger.log(message: "\(error)", level: .error)
                    continuation.resume(returning: .failure(error.toErrorInfo()))
                default:
                    break
                }
            }
        }.get()
    }

    internal enum MessagesError: Error {
        case noReferenceToSelf
    }
}
