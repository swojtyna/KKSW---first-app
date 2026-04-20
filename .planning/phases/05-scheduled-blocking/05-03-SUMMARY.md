---
phase: 05-scheduled-blocking
plan: 03
subsystem: scheduling
tags: [scheduling, repository, managed-settings, device-activity, wave-1]
status: complete

# Dependency graph
requires:
  - phase: 05-scheduled-blocking
    plan: 01
    provides: "ManagedSettingsStoreNames.schedule + ScheduleActivityNames + ScheduleSegment + ScheduleProtocols empty-body seats + 10 XCTSkipIf stubs (4 shield + 6 monitoring)"
  - phase: 05-scheduled-blocking
    plan: 02
    provides: "protocol-extension-in-place pattern already exercised for ScheduleRepository; no churn in ScheduleProtocols file shape"
  - phase: 04-shield-customization
    provides: "ManagedSettingsStoreWriter + LiveManagedSettingsStoreWriter + DeviceActivityCenterRunner + LiveDeviceActivityCenterRunner seams reused verbatim — Plan 03 does NOT redeclare them"
provides:
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift — LiveScheduleShieldRepository pinned to ManagedSettingsStoreNames.schedule, arms requireAutomaticDateAndTime but deliberately skips denyAppRemoval"
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift — LiveScheduleActivityMonitoringRepository wrapping DeviceActivityCenterRunner; startMonitoring registers 1 or 2 DAS; stopMonitoring defensively clears all 3 segment variants"
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift — buildDeviceActivitySchedules() helper (RESEARCH §Example 1)"
  - "ScheduleShieldRepository protocol body (applyShield / clearShield) extended in-place in ScheduleProtocols.swift"
  - "ScheduleActivityMonitoringRepository protocol body (startMonitoring throws / stopMonitoring non-throwing) + ScheduleActivityMonitoringError.startFailed enum extended in-place in ScheduleProtocols.swift"
  - "MockScheduleShieldRepository signature realigned: applyShield(for:) replaces Plan 01 provisional applyShield(blocklistId:)"
  - "MockScheduleActivityMonitoringRepository signature realigned: stopMonitoring(scheduleId:) is non-throwing per Plan 03 interface"
  - "10 passing assertions replacing XCTSkipIf stubs (4 shield + 6 monitoring) — skipped test count 42 → 32, delta 10, 0 failures"
affects:
  - "Plan 05-04 — SyncScheduleWithSystemUseCase now has two production-shaped repositories to call (shield + monitoring); SchedulingInjection.register in Plan 04 wires LiveScheduleShieldRepository + LiveScheduleActivityMonitoringRepository"
  - "Plan 05-04 — SyncScheduleWithSystemUseCaseTests stub at line 19-20 describes a throwing stopMonitoring; Plan 04 must drop the throws expectation (Plan 03 made stopMonitoring non-throwing) OR add a thrown-error ScheduleActivityMonitoringRepository.stopMonitoring flavor. Heads-up, not a breaker."
  - "Plan 05-05 — DAM extension intervalDidStart writes to ManagedSettingsStore(named: ManagedSettingsStoreNames.schedule); the named-store literal is now settled. Plan 05-05 also reuses ScheduleSegment + ScheduleActivityNames which are already source-shared into the DAM extension target per Plan 01"
  - "Plan 05-08 — SCH-04 delivered zero-code: the existing Phase 4 ShieldConfigurationExtension renders the same branded shield against the new named store; device UAT just needs to verify visual parity (no separate Shield build required for schedules)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Phase 4 seam reuse over duplication: ManagedSettingsStoreWriter + DeviceActivityCenterRunner protocols are imported from Features/Session/Repository/*.swift, never redeclared"
    - "Differential from SessionShieldRepository: schedule variant pins storeName to ManagedSettingsStoreNames.schedule AND omits denyAppRemoval (D-05 + D-11). Same applyShield/clearShield shape otherwise"
    - "Defensive three-segment stopMonitoring: pass all of .main / .evening / .morning to runner.stopMonitoring so single-day ↔ cross-midnight edits never leak a stale segment into the 20-activity budget (D-14 pitfall #1). iOS silently ignores unknown activity names"
    - "Cross-midnight split encoded in a model-layer extension (Schedule+DeviceActivity.swift) rather than inside the repository — keeps the DAS construction pure, unit-testable without DeviceActivityCenter"

