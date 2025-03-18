import Ably
import AblyChat

class MockChatClient: ChatClient {
    let realtime: RealtimeClient
    nonisolated let clientOptions: ChatClientOptions
    nonisolated let rooms: Rooms
    nonisolated let connection: Connection

    init(realtime: RealtimeClient, clientOptions: ChatClientOptions?) {
        self.realtime = realtime
        self.clientOptions = clientOptions ?? .init()
        connection = MockConnection(status: .connected, error: nil)
        rooms = MockRooms(clientOptions: self.clientOptions)
    }

    nonisolated var clientID: String {
        realtime.clientId ?? "AblyTest"
    }
}

class MockRooms: Rooms {
    let clientOptions: ChatClientOptions
    private var rooms = [String: MockRoom]()

    func get(roomID: String, options: RoomOptions) async throws(ARTErrorInfo) -> any Room {
        if let room = rooms[roomID] {
            return room
        }
        let room = MockRoom(roomID: roomID, options: options)
        rooms[roomID] = room
        return room
    }

    func release(roomID _: String) async {
        fatalError("Not yet implemented")
    }

    init(clientOptions: ChatClientOptions) {
        self.clientOptions = clientOptions
    }
}

class MockRoom: Room {
    private let clientID = "AblyTest"

    nonisolated let roomID: String
    nonisolated let options: RoomOptions
    nonisolated let messages: any Messages
    nonisolated let presence: any Presence
    nonisolated let reactions: any RoomReactions
    nonisolated let typing: any Typing
    nonisolated let occupancy: any Occupancy

    let channel: any RealtimeChannelProtocol = MockRealtime.Channel()

    init(roomID: String, options: RoomOptions) {
        self.roomID = roomID
        self.options = options
        messages = MockMessages(clientID: clientID, roomID: roomID)
        presence = MockPresence(clientID: clientID, roomID: roomID)
        reactions = MockRoomReactions(clientID: clientID, roomID: roomID)
        typing = MockTyping(clientID: clientID, roomID: roomID)
        occupancy = MockOccupancy(clientID: clientID, roomID: roomID)
    }

    var status: RoomStatus = .initialized

    private let mockSubscriptions = MockSubscriptionStorage<RoomStatusChange>()

    func attach() async throws(ARTErrorInfo) {
        print("Mock client attached to room with roomID: \(roomID)")
    }

    func detach() async throws(ARTErrorInfo) {
        fatalError("Not yet implemented")
    }

    private func createSubscription() -> MockSubscription<RoomStatusChange> {
        mockSubscriptions.create(randomElement: {
            RoomStatusChange(current: [.attached(error: nil), .attached(error: nil), .attached(error: nil), .attached(error: nil), .attaching(error: nil), .attaching(error: nil), .suspended(error: .createUnknownError())].randomElement()!, previous: .attaching(error: nil))
        }, interval: 8)
    }

    func onStatusChange(bufferingPolicy _: BufferingPolicy) -> Subscription<RoomStatusChange> {
        .init(mockAsyncSequence: createSubscription())
    }

    func onDiscontinuity(bufferingPolicy _: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        fatalError("Not yet implemented")
    }
}

class MockMessages: Messages {
    let clientID: String
    let roomID: String

