import Foundation

/// A test helper that provides a future value that can be resolved synchronously and awaited asynchronously.
///
/// `FutureValue` is useful in tests where you need to:
/// - Resolve a value from synchronous code (e.g., callbacks, delegate methods)
/// - Await that value from asynchronous test code
///
/// Example usage:
/// ```swift
/// let future = FutureValue<String>()
///
/// // In a callback or synchronous context:
/// someCallback = { result in
///     future.resolve(with: result)
/// }
///
/// // In your async test:
/// let result = await future.value
/// ```
@MainActor
final class FutureValue<Value: Sendable> {
    private let stream: AsyncStream<Value>
    private let continuation: AsyncStream<Value>.Continuation
    private var resolvedValue: Value?

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    /// Resolves the future with the given value.
    ///
    /// This method can be called synchronously from any context. It will unblock any awaiting `value` access
    /// and cause it to return the provided value. Subsequent calls to `resolve(with:)` have no effect.
    ///
    /// - Parameter value: The value to resolve the future with.
    func resolve(with value: Value) {
        if resolvedValue != nil {
            return
        }
        resolvedValue = value
        continuation.yield(value)
        continuation.finish()
    }

    /// Asynchronously waits for and returns the resolved value.
    ///
    /// This property suspends until `resolve(with:)` is called with a value.
    ///
    /// - Returns: The resolved value, or `nil` if the task was cancelled before being resolved.
    var value: Value? {
        get async {
            if let resolvedValue {
                return resolvedValue
            }

            for await value in stream {
                return value
            }
            return nil
        }
    }
}
