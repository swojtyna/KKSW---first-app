# Phase 5 UAT — 2026-04-20

**Device:** iPhone 14 Pro
**iOS version:** 26.3.1
**App build:** DeluluDetox @ 736acb7 (post-hotfix — includes Editor VM MainActor fix)
**Wave 0 spike verdict:** Outcome A CONFIRMED (see 05-DISCUSSION-LOG.md)
**Tester:** kedziora.karol@gmail.com

## Pre-flight

- [x] Family Controls authorization granted
- [x] Blocklist contains Safari + N apps
- [x] Console.app filtered to com.kksw.DeluluDetox subsystem
- [x] Device clock auto-set

## Scenario 1: SCH-01 + SCH-03 basic fire — 2-minute test schedule

**Result:** PASS
**Evidence:** Schedule saved from editor → visible in List → shield applied at start time → Safari blocked → shield cleared at end time → Safari openable.
**Issues:** First attempt crashed with `EXC_BREAKPOINT` in `BlocklistRepositoryImpl.writeAndEmit`. Root cause: `ScheduleEditorViewModel` missing `.receive(on: DispatchQueue.main)` on blocklist subscription — Darwin `scheduleStarted` cascade ran `ReconcileBlocklistUseCase` off-MainActor, sink mutated `@MainActor` property off-main → Swift 6 runtime assert. Fixed in `736acb7`. Re-test after fix: PASS.

## Scenario 2: SCH-02 disable via list toggle stops future fires

**Result:** PASS
**Evidence:** Toggle flip → no `intervalDidStart` logged at original start time → Safari remained openable.

## Scenario 3: SCH-03 weekday filter

**Result:** PASS
**Evidence:** Schedule set for non-today weekday did not apply shield today. DAM weekday filter on `repeats: true` DAS worked as designed (Outcome A path).

## Scenario 4: SCH-03 cross-midnight survival (22:00–06:00)

**Result:** PASS
**Evidence:** `.evening` segment fired at 22:00 (shield applied). `.evening` ended at 23:59:59 (shield cleared). `.morning` fired at 00:00 (shield re-applied). `.morning` ended at 06:00 (shield cleared). `schedule_events.json` appended with 4 entries on next foreground.
**Note:** This scenario is also the definitive proof of Wave 0 Outcome A — repeating DAS survived a day rollover without main-app-side re-registration.

## Scenario 5: SCH-04 shield parity (session vs schedule)

**Result:** PASS
**Evidence:** Shield rendered during schedule uses the branded violet background + Phase 4 copy family. Visual parity with quick-session shield confirmed. Acceptable fallback copy path (missing `active_session.json` metadata) renders "Zablokowane" — per SHL-02.

## Scenario 6: Marker consumption + Darwin notification drives refresh

**Result:** PASS
**Evidence:** App backgrounded → schedule fired → on foreground, `ConsumeScheduleEventMarkerUseCase` + `SelfHealSchedulesUseCase` logged consumption + reconciliation. No stale marker files; `schedule_events.json` appended.

## Scenario 7: Session × schedule coexistence (D-07)

**Result:** PASS
**Evidence:** Overlapping quick session + schedule → shield union maintained correctly. Session end left schedule shield active on Safari; schedule end cleared both.

## Final Verdict

- [x] All 7 scenarios PASS → **SCH-01, SCH-02, SCH-03, SCH-04 validated** → Phase 5 **COMPLETE**
- [ ] Scenarios X..Y DEFERRED — none
- [ ] Scenarios X..Y FAILED — none (one crash surfaced and fixed via `736acb7` before completion)

## Console log excerpts

Captured via Console.app filter `subsystem:com.kksw.DeluluDetox` during UAT session. Full transcript retained by tester locally; only category markers recorded here:

- `[Monitor] intervalDidStart activity=deluludetox.schedule.<uuid>.main`
- `[Monitor] schedule applied id=<uuid> apps=N`
- `[Monitor] intervalDidEnd activity=deluludetox.schedule.<uuid>.main`
- `[Monitor] schedule cleared id=<uuid>`
- `[ConsumeScheduleEventMarkerUseCase] consumed N markers`
- `[SelfHealSchedulesUseCase] iterated N enabled schedules`
- `[SyncScheduleWithSystemUseCase] schedule synced id=<uuid> enabled=true`

Cross-midnight handoff (Scenario 4) observed with paired log lines at 23:59:59 + 00:00 for `.evening`/`.morning` segments.
