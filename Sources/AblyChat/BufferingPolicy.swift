/**
 * Describes what to do with realtime events that come in faster than the consumer of an `AsyncSequence` can handle them.
 * (This is the same as `AsyncStream<T>.Continuation.BufferingPolicy` but with the generic type parameter `T` removed.)
 */
public enum BufferingPolicy: Sendable {
    case unbounded
    case bufferingOldest(Int)
    case bufferingNewest(Int)

    internal func asAsyncStreamBufferingPolicy<T>() -> AsyncStream<T>.Continuation.BufferingPolicy {
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
