import Ably

// This disable of attributes can be removed once missing_docs fixed here
// swiftlint:disable attributes
@MainActor
// swiftlint:disable:next missing_docs
public protocol PaginatedResult<Item>: AnyObject, Sendable {
    // swiftlint:enable attributes

    // swiftlint:disable:next missing_docs
    associatedtype Item

    // swiftlint:disable:next missing_docs
    var items: [Item] { get }
    // swiftlint:disable:next missing_docs
    var hasNext: Bool { get }
    // swiftlint:disable:next missing_docs
    var isLast: Bool { get }
    // swiftlint:disable:next missing_docs
    func next() async throws(ARTErrorInfo) -> Self?
    // swiftlint:disable:next missing_docs
    func first() async throws(ARTErrorInfo) -> Self
    // swiftlint:disable:next missing_docs
    func current() async throws(ARTErrorInfo) -> Self
}

/// Used internally to reduce the amount of duplicate code when interacting with `ARTHTTPPaginatedCallback`'s. The wrapper takes in the callback result from the caller e.g. `realtime.request` and either throws the appropriate error, or decodes and returns the response.
internal struct ARTHTTPPaginatedCallbackWrapper<Response: JSONDecodable & Sendable & Equatable> {
    internal let callbackResult: (ARTHTTPPaginatedResponse?, ARTErrorInfo?)

    @MainActor
    internal func handleResponse(continuation: CheckedContinuation<Result<PaginatedResultWrapper<Response>, InternalError>, Never>) {
        let (paginatedResponse, error) = callbackResult

        // (CHA-M5i) If the REST API returns an error, then the method must throw its ErrorInfo representation.
        // (CHA-M6b) If the REST API returns an error, then the method must throw its ErrorInfo representation.
        if let error {
            continuation.resume(returning: .failure(.fromAblyCocoa(error)))
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
internal final class PaginatedResultWrapper<Item: JSONDecodable & Sendable & Equatable>: PaginatedResult, @MainActor Equatable {
    internal let items: [Item]
    internal let hasNext: Bool
    internal let isLast: Bool
    internal let paginatedResponse: ARTHTTPPaginatedResponse

    internal init(paginatedResponse: ARTHTTPPaginatedResponse, items: [Item]) {
        self.items = items
        hasNext = paginatedResponse.hasNext
        isLast = paginatedResponse.isLast
        self.paginatedResponse = paginatedResponse
    }

    /// Asynchronously fetch the next page if available
    internal func next() async throws(ARTErrorInfo) -> PaginatedResultWrapper<Item>? {
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

    /// Asynchronously fetch the first page
    internal func first() async throws(ARTErrorInfo) -> PaginatedResultWrapper<Item> {
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

    /// Asynchronously fetch the current page
    internal func current() async throws(ARTErrorInfo) -> PaginatedResultWrapper<Item> {
        self
    }

    internal static func == (lhs: PaginatedResultWrapper<Item>, rhs: PaginatedResultWrapper<Item>) -> Bool {
        lhs.items == rhs.items &&
            lhs.hasNext == rhs.hasNext &&
            lhs.isLast == rhs.isLast &&
            lhs.paginatedResponse == rhs.paginatedResponse
    }
}

internal extension ARTHTTPPaginatedResponse {
    /// Converts an `ARTHTTPPaginatedResponse` to a `PaginatedResultWrapper` allowing for access to operations as per conformance to `PaginatedResult`.
    @MainActor
    func toPaginatedResult<Item: JSONDecodable & Sendable>(items: [Item]) -> PaginatedResultWrapper<Item> {
        PaginatedResultWrapper(paginatedResponse: self, items: items)
    }
}
