# Parameterized Testing

## When to parameterize

- Replace copy-pasted tests and in-test `for` loops with `@Test(arguments: ...)`
- Keep one responsibility per parameterized test

## Single input

```swift
@Test(arguments: 18...21)
func validAges(_ age: Int) {
    #expect(isValidAge(age))
}
```

## Multiple inputs

Two collections produce a cartesian product. Control explosion by reducing sets, splitting tests by concern, or using `zip`.

## `zip` for paired scenarios

Pairs A with B without cartesian explosion. Caveat: silent truncation if lengths differ; case-order fragility with `CaseIterable.allCases`.

## Preferred alternatives to `zip`

- Array of tuples (recommended) — co-located, impossible to misalign
- Dictionary arguments — self-documenting, requires `Hashable` keys
- Fixed-size `zip` with `InlineArray` (Swift 6.2+) — compile-time length enforcement

## `CaseIterable.allCases` is valid only for property-based tests

Where expected result is derived from the property being tested, not a hard-coded mapping.

## Common pitfalls

- Derived expected values masking bugs (expected value derived from same expression as SUT)
- Control flow (`if`/`switch`) inside parameterized test bodies — mirrors implementation logic
- Using in-test `for` loops instead of parameterized arguments
- Passing huge argument sets that explode combinations
- Extracting argument arrays into separate properties (hides coverage, forces reader to jump)
