# Traits and Tags

## Trait categories

- Informational: display names, bug links, tags
- Conditional: `.enabled(if:)`, `.disabled(...)`, availability attributes
- Behavioral: `.timeLimit(...)`, `.serialized`

## Conditions and disabling

- Use `.disabled("reason")` instead of commenting tests out
- Include actionable reason text for CI/test reports
- Add `.bug(...)` to link issue trackers

## Availability

- Use `@available` on tests when entire behavior is OS-gated
- Prefer `@available` over inline runtime checks

## Tags — defining and applying

```swift
extension Tag {
    @Tag static var networking: Self
    @Tag static var regression: Self
}

@Suite(.tags(.networking))
struct APITests {
    @Test func fetchUser() async throws { #expect(true) }
}
```

## Inheritance

Traits and tags on suites cascade to contained tests. Apply at suite level when broadly true.

## Do / Don't

- Do put shared tags at suite level; attach bug links for temporary disables
- Don't use tags as a replacement for meaningful suite grouping
- Don't overuse `.serialized` as a blanket reliability fix
