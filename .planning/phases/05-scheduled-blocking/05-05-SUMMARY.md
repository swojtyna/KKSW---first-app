---
phase: 05
plan: 05
subsystem: Scheduling (DAM extension)
status: complete
tags: [dam-extension, scheduling, managed-settings, darwin-notification, cross-process]
requirements: [SCH-03, SCH-04]
dependency_graph:
  requires:
    - "Plan 05-01: ScheduleActivityNames + SchedulePaths + ManagedSettingsStoreNames + ScheduleEventMarker + Schedule + ScheduleSegment (source-shared into DAM target via project.yml)"
    - "Plan 05-02: ConsumeScheduleEventMarkerUseCase on main-app side (multi-marker consumer — the DAM writes, main app reads)"
    - "Plan 05-03: named-store + repository conventions (ScheduleShieldRepository mirrors the same apply/clear semantics used here)"
    - "Phase 3 Plan 03-04: canonical DAM handler pattern (clearSharedManagedSettingsStore + writeFinalizeMarker + postDarwinNotification — session path preserved byte-for-byte)"
    - "Phase 2 BlocklistRepositoryImpl: blocklists.json file format (single Blocklist object, not array)"
  provides:
    - "DAM dispatch-by-prefix: ScheduleActivityNames.parse(_:) branches schedule activities vs. session activities"
    - "Schedule intervalDidStart pipeline: load → weekday-filter → apply shield to schedule-named store → marker + Darwin"
    - "Schedule intervalDidEnd pipeline: clear schedule-named store → marker + Darwin"
    - "Cross-process Darwin notifications: com.kksw.DeluluDetox.scheduleStarted / scheduleEnded"
    - "Timestamp-suffixed marker writes via SchedulePaths.markerURL(timestamp:) — multi-marker-safe across midnight"
  affects:
    - "Plan 05-04 AppRoot Darwin observer names are now live (observers in AppRootViewModel match DAM posts)"
    - "Plan 05-07 ScheduleListView will surface events once DAM runs on real device (Plan 05-08 UAT)"
    - "Plan 05-08 device UAT becomes the next verification gate — simulator cannot fire DAS"
tech_stack:
  added:
    - "DAM extension: @preconcurrency import FamilyControls (Option A per plan)"
  patterns:
    - "Prefix-based dispatch inside existing override — no new entry points"
    - "Lean BlocklistEnvelope Decodable {id, lastSelection} — avoids pulling BlocklistRepository (Combine dependency) into DAM"
    - "Weekday filter applied to the SEGMENT's relevant weekday: .main/.evening → today, .morning → yesterday (morning fires on the NEXT calendar day but the schedule's day-of-week membership is its evening-start day)"
    - "Timestamp-suffixed markers use unix-millis precision so cross-midnight pairs never overwrite"
    - "Clock-skew defense applied at DAM fire (requireAutomaticDateAndTime = true) — protection live before main-app self-heal runs"
key_files:
  modified:
    - "Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift"
  created: []
decisions:
  - "DAM-side schedule dispatch uses ScheduleActivityNames.parse(_:) — no bare string prefix matching (keeps activity-name schema centralized in one source-shared file)"
  - "Option A — import FamilyControls into DAM — selected over Option B (main-app-only apply) because Option B fails SCH-03 when app is backgrounded at schedule start"
  - "handleScheduleEnd clears shield.applications/applicationCategories/webDomains/requireAutomaticDateAndTime, NEVER touches the session-named store (D-05 cross-store isolation)"
  - "Marker writes use timestamp-suffixed naming so the DAM never overwrites a pending marker that the main app hasn't consumed yet (RESEARCH OQ#4)"
metrics:
  duration_minutes: 9
  tasks_completed: 1
  files_modified: 1
  lines_added: 216
  lines_removed: 19
  tests_executed: 207
  tests_skipped: 15
  tests_failing: 0
  commits: 1
completed: 2026-04-20
---

# Phase 05 Plan 05: DAM Extension Handlers Summary

Added schedule dispatch to the DeviceActivityMonitor extension: parse activity names by prefix, apply tokens to the schedule-named ManagedSettingsStore on interval start, clear on interval end, write timestamp-suffixed event markers, and post Darwin notifications — all without breaking the Phase 3 session path.

## What Shipped

Single-file modification to `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`:

1. **New import:** `@preconcurrency import FamilyControls` — required to decode `FamilyActivitySelection` tokens from `blocklists.json`. Kept lean: no SwiftUI, Combine, or URLSession.

2. **Two new Darwin notification name constants:**
   - `darwinScheduleStartedName = "com.kksw.DeluluDetox.scheduleStarted"`
   - `darwinScheduleEndedName = "com.kksw.DeluluDetox.scheduleEnded"`
   (alongside existing `darwinSessionFinalizedName`)

3. **`intervalDidStart(for:)` gained a schedule branch** — previously log-only. Now: if `ScheduleActivityNames.parse(activity)` returns a non-nil `(scheduleId, segment)`, dispatch to `handleScheduleStart`. Phase 3 semantics preserved (session path never used `intervalDidStart` anyway).

4. **`intervalDidEnd(for:)` gained a schedule branch** — existing session path moved inside `if activity == SessionActivityNames.quickSession { ... return }`. Below that: if parse succeeds, dispatch to `handleScheduleEnd`. Unknown activities still log + return.

