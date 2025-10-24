import Ably

@MainActor
internal final class DefaultMessageReactions<Realtime: InternalRealtimeClientProtocol>: MessageReactions {
    private let channel: any InternalRealtimeChannelProtocol
    private let roomName: String
    private let logger: any InternalLogger
    private let chatAPI: ChatAPI<Realtime>
    private let options: MessagesOptions

    internal init(channel: any InternalRealtimeChannelProtocol, chatAPI: ChatAPI<Realtime>, roomName: String, options: MessagesOptions, logger: any InternalLogger) {
        self.channel = channel
        self.chatAPI = chatAPI
        self.roomName = roomName
        self.logger = logger
        self.options = options
    }

    // (CHA-MR4) Users should be able to send a reaction to a message via the `send` method of the `MessagesReactions` object
    internal func send(forMessageWithSerial messageSerial: String, params: SendMessageReactionParams) async throws(ErrorInfo) {
        var count = params.count
        if params.type == .multiple, params.count == nil {
            count = 1
        }

        let apiParams: ChatAPISendMessageReactionParams = .init(
            type: params.type ?? options.defaultMessageReactionType,
            name: params.name,
            count: count,
        )
        let response = try await chatAPI.sendReactionToMessage(messageSerial, roomName: roomName, params: apiParams)

        logger.log(message: "Added message reaction (annotation serial: \(response.serial))", level: .info)
    }

    // (CHA-MR11) Users should be able to delete a reaction from a message via the `delete` method of the `MessagesReactions` object
    internal func delete(fromMessageWithSerial messageSerial: String, params: DeleteMessageReactionParams) async throws(ErrorInfo) {
        let reactionType = params.type ?? options.defaultMessageReactionType
        if reactionType != .unique, params.name == nil {
            // CHA-MR11b1
            throw InternalError.unableDeleteReactionWithoutName(reactionType: reactionType.rawValue).toErrorInfo()
        }
        let apiParams: ChatAPIDeleteMessageReactionParams = .init(
            type: reactionType,
            name: reactionType != .unique ? params.name : nil,
        )
        let response = try await chatAPI.deleteReactionFromMessage(messageSerial, roomName: roomName, params: apiParams)

        logger.log(message: "Deleted message reaction (annotation serial: \(response.serial))", level: .info)
    }

    // (CHA-MR6) Users must be able to subscribe to message reaction summaries via the subscribe method of the MessagesReactions object. The events emitted will be of type MessageReactionSummaryEvent.
    @discardableResult
    internal func subscribe(_ callback: @escaping @MainActor @Sendable (MessageReactionSummaryEvent) -> Void) -> DefaultSubscription {
        logger.log(message: "Subscribing to message reaction summary events", level: .debug)

        let eventListener = channel.subscribe { [weak self] message in
            guard let self else {
                return
            }
            guard message.action == .messageSummary else {
                return
            }

            var summaryJson: [String: JSONValue]?
            if let summaryData = message.annotations?.summary {
                summaryJson = JSONValue(ablyCocoaData: summaryData).objectValue
            }

            guard let messageSerial = message.serial else {
                logger.log(message: "Received summary without serial: \(message)", level: .warn)
                return
            }

            let summaryEvent = MessageReactionSummaryEvent(
                type: MessageReactionSummaryEventType.summary,
                messageSerial: messageSerial,
                reactions: MessageReactionSummary(
                    values: summaryJson ?? [:], // CHA-MR6a1
                ),
            )

            logger.log(message: "Emitting reaction summary event: \(summaryEvent)", level: .debug)

            callback(summaryEvent)
        }

        return DefaultSubscription { [weak self] in
            self?.channel.unsubscribe(eventListener)
        }
    }

    // (CHA-MR7) Users must be able to subscribe to raw message reactions (as individual annotations) via the subscribeRaw method of the MessagesReactions object. The events emitted are of type MessageReactionRawEvent.
    @discardableResult
    internal func subscribeRaw(_ callback: @escaping @MainActor @Sendable (MessageReactionRawEvent) -> Void) -> DefaultSubscription {
        logger.log(message: "Subscribing to reaction events", level: .debug)
        guard options.rawMessageReactions else {
            // CHA-MR7c
            // I'm replacing throwing with `fatalError` because it's a programmer error to call this method with invalid options.
            fatalError("Room is not configured to support raw message reactions")
        }

        let eventListener = channel.annotations.subscribe { [weak self] annotation in
            guard let self else {
                return
            }
            logger.log(message: "Received reaction (message annotation): \(annotation)", level: .debug)

            guard let reactionEventType = MessageReactionRawEventType.fromAnnotationAction(annotation.action) else {
                logger.log(message: "Received reaction with unknown action: \(annotation.action)", level: .info) // CHA-MR7b2
                return
            }
            guard let reactionType = MessageReactionType(rawValue: annotation.type) else {
                logger.log(message: "Received reaction with unknown type: \(annotation.type)", level: .info) // CHA-MR7b1
                return
            }

            let annotationClientID = annotation.clientId ?? "" // CHA-MR7b3

            let reactionEvent = MessageReactionRawEvent(
                type: reactionEventType,
                // TODO: This is just a fallback value until ably-cocoa fixes the nullability of ARTAnnotation.timestamp. Remove in https://github.com/ably/ably-chat-swift/issues/395
                timestamp: annotation.timestamp ?? Date(),
                reaction: MessageReactionRawEvent.Reaction(
                    type: reactionType,
                    name: annotation.name ?? "", // CHA-MR7b3
                    messageSerial: annotation.messageSerial,
                    count: annotation.count?.intValue ?? (annotation.action == .create && reactionType == .multiple ? 1 : nil),
                    clientID: annotationClientID,
                ),
            )

            logger.log(message: "Emitting message reaction event: \(reactionEvent)", level: .debug)

            callback(reactionEvent)
        }
        return DefaultSubscription { [weak self] in
            self?.channel.unsubscribe(eventListener)
        }
    }

    // CHA-MR13
    internal func clientReactions(forMessageWithSerial messageSerial: String, clientID: String?) async throws(ErrorInfo) -> MessageReactionSummary {
        logger.log(message: "Fetching client reactions for message serial: \(messageSerial), clientId: \(clientID ?? "current client")", level: .debug)

        // CHA-MR13b, CHA-MR13c
        let summary = try await chatAPI.getClientReactions(forMessageWithSerial: messageSerial, roomName: roomName, clientID: clientID)

        logger.log(message: "Fetched client reactions for message serial: \(messageSerial)", level: .info)

        return summary
    }
}
