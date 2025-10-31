/**
 * Describes what to do with realtime events that come in faster than the consumer of an `AsyncSequence` can handle them.
 * (This is the same as `AsyncStream<Element>.Continuation.BufferingPolicy` but with the generic type parameter `Element` removed.)
 */
public enum BufferingPolicy: Sendable {
    /// Buffer all events without limit.
    case unbounded
    /// Buffer up to a specific number of oldest events.
    case bufferingOldest(Int)
    /// Buffer up to a specific number of newest events.
    case bufferingNewest(Int)

    internal func asAsyncStreamBufferingPolicy<Element>() -> AsyncStream<Element>.Continuation.BufferingPolicy {
        switch self {
        case let .bufferingNewest(count):
            .bufferingNewest(count)
        case let .bufferingOldest(count):
            .bufferingOldest(count)
        case .unbounded:
            .unbounded
        }
    }
}