    private let mockSubscriptions = MockSubscriptionStorage<Message>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
    }

    private func createSubscription() -> MockSubscription<Message> {
        mockSubscriptions.create(randomElement: {
            Message(
                serial: "\(Date().timeIntervalSince1970)",
                action: .create,
                clientID: MockStrings.names.randomElement()!,
                roomID: self.roomID,
                text: MockStrings.randomPhrase(),
                createdAt: Date(),
                metadata: [:],
                headers: [:],
                version: "",
                timestamp: Date(),
                operation: nil
            )
        }, interval: 3)
    }

    func subscribe(bufferingPolicy _: BufferingPolicy) -> MessageSubscription {
        MessageSubscription(mockAsyncSequence: createSubscription()) { _ in
            MockMessagesPaginatedResult(clientID: self.clientID, roomID: self.roomID)
        }
    }

    func get(options _: QueryOptions) async throws(ARTErrorInfo) -> any PaginatedResult<Message> {
        MockMessagesPaginatedResult(clientID: clientID, roomID: roomID)
    }

    func send(params: SendMessageParams) async throws(ARTErrorInfo) -> Message {
        let message = Message(
            serial: "\(Date().timeIntervalSince1970)",
            action: .create,
            clientID: clientID,
            roomID: roomID,
            text: params.text,
            createdAt: Date(),
            metadata: params.metadata ?? [:],
            headers: params.headers ?? [:],
            version: "",
            timestamp: Date(),
            operation: nil
        )
        mockSubscriptions.emit(message)
        return message
    }

    func update(newMessage: Message, description _: String?, metadata _: OperationMetadata?) async throws(ARTErrorInfo) -> Message {
        let message = Message(
            serial: newMessage.serial,
            action: .update,
            clientID: clientID,
            roomID: roomID,
            text: newMessage.text,
            createdAt: Date(),
            metadata: newMessage.metadata,
            headers: newMessage.headers,
            version: "\(Date().timeIntervalSince1970)",
            timestamp: Date(),
            operation: .init(clientID: clientID)
        )
        mockSubscriptions.emit(message)
        return message
    }

    func delete(message: Message, params _: DeleteMessageParams) async throws(ARTErrorInfo) -> Message {
        let message = Message(
            serial: message.serial,
            action: .delete,
            clientID: clientID,
            roomID: roomID,
            text: message.text,
            createdAt: Date(),
            metadata: message.metadata,
            headers: message.headers,
            version: "\(Date().timeIntervalSince1970)",
            timestamp: Date(),
            operation: .init(clientID: clientID)
        )
        mockSubscriptions.emit(message)
        return message
    }
}

class MockRoomReactions: RoomReactions {
    let clientID: String
    let roomID: String

    private let mockSubscriptions = MockSubscriptionStorage<Reaction>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
    }

    private func createSubscription() -> MockSubscription<Reaction> {
        mockSubscriptions.create(randomElement: {
            Reaction(
                type: ReactionType.allCases.randomElement()!.emoji,
                metadata: [:],
                headers: [:],
                createdAt: Date(),
                clientID: self.clientID,
                isSelf: false
            )
        }, interval: Double.random(in: 0.3 ... 0.6))
    }

    func send(params: SendReactionParams) async throws(ARTErrorInfo) {
        let reaction = Reaction(
            type: params.type,
            metadata: [:],
            headers: [:],
            createdAt: Date(),
            clientID: clientID,
            isSelf: false
        )
        mockSubscriptions.emit(reaction)
    }

    func subscribe(bufferingPolicy _: BufferingPolicy) -> Subscription<Reaction> {
        .init(mockAsyncSequence: createSubscription())
    }
}

class MockTyping: Typing {
    let clientID: String
    let roomID: String

    private let mockSubscriptions = MockSubscriptionStorage<TypingEvent>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
    }

    private func createSubscription() -> MockSubscription<TypingEvent> {
        mockSubscriptions.create(randomElement: {
            TypingEvent(
                currentlyTyping: [
                    MockStrings.names.randomElement()!,
                    MockStrings.names.randomElement()!,
                ],
                change: .init(clientId: MockStrings.names.randomElement()!, type: .started)
            )
        }, interval: 2)
    }

    func subscribe(bufferingPolicy _: BufferingPolicy) -> Subscription<TypingEvent> {
        .init(mockAsyncSequence: createSubscription())
    }

    func get() async throws(ARTErrorInfo) -> Set<String> {
        Set(MockStrings.names.shuffled().prefix(2))
    }

    func keystroke() async throws(ARTErrorInfo) {
        mockSubscriptions.emit(TypingEvent(currentlyTyping: [clientID], change: .init(clientId: clientID, type: .started)))
    }

    func stop() async throws(ARTErrorInfo) {
        mockSubscriptions.emit(TypingEvent(currentlyTyping: [], change: .init(clientId: clientID, type: .stopped)))
    }
}

class MockPresence: Presence {
    let clientID: String
    let roomID: String