key-files:
  created:
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift"
  modified:
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift — extended ScheduleShieldRepository + ScheduleActivityMonitoringRepository protocol bodies in-place + added ScheduleActivityMonitoringError enum"
    - "DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift — 4 XCTSkipIf stubs → 4 real assertions + FakeStore helper"
    - "DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift — 6 XCTSkipIf stubs → 6 real assertions + FakeCenter helper"
    - "DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleShieldRepository.swift — applyShield(blocklistId:) → applyShield(for blocklist:)"
    - "DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleActivityMonitoringRepository.swift — stopMonitoring(scheduleId:) throws → non-throwing; stopMonitoringError removed; stoppedScheduleIds array added"

key-decisions:
  - "Wave 0 Outcome A honored end-to-end: every DAS in buildDeviceActivitySchedules uses repeats: true; no daily-re-register fallback code in either repository (confirmed by 05-DISCUSSION-LOG.md §Wave 0 Spike Verdict)"
  - "Differential SessionShield → ScheduleShield: the *only* two deltas are storeName and the denyAppRemoval omission. Same applyShield/clearShield control flow, same facet-writer calls, same Logger subsystem — minimises maintenance drift"
  - "denyAppRemoval deliberately absent on schedule store: D-11 says schedules are user-reconfigurable; applying the 'cannot delete app' friction during a recurring window would contradict the design intent and could trap a user who simply wants to reinstall an app"
  - "Defensive three-segment stop survives schedule shape edits: a user who toggles 22:00→06:00 (cross-midnight) to 09:00→17:00 (single-day) would otherwise leak .evening+.morning DAS; always-clear-all-three guarantees cleanup without a pre-read of the prior schedule"
  - "Schedule+DeviceActivity.swift lives under Models/ because it is a pure extension of the Schedule value type — fits the 'extensions of a model type ship next to the model' convention used in existing codebase"

patterns-established:
  - "For repository tests where FamilyActivitySelection tokens cannot be minted on simulator (Blocklist.empty()), assert on the *facet-writer call counters* (shieldAppsSetCount / shieldCategoriesSetCount / shieldWebSetCount), not on decoded token-set sizes. Documented already in SessionShieldRepositoryTests; Plan 03 applies the same shape"

requirements-completed: []  # SCH-02 / SCH-03 / SCH-04 close only when Plans 05-04/05/06/07 also land — the repositories here are infrastructure.

# Metrics
duration: ~18min
completed: 2026-04-20
---

# Phase 05 Plan 03: Shield + Monitoring Repositories Summary

**Scheduling systemic-side is live — `LiveScheduleShieldRepository` writes shields to `deluludetox.schedule` named store (isolated from session per D-05); `LiveScheduleActivityMonitoringRepository` registers 1 or 2 DAS per schedule with `repeats: true` (Wave 0 Outcome A happy path); both reuse Phase 4's `ManagedSettingsStoreWriter` + `DeviceActivityCenterRunner` seams verbatim.**

## Performance

- **Duration:** ~18 min (2026-04-20)
- **Tasks planned:** 2
- **Tasks completed:** 2/2
- **Files created:** 3 (2 repository sources + 1 Schedule extension)
- **Files modified:** 5 (1 protocols + 2 test files + 2 mocks)
- **Test delta:** suite total 205 → 205; skipped 42 → 32 (10 promoted); failures 0 → 0
- **Scoped test passes:** 4 (ScheduleShieldRepositoryTests) + 6 (ScheduleActivityMonitoringRepositoryTests) = 10

## Accomplishments

