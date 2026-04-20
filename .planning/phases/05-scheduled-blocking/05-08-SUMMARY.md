---
phase: 05-scheduled-blocking
plan: 08
status: complete
subsystem: scheduling
tags: [uat, device-testing, sch-01, sch-02, sch-03, sch-04, wave-0-verification]

requires:
  - phase: 05-01
    provides: scaffolds + deferred Wave 0 spike gate
  - phase: 05-02
    provides: ScheduleRepository + persistence UCs
  - phase: 05-03
    provides: ScheduleShield + ActivityMonitoring repos
  - phase: 05-04
    provides: 5 domain UCs + DI + AppRoot foreground wiring
  - phase: 05-05
    provides: DAM extension schedule dispatch
  - phase: 05-06
    provides: Schedule Editor UI
  - phase: 05-07
    provides: Schedule List UI + Home entry
provides:
  - On-device validation of SCH-01, SCH-02, SCH-03, SCH-04 on iPhone 14 Pro / iOS 26.3.1
  - Retroactive confirmation of Wave 0 Outcome A (repeating DAS survives day rollover)
  - 05-UAT.md — 7-scenario UAT report with PASS verdicts
  - 05-HUMAN-UAT.md — all 7 scenarios marked PASS
affects: [milestone close, future scheduling work]

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/05-scheduled-blocking/05-UAT.md
  modified:
    - .planning/phases/05-scheduled-blocking/05-HUMAN-UAT.md (results filled)
    - .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md (Wave 0 Outcome A CONFIRMED)

key-decisions:
  - "Wave 0 Outcome A CONFIRMED — repeats=true survives day rollover on iOS 26.3.1. No decimal fix phase 05.1 needed."
  - "Incidental crash surfaced + fixed mid-UAT: ScheduleEditorViewModel missing .receive(on: .main) on blocklist subscription. Committed as 736acb7. Re-UAT clean."

patterns-established: []

requirements-completed: [SCH-01, SCH-02, SCH-03, SCH-04]

duration: ~1h (including hotfix turnaround)
completed: 2026-04-20
---

# Phase 05 Plan 08: Device UAT — Phase 5 Complete

**All 7 on-device scenarios PASS on iPhone 14 Pro / iOS 26.3.1 — SCH-01..SCH-04 validated, Wave 0 Outcome A retroactively confirmed, Phase 5 ready to close.**

## Performance

- **Duration:** ~1 hour (UAT execution + hotfix)
- **Device:** iPhone 14 Pro, iOS 26.3.1
- **App build:** `736acb7` (post-MainActor-hotfix)

## Accomplishments

- All 4 requirements validated on a real device: SCH-01 (create+fire), SCH-02 (disable stops fires), SCH-03 (weekday filter + cross-midnight), SCH-04 (shield parity).
- **Wave 0 Outcome A retroactively CONFIRMED** via Scenarios 3 + 4. The happy-path assumption implemented in Plans 05-02 / 05-04 / 05-05 (single `DeviceActivitySchedule(repeats: true)` per segment, no daily re-register-at-midnight fallback) holds on iOS 26.3.1.
- Incidental bug surfaced in Scenario 1 (Editor VM MainActor violation) — diagnosed via LLDB backtrace + fixed in `736acb7` before completing UAT.

## Commits

- `bc7779f` — test(05): persist human UAT items as HUMAN-UAT.md (before execution)
- `736acb7` — fix(05-06): hop blocklist subscribe to main queue (hotfix surfaced by Scenario 1)
- `<this commit>` — test(05-08): record Phase 5 UAT verdict + Wave 0 Outcome A confirmation + SUMMARY

## Deviations

- **D1 (Rule 3 — hotfix in flight):** Scenario 1 crashed on first attempt. Rather than mark scenario FAIL + route to `/gsd-plan-phase --gaps`, diagnosed in-place via user-provided `bt` output, shipped 1-line fix (`736acb7`), re-ran scenario → PASS. All subsequent scenarios executed post-fix.
