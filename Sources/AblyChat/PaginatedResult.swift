import Ably

public protocol PaginatedResult<Item>: AnyObject, Sendable, Equatable {
    associatedtype Item

    var items: [Item] { get }
    var hasNext: Bool { get }
    var isLast: Bool { get }
    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/11): consider how to avoid the need for an unwrap
    // Note that there seems to be a compiler bug (https://github.com/swiftlang/swift/issues/79992) that means that the compiler does not enforce the access level of the error type for property getters. I accidentally originally wrote these as throws(InternalError), which the compiler should have rejected since InternalError is internal and this protocol is public, but it did not reject it and this mistake was only noticed in code review.
    #if swift(>=6.2)
        var next: (any PaginatedResult<Item>)? { get async throws(ARTErrorInfo) }
        var first: any PaginatedResult<Item> { get async throws(ARTErrorInfo) }
        var current: any PaginatedResult<Item> { get async throws(ARTErrorInfo) }
    #else
        // TODO: (https://github.com/ably/ably-chat-swift/issues/267) restore typed throws here once Xcode 16.3 compiler bug fixed
        var next: (any PaginatedResult<Item>)? { get async throws }
        var first: any PaginatedResult<Item> { get async throws }
        var current: any PaginatedResult<Item> { get async throws }
    #endif
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
internal final class PaginatedResultWrapper<Item: JSONDecodable & Sendable & Equatable>: PaginatedResult {
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
    #if swift(>=6.2)
        internal var next: (any PaginatedResult<Item>)? {
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
    #else
        internal var next: (any PaginatedResult<Item>)? {
            get async throws {
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
    #endif

    /// Asynchronously fetch the first page
    #if swift(>=6.2)
        internal var first: any PaginatedResult<Item> {
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
    #else
        internal var first: any PaginatedResult<Item> {
            get async throws {
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
    #endif

    /// Asynchronously fetch the current page
    internal var current: any PaginatedResult<Item> {
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
    func toPaginatedResult<Item: JSONDecodable & Sendable>(items: [Item]) -> PaginatedResultWrapper<Item> {
        PaginatedResultWrapper(paginatedResponse: self, items: items)
    }
}