- Shipped `LiveScheduleShieldRepository` mirroring `LiveSessionShieldRepository` — same control flow, pins `storeName` to `ManagedSettingsStoreNames.schedule`, arms `requireAutomaticDateAndTime=true`, deliberately skips `denyAppRemoval` per D-11.
- Shipped `LiveScheduleActivityMonitoringRepository` wrapping Phase 4's `DeviceActivityCenterRunner` — `startMonitoring(schedule:)` iterates 1 or 2 `(name, das)` pairs and wraps center errors in `ScheduleActivityMonitoringError.startFailed`.
- Created `Schedule+DeviceActivity.swift` extension with `buildDeviceActivitySchedules()` — pure function mapping `(Schedule, crossesMidnight)` to the correct DAS shape (single-day .main OR .evening + .morning per D-03/D-13).
- Wave 0 Outcome A locked in: every DAS uses `repeats: true`; no daily-re-register fallback code in either repository.
- Defensive `stopMonitoring(scheduleId:)` clears all three segment variants so schedule-shape edits cannot orphan a DAS in the 20-activity budget.
- Promoted all 10 `XCTSkipIf` stubs in `ScheduleShieldRepositoryTests` (4) and `ScheduleActivityMonitoringRepositoryTests` (6) to real assertions — skipped count fell from 42 to 32, matching the planned delta.
- Realigned the two mocks whose Plan 01 shapes predated the final Plan 03 protocols (`applyShield(blocklistId:)` → `applyShield(for:)`, `stopMonitoring(scheduleId:) async throws` → non-throwing).
- Protocol-extension-in-place pattern preserved: both new protocol bodies land in the existing `ScheduleProtocols.swift`; no file splits, no type renames.

## Task Commits

| Task | Name                                                                                           | Commit    | Files                                                                                                                                    |
| ---- | ---------------------------------------------------------------------------------------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | ScheduleShieldRepository — protocol body + LiveScheduleShieldRepository + 4 tests + mock align | `48800b3` | ScheduleProtocols.swift + ScheduleShieldRepository.swift + ScheduleShieldRepositoryTests.swift + MockScheduleShieldRepository.swift     |
| 2    | ScheduleActivityMonitoringRepository + Schedule+DeviceActivity + 6 tests + mock align          | `814ae02` | ScheduleProtocols.swift + ScheduleActivityMonitoringRepository.swift + Schedule+DeviceActivity.swift + 1 test file + 1 mock             |

## Files Created/Modified

**Created (source):**

- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` — `LiveScheduleShieldRepository` (77 lines) pinned to schedule store
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift` — `LiveScheduleActivityMonitoringRepository` (65 lines) wrapping `DeviceActivityCenterRunner`
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift` — `Schedule.buildDeviceActivitySchedules()` extension (46 lines)

**Modified (source):**

- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` — added protocol bodies for `ScheduleShieldRepository` and `ScheduleActivityMonitoringRepository`; added `ScheduleActivityMonitoringError` enum

**Modified (tests):**

- `DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift` — 4 stubs → 4 real assertions + inline `FakeStore` helper mirroring Session analogue
- `DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift` — 6 stubs → 6 real assertions + inline `FakeCenter` helper capturing `(name, schedule)` pairs

**Modified (mocks):**

