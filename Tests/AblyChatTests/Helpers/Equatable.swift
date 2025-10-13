@testable import AblyChat

// Implementations of Equatable that we don't want in the public API but which are helpful for testing. It's unfortunate that we can't make use of the compiler's built-in synthesising of these conformances. (TODO: Use something like Sourcery to generate these, https://github.com/ably/ably-chat-swift/pull/310)

extension RoomStatusChange: Equatable {
    public static func == (lhs: RoomStatusChange, rhs: RoomStatusChange) -> Bool {
        lhs.current == rhs.current && lhs.previous == rhs.previous && lhs.error === rhs.error
    }
}

extension RoomOptions: Equatable {
    public static func == (lhs: RoomOptions, rhs: RoomOptions) -> Bool {
        lhs.equatableBox == rhs.equatableBox
    }
}
