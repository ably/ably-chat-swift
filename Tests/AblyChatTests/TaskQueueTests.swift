@testable import AblyChat
import Foundation
import Testing

#if canImport(Clocks)
    import Clocks

    @MainActor
    struct TaskQueueTests {
        @Test
        @available(iOS 16, *)
        func latestOnly_OnlyExecutesFirstAndLastTask() async throws {
            let taskQueue = TaskQueue(executionStyle: .latestOnly)
            let testClock = TestClock()

            for index in 0 ..< 5 {
                Task {
                    try await taskQueue.enqueue(operation: {
                        try await testClock.sleep(for: .seconds(1))
                    }, taskID: index.description)
                }
            }

            await testClock.advance(by: .seconds(10))

            #expect(taskQueue.testsOnly_totalTasksRan == 2)
            #expect(taskQueue.testsOnly_executedtaskIDs == ["0", "4"]) // First and last
        }

        @Test
        @available(iOS 16, *)
        func allSequentially_ExecutesAllQueuedTasks() async throws {
            let taskQueue = TaskQueue(executionStyle: .allSequentially)
            let testClock = TestClock()
            for _ in 0 ..< 5 {
                Task {
                    try await taskQueue.enqueue {
                        try await testClock.sleep(for: .seconds(1))
                    }
                }
            }

            await testClock.advance(by: .seconds(10))

            #expect(taskQueue.testsOnly_totalTasksRan == 5)
        }

        @Test
        @available(iOS 16, *)
        func enqueue_doesNotExecuteMoreThanOneTaskConcurrently() async throws {
            let taskQueue = TaskQueue(executionStyle: .allSequentially)
            let testClock = TestClock()

            for _ in 0 ..< 10 {
                Task {
                    try await taskQueue.enqueue {
                        try await testClock.sleep(for: .seconds(1))
                    }
                }
            }

            await testClock.advance(by: .seconds(20))

            #expect(taskQueue.testsOnly_totalTasksRan == 10)
            #expect(taskQueue.testsOnly_maxObservedConcurrentTasks == 1)
        }

        @Test
        @available(iOS 16, *)
        func latestOnly_ExecutesOnlyRelevantTasks_WhenAdditionalTasksQueued() async throws {
            let taskQueue = TaskQueue(executionStyle: .latestOnly)
            let testClock = TestClock()

            // Queue initial batch of tasks
            for index in 0 ..< 3 {
                Task {
                    try await taskQueue.enqueue(operation: {
                        try await testClock.sleep(for: .seconds(1))
                    }, taskID: "A\(index)")
                }
            }

            // Wait a bit before queueing more tasks
            await testClock.advance(by: .seconds(10))

            // Queue second batch of tasks
            for index in 0 ..< 3 {
                Task {
                    try await taskQueue.enqueue(operation: {
                        try await testClock.sleep(for: .seconds(1))
                    }, taskID: "B\(index)")
                }
            }

            await testClock.advance(by: .seconds(10))

            #expect(taskQueue.testsOnly_totalTasksRan == 4)
            // Should execute first and last from each batch
            #expect(taskQueue.testsOnly_executedtaskIDs.contains("A0"))
            #expect(taskQueue.testsOnly_executedtaskIDs.contains("A2"))
            #expect(taskQueue.testsOnly_executedtaskIDs.contains("B0"))
            #expect(taskQueue.testsOnly_executedtaskIDs.contains("B2"))
        }

        @Test
        @available(iOS 16, *)
        func latestOnly_HandlesErrorsCorrectly() async throws {
            let taskQueue = TaskQueue(executionStyle: .latestOnly)
            let testClock = TestClock()
            var errorThrown = false

            Task {
                try await taskQueue.enqueue(operation: {
                    try await testClock.sleep(for: .seconds(1))
                }, taskID: "success")
            }

            Task {
                do {
                    try await taskQueue.enqueue(operation: {
                        struct TestError: Error {}
                        throw TestError()
                    }, taskID: "error")
                } catch {
                    errorThrown = true
                }
            }

            await testClock.advance(by: .seconds(10))

            #expect(errorThrown)
            #expect(taskQueue.testsOnly_executedtaskIDs.contains("success"))
        }

        @Test
        @available(iOS 16, *)
        func allSequentially_PreservesTaskOrder() async throws {
            let taskQueue = TaskQueue(executionStyle: .allSequentially)
            let testClock = TestClock()

            let expectedOrder = ["task1", "task2", "task3", "task4", "task5"]

            // Enqueue tasks with varying sleep times to test ordering
            Task { try await taskQueue.enqueue(operation: { try await testClock.sleep(for: .seconds(1)) }, taskID: "task1") }
            Task { try await taskQueue.enqueue(operation: { try await testClock.sleep(for: .seconds(3)) }, taskID: "task2") }
            Task { try await taskQueue.enqueue(operation: { try await testClock.sleep(for: .seconds(1)) }, taskID: "task3") }
            Task { try await taskQueue.enqueue(operation: { try await testClock.sleep(for: .seconds(5)) }, taskID: "task4") }
            Task { try await taskQueue.enqueue(operation: { try await testClock.sleep(for: .seconds(3)) }, taskID: "task5") }

            await testClock.advance(by: .seconds(20))

            // The execution order should match the enqueue order despite different execution times
            #expect(taskQueue.testsOnly_executedtaskIDs == expectedOrder)
        }

        @Test
        @available(iOS 16, *)
        func latestOnly_HandlesHighConcurrency() async throws {
            let taskQueue = TaskQueue(executionStyle: .latestOnly)
            let testClock = TestClock()

            let taskCount = 50

            // Enqueue a large number of tasks simultaneously
            for index in 0 ..< taskCount {
                Task {
                    try await taskQueue.enqueue(operation: {
                        try await testClock.sleep(for: .seconds(.random(in: 1 ... 5)))
                    }, taskID: index.description)
                }
            }

            await testClock.advance(by: .seconds(300))

            #expect(taskQueue.testsOnly_totalTasksRan == 2)
            #expect(taskQueue.testsOnly_executedtaskIDs.contains("0"))
            #expect(taskQueue.testsOnly_executedtaskIDs.contains(String(taskCount - 1)))
        }
    }

#endif
