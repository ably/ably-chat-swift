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
    func next() async throws(ErrorInfo) -> Self?
    // swiftlint:disable:next missing_docs
    func first() async throws(ErrorInfo) -> Self
    // swiftlint:disable:next missing_docs
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

    /// Asynchronously fetch the next page if available
    internal func next() async throws(ErrorInfo) -> DefaultPaginatedResult<Underlying, Item>? {
        guard let nextUnderlying = try await underlying.next() else {
            return nil
        }
        return try DefaultPaginatedResult(response: nextUnderlying)
    }

    /// Asynchronously fetch the first page
    internal func first() async throws(ErrorInfo) -> DefaultPaginatedResult<Underlying, Item> {
        try await DefaultPaginatedResult(response: underlying.first())
    }

    /// Asynchronously fetch the current page
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
