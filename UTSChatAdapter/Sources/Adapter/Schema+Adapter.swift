import Ably
import AblyChat

typealias ErrorInfo = ARTErrorInfo
typealias AblyErrorInfo = ARTErrorInfo
typealias RealtimePresenceParams = PresenceQuery
typealias PaginatedResultMessage = PaginatedResult<Message>
typealias OnConnectionStatusChange = Subscription<ConnectionStatusChange>
typealias OnDiscontinuitySubscription = Subscription<ARTErrorInfo>
typealias OccupancySubscription = Subscription<OccupancyEvent>
typealias RoomReactionsSubscription = Subscription<Reaction>
typealias OnRoomStatusChange = Subscription<RoomStatusChange>
typealias TypingSubscription = Subscription<TypingEvent>
typealias PresenceSubscription = Subscription<PresenceEvent>

struct PresenceDataWrapper {}

public extension Message {
    func before(message: Message) throws -> Bool {
        try isBefore(message)
    }

    func after(message: Message) throws -> Bool {
        try isAfter(message)
    }

    func equal(message: Message) throws -> Bool {
        try isEqual(message)
    }
}

extension Room {
    func options() -> RoomOptions { options }
}

extension PaginatedResult {
    func hasNext() -> Bool { hasNext }
    func isLast() -> Bool { isLast }
    func next() async throws -> (any PaginatedResult<T>)? { try await next }
    func first() async throws -> (any PaginatedResult<T>)? { try await first }
    func current() async throws -> (any PaginatedResult<T>)? { try await current }
}

extension Presence {
    func subscribeAll() async -> Subscription<PresenceEvent> {
        await subscribe(events: [.enter, .leave, .present, .update])
    }
}
