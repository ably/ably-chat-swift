import Ably

public struct DiscontinuityEvent: Sendable {
    /// The error associated with this discontinuity.
    public var error: ARTErrorInfo

    public init(error: ARTErrorInfo) {
        self.error = error
    }
}
