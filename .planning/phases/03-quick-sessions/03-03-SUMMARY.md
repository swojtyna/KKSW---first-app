---
phase: 03-quick-sessions
plan: "03"
subsystem: Session/UseCase+DI
tags: [usecase, dependency-injection, rollback, idempotent, mainactor-hop, vm-boundary, tdd]
dependency_graph:
  requires:
    - "03-01: SessionRepository protocol + SessionRecord/SessionOutcome/SessionDuration/SessionFinalizeMarker"
    - "03-02: SessionEnforcer protocol + SessionActivityNames"
    - "02-03: AppSelection ObserveBlocklistUseCase (cross-feature UC consumption)"
  provides:
    - ObserveActiveSessionUseCase / ObserveSessionHistoryUseCase (thin publisher passthroughs)
    - StartSessionUseCase (atomic: repo → applyShield → startMonitoring w/ rollback)
    - EndSessionUseCase (defense-in-depth clear+stop THEN repo finalize, idempotent)
    - FinalizeSessionFromMarkerUseCase (DAM handoff reconciliation)
    - SelfHealExpiredSessionUseCase (CONTEXT §D-02 recovery)
    - DetectRevocationUseCase (CONTEXT §D-11 revoke detection on MainActor)
    - MarkSuccessShownUseCase / CheckSuccessShownUseCase (CONTEXT §D-19 VM→UserDefaults boundary)
    - SessionInjection (Repo + Enforcer .application; 9 UCs .unique)
    - 11 test mocks under DeluluDetoxTests/Features/Session/Mocks/
  affects:
    - "03-04: DAM extension writes SessionFinalizeMarker — FinalizeSessionFromMarkerUseCase consumes it"
    - "03-05: CountdownViewModel injects @LazyInjected ObserveActiveSessionUseCase + EndSessionUseCase"
    - "03-06: AppRoot foreground hook calls SelfHeal + FinalizeFromMarker + DetectRevocation on scenePhase .active"
    - "03-06: HomeViewModel injects @LazyInjected Mark/CheckSuccessShownUseCase (no direct UserDefaults)"
tech_stack:
  added:
    - "Combine.AnyCancellable + Publisher.first() for sync-read of active session / blocklist snapshot in UC bodies"
    - "@preconcurrency import FamilyControls (DetectRevocationUseCase only) + MainActor.run hop around AuthorizationCenter.shared.authorizationStatus"
    - "UserDefaults(suiteName:) for per-session 'success-shown' flag (MarkSuccessShownUseCaseImpl.defaultsOverride as test seam)"
  patterns:
    - "Cross-feature UC consumption: StartSessionUseCase injects ObserveBlocklistUseCase (AppSelection's PUBLIC UC surface) — never reaches into BlocklistRepository"
    - "Best-effort rollback: clearShield + stopMonitoring + finalize(.cancelledByUser) if step 2/3 of atomic start throws"
    - "Defense-in-depth EndSession: always clear+stop BEFORE repo finalize; swallow SessionStoreError.noActiveSession"
    - "EndSessionUseCase registered BEFORE the UCs that depend on it in SessionInjection (Finalize/SelfHeal/DetectRevocation resolve c.resolve() → EndSessionUseCase)"
    - "Idempotent marker consumption: repo.consumeFinalizeMarker is destructive; UC returns false on id mismatch without throwing"
    - "Date injection for all finalize-type UCs — P06 AppRoot tests can frame fixed timelines"
key_files:
  created:
    - DeluluDetox/Sources/Features/Session/UseCase/ObserveActiveSessionUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/ObserveSessionHistoryUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/StartSessionUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/EndSessionUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/SelfHealExpiredSessionUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/DetectRevocationUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/MarkSuccessShownUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/CheckSuccessShownUseCase.swift
    - DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockSessionRepository.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockSessionEnforcer.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockObserveActiveSessionUseCase.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockObserveSessionHistoryUseCase.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockStartSessionUseCase.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockEndSessionUseCase.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockFinalizeSessionFromMarkerUseCase.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockSelfHealExpiredSessionUseCase.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockDetectRevocationUseCase.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockMarkSuccessShownUseCase.swift
    - DeluluDetoxTests/Features/Session/Mocks/MockCheckSuccessShownUseCase.swift
    - DeluluDetoxTests/Features/Session/StartSessionUseCaseTests.swift
    - DeluluDetoxTests/Features/Session/EndSessionUseCaseTests.swift
    - DeluluDetoxTests/Features/Session/FinalizeSessionFromMarkerUseCaseTests.swift
    - DeluluDetoxTests/Features/Session/SelfHealExpiredSessionUseCaseTests.swift
    - DeluluDetoxTests/Features/Session/DetectRevocationUseCaseTests.swift
    - DeluluDetoxTests/Features/Session/SuccessShownUseCasesTests.swift
  modified:
    - DeluluDetox/Sources/App/DeluluDetoxApp.swift
