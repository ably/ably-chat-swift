@testable import AblyChat

// Implementations of Equatable that we don't want in the public API but which are helpful for testing. It's unfortunate that we can't make use of the compiler's built-in synthesising of these conformances. (TODO: Use something like Sourcery to generate these, https://github.com/ably/ably-chat-swift/pull/310)

extension RoomStatus: Equatable {
    public static func == (lhs: RoomStatus, rhs: RoomStatus) -> Bool {
        switch lhs {
        case .initialized:
            if case .initialized = rhs {
                return true
            }
        case let .attaching(lhsError):
            if case let .attaching(rhsError) = rhs {
                return lhsError === rhsError
            }
        case let .attached(lhsError):
            if case let .attached(rhsError) = rhs {
                return lhsError === rhsError
            }
        case let .detaching(lhsError):
            if case let .detaching(rhsError) = rhs {
                return lhsError === rhsError
            }
        case let .detached(lhsError):
            if case let .detached(rhsError) = rhs {
                return lhsError === rhsError
            }
        case let .suspended(lhsError):
            if case let .suspended(rhsError) = rhs {
                return lhsError === rhsError
            }
        case let .failed(lhsError):
            if case let .failed(rhsError) = rhs {
                return lhsError === rhsError
            }
        case .releasing:
            if case .releasing = rhs {
                return true
            }
        case .released:
            if case .released = rhs {
                return true
            }
        }
        return false
    }
}

extension RoomStatusChange: Equatable {
    public static func == (lhs: RoomStatusChange, rhs: RoomStatusChange) -> Bool {
        lhs.current == rhs.current && lhs.previous == rhs.previous
    }
}

extension DiscontinuityEvent: Equatable {
    public static func == (lhs: DiscontinuityEvent, rhs: DiscontinuityEvent) -> Bool {
        lhs.error === rhs.error
    }
}
