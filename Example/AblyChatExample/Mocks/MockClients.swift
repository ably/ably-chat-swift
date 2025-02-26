import Ably
import AblyChat

actor MockChatClient: ChatClient {
    let realtime: RealtimeClient
    nonisolated let clientOptions: ClientOptions
    nonisolated let rooms: Rooms
    nonisolated let connection: Connection

    init(realtime: RealtimeClient, clientOptions: ClientOptions?) {
        self.realtime = realtime
        self.clientOptions = clientOptions ?? .init()
        connection = MockConnection(status: .connected, error: nil)
        rooms = MockRooms(clientOptions: self.clientOptions)
    }

    nonisolated var clientID: String {
        realtime.clientId ?? "AblyTest"
    }
}

actor MockRooms: Rooms {
    let clientOptions: ClientOptions
    private var rooms = [String: MockRoom]()

    func get(roomID: String, options: RoomOptions) async throws -> any Room {
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

    init(clientOptions: ClientOptions) {
        self.clientOptions = clientOptions
    }
}

actor MockRoom: Room {
    private let clientID = "AblyTest"

    nonisolated let roomID: String
    nonisolated let options: RoomOptions

    init(roomID: String, options: RoomOptions) {
        self.roomID = roomID
        self.options = options
    }

    nonisolated lazy var messages: any Messages = MockMessages(clientID: clientID, roomID: roomID)

    nonisolated lazy var presence: any Presence = MockPresence(clientID: clientID, roomID: roomID)

    nonisolated lazy var reactions: any RoomReactions = MockRoomReactions(clientID: clientID, roomID: roomID)

    nonisolated lazy var typing: any Typing = MockTyping(clientID: clientID, roomID: roomID)

    nonisolated lazy var occupancy: any Occupancy = MockOccupancy(clientID: clientID, roomID: roomID)

    var status: RoomStatus = .initialized

    private let mockSubscriptions = MockSubscriptionStorage<RoomStatusChange>()

    func attach() async throws {
        print("Mock client attached to room with roomID: \(roomID)")
    }

    func detach() async throws {
        fatalError("Not yet implemented")
    }

    private func createSubscription() -> MockSubscription<RoomStatusChange> {
        mockSubscriptions.create(randomElement: {
            RoomStatusChange(current: [.attached, .attached, .attached, .attached, .attaching(error: nil), .attaching(error: nil), .suspended(error: .createUnknownError())].randomElement()!, previous: .attaching(error: nil))
        }, interval: 8)
    }

    func onStatusChange(bufferingPolicy _: BufferingPolicy) async -> Subscription<RoomStatusChange> {
        .init(mockAsyncSequence: createSubscription())
    }
}

actor MockMessages: Messages {
    let clientID: String
    let roomID: String
    let channel: any RealtimeChannelProtocol

    private let mockSubscriptions = MockSubscriptionStorage<Message>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
        channel = MockRealtime.Channel()
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

    func subscribe(bufferingPolicy _: BufferingPolicy) async -> MessageSubscription {
        MessageSubscription(mockAsyncSequence: createSubscription()) { _ in
            MockMessagesPaginatedResult(clientID: self.clientID, roomID: self.roomID)
        }
    }

    func get(options _: QueryOptions) async throws -> any PaginatedResult<Message> {
        MockMessagesPaginatedResult(clientID: clientID, roomID: roomID)
    }

    func send(params: SendMessageParams) async throws -> Message {
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

    func update(newMessage: Message, description _: String?, metadata _: OperationMetadata?) async throws -> Message {
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

    func delete(message: Message, params _: DeleteMessageParams) async throws -> Message {
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

    func onDiscontinuity(bufferingPolicy _: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        fatalError("Not yet implemented")
    }
}

actor MockRoomReactions: RoomReactions {
    let clientID: String
    let roomID: String
    let channel: any RealtimeChannelProtocol

    private let mockSubscriptions = MockSubscriptionStorage<Reaction>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
        channel = MockRealtime.Channel()
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

    func send(params: SendReactionParams) async throws {
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

    func onDiscontinuity(bufferingPolicy _: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        fatalError("Not yet implemented")
    }
}

actor MockTyping: Typing {
    let clientID: String
    let roomID: String
    let channel: any RealtimeChannelProtocol

    private let mockSubscriptions = MockSubscriptionStorage<TypingEvent>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
        channel = MockRealtime.Channel()
    }

    private func createSubscription() -> MockSubscription<TypingEvent> {
        mockSubscriptions.create(randomElement: {
            TypingEvent(currentlyTyping: [
                MockStrings.names.randomElement()!,
                MockStrings.names.randomElement()!,
            ])
        }, interval: 2)
    }

    func subscribe(bufferingPolicy _: BufferingPolicy) -> Subscription<TypingEvent> {
        .init(mockAsyncSequence: createSubscription())
    }

    func get() async throws -> Set<String> {
        Set(MockStrings.names.shuffled().prefix(2))
    }

    func start() async throws {
        mockSubscriptions.emit(TypingEvent(currentlyTyping: [clientID]))
    }

    func stop() async throws {
        mockSubscriptions.emit(TypingEvent(currentlyTyping: []))
    }

    func onDiscontinuity(bufferingPolicy _: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        fatalError("Not yet implemented")
    }
}

actor MockPresence: Presence {
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

    func get() async throws -> [PresenceMember] {
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

    func get(params _: PresenceQuery) async throws -> [PresenceMember] {
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

    func isUserPresent(clientID _: String) async throws -> Bool {
        fatalError("Not yet implemented")
    }

    func enter() async throws {
        try await enter(dataForEvent: nil)
    }

    func enter(data: PresenceData) async throws {
        try await enter(dataForEvent: data)
    }

    private func enter(dataForEvent: PresenceData?) async throws {
        mockSubscriptions.emit(
            PresenceEvent(
                action: .enter,
                clientID: clientID,
                timestamp: Date(),
                data: dataForEvent
            )
        )
    }

    func update() async throws {
        try await update(dataForEvent: nil)
    }

    func update(data: PresenceData) async throws {
        try await update(dataForEvent: data)
    }

    private func update(dataForEvent: PresenceData? = nil) async throws {
        mockSubscriptions.emit(
            PresenceEvent(
                action: .update,
                clientID: clientID,
                timestamp: Date(),
                data: dataForEvent
            )
        )
    }

    func leave() async throws {
        try await leave(dataForEvent: nil)
    }

    func leave(data: PresenceData) async throws {
        try await leave(dataForEvent: data)
    }

    func leave(dataForEvent: PresenceData? = nil) async throws {
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

    func onDiscontinuity(bufferingPolicy _: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        fatalError("Not yet implemented")
    }
}

actor MockOccupancy: Occupancy {
    let clientID: String
    let roomID: String
    let channel: any RealtimeChannelProtocol

    private let mockSubscriptions = MockSubscriptionStorage<OccupancyEvent>()

    init(clientID: String, roomID: String) {
        self.clientID = clientID
        self.roomID = roomID
        channel = MockRealtime.Channel()
    }

    private func createSubscription() -> MockSubscription<OccupancyEvent> {
        mockSubscriptions.create(randomElement: {
            let random = Int.random(in: 1 ... 10)
            return OccupancyEvent(connections: random, presenceMembers: Int.random(in: 0 ... random))
        }, interval: 1)
    }

    func subscribe(bufferingPolicy _: BufferingPolicy) async -> Subscription<OccupancyEvent> {
        .init(mockAsyncSequence: createSubscription())
    }

    func get() async throws -> OccupancyEvent {
        OccupancyEvent(connections: 10, presenceMembers: 5)
    }

    func onDiscontinuity(bufferingPolicy _: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        fatalError("Not yet implemented")
    }
}

actor MockConnection: Connection {
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
