@testable import AblyChat
import Foundation
import Testing

@MainActor
struct TaskQueueTests {
    @Test
    func latestOnly_OnlyExecutesFirstAndLastTask() async throws {
        let taskQueue = TaskQueue(executionStyle: .latestOnly)

        for index in 0 ..< 5 {
            taskQueue.enqueue(operation: {
                try await Task.sleep(nanoseconds: .random(in: 0 ... 5_000_000)) // 0-5ms
            }, taskID: index.description)
        }

        // Wait actively for the queue to process
        try await waitUntil(timeout: 5_000_000_000) { // 5s max
            taskQueue.testsOnly_totalTasksRan == 2
        }

        #expect(taskQueue.testsOnly_totalTasksRan == 2)
        #expect(taskQueue.testsOnly_executedtaskIDs == ["0", "4"]) // First and last
    }

    @Test
    func allSequentially_ExecutesAllQueuedTasks() async throws {
        let taskQueue = TaskQueue(executionStyle: .allSequentially)
        for _ in 0 ..< 5 {
            taskQueue.enqueue {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }

        // Wait actively for all tasks to finish
        try await waitUntil(timeout: 5_000_000_000) { // 5s max
            taskQueue.testsOnly_totalTasksRan == 5
        }

        #expect(taskQueue.testsOnly_totalTasksRan == 5)
    }

    @Test
    func enqueue_doesNotExecuteMoreThanOneTaskConcurrently() async throws {
        let taskQueue = TaskQueue(executionStyle: .allSequentially)

        for _ in 0 ..< 10 {
            taskQueue.enqueue {
                try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            }
        }

        // Wait actively for all tasks to finish
        try await waitUntil(timeout: 5_000_000_000) { // 5s max
            taskQueue.testsOnly_totalTasksRan == 10
        }

        #expect(taskQueue.testsOnly_maxObservedConcurrentTasks == 1)
    }

    private func waitUntil(timeout: UInt64, condition: @escaping () async -> Bool) async throws {
        let startTime = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - startTime < timeout {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000) // Check every 10ms
        }
        throw TimeoutError()
    }

    struct TimeoutError: Error, CustomStringConvertible {
        var description: String { "Timed out waiting for condition to be met" }
    }
}
