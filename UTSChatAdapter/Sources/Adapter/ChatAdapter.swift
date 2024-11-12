import Ably
import AblyChat

/**
 * Unified Test Suite adapter for swift Chat SDK
 */
@MainActor
struct ChatAdapter {
    // Runtime SDK objects storage
    private var idToChannel = [String: ARTRealtimeChannel]()
    private var idToChannels = [String: ARTRealtimeChannels]()
    private var idToChatClient = [String: ChatClient]()
    private var idToConnection = [String: Connection]()
    private var idToConnectionStatus = [String: ConnectionStatus]()
    private var idToMessage = [String: Message]()
    private var idToMessages = [String: Messages]()
    private var idToOccupancy = [String: Occupancy]()
    private var idToPresence = [String: Presence]()
    private var idToRealtime = [String: RealtimeClient]()
    private var idToRealtimeChannel = [String: RealtimeChannelProtocol]()
    private var idToRoom = [String: Room]()
    private var idToRoomReactions = [String: RoomReactions]()
    private var idToRooms = [String: Rooms]()
    private var idToRoomStatus = [String: RoomStatus]()
    private var idToTyping = [String: Typing]()
    private var idToPaginatedResultMessage = [String: any PaginatedResultMessage]()
    private var idToMessageSubscription = [String: MessageSubscription]()
    private var idToOnConnectionStatusChange = [String: OnConnectionStatusChange]()
    private var idToOnDiscontinuitySubscription = [String: OnDiscontinuitySubscription]()
    private var idToOccupancySubscription = [String: OccupancySubscription]()
    private var idToRoomReactionsSubscription = [String: RoomReactionsSubscription]()
    private var idToOnRoomStatusChange = [String: OnRoomStatusChange]()
    private var idToTypingSubscription = [String: TypingSubscription]()
    private var idToPresenceSubscription = [String: PresenceSubscription]()

    private var webSocket: WebSocketWrapper

    init(webSocket: WebSocketWrapper) {
        self.webSocket = webSocket
    }

    mutating func handleRpcCall(rpcParams: JSON) async throws -> String {
        do {
            switch try rpcParams.method() {
            // Disabling this for generated content since it simplifies generator code:
            // swiftlint:disable anonymous_argument_in_multiline_closure

            // GENERATED CONTENT BEGIN
            // GENERATED CONTENT END
            // swiftlint:enable anonymous_argument_in_multiline_closure

            // Custom fields implementation (see `Schema.skipPaths` for reasons):

            case "ChatClient":
                let chatOptions = try ClientOptions.from(rpcParams.methodArg("clientOptions"))
                let realtimeOptions = try ARTClientOptions.from(rpcParams.methodArg("realtimeClientOptions"))
                let realtime = ARTRealtime(options: realtimeOptions)
                let chatClient = DefaultChatClient(realtime: realtime, clientOptions: chatOptions)
                let instanceId = generateId()
                idToChatClient[instanceId] = chatClient
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(instanceId)\"}")

            // This field is optional and should be included in a corresponding json schema for automatic generation
            case "Message#createdAt":
                guard let message = try idToMessage[rpcParams.refId()] else {
                    throw try AdapterError.objectNotFound(type: "Message", refId: rpcParams.refId())
                }
                if let createdAt = message.createdAt { // number
                    return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(createdAt)\"}")
                } else {
                    return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(NSNull()) }")
                }

            // Here is a custom getter (by "roomId", not with `generateId()`)
            case "Rooms.get":
                let options = try RoomOptions.from(rpcParams.methodArg("options"))
                let roomID = try String.from(rpcParams.methodArg("roomId"))
                let refId = try rpcParams.refId()
                guard let roomsRef = idToRooms[refId] else {
                    throw AdapterError.objectNotFound(type: "Rooms", refId: refId)
                }
                let room = try await roomsRef.get(roomID: roomID, options: options) // Room
                idToRoom[roomID] = room
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(roomID)\"}")

            // `events` is an array of strings in schema file which is not enougth for param auto-generation (should be `PresenceEventType`)
            case "~Presence.subscribe_eventsAndListener":
                let refId = try rpcParams.refId()
                guard let events = try rpcParams.methodArgs()["events"] as? [String] else {
                    throw AdapterError.jsonValueNotFound("events")
                }
                guard let presenceRef = idToPresence[refId] else {
                    throw AdapterError.objectNotFound(type: "Presence", refId: refId)
                }
                let subscription = await presenceRef.subscribe(events: events.map { PresenceEventType.from($0) })
                let webSocket = webSocket
                let callback: (PresenceEvent) async throws -> Void = { event in
                    try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString(event))"))
                }
                Task {
                    for await event in subscription {
                        try await callback(event)
                    }
                }
                let resultRefId = generateId()
                idToPresenceSubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            // Temporarily fix until chat v2 implemented (ECO-5116)
            case "Messages.subscribe":
                let refId = try rpcParams.refId()
                guard let messagesRef = idToMessages[refId] else {
                    throw AdapterError.objectNotFound(type: "Messages", refId: refId)
                }
                let subscription = try await messagesRef.subscribe(bufferingPolicy: .unbounded)
                let webSocket = webSocket
                let callback: (Message) async throws -> Void = { message in
                    try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "{ \"type\": \"message.created\", \"message\": \(jsonString(message))}"))
                }
                Task {
                    for await event in subscription {
                        try await callback(event)
                    }
                }
                let resultRefId = generateId()
                idToMessageSubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            default:
                let method = try rpcParams.method()
                print("Warning: method `\(method)` was not found") // TODO: use logger
                return try jsonRpcError(rpcParams.requestId(), error: AdapterError.methodNotFound(method))
            }
        } catch {
            print("Error: \(error)") // TODO: use logger
            return try jsonRpcError(rpcParams.requestId(), error: error)
        }
    }
}

extension ChatAdapter {
    enum AdapterError: Error, CustomStringConvertible {
        case methodNotFound(_ method: String)
        case objectNotFound(type: String, refId: String)
        case jsonValueNotFound(_ key: String)

        var description: String {
            switch self {
            case let .objectNotFound(type: type, refId: refId):
                "Object of type '\(type)' with tne refId '\(refId)' was not found."
            case let .jsonValueNotFound(key):
                "JSON value for key '\(key)' was not found."
            case let .methodNotFound(method):
                "Method '\(method)' was not found."
            }
        }
    }
}

private extension JSON {
    func method() throws -> String { try stringValue("method") }
    func methodArgs() throws -> JSON { try jsonValue("params").jsonValue("args") }
    func methodArg(_ name: String) throws -> Any { try methodArgs().anyValue(name) }
    func refId() throws -> String { try jsonValue("params").stringValue("refId") }
    func callbackId() throws -> String { try jsonValue("params").stringValue("callbackId") }
    func requestId() throws -> String { try stringValue("id") }
}
