import Ably
import AblyChat
import AsyncAlgorithms

final class MockSubscription<T: Sendable>: Sendable, AsyncSequence {
    typealias Element = T
    typealias AsyncTimerMockSequence = AsyncMapSequence<AsyncTimerSequence<ContinuousClock>, Element>
    typealias MockMergedSequence = AsyncMerge2Sequence<AsyncStream<Element>, AsyncTimerMockSequence>
    typealias AsyncIterator = MockMergedSequence.Iterator

    private let continuation: AsyncStream<Element>.Continuation
    private let mergedSequence: MockMergedSequence

    func emit(_ object: Element) {
        continuation.yield(object)
    }

    func makeAsyncIterator() -> AsyncIterator {
        mergedSequence.makeAsyncIterator()
    }

    init(randomElement: @escaping @Sendable () -> Element, interval: Double) {
        let (stream, continuation) = AsyncStream.makeStream(of: Element.self)
        self.continuation = continuation
        let timer: AsyncTimerSequence<ContinuousClock> = .init(interval: .seconds(interval), clock: .init())
        mergedSequence = merge(stream, timer.map { _ in
            randomElement()
        })
    }

    func setOnTermination(_ onTermination: @escaping @Sendable () -> Void) {
        continuation.onTermination = { _ in
            onTermination()
        }
    }
}
