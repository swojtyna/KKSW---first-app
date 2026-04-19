import Foundation

// MARK: - DI Container (Core)

/// Thread-safe Dependency Injection Container.
/// Architecture: Singleton registry.
/// Concurrency: Uses NSRecursiveLock. @unchecked Sendable to manage internal storage lock manually.
public final class DIContainer: @unchecked Sendable {
    public static let shared = DIContainer()

    // Internal factory type. Stored as Any to allow heterogenous storage.
    private typealias StorageFactory = @Sendable (DIContainer) -> Any

    public enum ObjectScope: Sendable {
        case unique  // Creates new instance every resolve.
        case application  // Singleton. Created once, cached.
    }

    private struct ServiceEntry {
        let scope: ObjectScope
        let factory: StorageFactory
        var instance: Any?
    }

    private var storage: [String: ServiceEntry] = [:]
    private let lock = NSRecursiveLock()

    private init() {}

    // MARK: - Registration

    /// Universal register method.
    /// Constraint: Factory MUST be @MainActor.
    /// Purpose: Allows safe creation of UI components (Coordinators, ViewModels) and Background Services using single API.
    /// Mechanism: Wraps factory in MainActor.assumeIsolated to satisfy Swift 6 strict concurrency checks.
    public func register<T: Sendable>(
        _ type: T.Type,
        scope: ObjectScope,
        factory: @escaping @MainActor (DIContainer) -> T
    ) {
        lock.lock()
        defer { lock.unlock() }

        let key = String(reflecting: type)

        // Wrap MainActor closure into Sendable storage closure.
        // Resolver handles isolation context.
        let wrappedFactory: StorageFactory = { container in
            MainActor.assumeIsolated {
                factory(container)
            }
        }

        storage[key] = ServiceEntry(scope: scope, factory: wrappedFactory, instance: nil)
    }

    // MARK: - Resolution

    /// Resolves dependency.
    /// Constraint: Must be called from Main Thread if resolving UI components registered via above method.
    public func resolve<T>(_ type: T.Type = T.self) -> T {
        lock.lock()
        defer { lock.unlock() }

        let key = String(reflecting: type)

        guard var entry = storage[key] else {
            fatalError("📛 DIContainer: \(key) not registered. Check Injection files.")
        }

        // Return cached singleton if exists
        if let instance = entry.instance as? T {
            return instance
        }

        // Create instance.
        // Executes wrapped factory. Uses MainActor.assumeIsolated implicitly.
        guard let object = entry.factory(self) as? T else {
            fatalError("📛 DIContainer: Factory for \(key) returned wrong type.")
        }

        // Cache if application scope
        if entry.scope == .application {
            entry.instance = object
            storage[key] = entry
        }

        return object
    }

    /// Clears storage. Testing only.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
