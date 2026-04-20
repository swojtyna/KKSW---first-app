---
phase: 06-engagement-layer
plan: 01
subsystem: stats
tags: [swift, xctest, foundation, calendar, dst, streak, clean-architecture, usecase]

# Dependency graph
requires:
  - phase: 03-quick-sessions
    provides: SessionRecord (outcome, actualEndAt) — the raw data source for stats
provides:
  - Stats value type (currentStreak, longestStreak, totalCount, last7DaysFlags Monday-first, todayWeekdayIndex, completedDaysSet)
  - ComputeStatsUseCase protocol + ComputeStatsUseCaseImpl pure function ([SessionRecord] + Date → Stats)
  - SessionRecordFixtures shared test builder (completed / cancelled / brokenByRevoke / active / malformed + polishCalendar)
  - 22 unit tests proving GAM-01 + GAM-02 correctness (totalCount / current / longest / weekday-flags / DST / defensive)
affects: [06-02-stats-repository, 06-05-stats-screen, home-card, stats-screen, gam-01, gam-02]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure UseCase with Calendar injected for deterministic testing"
    - "Monday-first mapping: mondayFirstIndex = (Calendar.weekday + 5) % 7"
    - "Trailing-edge streak (D-03): today empty + yesterday .completed = streak alive"
    - "Europe/Warsaw fixture calendar with firstWeekday=2 for test determinism"

key-files:
  created:
    - DeluluDetox/Sources/Features/Stats/Repository/Models/Stats.swift
    - DeluluDetox/Sources/Features/Stats/UseCase/ComputeStatsUseCase.swift
    - DeluluDetoxTests/Features/Stats/Fixtures/SessionRecordFixtures.swift
    - DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift
  modified: []

key-decisions:
  - "Calendar injected via init (default: Gregorian with firstWeekday=2) — no Calendar.current calls inside algorithm"
  - "DST safety guaranteed by Calendar.date(byAdding:.day) exclusively — zero TimeInterval arithmetic"
  - "Defensive ignoring of malformed records: outcome==.completed with actualEndAt==nil skipped, no crash"
  - "completedDaysSet exposed on Stats for future calendar-grid consumers (Plan 05)"
  - "Stats.empty static factory to simplify initial state in downstream ViewModels"

patterns-established:
  - "Domain purity: UseCase imports Foundation only (no SwiftUI, no UserNotifications, no FamilyControls)"
  - "Feature layout: Features/Stats/{Repository/Models, UseCase}/* + DeluluDetoxTests/Features/Stats/{Fixtures,}/*"
  - "Test determinism pattern: polishCalendar() fixture + SessionRecordFixtures.date(y,m,d) for every test"

requirements-completed: [GAM-01, GAM-02]

# Metrics
duration: ~20min
completed: 2026-04-20
---

# Phase 6 Plan 01: Pure Streak Algorithm Summary

**Deterministic [SessionRecord]+Date→Stats compute function powering GAM-01 (total completed) and GAM-02 (current + longest streak), with 22 XCTest scenarios covering DST boundaries, trailing-edge semantics, and defensive malformed-record handling.**

## Performance

- **Started:** 2026-04-20T22:00:00Z (approx)
- **Completed:** 2026-04-20T22:16:22Z
- **Tasks:** 1 (TDD — files delivered together per plan `<action>`)
- **Files created:** 4
- **Test count:** 22 (100% pass, ~0.04s total execution time)

## Accomplishments

- **Stats value type** — plain Sendable struct exposing `currentStreak`, `longestStreak`, `totalCount`, `last7DaysFlags` (Monday..Sunday), `todayWeekdayIndex`, `completedDaysSet`; `Stats.empty` static for zero state.
- **ComputeStatsUseCaseImpl** — pure, calendar-injected algorithm. No I/O, no DI beyond `Calendar`. Trailing-edge streak rule enforced (today empty + yesterday `.completed` → streak alive). DST-safe: zero `TimeInterval(86400)` usage, all day arithmetic via `Calendar.date(byAdding:.day, value:, to:)`.
- **SessionRecordFixtures** — shared test fixture builder with Europe/Warsaw `polishCalendar()` (firstWeekday=2, pl_PL locale) and date factory `date(y,m,d,hour:)`. Covers `completed`, `cancelled`, `brokenByRevoke`, `active`, and `malformedCompletedWithoutEndDate` variants.
- **22 unit tests** — all green on iPhone 17 iOS 26.2 simulator:
  - Tests 1-2: totalCount outcome filter + empty
  - Tests 3-9: current streak (today+past, today-only, trailing edge, two-day gap, empty, cancelled-only, broken-only)
  - Tests 10-12: longest streak (multi-run max, single day, empty)
  - Tests 13-15: last7DaysFlags Monday-first ordering + todayWeekdayIndex + all-seven
  - Tests 16-17: **DST boundaries** — spring-forward 2026-03-27..29 (CET→CEST) + fall-back 2026-10-24..26 (CEST→CET), both yield currentStreak=3 contiguous.
  - Tests 18-22: completedDaysSet bucketing, active-record ignore, multi-completed-same-day, calendar injection, defensive malformed handling.

## Task Commits

1. **Task 1: Stats + ComputeStatsUseCase + Fixtures + Tests (TDD — RED+GREEN combined, 22 tests green on first green run)** — `45bcd37` (feat)

## Files Created

