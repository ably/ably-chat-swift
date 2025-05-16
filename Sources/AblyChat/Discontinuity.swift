import Ably

public struct DiscontinuityEvent: Sendable, Equatable {
    /// The error associated with this discontinuity.
    public var error: ARTErrorInfo

    public init(error: ARTErrorInfo) {
        self.error = error
    }
}

@MainActor
public protocol ProvidesDiscontinuity {
    /**
     * Subscribes a given listener to a detected discontinuity.
     *
     * - Parameters:
     *   - callback: The listener closure for capturing ``DiscontinuityEvent``.
     *
     * - Returns: A subscription handle that can be used to unsubscribe from ``DiscontinuityEvent``.
     */
    @discardableResult
    func onDiscontinuity(_ callback: @escaping @MainActor (DiscontinuityEvent) -> Void) -> SubscriptionHandle
}

/// `AsyncSequence` variant of `ProvidesDiscontinuity`.
public extension ProvidesDiscontinuity {
    /**
     * Subscribes a given listener to a detected discontinuity using `AsyncSequence` subscription.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``DiscontinuityEvent`` events.
     */
    func onDiscontinuity(bufferingPolicy: BufferingPolicy) -> Subscription<DiscontinuityEvent> {
        let subscription = Subscription<DiscontinuityEvent>(bufferingPolicy: bufferingPolicy)

        let subscriptionHandle = onDiscontinuity { statusChange in
            subscription.emit(statusChange)
        }
        subscription.addTerminationHandler {
            Task { @MainActor in
                subscriptionHandle.unsubscribe()
            }
        }

        return subscription
    }

    /// Same as calling ``onDiscontinuity(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Room` protocol provides a default implementation of this method.
    func onDiscontinuity() -> Subscription<DiscontinuityEvent> {
        onDiscontinuity(bufferingPolicy: .unbounded)
    }
}
