import Foundation

// A non-throwing `AsyncSequence` (means that we can iterate over it without a `try`).
//
// This should respect the `BufferingPolicy` passed to the `subscribe(bufferingPolicy:)` method.
//
// At some point we should define how this thing behaves when you iterate over it from multiple loops, or when you pass it around. I'm not yet sufficiently experienced with `AsyncSequence` to know what's idiomatic. I tried the same thing out with `AsyncStream` (two tasks iterating over a single stream) and it appears that each element is delivered to precisely one consumer. But we can leave that for later. On a similar note consider whether it makes a difference whether this is a struct or a class.
//
// I wanted to implement this as a protocol (from which `MessageSubscription` would then inherit) but struggled to do so (see https://forums.swift.org/t/struggling-to-create-a-protocol-that-inherits-from-asyncsequence-with-primary-associated-type/73950 where someone suggested it's a compiler bug), hence the struct. I was also hoping that upon switching to Swift 6 we could use AsyncSequence's `Failure` associated type to simplify the way in which we show that the subscription is non-throwing, but it turns out this can only be done in macOS 15 etc. So I think that for now we're stuck with things the way they are.

/// A non-throwing `AsyncSequence`. The Chat SDK uses this type as the return value of the `AsyncSequence` convenience variants of methods that allow you to find out about events such as typing events, connection status changes, discontinuity events etc.
///
/// You should only iterate over a given `SubscriptionAsyncSequence` once; the results of iterating more than once are undefined.
public final class SubscriptionAsyncSequence<Element: Sendable>: Sendable, AsyncSequence {
    private enum Mode: Sendable {
        case `default`(stream: AsyncStream<Element>, continuation: AsyncStream<Element>.Continuation)
        case mockAsyncSequence(AnyNonThrowingAsyncSequence)
    }

    /// A type-erased AsyncSequence that doesn't throw any errors.
    fileprivate struct AnyNonThrowingAsyncSequence: AsyncSequence, Sendable {
        private var makeAsyncIteratorImpl: @Sendable () -> AsyncIterator

        init<Underlying: AsyncSequence & Sendable>(asyncSequence: Underlying) where Underlying.Element == Element {
            makeAsyncIteratorImpl = {
                AsyncIterator(asyncIterator: asyncSequence.makeAsyncIterator())
            }
        }

        fileprivate struct AsyncIterator: AsyncIteratorProtocol {
            private var nextImpl: () async -> Element?

            init<Underlying: AsyncIteratorProtocol>(asyncIterator: Underlying) where Underlying.Element == Element {
                var iterator = asyncIterator
                nextImpl = { () async -> Element? in
                    do {
                        return try await iterator.next()
                    } catch {
                        fatalError("The AsyncSequence passed to Subscription.init(mockAsyncSequence:) threw an error: \(error). This is not supported.")
                    }
                }
            }

            mutating func next() async -> Element? {
                await nextImpl()
            }
        }

        func makeAsyncIterator() -> AsyncIterator {
            makeAsyncIteratorImpl()
        }
    }

    @MainActor private var terminationHandlers: [@Sendable () -> Void] = []
    private let mode: Mode

    internal init(bufferingPolicy: BufferingPolicy) {
        let (stream, continuation) = AsyncStream.makeStream(of: Element.self, bufferingPolicy: bufferingPolicy.asAsyncStreamBufferingPolicy())
        mode = .default(stream: stream, continuation: continuation)
    }

    /// Creates a mock instance for testing purposes.
    ///
    /// This initializer allows creating a `SubscriptionAsyncSequence` for testing by providing
    /// a mock async sequence. The created subscription will replay the sequence that you pass it.
    ///
    /// - Note: It is a programmer error to pass a throwing AsyncSequence.
    public init<Underlying: AsyncSequence & Sendable>(mockAsyncSequence: Underlying) where Underlying.Element == Element {
        mode = .mockAsyncSequence(.init(asyncSequence: mockAsyncSequence))
    }

    /**
     Causes the subscription to make a new element available on its `AsyncSequence` interface.

     It is a programmer error to call this when the receiver was created using ``init(mockAsyncSequence:)``.
     */
    internal func emit(_ element: Element) {
        switch mode {
        case let .default(_, continuation):
            continuation.yield(element)
        case .mockAsyncSequence:
            fatalError("`emit` cannot be called on a Subscription that was created using init(mockAsyncSequence:)")
        }
    }

    #if DEBUG
        /**
         Signal that there are no more elements for the iteration to receive.

         It is a programmer error to call this when the receiver was created using ``init(mockAsyncSequence:)``.
         */
        internal func testsOnly_finish() {
            switch mode {
            case let .default(_, continuation):
                continuation.finish()
            case .mockAsyncSequence:
                fatalError("`finish` cannot be called on a Subscription that was created using init(mockAsyncSequence:)")
            }
        }
    #endif

    @MainActor
    internal func addTerminationHandler(_ terminationHandler: @escaping (@Sendable () -> Void)) {
        terminationHandlers.append(terminationHandler)

        switch mode {
        case let .default(_, continuation):
            let constantTerminationHandlers = terminationHandlers
            continuation.onTermination = { _ in
                for terminationHandler in constantTerminationHandlers {
                    terminationHandler()
                }
            }
        case .mockAsyncSequence:
            fatalError("`addTerminationHandler(_:)` cannot be called on a Subscription that was created using init(mockAsyncSequence:)")
        }
    }

    /// The iterator for this async sequence.
    public struct AsyncIterator: AsyncIteratorProtocol {
        fileprivate enum Mode {
            case `default`(iterator: AsyncStream<Element>.AsyncIterator)
            case mockAsyncSequence(iterator: AnyNonThrowingAsyncSequence.AsyncIterator)

            mutating func next() async -> Element? {
                switch self {
                case var .default(iterator: iterator):
                    let next = await iterator.next()
                    self = .default(iterator: iterator)
                    return next
                case var .mockAsyncSequence(iterator: iterator):
                    let next = await iterator.next()
                    self = .mockAsyncSequence(iterator: iterator)
                    return next
                }
            }
        }

        private var mode: Mode

        fileprivate init(mode: Mode) {
            self.mode = mode
        }

        /// Asynchronously advances to the next element and returns it, or `nil` if no next element exists.
        public mutating func next() async -> Element? {
            await mode.next()
        }
    }

    /// Creates an async iterator for this sequence.
    public func makeAsyncIterator() -> AsyncIterator {
        let iteratorMode: AsyncIterator.Mode = switch mode {
        case let .default(stream: stream, continuation: _):
            .default(iterator: stream.makeAsyncIterator())
        case let .mockAsyncSequence(asyncSequence):
            .mockAsyncSequence(iterator: asyncSequence.makeAsyncIterator())
        }

        return .init(mode: iteratorMode)
    }
}
