import Ably

public struct DiscontinuityEvent: Sendable, Equatable {
    /// The error, if any, associated with this discontinuity.
    public var error: ARTErrorInfo?

    public init(error: ARTErrorInfo? = nil) {
        self.error = error
    }
}

public protocol EmitsDiscontinuities {
    func subscribeToDiscontinuities(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent>
}
