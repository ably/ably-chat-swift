/**
 * Describes what to do with realtime events that come in faster than the consumer of an `AsyncSequence` can handle them.
 * (This is the same as `AsyncStream<Element>.Continuation.BufferingPolicy` but with the generic type parameter `Element` removed.)
 */
public enum BufferingPolicy: Sendable {
    /// No buffering limit; all events are stored until consumed.
    case unbounded
    /// Buffers up to the specified number of oldest events, dropping new events when full.
    case bufferingOldest(Int)
    /// Buffers up to the specified number of newest events, dropping old events when full.
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
