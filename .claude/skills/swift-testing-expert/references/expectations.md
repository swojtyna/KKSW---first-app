# Expectations

## Primary assertion method

`#expect` is the default. Pass natural Swift expressions (`==`, `>`, `.contains`, `.isEmpty`, etc.).

## Prerequisites & unwrapping

Use `#require` for conditions that later tests depend on — acts as an early exit and safely unwraps optionals.

## Throw verification

Use throw-aware expectations rather than manual `do/catch` — check for any error, specific error types, or particular error cases.

## Temporary failures

Use `withKnownIssue` wrapper to keep tests active while marking specific sections as expected failures — preferable to disabling entire tests.

## Better diagnostics

Make domain types conform to `CustomTestStringConvertible` for cleaner failure output.

## XCTest migration mappings

```swift
// XCTAssertTrue(isEnabled)        → #expect(isEnabled)
// XCTAssertNil(error)             → #expect(error == nil)
// XCTAssertThrowsError(try run()) → #expect(throws: (any Error).self) { try run() }
// try XCTUnwrap(user)             → let user = try #require(user)
// XCTFail("...")                  → Issue.record("...")
```
