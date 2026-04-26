# Swift Testing Fundamentals

## Core Structure

- Import `Testing` exclusively in test targets
- Use `@Test` to explicitly declare tests as global functions or type methods
- Organize tests into suites using `struct`, `actor`, or `class` types
- Prefer `struct` for value semantics and to prevent accidental state sharing

## Best Practices

- "Keep tests small and behavior-focused"
- Use descriptive naming rather than boilerplate prefixes
- Apply display names when human-readable output aids troubleshooting
- Localize setup code or consolidate in suite initializers when shared

## Critical Constraint

Any suite with instance test methods must have a callable zero-argument initializer (with optional default parameters, potentially async or throwing). If this requirement cannot be satisfied, convert to static/global functions or restructure the suite's state management.

## Availability Handling

Apply `@available` annotations to individual test functions, never to suite type declarations themselves.

## Organization Strategy

Group tests by feature behavior rather than implementation class alone, and leverage tags for cross-cutting concerns across multiple files or targets.
