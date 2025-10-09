import Ably
@testable import AblyChat

class MockChatClient: ChatClientProtocol {
    final class Realtime: Sendable {
        init() {}
    }

    let realtime = Realtime()
    let clientOptions: ChatClientOptions
    let rooms: MockRooms
    let connection: MockConnection

    init(clientOptions: ChatClientOptions?) {
        self.clientOptions = clientOptions ?? .init()
        connection = MockConnection(status: .connected, error: nil)
        rooms = MockRooms(clientOptions: self.clientOptions)
    }

    var clientID: String {
        "AblyTest"
    }
}

class MockRooms: Rooms {
    let clientOptions: ChatClientOptions
    private var rooms = [String: MockRoom]()

    func get(name: String, options: RoomOptions) async throws(ARTErrorInfo) -> MockRoom {
        if let room = rooms[name] {
            return room
        }
        let room = MockRoom(name: name, options: options)
        rooms[name] = room
        return room
    }

    func release(name _: String) async {
        fatalError("Not yet implemented")
    }

    init(clientOptions: ChatClientOptions) {
        self.clientOptions = clientOptions
    }
}

class MockRoom: Room {
    final class Channel: Sendable {
        init() {}
    }

    private let clientID = "AblyTest"

    let name: String
    let options: RoomOptions
    let messages: MockMessages
    let presence: MockPresence
    let reactions: MockRoomReactions
    let typing: MockTyping
    let occupancy: MockOccupancy

    let channel = Channel()

    init(name: String, options: RoomOptions) {
        self.name = name
        self.options = options
        messages = MockMessages(clientID: clientID, roomName: name)
        presence = MockPresence(clientID: clientID, roomName: name)
        reactions = MockRoomReactions(clientID: clientID, roomName: name)
        typing = MockTyping(clientID: clientID, roomName: name)
        occupancy = MockOccupancy(clientID: clientID, roomName: name)
    }

    var status: RoomStatus = .initialized

    private func randomStatusInterval() -> Double { 8.0 }

    private let randomStatusChange = { @Sendable in
        RoomStatusChange(current: [.attached(error: nil), .attached(error: nil), .attached(error: nil), .attached(error: nil), .attaching(error: nil), .attaching(error: nil), .suspended(error: .createUnknownError())].randomElement()!, previous: .attaching(error: nil))
    }

    func attach() async throws(ARTErrorInfo) {
        print("Mock client attached to room with roomName: \(name)")
    }

    func detach() async throws(ARTErrorInfo) {
        fatalError("Not yet implemented")
    }

    @discardableResult
    func onStatusChange(_ callback: @escaping @MainActor (RoomStatusChange) -> Void) -> DefaultStatusSubscription {
        var needNext = true
        periodic(with: randomStatusInterval) { [weak self] in
            guard let self else {
                return false
            }
            if needNext {
                callback(randomStatusChange())
            }
            return needNext
        }
        return DefaultStatusSubscription {
            needNext = false
        }
    }

    @discardableResult
    func onDiscontinuity(_: @escaping @MainActor (ARTErrorInfo) -> Void) -> DefaultStatusSubscription {
        fatalError("Not yet implemented")
    }
}

class MockMessages: Messages {
    let clientID: String
    let roomName: String

    var reactions: MockMessageReactions

    private let mockSubscriptions = MockMessageSubscriptionStorage<ChatMessageEvent, MockMessagesPaginatedResult>()

    init(clientID: String, roomName: String) {
        self.clientID = clientID
        self.roomName = roomName
        reactions = MockMessageReactions(clientID: clientID, roomName: roomName)
    }

    func subscribe(_ callback: @escaping @MainActor (ChatMessageEvent) -> Void) -> some MessageSubscriptionResponse {
        mockSubscriptions.create(
            randomElement: {
                let message = Message(
                    serial: "\(Date().timeIntervalSince1970)",
                    action: .messageCreate,
                    clientID: MockStrings.names.randomElement()!,
                    text: MockStrings.randomPhrase(),
                    metadata: [:],
                    headers: [:],
                    version: .init(
                        serial: "",
                        timestamp: Date(),
                    ),
                    timestamp: Date(),
                    reactions: .init(unique: [:], distinct: [:], multiple: [:]),
                )
                if byChance(30) { /* 30% of the messages will get the reaction */
                    self.reactions.messageSerials.append(message.serial)
                }
                self.reactions.clientIDs.insert(message.clientID)
                return ChatMessageEvent(message: message)
            },
            previousMessages: { _ in
                MockMessagesPaginatedResult(clientID: self.clientID, roomName: self.roomName)
            },
            interval: 3.0,
            callback: callback,
        )
    }

