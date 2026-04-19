import Foundation

// MARK: - Lazy Injected Property Wrapper

/// Lazy Injection with Cache
/// Thread-safe via NSLock. @unchecked Sendable for Swift 6 compatibility.
/// Uses `final class` to modify internal state (`cached`) without `mutating`
/// Works fast (resolve only once) and everywhere (in classes and structs)
@propertyWrapper
public final class LazyInjected<Value>: @unchecked Sendable {
    private var cached: Value?
    private let lock = NSLock()

    public var wrappedValue: Value {
        lock.lock()
        defer { lock.unlock() }

        // If already fetched once, return from wrapper cache
        if let cached = cached {
            return cached
        }

        // First fetch: go to container
        let object = DIContainer.shared.resolve(Value.self)
        cached = object
        return object
    }

    public init() {}
}
