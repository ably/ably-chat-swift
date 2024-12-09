import Ably

public struct DiscontinuityEvent: Sendable, Equatable {
    /// The error, if any, associated with this discontinuity.
    public var error: ARTErrorInfo?

    public init(error: ARTErrorInfo? = nil) {
        self.error = error
    }
}

/**
 * An interface to be implemented by objects that can emit discontinuities to listeners.
 */
public protocol EmitsDiscontinuities {
    /**
     * Subscribes a given listener to a detected discontinuity.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``DiscontinuityEvent`` events.
     */
    func onDiscontinuity(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent>

    /// Same as calling ``onDiscontinuity(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `EmitsDiscontinuities` protocol provides a default implementation of this method.
    func onDiscontinuity() async -> Subscription<DiscontinuityEvent>
}

public extension EmitsDiscontinuities {
    func onDiscontinuity() async -> Subscription<DiscontinuityEvent> {
        await onDiscontinuity(bufferingPolicy: .unbounded)
    }
}