    func history(withParams _: HistoryParams) async throws(ARTErrorInfo) -> some PaginatedResult<Message> {
        MockMessagesPaginatedResult(clientID: clientID, roomName: roomName)
    }

    func send(withParams params: SendMessageParams) async throws(ARTErrorInfo) -> Message {
        let message = Message(
            serial: "\(Date().timeIntervalSince1970)",
            action: .messageCreate,
            clientID: clientID,
            text: params.text,
            metadata: params.metadata ?? [:],
            headers: params.headers ?? [:],
            version: .init(
                serial: "",
                timestamp: Date(),
            ),
            timestamp: Date(),
            reactions: .init(unique: [:], distinct: [:], multiple: [:]),
        )
        mockSubscriptions.emit(ChatMessageEvent(message: message))
        return message
    }

    func update(newMessage: Message, description _: String?, metadata _: OperationMetadata?) async throws(ARTErrorInfo) -> Message {
        let message = Message(
            serial: newMessage.serial,
            action: .messageUpdate,
            clientID: clientID,
            text: newMessage.text,
            metadata: newMessage.metadata,
            headers: newMessage.headers,
            version: .init(serial: "\(Date().timeIntervalSince1970)", timestamp: Date(), clientID: clientID),
            timestamp: Date(),
            reactions: .init(unique: [:], distinct: [:], multiple: [:]),
        )
        mockSubscriptions.emit(ChatMessageEvent(message: message))
        return message
    }

    func delete(message: Message, params _: DeleteMessageParams) async throws(ARTErrorInfo) -> Message {
        let message = Message(
            serial: message.serial,
            action: .messageDelete,
            clientID: clientID,
            text: message.text,
            metadata: message.metadata,
            headers: message.headers,
            version: .init(
                serial: "\(Date().timeIntervalSince1970)",
                timestamp: Date(),
                clientID: clientID,
            ),
            timestamp: Date(),
            reactions: .init(unique: [:], distinct: [:], multiple: [:]),
        )
        mockSubscriptions.emit(ChatMessageEvent(message: message))
        return message
    }
}

class MockMessageReactions: MessageReactions {
    let clientID: String
    let roomName: String

    var clientIDs: Set<String> = []
    var messageSerials: [String] = []

    private var reactions: [MessageReactionRawEvent.Reaction] = []

    private let mockSubscriptions = MockSubscriptionStorage<MessageReactionSummaryEvent>()

    private func getUniqueReactionsSummaryForMessage(_ messageSerial: String) -> MessageReactionSummary {
        MessageReactionSummary(
            unique: [:],
            distinct: reactions.filter { $0.messageSerial == messageSerial }.reduce(into: [String: MessageReactionSummary.ClientIDList]()) { dict, newItem in
                if var oldItem = dict[newItem.name] {
                    if !oldItem.clientIDs.contains(newItem.clientID) {
                        oldItem.clientIDs.append(newItem.clientID)
                        oldItem.total += 1
                    }
                    dict[newItem.name] = oldItem
                } else {
                    dict[newItem.name] = MessageReactionSummary.ClientIDList(total: 1, clientIDs: [newItem.clientID], clipped: false)
                }
            },
            multiple: [:],
        )
    }

    init(clientID: String, roomName: String) {
        self.clientID = clientID
        self.roomName = roomName
    }

    func send(forMessageWithSerial messageSerial: String, params: SendMessageReactionParams) async throws(ARTErrorInfo) {
        reactions.append(
            MessageReactionRawEvent.Reaction(
                type: .distinct,
                name: params.name,
                messageSerial: messageSerial,
                count: params.count,
                clientID: clientID,
                isSelf: true,
            ),
        )
        mockSubscriptions.emit(
            MessageReactionSummaryEvent(
                type: MessageReactionSummaryEventType.summary,
                messageSerial: messageSerial,
                reactions: getUniqueReactionsSummaryForMessage(messageSerial),
            ),
        )
    }

    func delete(forMessageWithSerial messageSerial: String, params: DeleteMessageReactionParams) async throws(ARTErrorInfo) {
        reactions.removeAll { reaction in
            reaction.messageSerial == messageSerial && reaction.name == params.name && reaction.clientID == clientID
        }
        mockSubscriptions.emit(
            MessageReactionSummaryEvent(
                type: MessageReactionSummaryEventType.summary,
                messageSerial: messageSerial,
                reactions: getUniqueReactionsSummaryForMessage(messageSerial),
            ),
        )
    }

