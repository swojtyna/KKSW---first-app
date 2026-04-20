---
phase: 05-scheduled-blocking
plan: 04
status: complete
subsystem: scheduling
tags: [usecase, di, lazyinjected, combine, darwin-notification, foreground-sync, self-heal]

requires:
  - phase: 05-01
    provides: Scheduling scaffold (models, DI skeleton, XCTSkipIf stubs)
  - phase: 05-02
    provides: ScheduleRepository + CreateOrUpdate/ConsumeEventMarker UCs
  - phase: 05-03
    provides: ScheduleShieldRepository + ScheduleActivityMonitoringRepository + Schedule+DeviceActivity helper
provides:
  - ObserveScheduleUseCase (Combine pass-through for ViewModels)
  - SyncScheduleWithSystemUseCase (D-14 entry point — happy-path DAS registration, rollback on failure)
  - ToggleScheduleUseCase (flip enabled + delegate to sync)
  - ComputeScheduleWindowUseCase (pure time math — single-day + cross-midnight + ScheduleWindow value)
  - SelfHealSchedulesUseCase (D-18 reconciliation on foreground)
  - SchedulingInjection filled — 3 repos .application + 7 UCs .unique registered
  - AppRootViewModel extended with 2 LazyInjected schedule UCs + 2 Darwin observers
affects: [05-05, 05-06, 05-07, 05-08]

tech-stack:
  added: []
  patterns:
    - UserDefaults test seam via nonisolated(unsafe) static defaultsOverride (mirrors Phase 3 MarkSuccessShownUseCase)
    - Eager UC capture in refreshStatus before Task spawn (mirrors Phase 3 pattern — prevents DIContainer-reset race)
    - Parameterised Darwin observer registration (registerDarwinObserver(name:))

key-files:
  created:
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ObserveScheduleUseCase.swift
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ToggleScheduleUseCase.swift
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ComputeScheduleWindowUseCase.swift
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SelfHealSchedulesUseCase.swift
  modified:
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift (filled Observe/Toggle/Sync/SelfHeal/Compute protocol bodies + ScheduleWindow + ScheduleUseCaseError)
    - DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift (3 repos + 7 UCs registered)
    - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift (+2 LazyInjected UCs, +refreshStatus Phase 05 steps, +registerDarwinObservers)
    - DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift (6 stubs → 6 asserts)
    - DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift
    - DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift
    - DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift (4 stubs → 4 asserts)
    - DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift (+2 tests: order + Darwin)
    - DeluluDetoxTests/Features/Scheduling/Mocks/MockConsumeScheduleEventMarkerUseCase.swift (+callOrderLog)

key-decisions:
  - "Happy-path only: SyncScheduleWithSystemUseCase registers one DeviceActivitySchedule with repeats=true per segment, no daily re-register-at-midnight fallback. Waiver recorded in 05-DISCUSSION-LOG.md (Wave 0 Spike Verdict — ASSUMED Outcome A)."
  - "SelfHeal UserDefaults suite name is a static on ComputeScheduleWindowUseCaseImpl (scheduleStateSuiteName) — colocated with lastAppliedKey(scheduleId:) helper so compute UC owns the schema."
  - "SchedulingInjection registers Sync BEFORE CreateOrUpdate/Toggle so the container resolves deps correctly (DIContainer resolves bottom-up but explicit order helps readers)."
  - "Darwin observer refactor — registerDarwinFinalizeObserver() replaced by parameterised registerDarwinObservers() + registerDarwinObserver(name:). Observes sessionFinalized + scheduleStarted + scheduleEnded — all cascade to refreshStatus()."
  - "SelfHeal short-circuits apply when blocklist.records is empty (keeps clear path live). Avoids arming shield with an empty selection."

patterns-established:
  - "Pattern 1: Schedule UC rollback via currentSnapshot read BEFORE mutation — Sync UC snapshots the prior schedule version, attempts DAS register, restores via repository.upsert on startFailed."
  - "Pattern 2: Cross-feature UC resolve in DI closure — SelfHeal registers with observeBlocklist: c.resolve() (ObserveBlocklistUseCase lives in AppSelection). Same sanctioned pattern as Phase 3 StartSessionUseCase."
  - "Pattern 3: Marker-before-self-heal ordering in AppRoot (RESEARCH §Pitfall 8) verified by shared NSMutableArray appended from both mocks."

