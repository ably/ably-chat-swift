import Ably

// Wraps the MessageSubscription with the message serial of when the subscription was attached or resumed.
private struct MessageSubscriptionWrapper {
    let subscription: MessageSubscription
    var serial: String
}

// TODO: Don't have a strong understanding of why @MainActor is needed here. Revisit as part of https://github.com/ably-labs/ably-chat-swift/issues/83
@MainActor
internal final class DefaultMessages: Messages, EmitsDiscontinuities {
    private let roomID: String
    public nonisolated let featureChannel: FeatureChannel
    private let chatAPI: ChatAPI
    private let clientID: String
    private let logger: InternalLogger

    // UUID acts as a unique identifier for each listener/subscription. MessageSubscriptionWrapper houses the subscription and the serial of when it was attached or resumed.
    private var subscriptionPoints: [UUID: MessageSubscriptionWrapper] = [:]

    internal nonisolated init(featureChannel: FeatureChannel, chatAPI: ChatAPI, roomID: String, clientID: String, logger: InternalLogger) async {
        self.featureChannel = featureChannel
        self.chatAPI = chatAPI
        self.roomID = roomID
        self.clientID = clientID
        self.logger = logger

        // Implicitly handles channel events and therefore listners within this class. Alternative is to explicitly call something like `DefaultMessages.start()` which makes the SDK more cumbersome to interact with. This class is useless without kicking off this flow so I think leaving it here is suitable.
        // "Calls to instance method 'handleChannelEvents(roomId:)' from outside of its actor context are implicitly asynchronous" hence the `await` here.
        await handleChannelEvents(roomId: roomID)
    }

    internal nonisolated var channel: any RealtimeChannelProtocol {
        featureChannel.channel
    }

    // (CHA-M4) Messages can be received via a subscription in realtime.
    internal func subscribe(bufferingPolicy: BufferingPolicy) async throws -> MessageSubscription {
        logger.log(message: "Subscribing to messages", level: .debug)
        let uuid = UUID()
        let serial = try await resolveSubscriptionStart()
        let messageSubscription = MessageSubscription(
            bufferingPolicy: bufferingPolicy
        ) { [weak self] queryOptions in
            guard let self else { throw MessagesError.noReferenceToSelf }
            return try await getBeforeSubscriptionStart(uuid, params: queryOptions)
        }

        // (CHA-M4a) A subscription can be registered to receive incoming messages. Adding a subscription has no side effects on the status of the room or the underlying realtime channel.
        subscriptionPoints[uuid] = .init(subscription: messageSubscription, serial: serial)

        // (CHA-M4c) When a realtime message with name set to message.created is received, it is translated into a message event, which contains a type field with the event type as well as a message field containing the Message Struct. This event is then broadcast to all subscribers.
        // (CHA-M4d) If a realtime message with an unknown name is received, the SDK shall silently discard the message, though it may log at DEBUG or TRACE level.
        // (CHA-M5k) Incoming realtime events that are malformed (unknown field should be ignored) shall not be emitted to subscribers.
        let eventListener = channel.subscribe(RealtimeMessageName.chatMessage.rawValue) { message in
            Task {
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

                let metadata = try data.optionalObjectValueForKey("metadata")

                let headers: Headers? = if let headersJSONObject = try extras.optionalObjectValueForKey("headers") {
                    try headersJSONObject.mapValues { try HeadersValue(jsonValue: $0) }
                } else {
                    nil
                }

                guard let action = MessageAction.fromRealtimeAction(message.action) else {
                    return
                }

                let message = Message(
                    serial: serial,
                    action: action,
                    clientID: clientID,
                    roomID: self.roomID,
                    text: text,
                    createdAt: message.timestamp,
                    metadata: metadata ?? .init(),
                    headers: headers ?? .init()
                )

                messageSubscription.emit(message)
            }
        }

        messageSubscription.addTerminationHandler {
            Task {
                await MainActor.run { [weak self] () in
                    guard let self else {
                        return
                    }
                    channel.unsubscribe(eventListener)
                    subscriptionPoints.removeValue(forKey: uuid)
                }
            }
        }

        return messageSubscription
    }

    // (CHA-M6a) A method must be exposed that accepts the standard Ably REST API query parameters. It shall call the “REST API”#rest-fetching-messages and return a PaginatedResult containing messages, which can then be paginated through.
    internal func get(options: QueryOptions) async throws -> any PaginatedResult<Message> {
        try await chatAPI.getMessages(roomId: roomID, params: options)
    }

    internal func send(params: SendMessageParams) async throws -> Message {
        try await chatAPI.sendMessage(roomId: roomID, params: params)
    }

    // (CHA-M7) Users may subscribe to discontinuity events to know when there’s been a break in messages that they need to resolve. Their listener will be called when a discontinuity event is triggered from the room lifecycle.
    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent> {
        await featureChannel.onDiscontinuity(bufferingPolicy: bufferingPolicy)
    }