    func subscribe(_ callback: @escaping @MainActor @Sendable (MessageReactionSummaryEvent) -> Void) -> MockSubscription {
        mockSubscriptions.create(
            randomElement: {
                guard let senderClientID = self.clientIDs.randomElement(), let messageSerial = self.messageSerials.randomElement() else {
                    return nil
                }
                self.reactions.append(
                    MessageReactionRawEvent.Reaction(
                        type: .distinct,
                        name: Emoji.random(),
                        messageSerial: messageSerial,
                        count: 1,
                        clientID: senderClientID,
                        isSelf: senderClientID == self.clientID,
                    ),
                )
                return MessageReactionSummaryEvent(
                    type: MessageReactionSummaryEventType.summary,
                    messageSerial: messageSerial,
                    reactions: self.getUniqueReactionsSummaryForMessage(messageSerial),
                )
            },
            interval: Double([Int](1 ... 10).randomElement()!) / 10.0,
            callback: callback,
        )
    }

    func subscribeRaw(_: @escaping @MainActor @Sendable (MessageReactionRawEvent) -> Void) -> MockSubscription {
        fatalError("Not implemented")
    }
}

class MockRoomReactions: RoomReactions {
    let clientID: String
    let roomName: String

    private let mockSubscriptions = MockSubscriptionStorage<RoomReactionEvent>()

    init(clientID: String, roomName: String) {
        self.clientID = clientID
        self.roomName = roomName
    }

    func send(withParams params: SendReactionParams) async throws(ARTErrorInfo) {
        let reaction = RoomReaction(
            name: params.name,
            metadata: [:],
            headers: [:],
            createdAt: Date(),
            clientID: clientID,
            isSelf: false,
        )
        let event = RoomReactionEvent(type: .reaction, reaction: reaction)
        mockSubscriptions.emit(event)
    }

    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (RoomReactionEvent) -> Void) -> some Subscription {
        mockSubscriptions.create(
            randomElement: {
                let reaction = RoomReaction(
                    name: ReactionName.allCases.randomElement()!.emoji,
                    metadata: [:],
                    headers: [:],
                    createdAt: Date(),
                    clientID: self.clientID,
                    isSelf: false,
                )
                return RoomReactionEvent(type: .reaction, reaction: reaction)
            },
            interval: 0.5,
            callback: callback,
        )
    }
}

class MockTyping: Typing {
    let clientID: String
    let roomName: String

    private let mockSubscriptions = MockSubscriptionStorage<TypingSetEvent>()

    init(clientID: String, roomName: String) {
        self.clientID = clientID
        self.roomName = roomName
    }

    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (TypingSetEvent) -> Void) -> some Subscription {
        mockSubscriptions.create(
            randomElement: {
                TypingSetEvent(
                    type: .setChanged,
                    currentlyTyping: [
                        MockStrings.names.randomElement()!,
                        MockStrings.names.randomElement()!,
                    ],
                    change: .init(clientID: MockStrings.names.randomElement()!, type: .started),
                )
            },
            interval: 2,
            callback: callback,
        )
    }

    var current: Set<String> {
        Set(MockStrings.names.shuffled().prefix(2))
    }

    func keystroke() async throws(ARTErrorInfo) {
        mockSubscriptions.emit(
            TypingSetEvent(
                type: .setChanged,
                currentlyTyping: [clientID],
                change: .init(clientID: clientID, type: .started),
            ),
        )
    }

    func stop() async throws(ARTErrorInfo) {
        mockSubscriptions.emit(
            TypingSetEvent(
                type: .setChanged,
                currentlyTyping: [],
                change: .init(clientID: clientID, type: .stopped),
            ),
        )
    }
}

class MockPresence: Presence {
    let clientID: String
    let roomName: String

    private let mockSubscriptions = MockSubscriptionStorage<PresenceEvent>()

    init(clientID: String, roomName: String) {
        self.clientID = clientID
        self.roomName = roomName
    }

    private func createSubscription(callback: @escaping @MainActor (PresenceEvent) -> Void) -> MockSubscription {
        mockSubscriptions.create(
            randomElement: {
                let member = PresenceMember(
                    clientID: MockStrings.names.randomElement()!,
                    data: nil,
                    extras: nil,
                    updatedAt: Date(),
                )
                return PresenceEvent(
                    type: [.enter, .leave].randomElement()!,
                    member: member,
                )
            },
            interval: 5,
            callback: callback,
        )
    }

    func get() async throws(ARTErrorInfo) -> [PresenceMember] {
        MockStrings.names.shuffled().map { name in
            PresenceMember(
                clientID: name,
                data: nil,
                extras: nil,
                updatedAt: Date(),
            )
        }
    }

