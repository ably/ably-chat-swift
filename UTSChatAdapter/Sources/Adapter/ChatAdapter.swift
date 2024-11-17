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

            case "ChatClient#rooms":
                let refId = try rpcParams.refId()
                guard let chatClientRef = idToChatClient[refId] else {
                    throw AdapterError.objectNotFound(type: "ChatClient", refId: refId)
                }
                let rooms = chatClientRef.rooms // Rooms
                let fieldRefId = generateId()
                idToRooms[fieldRefId] = rooms
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "ChatClient#realtime":
                let refId = try rpcParams.refId()
                guard let chatClientRef = idToChatClient[refId] else {
                    throw AdapterError.objectNotFound(type: "ChatClient", refId: refId)
                }
                let realtime = chatClientRef.realtime // Realtime
                let fieldRefId = generateId()
                idToRealtime[fieldRefId] = realtime
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "~ChatClient#connection":
                let refId = try rpcParams.refId()
                guard let chatClientRef = idToChatClient[refId] else {
                    throw AdapterError.objectNotFound(type: "ChatClient", refId: refId)
                }
                let connection = chatClientRef.connection // Connection
                let fieldRefId = generateId()
                idToConnection[fieldRefId] = connection
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "ChatClient#clientOptions":
                let refId = try rpcParams.refId()
                guard let chatClientRef = idToChatClient[refId] else {
                    throw AdapterError.objectNotFound(type: "ChatClient", refId: refId)
                }
                let clientOptions = chatClientRef.clientOptions // ClientOptions
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(jsonString(clientOptions))}")

            case "ChatClient#clientId":
                let refId = try rpcParams.refId()
                guard let chatClientRef = idToChatClient[refId] else {
                    throw AdapterError.objectNotFound(type: "ChatClient", refId: refId)
                }
                let clientID = chatClientRef.clientID // string
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(clientID)\"}")

            case "~Connection#status":
                let refId = try rpcParams.refId()
                guard let connectionRef = idToConnection[refId] else {
                    throw AdapterError.objectNotFound(type: "Connection", refId: refId)
                }
                let status = connectionRef.status // ConnectionStatus
                let fieldRefId = generateId()
                idToConnectionStatus[fieldRefId] = status
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "Message.equal":
                let message = try Message.from(rpcParams.methodArg("message"))
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let bool = try messageRef.equal(message: message) // Bool
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(bool)\"}")

            case "Message.before":
                let message = try Message.from(rpcParams.methodArg("message"))
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let bool = try messageRef.before(message: message) // Bool
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(bool)\"}")

            case "Message.after":
                let message = try Message.from(rpcParams.methodArg("message"))
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let bool = try messageRef.after(message: message) // Bool
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(bool)\"}")

            case "Message#timeserial":
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let timeserial = messageRef.timeserial // string
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(timeserial)\"}")

            case "Message#text":
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let text = messageRef.text // string
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(text)\"}")

            case "Message#roomId":
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let roomID = messageRef.roomID // string
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(roomID)\"}")

            case "Message#metadata":
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let metadata = messageRef.metadata // object
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(jsonString(metadata))}")

            case "Message#headers":
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let headers = messageRef.headers // object
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(jsonString(headers))}")

            case "Message#clientId":
                let refId = try rpcParams.refId()
                guard let messageRef = idToMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "Message", refId: refId)
                }
                let clientID = messageRef.clientID // string
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(clientID)\"}")

            case "Messages.send":
                let params = try SendMessageParams.from(rpcParams.methodArg("params"))
                let refId = try rpcParams.refId()
                guard let messagesRef = idToMessages[refId] else {
                    throw AdapterError.objectNotFound(type: "Messages", refId: refId)
                }
                let message = try await messagesRef.send(params: params) // Message
                let resultRefId = generateId()
                idToMessage[resultRefId] = message
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "Messages.get":
                let options = try QueryOptions.from(rpcParams.methodArg("options"))
                let refId = try rpcParams.refId()
                guard let messagesRef = idToMessages[refId] else {
                    throw AdapterError.objectNotFound(type: "Messages", refId: refId)
                }
                let paginatedResultMessage = try await messagesRef.get(options: options) // PaginatedResultMessage
                let resultRefId = generateId()
                idToPaginatedResultMessage[resultRefId] = paginatedResultMessage
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "Messages#channel":
                let refId = try rpcParams.refId()
                guard let messagesRef = idToMessages[refId] else {
                    throw AdapterError.objectNotFound(type: "Messages", refId: refId)
                }
                let channel = messagesRef.channel // RealtimeChannel
                let fieldRefId = generateId()
                idToRealtimeChannel[fieldRefId] = channel
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "~Messages.subscribe":
                let refId = try rpcParams.refId()
                guard let messagesRef = idToMessages[refId] else {
                    throw AdapterError.objectNotFound(type: "Messages", refId: refId)
                }
                let subscription = try await messagesRef.subscribe(bufferingPolicy: .unbounded)
                let webSocket = webSocket
                let callback: (Message) async throws -> Void = {
                    try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString($0))"))
                }
                Task {
                    for await event in subscription {
                        try await callback(event)
                    }
                }
                let resultRefId = generateId()
                idToMessageSubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "~Messages.onDiscontinuity":
                let refId = try rpcParams.refId()
                guard let messagesRef = idToMessages[refId] else {
                    throw AdapterError.objectNotFound(type: "Messages", refId: refId)
                }
                let subscription = await messagesRef.subscribeToDiscontinuities()
                let webSocket = webSocket
                let callback: (AblyErrorInfo?) async throws -> Void = {
                    if let param = $0 {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString(param))"))
                    } else {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "{}"))
                    }
                }
                Task {
                    for await reason in subscription {
                        try await callback(reason)
                    }
                }
                let resultRefId = generateId()
                idToOnDiscontinuitySubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "MessageSubscriptionResponse.getPreviousMessages":
                let params = try QueryOptions.from(rpcParams.methodArg("params"))
                let refId = try rpcParams.refId()
                guard let messageSubscriptionRef = idToMessageSubscription[refId] else {
                    throw AdapterError.objectNotFound(type: "MessageSubscriptionResponse", refId: refId)
                }
                let paginatedResultMessage = try await messageSubscriptionRef.getPreviousMessages(params: params) // PaginatedResultMessage
                let resultRefId = generateId()
                idToPaginatedResultMessage[resultRefId] = paginatedResultMessage
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "~Occupancy.get":
                let refId = try rpcParams.refId()
                guard let occupancyRef = idToOccupancy[refId] else {
                    throw AdapterError.objectNotFound(type: "Occupancy", refId: refId)
                }
                let occupancyEvent = try await occupancyRef.get() // OccupancyEvent
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(jsonString(occupancyEvent))}")

            case "~Occupancy#channel":
                let refId = try rpcParams.refId()
                guard let occupancyRef = idToOccupancy[refId] else {
                    throw AdapterError.objectNotFound(type: "Occupancy", refId: refId)
                }
                let channel = occupancyRef.channel // RealtimeChannel
                let fieldRefId = generateId()
                idToRealtimeChannel[fieldRefId] = channel
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "~Occupancy.subscribe":
                let refId = try rpcParams.refId()
                guard let occupancyRef = idToOccupancy[refId] else {
                    throw AdapterError.objectNotFound(type: "Occupancy", refId: refId)
                }
                let subscription = await occupancyRef.subscribe(bufferingPolicy: .unbounded)
                let webSocket = webSocket
                let callback: (OccupancyEvent) async throws -> Void = {
                    try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString($0))"))
                }
                Task {
                    for await event in subscription {
                        try await callback(event)
                    }
                }
                let resultRefId = generateId()
                idToOccupancySubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "~Occupancy.onDiscontinuity":
                let refId = try rpcParams.refId()
                guard let occupancyRef = idToOccupancy[refId] else {
                    throw AdapterError.objectNotFound(type: "Occupancy", refId: refId)
                }
                let subscription = await occupancyRef.subscribeToDiscontinuities()
                let webSocket = webSocket
                let callback: (AblyErrorInfo?) async throws -> Void = {
                    if let param = $0 {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString(param))"))
                    } else {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "{}"))
                    }
                }
                Task {
                    for await reason in subscription {
                        try await callback(reason)
                    }
                }
                let resultRefId = generateId()
                idToOnDiscontinuitySubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "PaginatedResult.isLast":
                let refId = try rpcParams.refId()
                guard let paginatedResultMessageRef = idToPaginatedResultMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "PaginatedResult", refId: refId)
                }
                let bool = paginatedResultMessageRef.isLast() // Bool
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(bool)\"}")

            case "PaginatedResult.hasNext":
                let refId = try rpcParams.refId()
                guard let paginatedResultMessageRef = idToPaginatedResultMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "PaginatedResult", refId: refId)
                }
                let bool = paginatedResultMessageRef.hasNext() // Bool
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(bool)\"}")

            case "PaginatedResult.next":
                let refId = try rpcParams.refId()
                guard let paginatedResultMessageRef = idToPaginatedResultMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "PaginatedResult", refId: refId)
                }
                let paginatedResultMessage = try await paginatedResultMessageRef.next() // PaginatedResultMessage
                let resultRefId = generateId()
                idToPaginatedResultMessage[resultRefId] = paginatedResultMessage
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "PaginatedResult.first":
                let refId = try rpcParams.refId()
                guard let paginatedResultMessageRef = idToPaginatedResultMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "PaginatedResult", refId: refId)
                }
                let paginatedResultMessage = try await paginatedResultMessageRef.first() // PaginatedResultMessage
                let resultRefId = generateId()
                idToPaginatedResultMessage[resultRefId] = paginatedResultMessage
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "PaginatedResult.current":
                let refId = try rpcParams.refId()
                guard let paginatedResultMessageRef = idToPaginatedResultMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "PaginatedResult", refId: refId)
                }
                let paginatedResultMessage = try await paginatedResultMessageRef.current() // PaginatedResultMessage
                let resultRefId = generateId()
                idToPaginatedResultMessage[resultRefId] = paginatedResultMessage
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "PaginatedResult#items":
                let refId = try rpcParams.refId()
                guard let paginatedResultMessageRef = idToPaginatedResultMessage[refId] else {
                    throw AdapterError.objectNotFound(type: "PaginatedResult", refId: refId)
                }
                let items = paginatedResultMessageRef.items // object
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(jsonString(items))}")

            case "~Presence.update":
                let data = try PresenceDataWrapper.from(rpcParams.methodArg("data"))
                let refId = try rpcParams.refId()
                guard let presenceRef = idToPresence[refId] else {
                    throw AdapterError.objectNotFound(type: "Presence", refId: refId)
                }
                try await presenceRef.update(data: data) // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "~Presence.leave":
                let data = try PresenceDataWrapper.from(rpcParams.methodArg("data"))
                let refId = try rpcParams.refId()
                guard let presenceRef = idToPresence[refId] else {
                    throw AdapterError.objectNotFound(type: "Presence", refId: refId)
                }
                try await presenceRef.leave(data: data) // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "~Presence.isUserPresent":
                let clientID = try String.from(rpcParams.methodArg("clientId"))
                let refId = try rpcParams.refId()
                guard let presenceRef = idToPresence[refId] else {
                    throw AdapterError.objectNotFound(type: "Presence", refId: refId)
                }
                let bool = try await presenceRef.isUserPresent(clientID: clientID) // Bool
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(bool)\"}")

            case "Presence.get":
                let params = try RealtimePresenceParams.from(rpcParams.methodArg("params"))
                let refId = try rpcParams.refId()
                guard let presenceRef = idToPresence[refId] else {
                    throw AdapterError.objectNotFound(type: "Presence", refId: refId)
                }
                let presenceMember = try await presenceRef.get(params: params) // PresenceMember
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(jsonString(presenceMember))}")

            case "~Presence.enter":
                let data = try PresenceDataWrapper.from(rpcParams.methodArg("data"))
                let refId = try rpcParams.refId()
                guard let presenceRef = idToPresence[refId] else {
                    throw AdapterError.objectNotFound(type: "Presence", refId: refId)
                }
                try await presenceRef.enter(data: data) // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "~Presence.subscribe_listener":
                let refId = try rpcParams.refId()
                guard let presenceRef = idToPresence[refId] else {
                    throw AdapterError.objectNotFound(type: "Presence", refId: refId)
                }
                let subscription = await presenceRef.subscribeAll()
                let webSocket = webSocket
                let callback: (PresenceEvent) async throws -> Void = {
                    try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString($0))"))
                }
                Task {
                    for await event in subscription {
                        try await callback(event)
                    }
                }
                let resultRefId = generateId()
                idToPresenceSubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "~Presence.onDiscontinuity":
                let refId = try rpcParams.refId()
                guard let presenceRef = idToPresence[refId] else {
                    throw AdapterError.objectNotFound(type: "Presence", refId: refId)
                }
                let subscription = await presenceRef.subscribeToDiscontinuities()
                let webSocket = webSocket
                let callback: (AblyErrorInfo?) async throws -> Void = {
                    if let param = $0 {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString(param))"))
                    } else {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "{}"))
                    }
                }
                Task {
                    for await reason in subscription {
                        try await callback(reason)
                    }
                }
                let resultRefId = generateId()
                idToOnDiscontinuitySubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "~RoomReactions.send":
                let params = try SendReactionParams.from(rpcParams.methodArg("params"))
                let refId = try rpcParams.refId()
                guard let roomReactionsRef = idToRoomReactions[refId] else {
                    throw AdapterError.objectNotFound(type: "RoomReactions", refId: refId)
                }
                try await roomReactionsRef.send(params: params) // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "~RoomReactions#channel":
                let refId = try rpcParams.refId()
                guard let roomReactionsRef = idToRoomReactions[refId] else {
                    throw AdapterError.objectNotFound(type: "RoomReactions", refId: refId)
                }
                let channel = roomReactionsRef.channel // RealtimeChannel
                let fieldRefId = generateId()
                idToRealtimeChannel[fieldRefId] = channel
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "~RoomReactions.subscribe":
                let refId = try rpcParams.refId()
                guard let roomReactionsRef = idToRoomReactions[refId] else {
                    throw AdapterError.objectNotFound(type: "RoomReactions", refId: refId)
                }
                let subscription = await roomReactionsRef.subscribe(bufferingPolicy: .unbounded)
                let webSocket = webSocket
                let callback: (Reaction) async throws -> Void = {
                    try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString($0))"))
                }
                Task {
                    for await reaction in subscription {
                        try await callback(reaction)
                    }
                }
                let resultRefId = generateId()
                idToRoomReactionsSubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "~RoomReactions.onDiscontinuity":
                let refId = try rpcParams.refId()
                guard let roomReactionsRef = idToRoomReactions[refId] else {
                    throw AdapterError.objectNotFound(type: "RoomReactions", refId: refId)
                }
                let subscription = await roomReactionsRef.subscribeToDiscontinuities()
                let webSocket = webSocket
                let callback: (AblyErrorInfo?) async throws -> Void = {
                    if let param = $0 {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString(param))"))
                    } else {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "{}"))
                    }
                }
                Task {
                    for await reason in subscription {
                        try await callback(reason)
                    }
                }
                let resultRefId = generateId()
                idToOnDiscontinuitySubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "Room.options":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                let roomOptions = roomRef.options() // RoomOptions
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(jsonString(roomOptions))}")

            case "Room.detach":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                try await roomRef.detach() // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "Room.attach":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                try await roomRef.attach() // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "~Room#typing":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                let typing = roomRef.typing // Typing
                let fieldRefId = generateId()
                idToTyping[fieldRefId] = typing
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "Room#status":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                let status = await roomRef.status // RoomStatus
                let fieldRefId = generateId()
                idToRoomStatus[fieldRefId] = status
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "Room#roomId":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                let roomID = roomRef.roomID // string
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(roomID)\"}")

            case "~Room#reactions":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                let reactions = roomRef.reactions // RoomReactions
                let fieldRefId = generateId()
                idToRoomReactions[fieldRefId] = reactions
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "~Room#presence":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                let presence = roomRef.presence // Presence
                let fieldRefId = generateId()
                idToPresence[fieldRefId] = presence
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "~Room#occupancy":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                let occupancy = roomRef.occupancy // Occupancy
                let fieldRefId = generateId()
                idToOccupancy[fieldRefId] = occupancy
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "Room#messages":
                let refId = try rpcParams.refId()
                guard let roomRef = idToRoom[refId] else {
                    throw AdapterError.objectNotFound(type: "Room", refId: refId)
                }
                let messages = roomRef.messages // Messages
                let fieldRefId = generateId()
                idToMessages[fieldRefId] = messages
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "~Rooms.release":
                let roomID = try String.from(rpcParams.methodArg("roomId"))
                let refId = try rpcParams.refId()
                guard let roomsRef = idToRooms[refId] else {
                    throw AdapterError.objectNotFound(type: "Rooms", refId: refId)
                }
                try await roomsRef.release(roomID: roomID) // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "Rooms#clientOptions":
                let refId = try rpcParams.refId()
                guard let roomsRef = idToRooms[refId] else {
                    throw AdapterError.objectNotFound(type: "Rooms", refId: refId)
                }
                let clientOptions = roomsRef.clientOptions // ClientOptions
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \(jsonString(clientOptions))}")

            case "~Typing.stop":
                let refId = try rpcParams.refId()
                guard let typingRef = idToTyping[refId] else {
                    throw AdapterError.objectNotFound(type: "Typing", refId: refId)
                }
                try await typingRef.stop() // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "~Typing.start":
                let refId = try rpcParams.refId()
                guard let typingRef = idToTyping[refId] else {
                    throw AdapterError.objectNotFound(type: "Typing", refId: refId)
                }
                try await typingRef.start() // Void
                return try jsonRpcResult(rpcParams.requestId(), "{}")

            case "~Typing.get":
                let refId = try rpcParams.refId()
                guard let typingRef = idToTyping[refId] else {
                    throw AdapterError.objectNotFound(type: "Typing", refId: refId)
                }
                let string = try await typingRef.get() // String
                return try jsonRpcResult(rpcParams.requestId(), "{\"response\": \"\(string)\"}")

            case "~Typing#channel":
                let refId = try rpcParams.refId()
                guard let typingRef = idToTyping[refId] else {
                    throw AdapterError.objectNotFound(type: "Typing", refId: refId)
                }
                let channel = typingRef.channel // RealtimeChannel
                let fieldRefId = generateId()
                idToRealtimeChannel[fieldRefId] = channel
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(fieldRefId)\"}")

            case "~Typing.subscribe":
                let refId = try rpcParams.refId()
                guard let typingRef = idToTyping[refId] else {
                    throw AdapterError.objectNotFound(type: "Typing", refId: refId)
                }
                let subscription = await typingRef.subscribe(bufferingPolicy: .unbounded)
                let webSocket = webSocket
                let callback: (TypingEvent) async throws -> Void = {
                    try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString($0))"))
                }
                Task {
                    for await event in subscription {
                        try await callback(event)
                    }
                }
                let resultRefId = generateId()
                idToTypingSubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

            case "~Typing.onDiscontinuity":
                let refId = try rpcParams.refId()
                guard let typingRef = idToTyping[refId] else {
                    throw AdapterError.objectNotFound(type: "Typing", refId: refId)
                }
                let subscription = await typingRef.subscribeToDiscontinuities()
                let webSocket = webSocket
                let callback: (AblyErrorInfo?) async throws -> Void = {
                    if let param = $0 {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\(jsonString(param))"))
                    } else {
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "{}"))
                    }
                }
                Task {
                    for await reason in subscription {
                        try await callback(reason)
                    }
                }
                let resultRefId = generateId()
                idToOnDiscontinuitySubscription[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\"refId\":\"\(resultRefId)\"}")

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
