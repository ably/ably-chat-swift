import Foundation

/// A property wrapper that uses a mutex to protect its wrapped value from concurrent reads and writes. Similar to Objective-C’s `@atomic`.
///
/// Don’t overestimate the abilities of this property wrapper; it won’t allow you to, for example, increment a counter in a threadsafe manner.
@propertyWrapper
struct SynchronizedAccess<Value> {
    var wrappedValue: Value {
        get {
            mutex.withLock {
                _wrappedValue
            }
        }

        set {
            mutex.withLock {
                _wrappedValue = newValue
            }
        }
    }

    private var _wrappedValue: Value
    private var mutex = NSLock()

    init(wrappedValue: Value) {
        _wrappedValue = wrappedValue
    }
}
