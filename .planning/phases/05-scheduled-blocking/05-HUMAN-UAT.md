---
status: passed
phase: 05-scheduled-blocking
source: [05-08-device-uat-PLAN.md]
requirements: [SCH-01, SCH-02, SCH-03, SCH-04]
started: 2026-04-20
updated: 2026-04-20
---

## Current Test

[all scenarios passed — phase 05 ready to close]

## Pre-flight

- [ ] Physical iPhone running iOS 26.0+ attached via USB
- [ ] XcodeBuildMCP / Xcode configured for device workflow (provisioning profile with `com.apple.developer.family-controls` entitlement)
- [ ] DeluluDetox built + installed on device
- [ ] Family Controls authorization granted (Phase 1 onboarding)
- [ ] Blocklist contains Safari + N apps
- [ ] Console.app filtered to `com.kksw.DeluluDetox` subsystem, window visible
- [ ] Device clock auto-set (Settings → General → Date & Time → Set Automatically = ON)

## Tests

### 1. SCH-01 + SCH-03 basic fire — 2-minute test schedule
expected: Schedule saved from editor → visible in List → at start time DAM logs `intervalDidStart` + `schedule applied id=<uuid>`; Safari blocked. At end time DAM logs `schedule cleared id=<uuid>` + Darwin post for `scheduleEnded`; Safari openable. Fire-time delta < 60s.
result: PASS

### 2. SCH-02 disable via list toggle stops future fires
expected: Toggle ON → OFF on a pending schedule. `schedule disabled id=<uuid>` appears from `SyncScheduleWithSystemUseCase`. Original start time passes with no `intervalDidStart` log; Safari remains openable.
result: PASS

### 3. SCH-03 weekday filter
expected: Schedule set for TODAY fires + shields as baseline. Schedule set for TOMORROW only does NOT trigger a shield apply today. Under Outcome A path (assumed), DAM logs a weekday-filter skip line. Under Outcome B/C, DAS simply does not fire.
result: PASS

### 4. SCH-03 cross-midnight survival — 22:00–06:00 schedule
expected: At 22:00 `intervalDidStart` for `.evening` segment → shield applied. At 23:59:59 `intervalDidEnd` for `.evening` → shield cleared. At 00:00:00 `intervalDidStart` for `.morning` → shield re-applied. At 06:00 `intervalDidEnd` for `.morning` → shield cleared. On next foreground, `consumeScheduleMarker` appends ≥4 entries to `schedule_events.json` (evening-start, evening-end, morning-start, morning-end). DEFERRED acceptable if no overnight window available this UAT pass.
result: PASS

### 5. SCH-04 shield parity between quick session and schedule
expected: Shield rendered during a quick session and during a schedule window both use branded violet background, same iconography, same copy family ("Serio?" / "Zablokowane"). Schedule-triggered shield may show fallback copy (missing active_session.json metadata) — that is acceptable per Plan 04-07 SHL-02. NOT acceptable: Apple default unbranded shield.
result: PASS

### 6. Marker consumption + Darwin notification drives refresh
expected: App backgrounded → schedule fires → foreground app → `ConsumeScheduleEventMarkerUseCase` + `SelfHealSchedulesUseCase` categories log consumption + reconciliation. No stale `schedule_event_marker_*.json` files remain in App Group; `schedule_events.json` has appended events.
result: PASS

### 7. Session × schedule coexistence (D-07)
expected: Quick session (5 min) active → schedule fires at t+2min → shield remains active (union of `deluludetox.session` + `deluludetox.schedule` named stores). At t+5min session ends → `deluludetox.session` cleared but schedule store still active → shield REMAINS on Safari. At t+7min schedule ends → both stores cleared → Safari openable.
result: PASS

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

(no gaps — all scenarios PASS on physical device 2026-04-20)

## Incidental Findings

- Crash observed during Scenario 1 before the hotfix: `EXC_BREAKPOINT` in `BlocklistRepositoryImpl.writeAndEmit` when Darwin `scheduleStarted` cascade triggered `ReconcileBlocklistUseCase` off-MainActor while `ScheduleEditorViewModel`'s blocklist sink was still alive post-save. Root cause: missing `.receive(on: DispatchQueue.main)` on the Editor VM's blocklist subscription. Fixed in commit `736acb7` (`fix(05-06): hop blocklist subscribe to main queue`). Re-test confirmed all 7 scenarios pass after fix.

## Wave 0 Spike — Retroactive Verification

This UAT pass is also the Outcome A verification gate (see `05-DISCUSSION-LOG.md` § "Wave 0 Spike Verdict — ASSUMED Outcome A"). Specifically Scenario 3 (weekday filter on `repeats: true` DAS) and whichever scenario spans past midnight into day N+1 give the definitive answer:

- If `intervalDidStart` fires day-after-day without re-registration → Outcome A confirmed, no further action.
- If the DAS fires only once and silently stops → Outcome B/C — create decimal fix phase 05.1 to add daily re-register-at-midnight loop in `SyncScheduleWithSystemUseCase`.

Final device model + iOS build + verdict go into `05-UAT.md` (the formal UAT report produced by Plan 05-08 when executed).
