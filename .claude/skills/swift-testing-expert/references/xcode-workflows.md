# Xcode Workflows

## Test Navigator usage

- Run tests at function, suite, tag, and argument level
- In parameterized tests, rerun only failing arguments for fast iteration
- Use "Group by Tag" to inspect cross-suite behavior

## Filtering and grouping

- Use tag filters in navigator for focused development loops
- Prefer tag-based include/exclude over fragile test-name patterns

## Suggested tag conventions

- `core` — always-on fast checks
- `integration` — external dependency coverage
- `regression` — bug-fix lock-in tests
- `flaky` — temporary quarantine while fixing

## Test plans

- Maintain separate plans: fast core checks, integration checks, slower/optional scenarios
- Example strategy:
  - `Core` plan: include `core`, exclude `integration`
  - `Integration` plan: include `integration`, exclude `flaky`
  - `ReleaseGate` plan: include `core` and `regression`

## Report triage sequence

1. Check if failures cluster by a shared tag
2. Open one representative failure
3. Confirm whether root cause is common (dependency/outage/config) or test-local
4. Fix root cause, then remove temporary `withKnownIssue` annotations

## Diagnostic quality

- Keep expectations expressive and narrow
- Improve argument/type descriptions for faster root-cause identification
- Ensure bug traits link to trackable issues
