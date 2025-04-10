import Ably

public protocol PaginatedResult: AnyObject, Sendable, Equatable {
    associatedtype T

    var items: [T] { get }
    var hasNext: Bool { get }
    var isLast: Bool { get }
    // TODO: (https://github.com/ably-labs/ably-chat-swift/issues/11): consider how to avoid the need for an unwrap
    func next() async throws(ARTErrorInfo) -> AnyPaginatedResult<T>?
    func first() async throws(ARTErrorInfo) -> AnyPaginatedResult<T>
    func current() async throws(ARTErrorInfo) -> AnyPaginatedResult<T>
}

// TODO explain (workaround for https://github.com/swiftlang/swift/issues/80732)
public final class AnyPaginatedResult<T>: PaginatedResult {
    private let itemsImpl: @Sendable () -> [T]
    public var items: [T] {
        itemsImpl()
    }

    private let hasNextImpl: @Sendable () -> Bool
    public var hasNext: Bool {
        hasNextImpl()
    }

    private let isLastImpl: @Sendable () -> Bool
    public var isLast: Bool {
        isLastImpl()
    }

    private let nextImpl: @Sendable () async throws(ARTErrorInfo) -> AnyPaginatedResult<T>?
    public func next() async throws(ARTErrorInfo) -> AnyPaginatedResult<T>? {
        try await nextImpl()
    }
    
    private let firstImpl: @Sendable () async throws(ARTErrorInfo) -> AnyPaginatedResult<T>
    public func first() async throws(ARTErrorInfo) -> AnyPaginatedResult<T> {
        try await firstImpl()
    }
    
    private let currentImpl: @Sendable () async throws(ARTErrorInfo) -> AnyPaginatedResult<T>
    public func current() async throws(ARTErrorInfo) -> AnyPaginatedResult<T> {
        try await currentImpl()
    }

    init<Underlying: PaginatedResult>(underlying: Underlying) where Underlying.T == T {
        itemsImpl = {
            underlying.items
        }
        hasNextImpl = {
            underlying.hasNext
        }
        isLastImpl = {
            underlying.isLast
        }
        nextImpl = { () throws (ARTErrorInfo) in
            try await underlying.next()
        }
        firstImpl = { () throws (ARTErrorInfo) in
            try await underlying.first()
        }
        currentImpl = { () throws (ARTErrorInfo) in
            try await underlying.current()
        }
    }

    public static func == (lhs: AnyPaginatedResult<T>, rhs: AnyPaginatedResult<T>) -> Bool {
        fatalError("TODO")
    }
}

/// Used internally to reduce the amount of duplicate code when interacting with `ARTHTTPPaginatedCallback`'s. The wrapper takes in the callback result from the caller e.g. `realtime.request` and either throws the appropriate error, or decodes and returns the response.
internal struct ARTHTTPPaginatedCallbackWrapper<Response: JSONDecodable & Sendable & Equatable> {
    internal let callbackResult: (ARTHTTPPaginatedResponse?, ARTErrorInfo?)

    internal func handleResponse(continuation: CheckedContinuation<Result<AnyPaginatedResult<Response>, InternalError>, Never>) {
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
            let typeErased = AnyPaginatedResult(underlying: result)
            continuation.resume(returning: .success(typeErased))
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
    internal func next() async throws(ARTErrorInfo) -> (AnyPaginatedResult<T>)? {
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
    internal func first() async throws(ARTErrorInfo) -> (AnyPaginatedResult<T>) {
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
    internal func current() -> AnyPaginatedResult<T> {
        .init(underlying: self)
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