    func get(withParams _: PresenceParams) async throws(ARTErrorInfo) -> [PresenceMember] {
        MockStrings.names.shuffled().map { name in
            PresenceMember(
                clientID: name,
                data: nil,
                extras: nil,
                updatedAt: Date(),
            )
        }
    }

    func isUserPresent(withClientID _: String) async throws(ARTErrorInfo) -> Bool {
        fatalError("Not yet implemented")
    }

    func enter() async throws(ARTErrorInfo) {
        try await enter(dataForEvent: nil)
    }

    func enter(withData data: PresenceData) async throws(ARTErrorInfo) {
        try await enter(dataForEvent: data)
    }

    private func enter(dataForEvent: PresenceData?) async throws(ARTErrorInfo) {
        let member = PresenceMember(
            clientID: clientID,
            data: dataForEvent,
            extras: nil,
            updatedAt: Date(),
        )
        mockSubscriptions.emit(
            PresenceEvent(
                type: .enter,
                member: member,
            ),
        )
    }

    func update() async throws(ARTErrorInfo) {
        try await update(dataForEvent: nil)
    }

    func update(withData data: PresenceData) async throws(ARTErrorInfo) {
        try await update(dataForEvent: data)
    }

    private func update(dataForEvent: PresenceData? = nil) async throws(ARTErrorInfo) {
        let member = PresenceMember(
            clientID: clientID,
            data: dataForEvent,
            extras: nil,
            updatedAt: Date(),
        )
        mockSubscriptions.emit(
            PresenceEvent(
                type: .update,
                member: member,
            ),
        )
    }

    func leave() async throws(ARTErrorInfo) {
        try await leave(dataForEvent: nil)
    }

    func leave(withData data: PresenceData) async throws(ARTErrorInfo) {
        try await leave(dataForEvent: data)
    }

    func leave(dataForEvent: PresenceData? = nil) async throws(ARTErrorInfo) {
        let member = PresenceMember(
            clientID: clientID,
            data: dataForEvent,
            extras: nil,
            updatedAt: Date(),
        )
        mockSubscriptions.emit(
            PresenceEvent(
                type: .leave,
                member: member,
            ),
        )
    }

    func subscribe(_ callback: @escaping @MainActor (PresenceEvent) -> Void) -> MockSubscription {
        createSubscription(callback: callback)
    }

    func subscribe(event _: PresenceEventType, _ callback: @escaping @MainActor (PresenceEvent) -> Void) -> MockSubscription {
        createSubscription(callback: callback)
    }

    func subscribe(events _: [PresenceEventType], _ callback: @escaping @MainActor (PresenceEvent) -> Void) -> MockSubscription {
        createSubscription(callback: callback)
    }
}

class MockOccupancy: Occupancy {
    let clientID: String
    let roomName: String

    private let mockSubscriptions = MockSubscriptionStorage<OccupancyEvent>()

    init(clientID: String, roomName: String) {
        self.clientID = clientID
        self.roomName = roomName
    }

    @discardableResult
    func subscribe(_ callback: @escaping @MainActor (OccupancyEvent) -> Void) -> MockSubscription {
        mockSubscriptions.create(
            randomElement: {
                let random = Int.random(in: 1 ... 10)
                let occupancyData = OccupancyData(connections: random, presenceMembers: Int.random(in: 0 ... random))
                return OccupancyEvent(type: .updated, occupancy: occupancyData)
            },
            interval: 2,
            callback: callback,
        )
    }

    func get() async throws(ARTErrorInfo) -> OccupancyData {
        OccupancyData(connections: 10, presenceMembers: 5)
    }

    var current: AblyChat.OccupancyData? {
        OccupancyData(connections: 10, presenceMembers: 5)
    }
}

class MockConnection: Connection {
    let status: ConnectionStatus
    let error: ARTErrorInfo?

    private let mockSubscriptions = MockStatusSubscriptionStorage<ConnectionStatusChange>()

    init(status: ConnectionStatus, error: ARTErrorInfo?) {
        self.status = status
        self.error = error
    }

    @discardableResult
    func onStatusChange(_ callback: @escaping @MainActor (ConnectionStatusChange) -> Void) -> some StatusSubscription {
        mockSubscriptions.create(
            randomElement: {
                ConnectionStatusChange(
                    current: [.connected, .connecting].randomElement()!,
                    previous: [.suspended, .disconnected].randomElement()!,
                    retryIn: 1,
                )
            },
            interval: 5,
            callback: callback,
        )
    }
}
