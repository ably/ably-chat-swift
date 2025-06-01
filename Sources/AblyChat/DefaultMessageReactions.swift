import Ably

@MainActor
internal final class DefaultMessageReactions: MessageReactions {
    private let channel: any InternalRealtimeChannelProtocol
    private let roomID: String
    private let logger: InternalLogger
    private let clientID: String
    private let chatAPI: ChatAPI

    private var defaultReaction: MessageReactionType

    internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI, roomID: String, options: MessagesOptions, clientID: String, logger: InternalLogger) {
        self.channel = channel
        self.chatAPI = chatAPI
        self.roomID = roomID
        self.logger = logger
        self.clientID = clientID
        defaultReaction = options.defaultMessageReactionType
    }

    internal func add(for messageSerial: String, params: AddMessageReactionParams) async throws(ARTErrorInfo) {
        do {
            var apiParams = params
            if apiParams.type == nil {
                apiParams.type = defaultReaction
            }
            if apiParams.type == .multiple, apiParams.count == nil {
                apiParams.count = 1
            }

            let response = try await chatAPI.addReactionForMessage(messageSerial, roomID: roomID, params: apiParams)

            logger.log(message: "Added message reaction (annotation serial: \(response.serial))", level: .info)
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    internal func delete(for messageSerial: String, params: DeleteMessageReactionParams) async throws(ARTErrorInfo) {
        do {
            var apiParams = params
            if apiParams.type == nil {
                apiParams.type = defaultReaction
            }

            let response = try await chatAPI.deleteReactionForMessage(messageSerial, roomID: roomID, params: apiParams)

            logger.log(message: "Deleted message reaction (annotation serial: \(response.serial))", level: .info)
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    // CHA-MR6
    @discardableResult
    internal func subscribe(_ callback: @escaping @MainActor @Sendable (MessageReactionSummaryEvent) -> Void) -> SubscriptionHandle {
        logger.log(message: "Subscribing to message reaction summary events", level: .debug)

        let eventListener = channel.subscribe { [logger] message in
            do {
                guard message.action == .messageSummary else {
                    return
                }
                guard let summaryData = message.summary else {
                    return
                }
                guard let summaryJson = JSONValue(ablyCocoaData: summaryData).objectValue else {
                    logger.log(message: "Received summary event with invalid JSON: \(message)", level: .warn)
                    return
                }
                guard let messageSerial = message.serial else {
                    logger.log(message: "Received summary without serial: \(message)", level: .warn)
                    return
                }

                let summaryEvent = try MessageReactionSummaryEvent(
                    type: MessageReactionEvent.summary,
                    summary: MessageReactionSummary(
                        messageSerial: messageSerial,
                        values: summaryJson
                    )
                )

                logger.log(message: "Emitting reaction summary event: \(summaryEvent)", level: .debug)

                callback(summaryEvent)
            } catch {
                logger.log(message: "Error processing incoming reaction message: \(error)", level: .error)
            }
        }

        return SubscriptionHandle { [weak self] in
            self?.channel.unsubscribe(eventListener)
        }
    }

    // CHA-MR7
    @discardableResult
    internal func subscribeRaw(_ callback: @escaping @MainActor @Sendable (MessageReactionRawEvent) -> Void) -> SubscriptionHandle {
        logger.log(message: "Subscribing to reaction events", level: .debug)

        let eventListener = channel.annotations.subscribe { [clientID, logger] annotation in
            logger.log(message: "Received reaction (message annotation): \(annotation)", level: .debug)
            do {
                guard let messageSerial = annotation.messageSerial else {
                    logger.log(message: "Received annotation without messageSerial: \(annotation)", level: .warn)
                    return
                }

                guard let annotationRawType = annotation.type, let annotationType = MessageReactionType(rawValue: annotationRawType) else {
                    logger.log(message: "Received annotation without annotation's type: \(annotation)", level: .debug)
                    return
                }

                let reactionEventType = annotation.action == .delete ? MessageReactionEvent.delete : MessageReactionEvent.create

                var reactionName = annotation.name
                if reactionName == nil {
                    if reactionEventType == .delete, annotationType == .unique {
                        // deletes of type unique are allowed to have no name
                        reactionName = ""
                    } else {
                        logger.log(message: "Received annotation without name: \(annotation)", level: .debug)
                        return
                    }
                }

                guard let timestamp = annotation.timestamp else {
                    throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming annotation without timestamp")
                }

                guard let annotationClientID = annotation.clientId else {
                    throw ARTErrorInfo.create(withCode: 50000, status: 500, message: "Received incoming annotation without clientId")
                }

                let reactionEvent = MessageReactionRawEvent(
                    type: reactionEventType,
                    timestamp: timestamp,
                    reaction: MessageReaction(
                        type: annotationType,
                        name: reactionName ?? "",
                        messageSerial: messageSerial,
                        count: annotation.count?.intValue ?? (annotation.action == .create && annotationType == .multiple ? 1 : nil),
                        clientID: annotationClientID,
                        isSelf: annotationClientID == clientID
                    )
                )

                logger.log(message: "Emitting message reaction event: \(reactionEvent)", level: .debug)

                callback(reactionEvent)
            } catch {
                logger.log(message: "Error processing incoming message reaction: \(error)", level: .error)
            }
        }

        return SubscriptionHandle { [weak self] in
            self?.channel.unsubscribe(eventListener)
        }
    }
}
