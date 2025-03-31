import Ably
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
    private var enqueuedTasks: [(operation: () async throws -> Void, continuation: CheckedContinuation<Void, Error>, taskID: String?)] = []
    private var isRunning = false

    internal init(executionStyle: TaskQueueExecutionStyle) {
        self.executionStyle = executionStyle
    }

    internal func enqueue(operation: @escaping () async throws -> Void, taskID: String? = nil) async throws(ARTErrorInfo) {
        do {
            try await withCheckedThrowingContinuation { continuation in
                if executionStyle == .latestOnly {
                    // Silently complete any pending tasks as no-op success
                    if enqueuedTasks.count > 1 {
                        for task in enqueuedTasks.dropFirst() {
                            task.continuation.resume(returning: ())
                        }
                        enqueuedTasks.removeSubrange(1...)
                    }
                }

                enqueuedTasks.append((operation, continuation, taskID))
                Task {
                    try await processQueue()
                }
            }
        } catch {
            // Convert any errors to ARTErrorInfo
            if let artError = error as? ARTErrorInfo {
                throw artError
            } else {
                throw ARTErrorInfo.create(withCode: 50000, status: 500, message: error.localizedDescription)
            }
        }
    }

    private func processQueue() async throws(ARTErrorInfo) {
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
                taskToExecute.continuation.resume(returning: ())
            } catch {
                isRunning = false
                if let artError = error as? ARTErrorInfo {
                    taskToExecute.continuation.resume(throwing: artError)
                    throw artError
                } else {
                    let artError = ARTErrorInfo.create(withCode: 50000, status: 500, message: error.localizedDescription)
                    taskToExecute.continuation.resume(throwing: artError)
                    throw artError
                }
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
