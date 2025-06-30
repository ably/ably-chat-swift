@testable import AblyChat
import AsyncAlgorithms
import Testing

struct SubscriptionAsyncSequenceTests {
    @Test
    func withMockAsyncSequence() async {
        let subscription = SubscriptionAsyncSequence(mockAsyncSequence: ["First", "Second"].async)

        #expect(await Array(subscription.prefix(2)) == ["First", "Second"])
    }

    @Test
    func emit() async {
        let subscription = SubscriptionAsyncSequence<String>(bufferingPolicy: .unbounded)

        async let emittedElements = Array(subscription.prefix(2))

        subscription.emit("First")
        subscription.emit("Second")

        #expect(await emittedElements == ["First", "Second"])
    }

    @MainActor
    @Test
    func addTerminationHandler_terminationHandlerCalledWhenSubscriptionDiscarded() async throws {
        let onTerminationCalled = AsyncStream<Void>.makeStream()

        ({
            let subscription = SubscriptionAsyncSequence<Void>(bufferingPolicy: .unbounded)
            subscription.addTerminationHandler {
                onTerminationCalled.continuation.yield()
            }
            // Now there are no more references to `subscription`.
        })()

        await onTerminationCalled.stream.first { @Sendable _ in true }
    }

    @MainActor
    @Test
    func addTerminationHandler_terminationHandlerCalledWhenIterationTaskCancelled() async throws {
        let onTerminationCalled = AsyncStream<Void>.makeStream()

        let subscription = SubscriptionAsyncSequence<Void>(bufferingPolicy: .unbounded)
        subscription.addTerminationHandler {
            onTerminationCalled.continuation.yield()
        }

        let iterationTask = Task {
            for await _ in subscription {}
        }
        iterationTask.cancel()

        await onTerminationCalled.stream.first { @Sendable _ in true }
    }
}