5. **New private helpers:**
   - `handleScheduleStart(scheduleId:segment:)` — 5-step pipeline: load schedule → enable-check → weekday filter → load tokens → write schedule-named store (`shield.applications`, `shield.webDomains`, `shield.applicationCategories = .specific(...)`, `dateAndTime.requireAutomaticDateAndTime = true`) → marker + Darwin.
   - `handleScheduleEnd(scheduleId:segment:)` — clear the four schedule-store fields → marker + Darwin. Session-named store is never touched (D-05 isolation).
   - `loadScheduleById(_:)` — decode `[Schedule]` from `schedule.json`, return first id match.
   - `loadBlocklistTokens(blocklistId:)` — decode lean `BlocklistEnvelope {id, lastSelection}` from `blocklists.json` (single-object file, not array).
   - `blocklistsURL()` — reproduce the Phase 2 path locally (`group.com.kksw.DeluluDetox/blocklists.json`) to avoid importing `BlocklistRepository` (Combine drag).
   - `writeScheduleEventMarker(scheduleId:kind:)` — encodes `ScheduleEventMarker` + writes via `SchedulePaths.markerURL(timestamp:)` (multi-marker-safe naming).
   - `postScheduleDarwin(name:)` — `CFNotificationCenterPostNotification` with deliverImmediately = true.

## Weekday-Filter Subtlety

The schedule's `daysOfWeek` is keyed to the schedule's **start day**. Segment-aware filter:

| Segment | Fires | Relevant weekday |
|---|---|---|
| `.main` | start-day | today |
| `.evening` | start-day | today |
| `.morning` | next calendar day (after midnight) | yesterday (`((today - 2 + 7) % 7) + 1`) |

This keeps a Monday–Tuesday 22:00–06:00 schedule firing `.morning` on Tuesday at 00:00 where the filter checks Monday's weekday (which is enabled) — not Tuesday's (which may not be).

## Verification

**Build (`xcodebuild build` for iPhone 17 / iOS 26.3):** `** BUILD SUCCEEDED **` — DAM extension compiles cleanly with 5 imports.

**Tests (`xcodebuild test`):** 207 executed, 15 skipped, 0 failures. Zero regressions across Phase 2/3/4/5-Wave-1 test suites.

**Acceptance criteria greps — all pass:**
- `@preconcurrency import FamilyControls` count = 1
- `^import SwiftUI$` / `^import Combine$` count = 0 (strict RAM posture)
- `ScheduleActivityNames.parse(activity)` count = 2 (dispatch in both overrides)
- `ManagedSettingsStore(named: .init(ManagedSettingsStoreNames.schedule))` count = 2 (apply + clear)
- `handleScheduleStart` / `handleScheduleEnd` / `loadScheduleById` / `loadBlocklistTokens` / `writeScheduleEventMarker` / `postScheduleDarwin` each count = 1
- `SessionActivityNames.quickSession` count ≥ 1 (Phase 3 path preserved)
- `com.kksw.DeluluDetox.scheduleStarted` / `scheduleEnded` each count = 1
- `SchedulePaths.markerURL(timestamp:` count = 1

**RAM posture — deferred:** Real-device RAM profiling requires Plan 05-08 UAT on a physical device. Simulator cannot fire DeviceActivitySchedule events. Expected ~1 MB added for FamilyControls framework under the 6 MB ceiling; Phase 3 baseline is ~500 KB so >4 MB headroom remains. If UAT surfaces >5 MB runtime usage, pivot to Option B (main-app-only apply) is documented as threat T-05-05-01 mitigation.

## SCH-04 Delivery

SCH-04 ("Shield overlay during scheduled blocks behaves identically to quick session shields") ships with **zero code in this plan**. The Phase 4 `ShieldConfigurationExtension` renders the same branded shield regardless of which named store (`deluludetox.session` or `deluludetox.schedule`) placed the tokens. No DAM-side work is required.

## Deviations from Plan

None — plan executed exactly as written. No auto-fixes, no architectural questions, no authentication gates.

## Known Stubs

None. DAM extension handlers write real tokens, real markers, real Darwin posts. No placeholder paths.

## Threat Flags

None. All new surface is covered by the plan's existing `<threat_model>`:
- T-05-05-01 (FamilyControls RAM) → mitigation deferred to Plan 05-08 UAT
- T-05-05-02/03 (corrupted JSON) → do/catch + lean envelope decoders in place
- T-05-05-04 (spoofed activity name) → dispatch gate via `ScheduleActivityNames.parse(_:)` (non-schedule names fall through to session-path + default log)
- T-05-05-05 (info disclosure) → logs contain only UUIDs + scalar counts, never token bytes
- T-05-05-06 (cross-store EoP) → `handleScheduleEnd` uses schedule-name literal only
- T-05-05-07 (audit trail) → every apply/clear emits marker + Darwin + log
- T-05-05-08 (morning weekday) → explicit `((today - 2 + 7) % 7) + 1` rollback
- T-05-05-09 (crash between write+Darwin) → marker survives; next foreground consumes

## Self-Check: PASSED

- FOUND: `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` (318 lines on disk)
- FOUND: commit `09287f1` in `git log --all`
- FOUND: build green for scheme DeluluDetox on simulator `6D73311F-3541-4B74-92E8-8014FABC3329`
- FOUND: 207/207 tests pass (15 skipped, 0 failures)
