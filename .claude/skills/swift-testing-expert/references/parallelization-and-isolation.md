# Parallelization and Isolation

## Default execution model

- Swift Testing runs tests in parallel by default
- Execution order is randomized to expose hidden test dependencies
- Applies to both synchronous and asynchronous tests

## Isolation strategy

- Avoid shared mutable globals and singleton mutation across tests
- Isolate state per test invocation (fresh suite instance helps)
- Prefer deterministic test data setup over implicit ordering assumptions

## Better pattern — isolate per test

```swift
struct CounterStore {
    var counter = 0
    mutating func increment() { counter += 1 }
}

@Test func isolatedCounter() {
    var store = CounterStore()
    store.increment()
    #expect(store.counter == 1)
}
```

## `.serialized` as a targeted tool

- Apply to suites when tests must run one-at-a-time
- Use as transitional safety measure during migration from serial XCTest suites
- Refactor toward parallel-safe tests before normalizing serialization
- Serialized suites can still run alongside unrelated suites in parallel

## Shared resource scenarios

Isolate backing state per test, use in-memory substitutes, or create separate serial test plan for integration path.

## Do / Don't

- Do fix shared-state coupling before adding broad serialization
- Don't rely on execution order
- Don't mutate singletons across tests without reset/isolation