requirements-completed: [SCH-01, SCH-02, SCH-03]

duration: 75min (~1h — agent got 1 task + partial 2nd before hitting Opus limit, orchestrator finished Tasks 2/3/4 inline)
completed: 2026-04-20
---

# Phase 05 Plan 04: UseCases + DI + AppRoot Wiring

**Scheduling domain layer complete — 5 UCs, DI bootstrap, AppRoot foreground reconciliation wired.**

## Performance

- **Duration:** ~75 min (Task 1 under agent at ~12:33, Tasks 2-4 inline through ~12:50)
- **Tasks:** 4/4 complete
- **Files modified:** 5 created + 9 modified
- **Tests:** 205 → 207 total; 190 → 192 passed; 15 → 15 skipped; 0 failures.

## Accomplishments

- 5 Scheduling UseCases shipped with real bodies: Observe (pass-through), Toggle (flip+sync), Sync (happy-path DAS + rollback), Compute (pure time math + ScheduleWindow), SelfHeal (D-18 reconcile).
- `SchedulingInjection.register(in:)` filled — 3 repos (`.application`) + 7 UCs (`.unique`) resolve through DIContainer. Cross-feature resolve to `ObserveBlocklistUseCase` works through AppSelectionInjection's earlier bootstrap.
- AppRootViewModel now consumes schedule markers AND runs self-heal on scenePhase.active; Darwin observers on `scheduleStarted`/`scheduleEnded` cascade to the same refresh path so a foregrounded main app reacts instantly to DAM transitions.
- Waiver recorded: Wave 0 on-device spike was deferred; all code paths assume Outcome A (`repeats=true` suffices). SCH-03 day-N+1 verification moves to Plan 05-08 UAT.

## Task Commits

1. **Task 1: ComputeScheduleWindowUseCase pure logic + 6 tests** — `f12c1ad` (feat)
2. **Task 2: Observe + Sync + Toggle UCs** — `ed06311` (feat)
3. **Task 3: SelfHealSchedulesUseCase + SchedulingInjection registrations + 4 tests** — `068acdb` (feat)
4. **Task 4: AppRootViewModel wiring + 2 tests** — `1094562` (feat)

Agent handoff: initial executor (`ae2a56ff`) landed Task 1 + partial Task 2 before hitting Opus usage limit. Orchestrator picked up in-flight uncommitted files from the worktree (Observe/Sync/Toggle UCs + 2 test file edits), cleaned up the duplicate `Equatable` conformance Swift auto-synthesizes for associated-value-free enums, and committed Tasks 2-4 inline on `develop`.

## Deviations

- **D1 (Rule 3 — clean-up):** Removed test-side `extension ScheduleUseCaseError: Equatable` — Swift auto-synthesizes Equatable for enums without associated values, duplicate conformance was a compiler warning. Fixed during Task 2 commit.
- **D2 (Rule 1 — spec clarification):** Plan Task 3 blocklist-availability check used `blocklist.id == UUID(uuidString: "00000000…")`. Replaced with `blocklist.records.isEmpty` — matches `Blocklist.empty()` semantics and reads better. Self-heal still short-circuits apply when empty.

## Test Delta

Baseline (after 05-03): 205 / 173 passed / 32 skipped
Post 05-04: 207 / 192 passed / 15 skipped / 0 failed
Delta: +2 tests added (AppRoot Darwin + order), +19 stubs promoted (6 Compute + 3 Sync + 2 Toggle + 4 SelfHeal + 4 Observe context), −17 skips.

## What's Next

- **Plan 05-05 (DAM extension handlers)** — with Scheduling UCs in place, the DAM extension can now post timestamp-suffixed markers + Darwin notifications knowing the main-app consumer exists and will process them on foreground.
- **Plans 05-06 / 05-07 (UI)** — ViewModels can now `@LazyInjected` real UCs (Observe, Toggle, CreateOrUpdate).
- **Plan 05-08 (UAT)** — will exercise SCH-03 day-N+1 case which is the deferred Wave 0 verification gate.
