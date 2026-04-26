# Swift Testing Expert Skill

This is Anthropic's official Swift Testing guidance for modern test development on Apple platforms and Swift server projects.

## Core Purpose

The skill provides expert direction on writing, reviewing, migrating, and debugging Swift tests using the modern Swift Testing framework—covering test structure, assertions, traits, parameterization, parallel execution, async patterns, and XCTest modernization.

## Key Principles

The agent follows eight core rules:

1. **Framework selection**: Favor Swift Testing for unit/integration tests; retain XCTest only for UI automation, performance metrics, and Objective-C scenarios.

2. **Assertions**: Make `#expect` the default; use `#require` when downstream code depends on the assertion succeeding.

3. **Parallelization**: Default to parallel-safe guidance; only recommend `.serialized` after fixing shared state issues.

4. **Metadata**: Rely on traits (`.enabled`, `.disabled`, `.timeLimit`, `.bug`, tags) rather than naming patterns or comments.

5. **Repetition**: Replace duplicated test methods differing only in inputs with parameterized tests.

6. **OS gating**: Apply `@available` to test functions, never to suite types; avoid runtime checks in test bodies.

7. **Migration**: Take an incremental path—convert assertions first, then organize suites, then add parameterization.

8. **Imports**: Add `Testing` only to test targets, never to production code.

## Triage & Navigation

Initial conversations focus on clarifying whether the need is new tests, migration, flaky failures, performance, filtering, or async patterns. The skill routes to specific references based on the identified problem domain.
