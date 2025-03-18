import Ably

public struct DiscontinuityEvent: Sendable, Equatable {
    /// The error associated with this discontinuity.
    public var error: ARTErrorInfo

    public init(error: ARTErrorInfo) {
        self.error = error
    }
}
