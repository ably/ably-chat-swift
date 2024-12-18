@testable import AblyChat
import AsyncAlgorithms
import Testing

struct SubscriptionTests {
    @Test
    func withMockAsyncSequence() async {
        let subscription = Subscription(mockAsyncSequence: ["First", "Second"].async)

        #expect(await Array(subscription.prefix(2)) == ["First", "Second"])
    }

    @Test
    func emit() async {
        let subscription = Subscription<String>(bufferingPolicy: .unbounded)

        async let emittedElements = Array(subscription.prefix(2))

        subscription.emit("First")
        subscription.emit("Second")

        #expect(await emittedElements == ["First", "Second"])
    }

    @Test
    func addTerminationHandler_terminationHandlerCalledWhenSubscriptionDiscarded() async throws {
        let onTerminationCalled = AsyncStream<Void>.makeStream()

        ({
            let subscription = Subscription<Void>(bufferingPolicy: .unbounded)
            subscription.addTerminationHandler {
                onTerminationCalled.continuation.yield()
            }
            // Now there are no more references to `subscription`.
        })()

        await onTerminationCalled.stream.first { _ in true }
    }

    @Test
    func addTerminationHandler_terminationHandlerCalledWhenIterationTaskCancelled() async throws {
        let onTerminationCalled = AsyncStream<Void>.makeStream()

        let subscription = Subscription<Void>(bufferingPolicy: .unbounded)
        subscription.addTerminationHandler {
            onTerminationCalled.continuation.yield()
        }

        let iterationTask = Task {
            for await _ in subscription {}
        }
        iterationTask.cancel()

        await onTerminationCalled.stream.first { _ in true }
    }
}
