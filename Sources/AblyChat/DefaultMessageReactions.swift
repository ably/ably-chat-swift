import Ably

@MainActor
internal final class DefaultMessageReactions: MessageReactions {
    private let channel: any InternalRealtimeChannelProtocol
    private let roomName: String
    private let logger: InternalLogger
    private let clientID: String
    private let chatAPI: ChatAPI

    private var defaultReaction: MessageReactionType

    internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI, roomName: String, options: MessagesOptions, clientID: String, logger: InternalLogger) {
        self.channel = channel
        self.chatAPI = chatAPI
        self.roomName = roomName
        self.logger = logger
        self.clientID = clientID
        defaultReaction = options.defaultMessageReactionType
    }

    // (CHA-MR4) Users should be able to send a reaction to a message via the `send` method of the `MessagesReactions` object
    internal func send(to messageSerial: String, params: SendMessageReactionParams) async throws(ARTErrorInfo) {
        do {
            var count = params.count
            if params.type == .multiple, params.count == nil {
                count = 1
            }

            let apiParams: ChatAPI.SendMessageReactionParams = .init(
                type: params.type ?? defaultReaction,
                name: params.name,
                count: count
            )
            let response = try await chatAPI.sendReactionToMessage(messageSerial, roomName: roomName, params: apiParams)

            logger.log(message: "Added message reaction (annotation serial: \(response.serial))", level: .info)
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    // (CHA-MR11) Users should be able to delete a reaction from a message via the `delete` method of the `MessagesReactions` object
    internal func delete(from messageSerial: String, params: DeleteMessageReactionParams) async throws(ARTErrorInfo) {
        let reactionType = params.type ?? defaultReaction
        if reactionType != .unique, params.name == nil {
            throw ARTErrorInfo(chatError: .unableDeleteReactionWithoutName(reactionType: reactionType.rawValue))
        }
        do {
            let apiParams: ChatAPI.DeleteMessageReactionParams = .init(
                type: reactionType,
                name: reactionType != .unique ? params.name : nil
            )
            let response = try await chatAPI.deleteReactionFromMessage(messageSerial, roomName: roomName, params: apiParams)

            logger.log(message: "Deleted message reaction (annotation serial: \(response.serial))", level: .info)
        } catch {
            throw error.toARTErrorInfo()
        }
    }

    // (CHA-MR6) Users must be able to subscribe to message reaction summaries via the subscribe method of the MessagesReactions object. The events emitted will be of type MessageReactionSummaryEvent.
    @discardableResult
    internal func subscribe(_ callback: @escaping @MainActor @Sendable (MessageReactionSummaryEvent) -> Void) -> SubscriptionProtocol {
        logger.log(message: "Subscribing to message reaction summary events", level: .debug)

        let eventListener = channel.subscribe { [logger] message in
            guard message.action == .messageSummary else {
                return
            }

            var summaryJson: [String: JSONValue]?
            if let summaryData = message.summary {
                summaryJson = JSONValue(ablyCocoaData: summaryData).objectValue
            }

            guard let messageSerial = message.serial else {
                logger.log(message: "Received summary without serial: \(message)", level: .warn)
                return
            }

            let summaryEvent = MessageReactionSummaryEvent(
                type: MessageReactionEvent.summary,
                summary: MessageReactionSummary(
                    messageSerial: messageSerial,
                    values: summaryJson ?? [:] // CHA-MR6a1
                )
            )

            logger.log(message: "Emitting reaction summary event: \(summaryEvent)", level: .debug)

            callback(summaryEvent)
        }

        return Subscription { [weak self] in
            self?.channel.unsubscribe(eventListener)
        }
    }

    // (CHA-MR7) Users must be able to subscribe to raw message reactions (as individual annotations) via the subscribeRaw method of the MessagesReactions object. The events emitted are of type MessageReactionRawEvent.
    @discardableResult
    internal func subscribeRaw(_ callback: @escaping @MainActor @Sendable (MessageReactionRawEvent) -> Void) -> SubscriptionProtocol {
        logger.log(message: "Subscribing to reaction events", level: .debug)

        let eventListener = channel.annotations.subscribe { [clientID, logger] annotation in
            logger.log(message: "Received reaction (message annotation): \(annotation)", level: .debug)

            guard let reactionEventType = MessageReactionEvent.fromAnnotationAction(annotation.action) else {
                logger.log(message: "Received reaction with unknown action: \(annotation.action)", level: .info) // CHA-MR7b2
                return
            }
            guard let reactionType = MessageReactionType(rawValue: annotation.type) else {
                logger.log(message: "Received reaction with unknown type: \(annotation.type)", level: .info) // CHA-MR7b1
                return
            }

            var reactionName = annotation.name
            if reactionName == nil {
                if reactionEventType == .delete, reactionType == .unique {
                    // deletes of type unique are allowed to have no name
                    reactionName = ""
                } else {
                    logger.log(message: "Received annotation without name: \(annotation)", level: .debug)
                    return
                }
            }

            let annotationClientID = annotation.clientId ?? "" // CHA-MR7b3

            let reactionEvent = MessageReactionRawEvent(
                type: reactionEventType,
                timestamp: annotation.timestamp,
                reaction: MessageReaction(
                    type: reactionType,
                    name: reactionName ?? "", // CHA-MR7b3
                    messageSerial: annotation.messageSerial,
                    count: annotation.count?.intValue ?? (annotation.action == .create && reactionType == .multiple ? 1 : nil),
                    clientID: annotationClientID,
                    isSelf: annotationClientID == clientID
                )
            )

            logger.log(message: "Emitting message reaction event: \(reactionEvent)", level: .debug)

            callback(reactionEvent)
        }
        return Subscription { [weak self] in
            self?.channel.unsubscribe(eventListener)
        }
    }
}
