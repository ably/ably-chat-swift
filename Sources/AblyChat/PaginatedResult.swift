import Ably

public protocol PaginatedResult<T>: AnyObject, Sendable, Equatable {
    associatedtype T

    var items: [T] { get }
    var hasNext: Bool { get }
    var isLast: Bool { get }
    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/11): consider how to avoid the need for an unwrap
    // Note that there seems to be a compiler bug (https://github.com/swiftlang/swift/issues/79992) that means that the compiler does not enforce the access level of the error type for property getters. I accidentally originally wrote these as throws(InternalError), which the compiler should have rejected since InternalError is internal and this protocol is public, but it did not reject it and this mistake was only noticed in code review.
    var next: (any PaginatedResult<T>)? { get async throws(ARTErrorInfo) }
    var first: any PaginatedResult<T> { get async throws(ARTErrorInfo) }
    var current: any PaginatedResult<T> { get async throws(ARTErrorInfo) }
}

/// Used internally to reduce the amount of duplicate code when interacting with `ARTHTTPPaginatedCallback`'s. The wrapper takes in the callback result from the caller e.g. `realtime.request` and either throws the appropriate error, or decodes and returns the response.
internal struct ARTHTTPPaginatedCallbackWrapper<Response: JSONDecodable & Sendable & Equatable> {
    internal let callbackResult: (ARTHTTPPaginatedResponse?, ARTErrorInfo?)

    internal func handleResponse(continuation: CheckedContinuation<Result<PaginatedResultWrapper<Response>, InternalError>, Never>) {
        let (paginatedResponse, error) = callbackResult

        // (CHA-M5i) If the REST API returns an error, then the method must throw its ErrorInfo representation.
        // (CHA-M6b) If the REST API returns an error, then the method must throw its ErrorInfo representation.
        if let error {
            continuation.resume(returning: .failure(error.toInternalError()))
            return
        }

        guard let paginatedResponse, paginatedResponse.statusCode == 200 else {
            continuation.resume(returning: .failure(PaginatedResultError.noErrorWithInvalidResponse.toInternalError()))
            return
        }

        do {
            let jsonValues = paginatedResponse.items.map { JSONValue(ablyCocoaData: $0) }
            let decodedResponse = try jsonValues.map { jsonValue throws(InternalError) in try Response(jsonValue: jsonValue) }
            let result = paginatedResponse.toPaginatedResult(items: decodedResponse)
            continuation.resume(returning: .success(result))
        } catch {
            continuation.resume(returning: .failure(error))
        }
    }
}

internal enum PaginatedResultError: Error {
    case noErrorWithInvalidResponse
}

/// `PaginatedResult` protocol implementation allowing access to the underlying items from a lower level paginated response object e.g. `ARTHTTPPaginatedResponse`, whilst succinctly handling errors through the use of `ARTHTTPPaginatedCallbackWrapper`.
internal final class PaginatedResultWrapper<T: JSONDecodable & Sendable & Equatable>: PaginatedResult {
    internal let items: [T]
    internal let hasNext: Bool
    internal let isLast: Bool
    internal let paginatedResponse: ARTHTTPPaginatedResponse

    internal init(paginatedResponse: ARTHTTPPaginatedResponse, items: [T]) {
        self.items = items
        hasNext = paginatedResponse.hasNext
        isLast = paginatedResponse.isLast
        self.paginatedResponse = paginatedResponse
    }

    /// Asynchronously fetch the next page if available
    internal var next: (any PaginatedResult<T>)? {
        get async throws(ARTErrorInfo) {
            do {
                return try await withCheckedContinuation { continuation in
                    paginatedResponse.next { paginatedResponse, error in
                        ARTHTTPPaginatedCallbackWrapper(callbackResult: (paginatedResponse, error)).handleResponse(continuation: continuation)
                    }
                }.get()
            } catch {
                throw error.toARTErrorInfo()
            }
        }
    }

    /// Asynchronously fetch the first page
    internal var first: any PaginatedResult<T> {
        get async throws(ARTErrorInfo) {
            do {
                return try await withCheckedContinuation { continuation in
                    paginatedResponse.first { paginatedResponse, error in
                        ARTHTTPPaginatedCallbackWrapper(callbackResult: (paginatedResponse, error)).handleResponse(continuation: continuation)
                    }
                }.get()
            } catch {
                throw error.toARTErrorInfo()
            }
        }
    }

    /// Asynchronously fetch the current page
    internal var current: any PaginatedResult<T> {
        self
    }

    internal static func == (lhs: PaginatedResultWrapper<T>, rhs: PaginatedResultWrapper<T>) -> Bool {
        lhs.items == rhs.items &&
            lhs.hasNext == rhs.hasNext &&
            lhs.isLast == rhs.isLast &&
            lhs.paginatedResponse == rhs.paginatedResponse
    }
}

internal extension ARTHTTPPaginatedResponse {
    /// Converts an `ARTHTTPPaginatedResponse` to a `PaginatedResultWrapper` allowing for access to operations as per conformance to `PaginatedResult`.
    func toPaginatedResult<T: JSONDecodable & Sendable>(items: [T]) -> PaginatedResultWrapper<T> {
        PaginatedResultWrapper(paginatedResponse: self, items: items)
    }
}
