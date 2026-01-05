import Ably

/// A paginated result containing items of a specific type.
///
/// This class provides pagination functionality for query results from the Ably Chat API.
/// You can iterate through pages using the `next()`, `first()`, and `current()` methods.
///
/// For testing purposes, you can create instances using the public initializer:
/// ```swift
/// let mockResult = PaginatedResult(
///     items: [message1, message2],
///     hasNext: false
/// )
/// ```
@MainActor
public final class PaginatedResult<Item: Sendable> {
    /// The items contained in the current page.
    public let items: [Item]

    /// Whether there is a next page available.
    public let hasNext: Bool

    /// Whether this is the last page.
    public let isLast: Bool

    // Internal storage for pagination operations
    private let nextProvider: (@MainActor @Sendable () async throws(ErrorInfo) -> PaginatedResult<Item>?)?
    private let firstProvider: (@MainActor @Sendable () async throws(ErrorInfo) -> PaginatedResult<Item>)?

    /// Creates a `PaginatedResult` for testing or mocking purposes.
    ///
    /// - Parameters:
    ///   - items: The items in this page.
    ///   - hasNext: Whether there is a next page. Defaults to `false`.
    ///   - isLast: Whether this is the last page. Defaults to `!hasNext`.
    ///   - next: Optional closure to provide the next page. If `nil` and `hasNext` is `true`,
    ///           calling `next()` will return `nil`.
    ///   - first: Optional closure to provide the first page. If `nil`, calling `first()`
    ///            will return `self`.
    public init(
        items: [Item],
        hasNext: Bool = false,
        isLast: Bool? = nil,
        next: (@MainActor @Sendable () async throws(ErrorInfo) -> PaginatedResult<Item>?)? = nil,
        first: (@MainActor @Sendable () async throws(ErrorInfo) -> PaginatedResult<Item>)? = nil,
    ) {
        self.items = items
        self.hasNext = hasNext
        self.isLast = isLast ?? !hasNext
        nextProvider = next
        firstProvider = first
    }

    /// Internal initializer for creating from HTTP responses.
    internal init(
        response: some InternalHTTPPaginatedResponseProtocol,
    ) throws(ErrorInfo) where Item: JSONDecodable {
        // TODO: We've had this check since the start of the codebase, but it's not specified anywhere; rectify this in https://github.com/ably/ably-chat-swift/issues/453
        guard response.statusCode == 200 else {
            throw InternalError.paginatedResultStatusCode(response.statusCode).toErrorInfo()
        }

        items = try response.items.map { jsonValue throws(ErrorInfo) in
            try Item(jsonValue: jsonValue)
        }
        hasNext = response.hasNext
        isLast = response.isLast

        // Capture response for pagination
        nextProvider = { @MainActor [response] () async throws(ErrorInfo) -> PaginatedResult<Item>? in
            guard let nextResponse = try await response.next() else {
                return nil
            }
            return try PaginatedResult<Item>(response: nextResponse)
        }
        firstProvider = { @MainActor [response] () async throws(ErrorInfo) -> PaginatedResult<Item> in
            try await PaginatedResult<Item>(response: response.first())
        }
    }

    /// Fetches the next page of results.
    ///
    /// - Returns: The next page, or `nil` if there are no more pages.
    public func next() async throws(ErrorInfo) -> PaginatedResult<Item>? {
        if let nextProvider {
            return try await nextProvider()
        }
        return nil
    }

    /// Fetches the first page of results.
    ///
    /// - Returns: The first page.
    public func first() async throws(ErrorInfo) -> PaginatedResult<Item> {
        if let firstProvider {
            return try await firstProvider()
        }
        return self
    }

    /// Returns the current page.
    ///
    /// - Returns: This page (self).
    public func current() async throws(ErrorInfo) -> PaginatedResult<Item> {
        self
    }
}

extension PaginatedResult: Equatable where Item: Equatable {
    // swiftlint:disable:next missing_docs
    public nonisolated static func == (lhs: PaginatedResult<Item>, rhs: PaginatedResult<Item>) -> Bool {
        lhs.items == rhs.items &&
            lhs.hasNext == rhs.hasNext &&
            lhs.isLast == rhs.isLast
    }
}
