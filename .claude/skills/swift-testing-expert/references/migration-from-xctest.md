# Migration from XCTest

## Coexistence strategy

- Swift Testing and XCTest can coexist in the same target
- Migrate incrementally; a single file can import both `XCTest` and `Testing`
- Keep XCTest for: UI automation (`XCUIApplication`), performance APIs (`XCTMetric`), Objective-C-only tests

## Practical migration order

1. Convert assertions to `#expect` / `#require`
2. Replace `test...` naming constraints with explicit `@Test`
3. Reorganize classes into suites where helpful
4. Collapse repetitive methods into parameterized tests
5. Add traits/tags for control and test-plan filtering

## Example conversion

```swift
// Before (XCTest)
final class PriceTests: XCTestCase {
    func testDiscountedTotal() {
        XCTAssertEqual(Price.total(subtotal: 20, discount: 5), 15)
    }
}

// After (Swift Testing)
import Testing
@Test func discountedTotal() {
    #expect(Price.total(subtotal: 20, discount: 5) == 15)
}
```

## Assertion mapping

```swift
// XCTAssertTrue(isEnabled)        → #expect(isEnabled)
// XCTAssertNil(error)             → #expect(error == nil)
// XCTAssertThrowsError(try run()) → #expect(throws: (any Error).self) { try run() }
// try XCTUnwrap(user)             → let user = try #require(user)
// XCTFail("...")                  → Issue.record("...")
```

## Suite model differences

- XCTest: class + `XCTestCase`
- Swift Testing: struct/actor/class suites, explicit attributes, value-semantics-friendly defaults
- `setUp` → suite `init`; teardown → `deinit` (for class/actor suites)
- XCTest sync tests default to main actor; Swift Testing runs on arbitrary tasks unless `@MainActor`

## Async migration

- Bridge completion-handler APIs with `withCheckedContinuation` / `withCheckedThrowingContinuation`
- Replace `XCTestExpectation` with confirmations for async event streams

## Common pitfalls

- Migrating all files at once instead of phased migration
- Keeping `continueAfterFailure` patterns instead of targeted `#require`
- Marking every migrated test `@MainActor` unnecessarily
