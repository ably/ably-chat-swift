import Ably

// swiftlint:disable:next missing_docs
public struct DiscontinuityEvent: Sendable {
    /// The error associated with this discontinuity.
    public var error: ARTErrorInfo

    /// Memberwise initializer to create a `DiscontinuityEvent`.
    ///
    /// - Note: You should not need to use this initializer when using the Chat SDK. It is exposed only to allow users to create mock versions of the SDK's protocols.
    public init(error: ARTErrorInfo) {
        self.error = error
    }
}