    private let mockSubscriptions = MockSubscriptionStorage<PresenceEvent>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
    }

    private func createSubscription() -> MockSubscription<PresenceEvent> {
        mockSubscriptions.create(randomElement: {
            PresenceEvent(
                action: [.enter, .leave].randomElement()!,
                clientID: MockStrings.names.randomElement()!,
                timestamp: Date(),
                data: nil
            )
        }, interval: 5)
    }

    func get() async throws(ARTErrorInfo) -> [PresenceMember] {
        MockStrings.names.shuffled().map { name in
            PresenceMember(
                clientID: name,
                data: nil,
                action: .present,
                extras: nil,
                updatedAt: Date()
            )
        }
    }

    func get(params _: PresenceParams) async throws(ARTErrorInfo) -> [PresenceMember] {
        MockStrings.names.shuffled().map { name in
            PresenceMember(
                clientID: name,
                data: nil,
                action: .present,
                extras: nil,
                updatedAt: Date()
            )
        }
    }

    func isUserPresent(clientID _: String) async throws(ARTErrorInfo) -> Bool {
        fatalError("Not yet implemented")
    }

    func enter() async throws(ARTErrorInfo) {
        try await enter(dataForEvent: nil)
    }

    func enter(data: PresenceData) async throws(ARTErrorInfo) {
        try await enter(dataForEvent: data)
    }

    private func enter(dataForEvent: PresenceData?) async throws(ARTErrorInfo) {
        mockSubscriptions.emit(
            PresenceEvent(
                action: .enter,
                clientID: clientID,
                timestamp: Date(),
                data: dataForEvent
            )
        )
    }

    func update() async throws(ARTErrorInfo) {
        try await update(dataForEvent: nil)
    }

    func update(data: PresenceData) async throws(ARTErrorInfo) {
        try await update(dataForEvent: data)
    }

    private func update(dataForEvent: PresenceData? = nil) async throws(ARTErrorInfo) {
        mockSubscriptions.emit(
            PresenceEvent(
                action: .update,
                clientID: clientID,
                timestamp: Date(),
                data: dataForEvent
            )
        )
    }

    func leave() async throws(ARTErrorInfo) {
        try await leave(dataForEvent: nil)
    }

    func leave(data: PresenceData) async throws(ARTErrorInfo) {
        try await leave(dataForEvent: data)
    }

    func leave(dataForEvent: PresenceData? = nil) async throws(ARTErrorInfo) {
        mockSubscriptions.emit(
            PresenceEvent(
                action: .leave,
                clientID: clientID,
                timestamp: Date(),
                data: dataForEvent
            )
        )
    }

    func subscribe(event _: PresenceEventType, bufferingPolicy _: BufferingPolicy) -> Subscription<PresenceEvent> {
        .init(mockAsyncSequence: createSubscription())
    }

    func subscribe(events _: [PresenceEventType], bufferingPolicy _: BufferingPolicy) -> Subscription<PresenceEvent> {
        .init(mockAsyncSequence: createSubscription())
    }
}

class MockOccupancy: Occupancy {
    let clientID: String
    let roomID: String

    private let mockSubscriptions = MockSubscriptionStorage<OccupancyEvent>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
    }

    private func createSubscription() -> MockSubscription<OccupancyEvent> {
        mockSubscriptions.create(randomElement: {
            let random = Int.random(in: 1 ... 10)
            return OccupancyEvent(connections: random, presenceMembers: Int.random(in: 0 ... random))
        }, interval: 1)
    }

    func subscribe(bufferingPolicy _: BufferingPolicy) -> Subscription<OccupancyEvent> {
        .init(mockAsyncSequence: createSubscription())
    }

    func get() async throws(ARTErrorInfo) -> OccupancyEvent {
        OccupancyEvent(connections: 10, presenceMembers: 5)
    }
}

class MockConnection: Connection {
    let status: AblyChat.ConnectionStatus
    let error: ARTErrorInfo?

    nonisolated func onStatusChange(bufferingPolicy _: BufferingPolicy) -> Subscription<ConnectionStatusChange> {
        let mockSub = MockSubscription<ConnectionStatusChange>(randomElement: {
            ConnectionStatusChange(current: .connecting, previous: .connected, retryIn: 1)
        }, interval: 5)

        return Subscription(mockAsyncSequence: mockSub)
    }

    init(status: AblyChat.ConnectionStatus, error: ARTErrorInfo?) {
        self.status = status
        self.error = error
    }
}
