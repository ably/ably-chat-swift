/// Describes what to do with realtime events that come in faster than the consumer of an `AsyncSequence` can handle them.
/// (This is the same as `AsyncStream<T>.Continuation.BufferingPolicy` but with the generic type parameter `T` removed.)
public enum BufferingPolicy {
    case unbounded
    case bufferingOldest(Int)
    case bufferingNewest(Int)
}