- `DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleShieldRepository.swift` — `applyShield(blocklistId:)` → `applyShield(for:)`; added `lastAppliedBlocklist`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleActivityMonitoringRepository.swift` — `stopMonitoring(scheduleId:) async throws` → non-throwing; added `stoppedScheduleIds: [UUID]`

## Decisions Made

- **Wave 0 Outcome A happy-path taken.** `05-DISCUSSION-LOG.md §Wave 0 Spike Verdict — ASSUMED Outcome A (conditional)` explicitly says implement `repeats: true` without the daily-re-register fallback. Every DAS in `buildDeviceActivitySchedules` carries `repeats: true`; the `testStartMonitoringUsesRepeatsTruePerD13` test asserts it on all 3 constructed DAS.
- **Phase 4 seams imported, not redeclared.** `ManagedSettingsStoreWriter`, `LiveManagedSettingsStoreWriter`, `DeviceActivityCenterRunner`, `LiveDeviceActivityCenterRunner` are all defined in `Features/Session/Repository/Session*Repository.swift` and used as-is. Plan 05-03 adds ZERO new protocol types that would need a Phase 4 backport.
- **`denyAppRemoval` left untouched by the schedule repo.** The tests now actively assert `fakeStore.denyAppRemovalSetCount == 0` after both `applyShield` and `clearShield`, so any future drift toward "match session behaviour" is caught immediately.
- **`Schedule+DeviceActivity.swift` under `Models/`.** The helper is a pure value-type extension with no dependencies on FamilyControls or ManagedSettings (only `DeviceActivity` for `DeviceActivityName`/`DeviceActivitySchedule`). Colocated with the `Schedule` model so its test (`testSegmentHelperBuildDeviceActivitySchedulesRoundTrip`) can live in the DAM-monitoring tests without import creep.
- **Splitting the ScheduleProtocols edit across the two commits.** Plan 03's `<interfaces>` nominally lands all protocol bodies at once, but that would have landed an unused `ScheduleActivityMonitoringError` in Task 1 before its thrower exists. Same scope split the SUMMARY for Plan 02 documents — Task 1 edits only `ScheduleShieldRepository`'s body; Task 2 adds the monitoring protocol body + the error enum together. Each commit is independently compilable.

## Deviations from Plan

None under Rules 1-4. Plan executed exactly as written on the happy path.

Minor executor-side clarifications recorded here, not as deviations:

1. **`project.yml` DAM source-share NOT extended for `Schedule+DeviceActivity.swift`.** The helper runs only in main-app context (DAS registration via `DeviceActivityCenter.startMonitoring` happens there). The DAM extension parses activity names at `intervalDidStart/End`, it never *constructs* a `DeviceActivitySchedule`. Keeping the extension slim preserves the 6 MB RAM budget and avoids pulling `DeviceActivitySchedule` usage into the extension where it has no callers.
2. **Xcode MCP fallback.** `mcp__XcodeBuildMCP__*` tools are still not exposed to this executor (same as Plan 01/02). Fell back to raw `xcodebuild test -only-testing:...` on simulator UUID `6D73311F-3541-4B74-92E8-8014FABC3329` (iPhone 17, iOS 26.3). Build SUCCEEDED and TEST SUCCEEDED; semantic outcome identical to XcodeBuildMCP.
3. **Mock throws drop for `stopMonitoring`.** Plan 04's `testSyncLogsErrorWhenStopMonitoringThrows` stub (in `SyncScheduleWithSystemUseCaseTests.swift`) implies `stopMonitoring` throws, but Plan 03's `<interfaces>` specifies `func stopMonitoring(scheduleId: UUID) async` (non-throwing). Followed the Plan 03 `<interfaces>` as the source of truth; left a `<affects>` note so Plan 04 knows to rewrite that stub when it lands. Listed under "affects", not "deviations", because no production code behaviour changed — only the forward-looking test stub author needs a heads-up.

## Acceptance Criteria Cross-check

### Task 1

- [x] `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` → OK
- [x] `grep -c "final class LiveScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable"` == 1
- [x] `grep -c "LiveManagedSettingsStoreWriter(storeName: ManagedSettingsStoreNames.schedule)"` == 1 (spelled across lines via multi-line arg form; `ManagedSettingsStoreNames.schedule` appears twice — once in the init, once in a doc comment)
- [x] `grep -c "setDateAndTimeRequireAutomatic(true)"` == 1
- [x] `grep -c "setApplicationDenyAppRemoval"` == 0 (intentionally absent)
- [x] `grep -c "protocol ScheduleShieldRepository: Sendable"` == 1
- [x] `grep -c "func applyShield(for blocklist: Blocklist) async throws"` == 1
- [x] `grep -c "XCTSkipIf(true"` in test file == 0
- [x] `xcodebuild test -only-testing:…/ScheduleShieldRepositoryTests`: **4 passed, 0 failed, 0 skipped**

### Task 2

- [x] `test -f ScheduleActivityMonitoringRepository.swift` + `Schedule+DeviceActivity.swift` → both OK
- [x] `grep -c "final class LiveScheduleActivityMonitoringRepository: ScheduleActivityMonitoringRepository, @unchecked Sendable"` == 1
- [x] `grep -c "enum ScheduleActivityMonitoringError"` in protocols == 1
- [x] `grep -c "case startFailed(Error)"` in protocols == 1
- [x] `grep -c "func buildDeviceActivitySchedules"` in extension == 1
- [x] `grep -c "ScheduleActivityNames.activityName(scheduleId:"` in extension == 3 (main + evening + morning)
- [x] `grep -c "ScheduleSegment.main, .evening, .morning"` in repo == 1
- [x] `grep -c "XCTSkipIf(true"` in test file == 0
- [x] `xcodebuild test -only-testing:…/ScheduleActivityMonitoringRepositoryTests`: **6 passed, 0 failed, 0 skipped**
- [x] Full suite still green — **205 tests, 32 skipped, 0 failures** (was 205/42/0 after Plan 02 — delta 10 exactly matches "4 shield + 6 monitoring")

### Plan-level verification

- [x] Full suite 0 failures, test count unchanged (205), skipped fell by 10 (42 → 32)
- [x] `git log --oneline -2` shows two `feat(05-03): …` commits
- [x] `grep -c "ManagedSettingsStoreNames.schedule" ScheduleShieldRepository.swift` == 2 (init + doc) — ≥1 as required
- [x] `grep -c "repeats: true" Schedule+DeviceActivity.swift` == 4 (3 DAS constructors + 1 doc comment "`repeats: true` per Wave 0 Outcome A") — all 3 DAS paths confirmed via `testStartMonitoringUsesRepeatsTruePerD13`
- [x] `grep -c "denyAppRemoval" ScheduleShieldRepository.swift` == 0 (intentionally absent per D-11)

## Issues Encountered

- **XcodeBuildMCP tools still not exposed.** Same as Plan 01/02; fell back to `xcodebuild` directly. Not a deviation.
- **Hook READ-BEFORE-EDIT reminders on already-read files.** The runtime's `PreToolUse` reminder fired on Write + Edit calls for files already read earlier in this session. Edits succeeded regardless; no data loss. Noted for orchestrator visibility.

## User Setup Required

None. No entitlements / signing / secrets needed for what is in this plan.

## Next Phase / Plan Readiness

**Ready:**

- **Plan 05-04** (SyncScheduleWithSystemUseCase + Toggle + SelfHeal + DI). Both repositories have their final shape and their mocks match the production protocols. `SchedulingInjection.register(in: container)` can wire `LiveScheduleShieldRepository()` and `LiveScheduleActivityMonitoringRepository()` alongside the Plan 02 types.
- **Plan 05-05** (DAM extension). The DAM-side code will write to `ManagedSettingsStore(named: ManagedSettingsStoreNames.schedule)` — the constant is now settled and lives in a file already source-shared into the DAM target.
- **Plan 05-08** (Device UAT). SCH-04 (shield parity) is delivered zero-code — the Phase 4 ShieldConfigurationExtension renders the same branded shield against the new named store. UAT need only visually confirm parity against a scheduled window.

**Blocked:**

- None within the plan's `<dependency_graph>`. Only residual phase-wide blocker is Wave 0 on-device verification (Plan 05-08 UAT), which is orthogonal to this plan's scope.

## Self-Check: PASSED

Created files verified present on disk:

- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift` — FOUND

Commits verified present in git log:

- `48800b3` (Task 1) — FOUND
- `814ae02` (Task 2) — FOUND

---

*Phase: 05-scheduled-blocking*
*Plan: 03 (complete)*
*Completed: 2026-04-20*
