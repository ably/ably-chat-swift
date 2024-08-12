public protocol PaginatedResult<T>: AnyObject, Sendable {
    associatedtype T

    var items: [T] { get }
    var hasNext: Bool { get }
    var isLast: Bool { get }
    // TODO: is there a way to link `hasNext` and `next`’s nullability?
    var next: (any PaginatedResult<T>)? { get async throws }
    var first: any PaginatedResult<T> { get async throws }
    var current: Bool { get async throws }
}