    private func getBeforeSubscriptionStart(_ uuid: UUID, params: QueryOptions) async throws -> any PaginatedResult<Message> {
        guard let subscriptionPoint = subscriptionPoints[uuid]?.serial else {
            throw ARTErrorInfo.create(
                withCode: 40000,
                status: 400,
                message: "cannot query history; listener has not been subscribed yet"
            )
        }

        // (CHA-M5f) This method must accept any of the standard history query options, except for direction, which must always be backwards.
        var queryOptions = params
        queryOptions.orderBy = .newestFirst // newestFirst is equivalent to backwards

        // (CHA-M5g) The subscribers subscription point must be additionally specified (internally, by us) in the fromSerial query parameter.
        queryOptions.fromSerial = subscriptionPoint

        return try await chatAPI.getMessages(roomId: roomID, params: queryOptions)
    }

    private func handleChannelEvents(roomId _: String) {
        // (CHA-M5c) If a channel leaves the ATTACHED state and then re-enters ATTACHED with resumed=false, then it must be assumed that messages have been missed. The subscription point of any subscribers must be reset to the attachSerial.
        channel.on(.attached) { [weak self] stateChange in
            Task {
                do {
                    try await self?.handleAttach(fromResume: stateChange.resumed)
                } catch {
                    throw ARTErrorInfo.create(from: error)
                }
            }
        }

        // (CHA-M4d) If a channel UPDATE event is received and resumed=false, then it must be assumed that messages have been missed. The subscription point of any subscribers must be reset to the attachSerial.
        channel.on(.update) { [weak self] stateChange in
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

    private func resolveSubscriptionStart() async throws -> String {
        logger.log(message: "Resolving subscription start", level: .debug)
        // (CHA-M5a) If a subscription is added when the underlying realtime channel is ATTACHED, then the subscription point is the current channelSerial of the realtime channel.
        if channel.state == .attached {
            if let channelSerial = channel.properties.channelSerial {
                logger.log(message: "Channel is attached, returning channelSerial: \(channelSerial)", level: .debug)
                return channelSerial
            } else {
                let error = ARTErrorInfo.create(withCode: 40000, status: 400, message: "channel is attached, but channelSerial is not defined")
                logger.log(message: "Error resolving subscription start: \(error)", level: .error)
                throw error
            }
        }

        // (CHA-M5b) If a subscription is added when the underlying realtime channel is in any other state, then its subscription point becomes the attachSerial at the the point of channel attachment.
        return try await serialOnChannelAttach()
    }

    // Always returns the attachSerial and not the channelSerial to also serve (CHA-M5c) - If a channel leaves the ATTACHED state and then re-enters ATTACHED with resumed=false, then it must be assumed that messages have been missed. The subscription point of any subscribers must be reset to the attachSerial.
    private func serialOnChannelAttach() async throws -> String {
        logger.log(message: "Resolving serial on channel attach", level: .debug)
        // If the state is already 'attached', return the attachSerial immediately
        if channel.state == .attached {
            if let attachSerial = channel.properties.attachSerial {
                logger.log(message: "Channel is attached, returning attachSerial: \(attachSerial)", level: .debug)
                return attachSerial
            } else {
                let error = ARTErrorInfo.create(withCode: 40000, status: 400, message: "Channel is attached, but attachSerial is not defined")
                logger.log(message: "Error resolving serial on channel attach: \(error)", level: .error)
                throw error
            }
        }

        // (CHA-M5b) If a subscription is added when the underlying realtime channel is in any other state, then its subscription point becomes the attachSerial at the the point of channel attachment.
        return try await withCheckedThrowingContinuation { continuation in
            // avoids multiple invocations of the continuation
            var nillableContinuation: CheckedContinuation<String, any Error>? = continuation

            channel.on { [weak self] stateChange in
                guard let self else {
                    return
                }

                switch stateChange.current {
                case .attached:
                    // Handle successful attachment
                    if let attachSerial = channel.properties.attachSerial {
                        logger.log(message: "Channel is attached, returning attachSerial: \(attachSerial)", level: .debug)
                        nillableContinuation?.resume(returning: attachSerial)
                    } else {
                        logger.log(message: "Channel is attached, but attachSerial is not defined", level: .error)
                        nillableContinuation?.resume(throwing: ARTErrorInfo.create(withCode: 40000, status: 400, message: "Channel is attached, but attachSerial is not defined"))
                    }
                    nillableContinuation = nil
                case .failed, .suspended:
                    // TODO: Revisit as part of https://github.com/ably-labs/ably-chat-swift/issues/32
                    logger.log(message: "Channel failed to attach", level: .error)
                    let errorCodeCase = ErrorCode.CaseThatImpliesFixedStatusCode.messagesAttachmentFailed
                    nillableContinuation?.resume(
                        throwing: ARTErrorInfo.create(
                            withCode: errorCodeCase.toNumericErrorCode.rawValue,
                            status: errorCodeCase.statusCode,
                            message: "Channel failed to attach"
                        )
                    )
                    nillableContinuation = nil
                default:
                    break
                }
            }
        }
    }

    internal enum MessagesError: Error {
        case noReferenceToSelf
    }
}
