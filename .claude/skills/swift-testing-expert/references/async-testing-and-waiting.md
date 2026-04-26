# Async Testing and Waiting

## Preferred approach

Use async test functions and `await` naturally. Prefer confirmations for async event-style tests that are not naturally awaitable.

```swift
@Test func fetchNameReturnsValue() async throws {
    let client = APIClient()
    let value = try await client.fetchName()
    #expect(value == "Antoine")
}
```

## Callback bridging

Use `withCheckedContinuation` / `withCheckedThrowingContinuation` for completion-handler APIs.

## Confirmations for async events

```swift
@Test func eventIsPublishedTwice() async {
    await confirmation("Publishes two events", expectedCount: 2) { confirm in
        confirm()
        confirm()
    }
}
```

## Actor-isolated counting

Use `actor` state instead of unsafe mutable shared counters in callbacks.

## Anti-patterns to avoid

- Returning from test before async callback work completes
- Sleeping/time-based waits as primary synchronization (`Task.sleep` as sync mechanism)
- Mutating shared globals from callback closures in strict concurrency mode

## Actor isolation

Use `@MainActor` on tests only when behavior truly requires it; keep non-UI tests off main actor.