- `DeluluDetox/Sources/Features/Stats/Repository/Models/Stats.swift` — Stats struct (6 fields + Stats.empty) for consumer ViewModels.
- `DeluluDetox/Sources/Features/Stats/UseCase/ComputeStatsUseCase.swift` — protocol + Impl, 106 lines.
- `DeluluDetoxTests/Features/Stats/Fixtures/SessionRecordFixtures.swift` — 95 lines of deterministic builders.
- `DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift` — 22 test methods, 297 lines.

## Decisions Made

- **Calendar default factory is a `private static` method, called via type-name (not `Self.`) in the `init` default argument** — `Self` inside a default argument on a non-final-but-still-class context triggers a Swift 6.2 compile error ("covariant 'Self' type cannot be referenced from a default argument expression"). Working around with explicit `ComputeStatsUseCaseImpl.defaultCalendar()` preserves API while satisfying the compiler.
- **Monday-first week flags computed via `(weekday + 5) % 7`** — Foundation's `Calendar.weekday` is 1=Sun..7=Sat; Polish convention is Mon=0..Sun=6. This single-line remapping avoids any locale-dependent iteration logic.
- **DST fixture dates for Europe/Warsaw** — `2026-03-29` (spring forward CET→CEST) and `2026-10-25` (fall back CEST→CET). These are the actual 2026 transitions per IANA tzdata. Tests verify streaks remain contiguous across both boundaries using `Calendar.date(byAdding:.day)`.
- **`completedDaysSet` included in `Stats` type** — not strictly needed for GAM-01/02 numeric display, but Plan 05 (Stats screen calendar grid) benefits from O(1) day-lookup without re-computation. Zero extra compute cost (already built during streak calculation).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Swift compile error on `Self.defaultCalendar()` default argument**
- **Found during:** Task 1 (first test run)
- **Issue:** `init(calendar: Calendar = Self.defaultCalendar())` triggered "covariant 'Self' type cannot be referenced from a default argument expression" under Swift 6.2 strict concurrency.
- **Fix:** Replaced `Self.defaultCalendar()` with explicit `ComputeStatsUseCaseImpl.defaultCalendar()`. Semantics identical, default-injection API preserved.
- **Files modified:** `DeluluDetox/Sources/Features/Stats/UseCase/ComputeStatsUseCase.swift`
- **Verification:** Build green, all 22 tests pass.
- **Committed in:** `45bcd37`

**2. [Rule 2 - Acceptance Criteria] Removed literal `86400` from code comment**
- **Found during:** Task 1 acceptance-criteria check
- **Issue:** Plan acceptance criterion `grep -c "86400" ... returns 0` — but the original comment text "never TimeInterval(86400)" contained the forbidden literal, failing the check even though it was documentation.
- **Fix:** Rewrote comment: `// Bucket by Calendar day (DST-safe; arithmetic via Calendar only, no raw TimeInterval).` — preserves intent, removes forbidden literal.
- **Files modified:** `DeluluDetox/Sources/Features/Stats/UseCase/ComputeStatsUseCase.swift`
- **Verification:** `grep -c "86400" ...` returns 0; acceptance criteria fully met.
- **Committed in:** `45bcd37`

---

**Total deviations:** 2 auto-fixed (1 blocking compile error, 1 acceptance-criteria compliance)
**Impact on plan:** Both fixes mechanical; zero scope change, zero behavior change. Algorithm and test suite shipped exactly as specified.

## Issues Encountered

- **Simulator UUID mismatch:** CLAUDE.md lists iPhone 17 as UUID `C958163F-49E1-4B46-8A6D-C2056CD25A37`, but the locally-booted iPhone 17 simulator on this machine is UUID `6D73311F-3541-4B74-92E8-8014FABC3329`. Used the booted UUID for `xcodebuild test -destination` — not a deviation from algorithm correctness, just environment drift. Future docs update for CLAUDE.md could normalize this or use `name=iPhone 17` instead of fixed UUID.

## User Setup Required

None — no external service configuration required. Pure unit-test-verified domain code.

## Next Phase Readiness

- **Plan 02 (StatsRepository) unblocked.** Can wrap `SessionRepository.loadAll()` + call `ComputeStatsUseCaseImpl()(history:now:)` — zero additional algorithm verification needed.
- **Plan 05 (Stats screen) unblocked.** ViewModels can consume `Stats.completedDaysSet` for calendar-grid dot rendering, `Stats.last7DaysFlags` for home-card mini row, `Stats.currentStreak/longestStreak/totalCount` for header copy.
- **No blockers for downstream plans.** GAM-01 + GAM-02 correctness is test-proven in isolation; Wave 2 plans only need to verify wiring (Repository read path, VM observation, View binding).

## Self-Check: PASSED

- `DeluluDetox/Sources/Features/Stats/Repository/Models/Stats.swift` — FOUND
- `DeluluDetox/Sources/Features/Stats/UseCase/ComputeStatsUseCase.swift` — FOUND
- `DeluluDetoxTests/Features/Stats/Fixtures/SessionRecordFixtures.swift` — FOUND
- `DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift` — FOUND
- Commit `45bcd37` — FOUND
- `xcrun xcodebuild test -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests` — 22/22 passed, exit 0
- Acceptance-criteria greps: struct Stats=1, protocol ComputeStatsUseCase=1, final class ComputeStatsUseCaseImpl=1, func test=22, byAdding:.day=5, 86400=0, import SwiftUI (UseCase)=0, import SwiftUI (Stats)=0 — ALL PASS

---
*Phase: 06-engagement-layer*
*Completed: 2026-04-20*
