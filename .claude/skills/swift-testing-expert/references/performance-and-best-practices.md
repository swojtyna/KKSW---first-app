# Performance and Best Practices

## Core principles

- Prefer deterministic over timing-sensitive tests
- Prefer synchronous verification when async is not required
- Keep tests independent so parallel execution stays safe
- Treat `.serialized` as a temporary compromise

## 8 practical rules

1. Keep tests synchronous where possible — avoid introducing `async` or sleeps for purely synchronous logic
2. Avoid unnecessary `@MainActor` — reduces useful parallelization
3. Remove shared mutable state — major source of flakiness
4. Prefer in-memory dependencies for the fast path — use fakes/in-memory repos for high-volume runs
5. Use parameterized tests to reduce overhead and improve diagnostics
6. Keep setup cheap and scoped — build expensive fixtures only when needed
7. Use `.serialized` narrowly — add TODO context and remove once dependencies are isolated
8. Flakiness reduction checklist:
   - No reliance on execution order
   - No shared mutable globals/singletons without reset
   - No arbitrary sleeps as synchronization
   - No hidden external dependencies in unit tests
   - Deterministic fixtures and stable clocks/random sources
   - Explicit `withKnownIssue` wrappers for temporary failures

## Quick do / don't

- Do optimize for determinism first, then speed
- Don't treat test slowness as only a hardware problem
- Don't move everything to `@MainActor` or `.serialized` to silence flakiness
