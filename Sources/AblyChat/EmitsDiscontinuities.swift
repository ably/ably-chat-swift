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
    /// Same as calling ``subscribeToDiscontinuities(bufferingPolicy:)`` with ``BufferingPolicy.unbounded``.
    ///
    /// The `EmitsDiscontinuities` protocol provides a default implementation of this method.
    func subscribeToDiscontinuities() async -> Subscription<DiscontinuityEvent>
}

public extension EmitsDiscontinuities {
    func subscribeToDiscontinuities() async -> Subscription<DiscontinuityEvent> {
        await subscribeToDiscontinuities(bufferingPolicy: .unbounded)
    }
}
