import Foundation

// MARK: - Injected Property Wrapper

/// Eager Injection: Fetches dependency IMMEDIATELY during initialization
/// Useful when you know the object is lightweight and needed immediately
@propertyWrapper
public struct Injected<Value> {
    public let wrappedValue: Value

    public init() {
        self.wrappedValue = DIContainer.shared.resolve(Value.self)
    }
}
