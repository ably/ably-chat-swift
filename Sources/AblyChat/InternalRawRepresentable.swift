// This is just copied from swift's `RawRepresentable`, because compiler requires its implementations to be public as well, but we want to leave raw values as internal details only.
internal protocol InternalRawRepresentable<RawValue> {
    associatedtype RawValue

    init?(rawValue: Self.RawValue)

    var rawValue: Self.RawValue { get }
}
