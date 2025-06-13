import Ably
@testable import AblyChat
import Semaphore
import Testing

@MainActor
struct TypingOperationQueueTests {
    /// An arbitrary error used by the tests in this file.
    enum TestError: Error {
        case badThing
    }

    // MARK: - Idle operation

    @Test
    func enqueue_whenIdle_executesOperation() async {
        let queue = TypingOperationQueue<Never>()

        var executed = false

        await queue.enqueue {
            executed = true
        }

        #expect(executed)

        // (Would have been nice to be able to test that the operation is executed immediately (i.e. without a potential suspension before we call it), but I don't _think_ there's an easy way to do so — think we'd need something like the `Task.startSynchronously` of SE-0472.
    }

    // MARK: - Queueing

    @Test
    func enqueue_whenExecutingAnOperation_enqueues() async throws {
        let queue = TypingOperationQueue<Never>()

        // Start operation1
        let semaphoreAwaitedByOperation1 = AsyncSemaphore(value: 0)
        var operation1Completed = false
        Task {
            await queue.enqueue { @MainActor in
                await semaphoreAwaitedByOperation1.wait()
                operation1Completed = true
            }
        }

        // Now, whilst operation1 is still in progress, enqueue operation2
        let semaphoreSignalledByOperation2 = AsyncSemaphore(value: 0)
        var valueOfOperation1CompletedAtStartOfExecutionOfOperation2: Bool?
        Task {
            await queue.enqueue {
                valueOfOperation1CompletedAtStartOfExecutionOfOperation2 = operation1Completed
                semaphoreSignalledByOperation2.signal()
            }
        }

        // Now complete operation1
        semaphoreAwaitedByOperation1.signal()

        // Wait for operation2 to execute and check that, when it started executing, operation1 had completed
        // (This is not a _great_ test because it doesn't convince me that operation2 was definitely waiting for operation1, but I don't want to get into the world of setting timers and getting either flaky tests or slow tests)
        await semaphoreSignalledByOperation2.wait()
        #expect(valueOfOperation1CompletedAtStartOfExecutionOfOperation2 == true)
    }

    @Test
    func enqueue_whenExecutingAnOperation_replacesAnyPendingRequest() async throws {
        let queue = TypingOperationQueue<Never>()

        // Start operation1
        let semaphoreAwaitedByOperation1 = AsyncSemaphore(value: 0)
        Task {
            await queue.enqueue { @MainActor in
                await semaphoreAwaitedByOperation1.wait()
            }
        }

        // Now, whilst operation1 is still in progress, enqueue operation2 through operation10
        var indicesOfExecutedSubsequentTasks: [Int] = []
        let subsequentOperationEnqueueTasks = (2 ... 10).map { i in
            Task {
                await queue.enqueue {
                    indicesOfExecutedSubsequentTasks.append(i)
                }
            }
        }

        // Now complete operation1
        semaphoreAwaitedByOperation1.signal()

        // Check that all of the calls to `enqueue` completed…
        for task in subsequentOperationEnqueueTasks {
            await task.value
        }

        // …but that only the last was executed
        #expect(indicesOfExecutedSubsequentTasks == [10])
    }

    @Test
    func enqueue_whenExecutingAPreviouslyPendingOperation() async {
        let queue = TypingOperationQueue<Never>()

        // Start operation1
        let semaphoreAwaitedByOperation1 = AsyncSemaphore(value: 0)
        Task {
            await queue.enqueue {
                await semaphoreAwaitedByOperation1.wait()
            }
        }

        // Whilst operation1 is still running, enqueue operation2
        let semaphoreAwaitedByOperation2 = AsyncSemaphore(value: 0)
        let semaphoreSignalledByOperation2 = AsyncSemaphore(value: 0)
        Task {
            await queue.enqueue {
                semaphoreSignalledByOperation2.signal()
                await semaphoreAwaitedByOperation2.wait()
            }
        }

        // Allow operation1 to complete so that operation2 can start
        semaphoreAwaitedByOperation1.signal()

        // Wait for operation2 to start
        await semaphoreSignalledByOperation2.wait()

        // Now, whilst operation2 is still running, enqueue operation3. This is the core of our test scenario — operation2 is the "previously-pending operation" mentioned by the test name. We want to test that operation3 gets executed.
        var operation3Executed = false
        let semaphoreSignalledByOperation3 = AsyncSemaphore(value: 0)
        Task {
            await queue.enqueue {
                operation3Executed = true
                semaphoreSignalledByOperation3.signal()
            }
        }

        // Allow operation2 to complete so that operation3 can start
        semaphoreAwaitedByOperation2.signal()

        // Wait for operation3 to complete
        await semaphoreSignalledByOperation3.wait()
        #expect(operation3Executed)
    }

    // MARK: - Error handling

    @Test
    func enqueue_rethrowsOperationError_whenOperationExecutedFromIdle() async {
        let queue = TypingOperationQueue<TestError>()

        await #expect(throws: TestError.badThing) {
            try await queue.enqueue { () async throws(TestError) in
                throw TestError.badThing
            }
        }
    }

    @Test
    func enqueue_rethrowsOperationError_whenOperationExecutedFromPending() async {
        let queue = TypingOperationQueue<TestError>()

        // Start operation1
        let semaphoreAwaitedByOperation1 = AsyncSemaphore(value: 0)
        async let _ = queue.enqueue {
            await semaphoreAwaitedByOperation1.wait()
        }

        // Now, whilst operation1 is still in progress, enqueue operation2, which throws an error
        let operation2Task: Task<Result<Void, TestError>, Never> = Task {
            do throws(TestError) {
                try await queue.enqueue { () async throws(TestError) in
                    throw TestError.badThing
                }
                return .success(())
            } catch {
                return .failure(error)
            }
        }

        // Now complete operation1 so that operation2 can progress
        semaphoreAwaitedByOperation1.signal()

        // Check that the error is propagated to operation2's call to `enqueue`
        await #expect(throws: TestError.badThing) {
            try await operation2Task.value.get()
        }
    }

    @Test
    func enqueue_whenAnOperationThrows_itDoesNotAffectPendingOperations() async {
        let queue = TypingOperationQueue<TestError>()

        // Start operation1, which will eventually complete by throwing an error
        let semaphoreAwaitedByOperation1 = AsyncSemaphore(value: 0)
        async let _ = queue.enqueue { () throws(TestError) in
            await semaphoreAwaitedByOperation1.wait()
            throw TestError.badThing
        }

        // Now, whilst operation1 is still in progress, enqueue operation2
        let semaphoreSignalledByOperation2 = AsyncSemaphore(value: 0)
        var operation2Executed = false
        let operation2Task = Task {
            try await queue.enqueue {
                operation2Executed = true
                semaphoreSignalledByOperation2.signal()
            }
        }

        // Now complete operation1 so that operation2 can progress
        semaphoreAwaitedByOperation1.signal()

        // Check that, despite operation1 throwing an error, operation2 still executes and its call to `enqueue` does not throw
        await semaphoreSignalledByOperation2.wait()
        #expect(operation2Executed)
        await #expect(throws: Never.self) {
            try await operation2Task.value
        }
    }
}