decisions:
  - "ObserveBlocklistUseCase (not BlocklistRepository) injected into StartSessionUseCase — preserves feature-boundary rule (Session does not reach into AppSelection Repository layer)"
  - "EndSessionUseCase swallows SessionStoreError.noActiveSession — makes it idempotent so AppRoot self-heal / revocation paths don't need to pre-check active state"
  - "DetectRevocationUseCaseImpl reads AuthorizationCenter.shared.authorizationStatus on MainActor via MainActor.run{...} (Phase 02-07 EXC_BREAKPOINT prevention); test seam is a @Sendable () async -> AuthorizationStatus closure that bypasses the hop"
  - "MarkSuccessShownUseCaseImpl.defaultsOverride exposed as nonisolated(unsafe) static — test seam that tears down the suite in tearDown() to avoid cross-test leakage"
  - "EndSessionUseCase MUST register before Finalize/SelfHeal/DetectRevocation in SessionInjection (they c.resolve() it) — registration order in that file matters for .unique scope"
  - "SelfHeal caps actualEndAt at plannedEndAt (not wall-clock now) — the user never saw wall-clock time pass live; reporting it would lie about session length"
  - "Phase 02-07 lesson: @preconcurrency import FamilyControls ONLY in DetectRevocationUseCase. Other Session UCs do not touch FamilyControls/ManagedSettings/DeviceActivity types"
metrics:
  duration_minutes: 5
  completed_date: "2026-04-19"
  tasks_completed: 2
  tasks_total: 2
  files_created: 27
  files_modified: 1
  tests_added: 22
  test_results: "98 total, 3 skipped, 0 failures"
requirements:
  - QSN-01
  - QSN-02
  - QSN-03
  - QSN-04
  - QSN-05
  - QSN-06
---

# Phase 03 Plan 03: Session UseCases + DI Wiring Summary

**One-liner:** Composed 9 Session UseCases (Start atomic-with-rollback / End defense-in-depth-idempotent / Finalize-from-marker / SelfHeal / DetectRevocation on MainActor / Mark+CheckSuccessShown) bound to Repo+Enforcer via `SessionInjection`, inserted into the `DeluluDetoxApp` bootstrap between AppSelection and Denial, with 11 test mocks + 22 new UC tests all green.

## What Was Built

### Task 1: 9 UseCases + SessionInjection + bootstrap edit (commit `aaf6b47`)

11 production files:

- **`ObserveActiveSessionUseCase`** / **`ObserveSessionHistoryUseCase`** — thin publisher passthroughs to `SessionRepository.activeSessionPublisher` / `historyPublisher`.
- **`StartSessionUseCase`** — atomic CONTEXT §D-07 composition: (1) `repo.startSession`, (2) snapshot current `Blocklist` via `observeBlocklist().first()`, (3) `enforcer.applyShield(for:)`, (4) `enforcer.startActivityMonitoring(for:)`. If step 3 OR 4 throws, `rollback(...)` fires: `clearShield` + `stopActivityMonitoring` + `repo.finalizeActiveSession(.cancelledByUser)`, and the original error rethrows. Injects `ObserveBlocklistUseCase` (NOT `BlocklistRepository`) to preserve feature-boundary discipline.
- **`EndSessionUseCase`** — CONTEXT §D-08 sequence: `clearShield` + `stopActivityMonitoring` FIRST (defense-in-depth, harmless when stale), THEN `repo.finalizeActiveSession`. Swallows `SessionStoreError.noActiveSession` so AppRoot can call this unconditionally on foreground without pre-checking state. All other errors propagate.
- **`FinalizeSessionFromMarkerUseCase`** — consumes marker via `repo.consumeFinalizeMarker()` (destructive). If marker exists AND active session id matches, calls `EndSessionUseCase(.completed, min(now, plannedEndAt))`. Stale marker (id mismatch) discarded silently; returns `false`. Returns `true` iff a finalize actually happened.
- **`SelfHealExpiredSessionUseCase`** — CONTEXT §D-02. If active session's `plannedEndAt < now`, `EndSessionUseCase(.completed, plannedEndAt)` — caps `actualEndAt` at planned end, never reports wall-clock-now the user didn't see live.
- **`DetectRevocationUseCase`** — CONTEXT §D-11. If active session exists AND `AuthorizationCenter.shared.authorizationStatus != .approved`, `EndSessionUseCase(.brokenByRevoke, now)`. Production reads authorization status on MainActor via `await MainActor.run { ... }` (Phase 02-07 device UAT lesson). Test seam: `authorizationStatusProvider: @Sendable () async -> AuthorizationStatus` closure.
- **`MarkSuccessShownUseCase`** / **`CheckSuccessShownUseCase`** — CONTEXT §D-19. Wrap a dedicated UserDefaults suite (`com.kksw.DeluluDetox.successShown`) so HomeViewModel stays UI-only per CLAUDE.md "VM → tylko UseCase". `MarkSuccessShownUseCaseImpl.defaultsOverride` is a `nonisolated(unsafe) static var UserDefaults?` test seam.
- **`SessionInjection`** — distributed DI registration. `SessionRepository` + `SessionEnforcer` at `.application` scope; all 9 UCs at `.unique`. `EndSessionUseCase` registered BEFORE the UCs that compose on top of it (Finalize/SelfHeal/DetectRevocation).
- **`DeluluDetoxApp.init()`** — inserted `SessionInjection.register(in: container)` between `AppSelectionInjection` and `DenialInjection` per feature-owner-first ordering (02-03 SUMMARY §"Bootstrap ordering").

