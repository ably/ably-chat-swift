@testable import AblyChat

// Implementations of Equatable that we don't want in the public API but which are helpful for testing. It's unfortunate that we can't make use of the compiler's built-in synthesising of these conformances. (TODO: Use something like Sourcery to generate these, https://github.com/ably/ably-chat-swift/pull/310)

extension RoomStatusChange: Equatable {
    public static func == (lhs: RoomStatusChange, rhs: RoomStatusChange) -> Bool {
        lhs.current == rhs.current && lhs.previous == rhs.previous && lhs.error == rhs.error
    }
}

extension RoomOptions: Equatable {
    public static func == (lhs: RoomOptions, rhs: RoomOptions) -> Bool {
        lhs.equatableBox == rhs.equatableBox
    }
}

extension ErrorInfo: Equatable {
    /// Two `ErrorInfo` instances are considered equal if all of their public properties are equal.
    ///
    /// - Note: We don't consider the internal data (i.e. the stored `ARTErrorInfo` or `InternalError` because these are difficult to compare; for example `InternalError` can store various types of associated values that's used to populate its error message, and this associated data is not necessarily `Equatable`).
    public static func == (lhs: ErrorInfo, rhs: ErrorInfo) -> Bool {
        lhs.code == rhs.code
            && lhs.href == rhs.href
            && lhs.message == rhs.message
            && lhs.cause == rhs.cause
            && lhs.statusCode == rhs.statusCode
            && lhs.requestID == rhs.requestID
    }
}
