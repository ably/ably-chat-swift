import Foundation
import Semaphore

internal enum TaskQueueExecutionStyle {
    case latestOnly
    case allSequentially
}

@MainActor
internal class TaskQueue {
    private let semaphore = AsyncSemaphore(value: 1)
    private let executionStyle: TaskQueueExecutionStyle
    private var enqueuedTasks: [(operation: () async throws -> Void, taskID: String?)] = []
    private var isRunning = false

    internal init(executionStyle: TaskQueueExecutionStyle) {
        self.executionStyle = executionStyle
    }

    internal func enqueue(operation: @escaping () async throws -> Void, taskID: String? = nil) {
        if executionStyle == .latestOnly {
            enqueuedTasks.removeAll()
        }
        enqueuedTasks.append((operation, taskID))
        Task { try await processQueue() }
    }

    private func processQueue() async throws {
        guard !isRunning else {
            return
        }
        isRunning = true

        while let taskToExecute = enqueuedTasks.first {
            await semaphore.wait()
            defer { semaphore.signal() }

            enqueuedTasks.removeFirst()

            #if DEBUG
                testsOnly_currentlyRunningTasks += 1
                testsOnly_maxObservedConcurrentTasks = max(testsOnly_maxObservedConcurrentTasks, testsOnly_currentlyRunningTasks)
            #endif

            do {
                try await taskToExecute.operation()
            } catch {
                isRunning = false
                throw error
            }

            #if DEBUG
                testsOnly_currentlyRunningTasks -= 1
                testsOnly_totalTasksRan += 1
                if let taskID = taskToExecute.taskID {
                    testsOnly_executedtaskIDs.append(taskID)
                }
            #endif
        }

        isRunning = false
    }

    #if DEBUG
        internal var testsOnly_totalTasksRan: Int = 0
        internal var testsOnly_maxObservedConcurrentTasks: Int = 0
        internal var testsOnly_currentlyRunningTasks: Int = 0
        internal var testsOnly_executedtaskIDs: [String] = []

    #endif
}