### Task 2: 11 mocks + 6 UC test files (commit `b939123`)

- **Mocks** (all `final class ... , @unchecked Sendable`):
  - `MockSessionRepository` — publishers backed by exposed `activeSubject` / `historySubject` CurrentValueSubjects; per-op error stubs (`startSessionError`, `finalizeActiveSessionError`, `consumeFinalizeMarkerError`, `loadActiveSessionFromDiskError`); capture properties; `callCount` counters. Destructive-consume semantics for `consumeFinalizeMarker`.
  - `MockSessionEnforcer` — per-method call counts, capture properties, `applyShieldError` / `startActivityMonitoringError` stubs.
  - 9 UC mocks mirroring AppSelection precedent. `MockStartSessionUseCase` adds `beforeReturn: (@Sendable () async -> Void)?` hook so P05's re-entry-guard test can gate the first call mid-flight.

- **Test files** (22 methods total, all PASS on iPhone 17 simulator iOS 26.3.1):
  - `StartSessionUseCaseTests` (4): happy path ordering, rollback on applyShield throw, rollback on startMonitoring throw, blocklist-snapshot plumbing.
  - `EndSessionUseCaseTests` (3): happy path, noActiveSession swallow (clearShield+stop still called), non-noActiveSession error propagation.
  - `FinalizeSessionFromMarkerUseCaseTests` (3): id match → finalize, stale id → destructive consume but no finalize, no marker → no-op.
  - `SelfHealExpiredSessionUseCaseTests` (3): expired → finalize (cap at plannedEndAt), still-running → no-op, no-active → no-op.
  - `DetectRevocationUseCaseTests` (3): denied → `.brokenByRevoke`, approved → no-op, no-active → no-op.
  - `SuccessShownUseCasesTests` (4): persist+read via override suite, returns false for unmarked, per-id independence, mock vs real parity.

## Test Results

```
Test Suite 'StartSessionUseCaseTests' passed — Executed 4 tests, 0 failures
Test Suite 'EndSessionUseCaseTests' passed — Executed 3 tests, 0 failures
Test Suite 'FinalizeSessionFromMarkerUseCaseTests' passed — Executed 3 tests, 0 failures
Test Suite 'SelfHealExpiredSessionUseCaseTests' passed — Executed 3 tests, 0 failures
Test Suite 'DetectRevocationUseCaseTests' passed — Executed 3 tests, 0 failures
Test Suite 'SuccessShownUseCasesTests' passed — Executed 4 tests, 0 failures

Test Suite 'All tests' passed
	 Executed 98 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.579 seconds
** TEST SUCCEEDED **
```

22 new Phase 3 Plan 3 tests added. Phase 02 + P01 + P02 baseline (76 tests + 3 skipped) fully preserved.

## Grep Audit

