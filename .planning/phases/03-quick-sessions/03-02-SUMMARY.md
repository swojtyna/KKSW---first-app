---
phase: 03-quick-sessions
plan: 02
subsystem: Session/Infrastructure
tags: [ManagedSettings, DeviceActivity, SessionEnforcer, shield, anti-bypass, TDD]
dependency_graph:
  requires:
    - DeluluDetox/Sources/Features/AppSelection/Repository/Models/Blocklist.swift
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionRecord.swift
  provides:
    - SessionEnforcer protocol (consumed by P03 UseCases: StartSessionUseCase, EndSessionUseCase)
    - SessionActivityNames.quickSession (cross-process contract with P04 DAM extension)
    - ManagedSettingsStoreWriter + DeviceActivityCenterRunner protocols (test seams)
  affects:
    - Extensions/DeviceActivityMonitorExtension (uses same store name "deluludetox.session" in P04)
    - Phase 3 StartSessionUseCase / EndSessionUseCase (P03 wires enforcer)
tech_stack:
  added:
    - ManagedSettings (first use in Phase 3; named store "deluludetox.session")
    - DeviceActivity (first use; DeviceActivityCenter + DeviceActivitySchedule)
  patterns:
    - Protocol seam pattern (ManagedSettingsStoreWriter / DeviceActivityCenterRunner) for unit-testable infrastructure
    - @unchecked Sendable + @preconcurrency imports for iOS 26.3 SDK concurrency limitations
    - Named ManagedSettingsStore isolates Phase 3 shield from future Phase 4/5 stores
key_files:
  created:
    - DeluluDetox/Sources/Features/Session/Infrastructure/SessionActivityNames.swift
    - DeluluDetox/Sources/Features/Session/Infrastructure/SessionEnforcer.swift
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionRecord.swift
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionOutcome.swift
    - DeluluDetoxTests/Features/Session/SessionEnforcerTests.swift
  modified: []
decisions:
  - "ActivityCategoryPolicy<Application> not ActivityCategoriesPolicy — iOS 26.3 SDK uses generic enum ShieldSettings.ActivityCategoryPolicy<Activity> with .specific(Set<ActivityCategoryToken>) case"
  - "SessionRecord + SessionOutcome stub added to this branch for parallel execution; Plan 03-01 (running in same wave) will provide the full implementation — orchestrator merges both branches"
  - "requireAutomaticDateAndTime and denyAppRemoval are Bool? in iOS 26.3 SDK — live adapter maps Bool param to nil (clear) or true (set), never passes false to SDK"
metrics:
  duration: "~15 minutes"
  completed_date: "2026-04-19T16:01:15Z"
  tasks_completed: 1
  tasks_total: 1
  files_created: 5
  files_modified: 0
requirements:
  - QSN-03
  - QSN-05
  - QSN-06
---

# Phase 03 Plan 02: SessionEnforcer + SessionActivityNames Summary

**One-liner:** Protocol-seamed ManagedSettingsStore + DeviceActivityCenter wrapper enforcing app shield, system-level anti-bypass restrictions, and one-shot DAS scheduling via named store "deluludetox.session".

## What Was Built

`SessionEnforcer` is the single infrastructure subsystem that writes to ManagedSettings in Phase 3.

- **`SessionActivityNames`** — `enum` holding the shared `DeviceActivityName("deluludetox.quickSession")` constant used by both the main app (to call `startMonitoring`) and the DAM extension (to dispatch `intervalDidEnd` in P04). Cross-process string contract.

- **`SessionEnforcer` protocol** — `Sendable` protocol with four methods: `applyShield(for:)`, `clearShield()`, `startActivityMonitoring(for:)`, `stopActivityMonitoring()`.

- **`SessionEnforcerImpl`** — `final class ... @unchecked Sendable`. Production init uses `LiveManagedSettingsStoreWriter` + `LiveDeviceActivityCenterRunner`. Test init takes protocol-typed doubles.

- **`ManagedSettingsStoreWriter` / `DeviceActivityCenterRunner`** — narrow protocol seams enabling full unit coverage without instantiating real `ManagedSettingsStore` (not Sendable in iOS 26.3 SDK, cannot be mocked directly).

- **`applyShield(for:)`** writes three shield facets from `blocklist.lastSelection` (applications, applicationCategories, webDomains) plus two system restrictions (QSN-05):
  - `requireAutomaticDateAndTime = true` — defeats clock-skew bypass (research §A.8)
  - `denyAppRemoval = true` — defeats delete-and-reinstall (research §A.4)

- **`clearShield()`** reverts all five settings unconditionally (idempotent — safe even if prior apply threw).

- **`startActivityMonitoring(for:)`** creates a `DeviceActivitySchedule(intervalStart:intervalEnd:repeats:false)` aligned to `session.plannedEndAt` and calls `DeviceActivityCenter.startMonitoring`. Throws `SessionEnforcerError.deviceActivityStartFailed` wrapping any system error (QSN-06 delivery path).

