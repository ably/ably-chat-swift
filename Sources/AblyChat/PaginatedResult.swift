import Ably

/**
 * A protocol representing a paginated result of items.
 *
 * This protocol allows for iterating through paginated data by fetching additional pages.
 */
@MainActor
public protocol PaginatedResult<Item>: AnyObject, Sendable {
    /// The type of items in this paginated result.
    associatedtype Item

    /// The items in the current page.
    var items: [Item] { get }

    /// Whether there is a next page available.
    var hasNext: Bool { get }

    /// Whether this is the last page.
    var isLast: Bool { get }

    /// Fetches the next page of results, if available.
    func next() async throws(ErrorInfo) -> Self?

    /// Fetches the first page of results.
    func first() async throws(ErrorInfo) -> Self

    /// Returns the current page.
    func current() async throws(ErrorInfo) -> Self
}

/// `PaginatedResult` protocol implementation that wraps an `InternalHTTPPaginatedResponseProtocol` and converts its items to the desired type.
@MainActor
internal final class DefaultPaginatedResult<Underlying: InternalHTTPPaginatedResponseProtocol, Item: JSONDecodable & Sendable>: PaginatedResult {
    internal let items: [Item]
    internal let hasNext: Bool
    internal let isLast: Bool
    private let underlying: Underlying

    internal init(underlying: Underlying, items: [Item]) {
        self.underlying = underlying
        self.items = items
        hasNext = underlying.hasNext
        isLast = underlying.isLast
    }

    /// Convenience initializer that checks status code and decodes items from the response.
    internal convenience init(response: Underlying) throws(ErrorInfo) {
        // TODO: We've had this check since the start of the codebase, but it's not specified anywhere; rectify this in https://github.com/ably/ably-chat-swift/issues/453
        guard response.statusCode == 200 else {
            throw InternalError.paginatedResultStatusCode(response.statusCode).toErrorInfo()
        }

        let items = try response.items.map { jsonValue throws(ErrorInfo) in
            try Item(jsonValue: jsonValue)
        }

        self.init(underlying: response, items: items)
    }

    internal func next() async throws(ErrorInfo) -> DefaultPaginatedResult<Underlying, Item>? {
        guard let nextUnderlying = try await underlying.next() else {
            return nil
        }
        return try DefaultPaginatedResult(response: nextUnderlying)
    }

    internal func first() async throws(ErrorInfo) -> DefaultPaginatedResult<Underlying, Item> {
        try await DefaultPaginatedResult(response: underlying.first())
    }

    internal func current() async throws(ErrorInfo) -> DefaultPaginatedResult<Underlying, Item> {
        self
    }
}

extension DefaultPaginatedResult: Equatable where Item: Equatable {
    internal nonisolated static func == (lhs: DefaultPaginatedResult<Underlying, Item>, rhs: DefaultPaginatedResult<Underlying, Item>) -> Bool {
        lhs.items == rhs.items &&
            lhs.hasNext == rhs.hasNext &&
            lhs.isLast == rhs.isLast
    }
}