| Check                                                                                                        | Result                              |
| ------------------------------------------------------------------------------------------------------------ | ----------------------------------- |
| `protocol StartSessionUseCase: Sendable`                                                                     | PASS (1 match)                      |
| `protocol EndSessionUseCase: Sendable`                                                                       | PASS (1 match)                      |
| `protocol FinalizeSessionFromMarkerUseCase: Sendable`                                                        | PASS (1 match)                      |
| `protocol SelfHealExpiredSessionUseCase: Sendable`                                                           | PASS (1 match)                      |
| `protocol DetectRevocationUseCase: Sendable`                                                                 | PASS (1 match)                      |
| `protocol MarkSuccessShownUseCase: Sendable`                                                                 | PASS (1 match)                      |
| `protocol CheckSuccessShownUseCase: Sendable`                                                                | PASS (1 match)                      |
| `enum SessionInjection`                                                                                      | PASS (1 match)                      |
| `scope: .application` in SessionInjection.swift                                                              | 2 (Repository + Enforcer)           |
| `scope: .unique` in SessionInjection.swift                                                                   | 9 (ObserveActive/History + Start + End + FinalizeFromMarker + SelfHeal + DetectRevocation + Mark + CheckSuccessShown) |
| `SessionInjection.register(in: container)` in DeluluDetoxApp.swift                                           | line 14 (between AppSelection=13 and Denial=15) |
| Bootstrap order Onboarding(12) → AppSelection(13) → Session(14) → Denial(15) → Home(16) → Root(17)           | PASS                                |
| `^import SwiftUI$` in Session/UseCase/*.swift                                                                | 0                                   |
| `@preconcurrency import FamilyControls` in Session/UseCase/*.swift                                           | 1 (DetectRevocationUseCase.swift only) |
| `import FamilyControls\|import ManagedSettings\|import DeviceActivity` in other Session/UseCase/*.swift      | 0                                   |
| 11 mock files with `@unchecked Sendable`                                                                     | 11/11 PASS                          |
| `beforeReturn` in MockStartSessionUseCase                                                                    | 2 (property declaration + await site) |
| `xcodegen generate` produces zero project.yml diff                                                           | PASS                                |
| Full `xcodebuild test` green                                                                                 | PASS (98 tests, 3 skipped, 0 failures) |

## Deviations from Plan

None — plan executed exactly as written.

All acceptance criteria in the plan's `<acceptance_criteria>` and `<verification>` blocks matched on the first build pass. Grep counts match, test names match, bootstrap order matches. No auto-fixes (Rules 1-3) triggered.

## Auth Gates

None encountered. Mock-based tests; no Screen Time API calls on the simulator; no entitlement friction.

## Known Stubs

None — all data paths are fully wired. UseCase protocols resolve real production types through `SessionInjection`; tests inject mocks directly via initializer (no DIContainer override required for Plan 3 tests).

## Threat Flags

No new surface introduced beyond the plan's `<threat_model>`. The plan's T-03-03-01 through T-03-03-05 mitigations are all implemented as specified:

- **T-03-03-01 (Tampering: partial rollback)** — `StartSessionUseCaseImpl.rollback(...)` unconditionally calls `clearShield` + `stopActivityMonitoring` + `repo.finalizeActiveSession(.cancelledByUser)`. Verified by `testStartSessionRollsBackWhenApplyShieldThrows` and `testStartSessionRollsBackWhenStartMonitoringThrows`.
- **T-03-03-02 (Repudiation: no audit trail)** — `EndSessionUseCaseImpl` logs `outcome.rawValue` + session id; repo persists full SessionRecord.
- **T-03-03-03 (DoS: AuthorizationCenter MainActor)** — `DetectRevocationUseCaseImpl` convenience init wraps `AuthorizationCenter.shared.authorizationStatus` in `await MainActor.run { ... }`.
- **T-03-03-04 (EoP: cross-feature reach)** — `SessionInjection` resolves `ObserveBlocklistUseCase`, never `BlocklistRepository`. Verified in SessionInjection.swift source.
- **T-03-03-05 (Info Disclosure: logs)** — `privacy: .public` on session UUIDs is acceptable per PROJECT.md hard constraint (opaque tokens, no user-identifying data).

## Commits

| Hash      | Scope                          | Message                                                        |
| --------- | ------------------------------ | -------------------------------------------------------------- |
| `aaf6b47` | production (11 files)          | feat(03-03): ship Session UseCases + SessionInjection + bootstrap wiring |
| `b939123` | tests (17 files, 22 new tests) | test(03-03): add 11 Session mocks + 6 UC test files (22 new tests) |

## Next Steps

- **P04 (wave 3, DAM extension):** `DeviceActivityMonitorExtension.intervalDidEnd(for: SessionActivityNames.quickSession)` writes a `SessionFinalizeMarker` to `SessionPaths.finalizeMarkerURL()` and clears its local shield. Main app's `FinalizeSessionFromMarkerUseCase` reconciles on next foreground.
- **P05 (Session Start screen):** `SessionStartViewModel` injects `@LazyInjected StartSessionUseCase` + `ObserveBlocklistUseCase`. Re-entry guard test uses `MockStartSessionUseCase.beforeReturn` to gate the first call mid-flight.
- **P06 (AppRoot foreground hook + Home success screen):** `AppRootViewModel.onScenePhaseActive()` calls `SelfHealExpiredSessionUseCase` → `FinalizeSessionFromMarkerUseCase` → `DetectRevocationUseCase` in that order. `HomeViewModel.onSessionCompleted(id:)` uses `CheckSuccessShownUseCase` + `MarkSuccessShownUseCase` instead of touching UserDefaults directly.

## Self-Check: PASSED

All 27 created files found on disk. Modified file (DeluluDetoxApp.swift) verified via grep to contain SessionInjection at line 14. Commits `aaf6b47` and `b939123` verified in git log. Full test suite on iPhone 17 simulator iOS 26.3.1: 98 tests, 3 skipped, 0 failures.