- **`stopActivityMonitoring()`** calls `stopMonitoring([SessionActivityNames.quickSession])`.

## Test Results

```
Executed 8 tests, with 0 failures (0 unexpected) in 0.008 seconds
```

All 8 `SessionEnforcerTests` methods passed:
- `testApplyShieldWritesAllThreeFacetsFromBlocklistLastSelection` — PASS
- `testApplyShieldWritesBothSystemRestrictionFlagsTrue` — PASS
- `testClearShieldRevertsAllFacetsAndBothRestrictions` — PASS
- `testClearShieldIsSafeToCallWhenNothingWasApplied` — PASS
- `testStartActivityMonitoringInvokesCenterWithQuickSessionNameAndNonRepeatingSchedule` — PASS
- `testStartActivityMonitoringThrowsWrappedErrorWhenCenterThrows` — PASS
- `testStopActivityMonitoringStopsTheQuickSessionActivity` — PASS
- `testSessionActivityNameRawValueMatchesSharedConstant` — PASS

Full suite: **57 tests, 3 skipped, 0 failures**.

## Grep Audit

| Check | Result |
|-------|--------|
| `ManagedSettingsStore(named:` | 1 match (LiveManagedSettingsStoreWriter.init) |
| `requireAutomaticDateAndTime` | 3 matches (comment, live adapter, log comment) |
| `denyAppRemoval` | 3 matches (comment, live adapter, log comment) |
| `SessionActivityNames.quickSession` | 2 matches (startMonitoring, stopMonitoring) |
| `@preconcurrency import FamilyControls` | 1 match |
| `@preconcurrency import ManagedSettings` | 1 match |
| `@preconcurrency import DeviceActivity` | 1 match (+ 1 in SessionActivityNames.swift) |
| `^import SwiftUI$` | 0 matches |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected ManagedSettings category policy type name**
- **Found during:** Task 1 (first build attempt)
- **Issue:** Plan specified `ShieldSettings.ActivityCategoriesPolicy` (plural), but iOS 26.3 SDK defines `ShieldSettings.ActivityCategoryPolicy<Application>` (singular, generic)
- **Fix:** Updated protocol seam, live adapter, enforcer impl, and test fake to use `ShieldSettings.ActivityCategoryPolicy<Application>`
- **Files modified:** `SessionEnforcer.swift`, `SessionEnforcerTests.swift`
- **Commit:** ac67b1b

**2. [Rule 3 - Blocking] Added SessionRecord + SessionOutcome stubs for parallel wave execution**
- **Found during:** Task 1 setup — Plan 03-01 runs in the same wave and provides `SessionRecord`, but both plans execute in parallel
- **Issue:** `SessionEnforcerImpl` and tests reference `SessionRecord` which Plan 03-01 owns. Without the type, this branch cannot compile.
- **Fix:** Created minimal `SessionRecord` + `SessionOutcome` in `DeluluDetox/Sources/Features/Session/Repository/Models/` matching the exact schema from Plan 03-01's interfaces contract. The orchestrator merges both branches; Plan 03-01's fuller implementation will take precedence.
- **Files created:** `SessionRecord.swift`, `SessionOutcome.swift`
- **Commit:** ac67b1b

**3. [Rule 1 - Bug] Live adapter uses nil not false for Bool? SDK properties**
- **Found during:** Task 1 SDK inspection
- **Issue:** `requireAutomaticDateAndTime` and `denyAppRemoval` are `Bool?` in the iOS 26.3 SDK (not `Bool`). Passing `false` is valid Swift (implicit Optional wrapping), but semantic intent is "unrestricted" = `nil`. Passing `false` vs `nil` behaves differently at the ManagedSettings layer.
- **Fix:** `LiveManagedSettingsStoreWriter` maps the `Bool` protocol param to `value ? true : nil` so `clearShield(false)` correctly writes `nil` to the SDK, not `false`.
- **Files modified:** `SessionEnforcer.swift`
- **Commit:** ac67b1b

## Commits

| Hash | Message |
|------|---------|
| ac67b1b | feat(03-02): ship SessionEnforcer + SessionActivityNames + unit tests |

## Known Stubs

None — all data paths are wired. `SessionRecord` minimal stub is intentional for parallel wave execution (Plan 03-01 provides the full version).

## Next Steps

- **P03 (StartSessionUseCase / EndSessionUseCase):** Inject `SessionEnforcer` protocol and `SessionRepository` (from P01). `StartSessionUseCase.execute()` calls `applyShield + startActivityMonitoring`; `EndSessionUseCase.execute()` calls `clearShield + stopActivityMonitoring`.
- **P04 (DeviceActivityMonitorExtension):** `intervalDidEnd(for: SessionActivityNames.quickSession)` creates its own `ManagedSettingsStore(named: "deluludetox.session")` instance and clears the shield — same store name = cross-process consistency per Apple's ManagedSettings design.
- **DI wiring (P03 or separate Injection plan):** Register `SessionEnforcerImpl` in `SessionInjection.swift` under `.application` scope.

## Self-Check

Checking created files exist and commit is present.
