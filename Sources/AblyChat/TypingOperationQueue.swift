import Ably
import Foundation

/// Implemements the CHA-T14 queueing behaviour for ``DefaultTyping``'s `keystroke()` and `stop()` operations.
///
/// Accepts requests to perform an operation via ``enqueue(operation:)``. Depending on the queue's current state, this operation may be performed immediately, or the request may be enqueued to be performed later, in which case it might end up being replaced via a later `enqueue(…)` call. See documentation for that method for more details.
///
/// - Note: The naming of this class is a bit tricky: `OperationQueue` already has a meaning in Foundation, and this has nothing to do with that. But "operation" seems a better word than "task", which has a specific meaning in Swift concurrency. So we choose what seems like the lesser of two evils.
@MainActor
internal class TypingOperationQueue<Failure: Error> {
    /// A request to execute an operation.
    private struct Request {
        // We're using `Result` here because if you try to write `throws (Failure)` you get "Runtime support for typed throws function types is only available in macOS 15.0.0 or newer" 🤷
        /// The work to be (potentially) performed.
        private var operation: () async -> Result<Void, Failure>
        /// Determines the result of this request's call to `enqueue`.
        private var continuation: CheckedContinuation<Result<Void, Failure>, Never>

        init(
            operation: @escaping () async throws(Failure) -> Void,
            continuation: CheckedContinuation<Result<Void, Failure>, Never>,
        ) {
            // Convert from throwing to `Result`-returning
            self.operation = {
                do throws(Failure) {
                    try await operation()
                    return .success(())
                } catch {
                    return .failure(error)
                }
            }

            self.continuation = continuation
        }

        /// Executes the requested operation, and causes this request's call to `enqueue` to complete with the result of the execution.
        func performOperation() async {
            let result = await operation()
            complete(with: result)
        }

        /// Causes this request's call to `enqueue` to complete with the given result.
        func complete(with result: Result<Void, Failure>) {
            continuation.resume(returning: result)
        }
    }

    /// Describes what the queue is currently doing and what it should do after it finishes what it's currently doing.
    private enum State {
        /// No operation is currently being executed.
        case idle

        /// An operation is currently being executed, and there is possibly another request enqueued to be performed when the current operation completes.
        ///
        /// - Important: `pendingRequest` is not the request that is currently being executed; it is the request that is _next in line to be executed_.
        case executing(pendingRequest: Request?)
    }

    private var state = State.idle

    /// Requests that a given operation be performed, and returns the eventual outcome of this request.
    ///
    /// - If the queue is not currently executing an operation, then the newly-requested operation will be immediately executed, and the method call will indicate the result of this execution (by returning or throwing).
    /// - If the queue is currently executing an operation, then any pending request (i.e. requested but execution of operation not yet started) will be completed with an outcome that indicates success (that is, the corresponding call to `enqueue` will return without throwing), but _its operation will not be executed_. The queue's pending request will be set to the given request, to be executed once the currently-executing operation completes (unless replaced via a later call to `enqueue`).
    internal func enqueue(operation: @escaping () async throws(Failure) -> Void) async throws(Failure) {
        switch state {
        case .idle:
            // Execute the operation immediately
            state = .executing(pendingRequest: nil)
            defer { didFinishExecutingOperation() }
            try await operation()
        case let .executing(pendingRequest):
            // Replace any pending request, indicating that it succeeded
            try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, Failure>, Never>) in
                if let pendingRequest {
                    pendingRequest.complete(with: .success(()))
                }

                let request = Request(operation: operation, continuation: continuation)
                state = .executing(pendingRequest: request)
            }.get()
        }
    }

    /// Called once the queue has finished executing its current operation.
    private func didFinishExecutingOperation() {
        guard case let .executing(pendingRequest) = state else {
            preconditionFailure()
        }

        if let pendingRequest {
            // If there's a pending request, execute it.
            state = .executing(pendingRequest: nil)
            Task {
                // We don't care about the result of this execution; `performOperation` takes care of propagating it to the requester's call to `enqueue`.
                await pendingRequest.performOperation()
                didFinishExecutingOperation()
            }
        } else {
            // No more work to do.
            state = .idle
        }
    }
}
