---
phase: 05-scheduled-blocking
plan: 01
subsystem: scheduling
tags: [wave-0, scaffold, scheduling, device-activity, managed-settings, xctskip, xcodegen]
status: partial

# Dependency graph
requires:
  - phase: 03-quick-sessions
    provides: "SessionPaths / SessionActivityNames / SessionFinalizeMarker — Phase 5 mirrors pattern"
  - phase: 04-shield-customization
    provides: "XCTSkipIf scaffold technique (Plan 04-01) + three-repo split pattern (Repository / ShieldRepository / ActivityMonitoringRepository)"
provides:
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift — D-02 Codable schema (id, name, daysOfWeek, startHour/Minute, endHour/Minute, enabled, blocklistId, appVersion) + crossesMidnight helper"
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift — enum .main/.evening/.morning (D-03/D-13 cross-midnight split)"
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift — namespaced DeviceActivityName builder + parser"
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift — App Group URL helpers with timestamp-suffixed marker naming (RESEARCH OQ#4 fix)"
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift + ScheduleEventMarker.swift — append-only history row + DAM→main-app handoff payload"
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift — canonical .session + .schedule literals (pitfall 6)"
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift — 10 empty Sendable protocols; Plans 05-02/03/04 extend in-place"
  - "DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift — skeleton enum; empty register(in:) body; Plan 04 fills"
  - "DeluluDetoxTests/Features/Scheduling/ — 11 XCTest files with 51 XCTSkipIf stubs documenting downstream plan assertions"
  - "DeluluDetoxTests/Features/Scheduling/Mocks/ — 10 @unchecked Sendable mocks with call counters + error stubs"
  - "project.yml — DeviceActivityMonitorExtension source-shares 6 Foundation-only Scheduling files"
  - "DeluluDetox/Sources/App/DeluluDetoxApp.swift — SchedulingInjection.register wired between Session and Denial"
affects:
  - "Plan 05-02 (ScheduleRepository + CreateOrUpdate + ConsumeEventMarker UCs — scaffolds + 3 test files waiting)"
  - "Plan 05-03 (ScheduleShieldRepository + ScheduleActivityMonitoringRepository — 2 test files waiting)"
  - "Plan 05-04 (Compute/Sync/Toggle/SelfHeal UCs + DI registrations — 4 test files waiting)"
  - "Plan 05-05 (DAM extension intervalDidStart/intervalDidEnd — source-share contract already wired)"
  - "Plan 05-06 (ScheduleEditorViewModel — 1 test file waiting)"
  - "Plan 05-07 (ScheduleListViewModel + HomeViewModel Destination wiring — 1 test file waiting)"
  - "Plan 05-08 (Device UAT) — blocked until Wave 0 spike verdict is also recorded"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Feature-first layout under DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ (mirrors Features/Session/Repository/Models/)"
    - "Timestamp-suffixed marker file naming (schedule_event_marker_{unix_ms}.json) to prevent cross-midnight event loss (RESEARCH OQ#4)"
    - "Empty-protocol upfront declaration in ScheduleProtocols.swift — mocks compile today; Plans 02/03/04 extend bodies in-place"
    - "XCTSkipIf(true, 'Stub — Plan 05-NN replaces with real assertion. Expected: ...') idiom — keeps suite green while documenting exact downstream behavior"
    - "App Group source-share of Foundation-only models into DAM extension (no SwiftUI / Combine / FamilyControls imports in shared files — verified by grep)"

key-files:
  created:
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift"
    - "DeluluDetoxTests/Features/Scheduling/ (11 test files)"
    - "DeluluDetoxTests/Features/Scheduling/Mocks/ (10 mocks)"
  modified:
    - "DeluluDetox/Sources/App/DeluluDetoxApp.swift"
    - "project.yml"
    - ".planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md"

key-decisions:
  - "Wave 0 spike (Task 1) deferred — physical iOS 26+ device unavailable this session; Plan 05-02 remains gated on verdict"
  - "Empty-protocol upfront option selected over '#if false' wrapping — avoids conditional-compilation fragility; Plans 02/03/04 extend protocol bodies in-place"
  - "51 XCTSkipIf stubs land today; skip message carries the exact assertion each downstream plan must execute — converts MISSING placeholders into concrete contracts"

patterns-established:
  - "Cross-process App Group schema file-sharing rule: every file source-shared into an extension target MUST import Foundation only (checked via grep in acceptance criteria)"
  - "Marker-file generation uses timestamp suffixes (unix millis) to allow multiple coexisting events between foreground runs — required for cross-midnight reliability"

requirements-completed: []  # SCH-01..04 remain OPEN — this plan delivers scaffolds only; downstream plans (02-07) close the acceptance criteria

# Metrics
duration: 25min
completed: 2026-04-20
---

# Phase 05 Plan 01: Wave 0 Spike + Scheduling Scaffolds Summary (PARTIAL)

**Scheduling feature skeleton (7 Foundation-only models + DI skeleton + 10 empty protocols + 11 XCTest files with 51 XCTSkipIf stubs + 10 mocks) + DAM source-share + Wave 0 spike DEFERRED pending physical iOS 26+ device.**

## Performance

- **Duration:** ~25 min (2026-04-20)
- **Tasks planned:** 3 (Task 1 deferred; Tasks 2 and 3 complete)
- **Tasks completed:** 2/3
- **Files created:** 21 (8 source + 11 tests + 10 mocks — minus one that is listed in both families: actually 9 source files incl. ScheduleProtocols, 11 tests, 10 mocks = 30 files; see Task Commits)
- **Files modified:** 3 (DeluluDetoxApp.swift, project.yml, 05-DISCUSSION-LOG.md)

## Accomplishments

- Laid down the full `Features/Scheduling/` directory tree (mirror of `Features/Session/`) so Plans 02-07 add files without structural churn
- Published the production schema (`Schedule`, `ScheduleSegment`, `ScheduleEvent`, `ScheduleEventMarker`, `ManagedSettingsStoreNames`) consumed by both main app and DAM extension via `project.yml` source-shares
- Replaced the fragile single-file marker overwrite with timestamp-suffixed markers (`schedule_event_marker_{unix_ms}.json`) — fixes the cross-midnight event-loss defect flagged in RESEARCH OQ#4 before any code depends on it
- Wrote 51 XCTSkipIf stubs that document, in plain English, the exact assertion each downstream plan (05-02, 05-03, 05-04, 05-06, 05-07) must land — converts every `<automated>` verify from MISSING to concrete `-only-testing:DeluluDetoxTests/Features/Scheduling/...`
- Wired `SchedulingInjection.register(in: container)` between Session and Denial in `DeluluDetoxApp.init()` — bootstrap ordering stable before feature registrations arrive in Plan 05-04
- Full test suite green on iPhone 17 / iOS 26.3.1 simulator: **205 tests, 54 skipped, 0 failures** (prior baseline 154/3/0 + 51 new stubs)

## Task Commits

| Task | Name                                                                                          | Commit    | Files                                                                                            |
| ---- | --------------------------------------------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------ |
| 1    | Wave 0 spike — verify iOS 26 DeviceActivitySchedule(repeats: true) on physical device         | DEFERRED  | None — see `## Deferred` below                                                                   |
| 2    | Scheduling feature scaffold — models, paths, DI skeleton, project.yml source-shares           | `2340031` | 7 model files + SchedulingInjection + DeluluDetoxApp edit + project.yml (10 changes, 181 inserts) |
| 3    | XCTest scaffolds + 10 mocks + ScheduleProtocols stub + Wave 0 deferral note                   | `ee351c0` | 11 test files + 10 mocks + ScheduleProtocols.swift + 05-DISCUSSION-LOG.md append (23 changes, 572 inserts) |

## Files Created/Modified

**Created (source):**

- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift` — D-02 Codable schema + crossesMidnight helper
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift` — `.main` / `.evening` / `.morning`
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift` — DeviceActivityName builder + parser (prefix `"deluludetox.schedule."`)
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift` — App Group URL helpers; timestamp-suffixed marker naming + `isMarkerFile(_:)` predicate
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift` — append-only history row
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift` — DAM→main-app marker payload
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift` — `session` + `schedule` literal constants
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` — 10 empty Sendable protocols (Plans 02/03/04 extend in-place)
- `DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` — skeleton enum; empty `register(in:)` body

**Created (tests):**

- `DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift` (5 stubs, Plan 05-02)
- `DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift` (4 stubs, Plan 05-03)
- `DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift` (6 stubs, Plan 05-03)
- `DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift` (6 stubs, Plan 05-04)
- `DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift` (4 stubs, Plan 05-04)
- `DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift` (3 stubs, Plan 05-04)
- `DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift` (4 stubs, Plan 05-04)
- `DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift` (3 stubs, Plan 05-02)
- `DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift` (4 stubs, Plan 05-02)
- `DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift` (8 stubs, Plan 05-06)
- `DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift` (4 stubs, Plan 05-07)

**Created (mocks):**

- `DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleShieldRepository.swift`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleActivityMonitoringRepository.swift` — ordered `callLog: [Call]` for Sync ordering assertions
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockComputeScheduleWindowUseCase.swift`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockObserveScheduleUseCase.swift`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockSyncScheduleWithSystemUseCase.swift`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockCreateOrUpdateScheduleUseCase.swift`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockToggleScheduleUseCase.swift`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockSelfHealSchedulesUseCase.swift`
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockConsumeScheduleEventMarkerUseCase.swift`

**Modified:**

- `DeluluDetox/Sources/App/DeluluDetoxApp.swift` — inserted `SchedulingInjection.register(in: container)` between `SessionInjection.register` and `DenialInjection.register`
- `project.yml` — DeviceActivityMonitorExtension.sources gains 6 new entries (Schedule, ScheduleSegment, ScheduleActivityNames, SchedulePaths, ScheduleEventMarker, ManagedSettingsStoreNames)
- `.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` — appended `## Wave 0 Spike — DEFERRED` section

## Decisions Made

- **Wave 0 spike deferred.** No physical iOS 26+ device available at execution time. Plan 05-02 must NOT pick `repeats=true` happy path vs. daily re-register fallback until the spike runs. Recorded as `## Wave 0 Spike — DEFERRED` in `05-DISCUSSION-LOG.md`.
- **`ScheduleProtocols.swift` with empty protocols** over `#if false` mock-wrapping. Rationale: avoids conditional-compilation fragility; mocks compile against named types today; Plans 02/03/04 extend the protocol bodies in-place (no file move / rename churn).
- **Timestamp-suffixed marker naming locked into `SchedulePaths`.** Single-file overwrite (the `D-17` original) cannot survive a cross-midnight pair (evening-start immediately followed by morning-end with no foreground between them). Decision honors RESEARCH OQ#4 resolution before any code depends on the old behavior.

## Deferred

### Task 1: Wave 0 spike (physical-device verification)

**Status:** DEFERRED — not executed.

**Reason:** No physical iOS 26+ device with Family Controls entitlement available at execution time.

**Consequences:**

- Plan 05-02 authoring MUST wait until Task 1 runs and a `## Wave 0 Spike Verdict` section is appended to `05-DISCUSSION-LOG.md` with Outcome A / B / C.
- If Outcome is **A** (fires reliably), Plan 05-02/03 proceed with `repeats=true` + DAM weekday filter per CONTEXT D-13.
- If Outcome is **B** (fires at wrong time), Plan 05-03 switches `DeviceActivitySchedule` to include `.year/.month/.day` components and treats DAS as effectively non-repeating.
- If Outcome is **C** (does not fire), Plan 05-02+ pivots to non-repeating DAS with daily midnight re-register via `SelfHealSchedulesUseCase`.

**How to resume:**

1. Obtain physical iOS 26+ device with Family Controls authorized.
2. Execute the `<spike_instrumentation>` block in `05-01-wave0-spike-scaffolds-PLAN.md` verbatim.
3. Append a `## Wave 0 Spike Verdict (YYYY-MM-DD)` section to `05-DISCUSSION-LOG.md` with device model, iOS version, start time, observed fire time, and Outcome letter.
4. Revert all spike-only changes before committing the verdict.
5. Confirm `grep -c "^## Wave 0 Spike Verdict" .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` == 1 (currently 0 — by design).

## Deviations from Plan

**None under Rules 1-3.** Task 1 is **deferred** by explicit user override (scope_override) rather than an auto-fixed deviation — the executor received an instruction from the orchestrator to skip the physical-device spike this session and continue with Tasks 2 and 3. This is a scope change communicated by the user, not an autonomous decision by the executor.

---

**Total deviations:** 0 auto-fixed
**Impact on plan:** Partial execution per user scope_override; scaffolds ready; spike outstanding.

## Acceptance Criteria Cross-check

Plan-level verification gate (adjusted to reflect deferral):

- [x] Task 2: 7 scaffold source files exist (`ls DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/*.swift | wc -l` = 7)
- [x] Task 2: `SchedulingInjection.register(in: container)` wired between Session and Denial in `DeluluDetoxApp.init()` (grep = 1)
- [x] Task 2: `project.yml` DeviceActivityMonitorExtension.sources source-shares 6 Scheduling Models files (grep on `Features/Scheduling/Common/Repository/Models` = 6 matching entries)
- [x] Task 2: No SwiftUI / Combine / FamilyControls imports in shared Models files (grep = 0)
- [x] Task 2: `xcodegen generate` idempotent (two consecutive runs, both zero-error)
- [x] Task 3: 11 XCTest files exist under `DeluluDetoxTests/Features/Scheduling/*.swift`
- [x] Task 3: 10 mock files exist under `DeluluDetoxTests/Features/Scheduling/Mocks/*.swift`
- [x] Task 3: 51 XCTSkipIf stubs across all test files (grep = 51; plan expected ~45+)
- [x] Task 3: `ScheduleProtocols.swift` declares 10 empty Sendable protocols
- [x] Task 3: `05-DISCUSSION-LOG.md` contains exactly one `## Wave 0 Spike — DEFERRED` header (grep = 1)
- [x] Task 3: Full test suite green — **205 tests, 54 skipped, 0 failures** on iPhone 17 / iOS 26.3.1 simulator (matches plan prediction of ≥204 / ≥54)
- [ ] Task 1: `grep -c "^## Wave 0 Spike Verdict" .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` == 1 — **DEFERRED, currently 0 (correct)**
- [ ] Task 1: Verdict contains Outcome A/B/C — **DEFERRED**
- [ ] Task 1: Verdict contains "Device:" + "iOS:" lines — **DEFERRED**

## Issues Encountered

- **Worktree base mismatch at start.** Worktree HEAD was on `4096a9f` (Initial commit + CLAUDE.md), not on the expected orchestrator base `283f6387`. Resolved via `git reset --soft 283f6387` + `git checkout -- .` + `git clean -fd`. Rest of the session proceeded cleanly.
- **`mcp__XcodeBuildMCP__*` tools not exposed to this executor.** CLAUDE.md prescribes XcodeBuildMCP for Apple build / test flow, but the MCP tool surface was not available in this session. Fallback: raw `xcodebuild build` + `xcodebuild test` with the booted iPhone 17 simulator (UUID `6D73311F-3541-4B74-92E8-8014FABC3329`, iOS 26.3.1). Build SUCCEEDED and TEST SUCCEEDED, so the substantive outcome matches what XcodeBuildMCP would have produced. Flagging for orchestrator visibility; not a deviation to fix.

## User Setup Required

None — no external service configuration required for scaffolding.

## Next Phase / Plan Readiness

**Ready:**

- All downstream Plans (05-02 through 05-07) can cite concrete `<automated>` commands like `xcodebuild test ... -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests/testCodableRoundTrip`.
- DAM extension build surface is extended — Plan 05-05 will replace `intervalDidEnd` stub with real dispatch over both Session + Schedule activity prefixes.
- DIContainer bootstrap order is stable — Plan 05-04 adds registrations inside the existing `SchedulingInjection.register` body.

**Blocked:**

- **Plan 05-02 (ScheduleRepository + UCs)** must not begin until Wave 0 spike Outcome is recorded (A/B/C). Reason: the exact shape of `ScheduleActivityMonitoringRepository.startMonitoring` (`repeats: true` vs. `repeats: false` + daily re-register) depends on the spike verdict. Proceeding now risks re-authoring Plan 05-03 tests.

## Self-Check: PASSED

All listed created files verified present on disk:

- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` — FOUND
- 11 test files + 10 mocks under `DeluluDetoxTests/Features/Scheduling/` — FOUND

Commits verified present in git log:

- `2340031` (Task 2) — FOUND
- `ee351c0` (Task 3) — FOUND

---

*Phase: 05-scheduled-blocking*
*Plan: 01 (PARTIAL — Task 1 deferred, Tasks 2/3 complete)*
*Completed: 2026-04-20*
