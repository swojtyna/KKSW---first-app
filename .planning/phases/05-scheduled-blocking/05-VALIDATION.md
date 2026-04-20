---
phase: 5
slug: scheduled-blocking
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-20
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (via XcodeBuildMCP `test_sim`) |
| **Config file** | project.yml (scheme: DeluluDetox, target: DeluluDetoxTests) |
| **Quick run command** | `mcp__XcodeBuildMCP__test_sim` (scoped to `DeluluDetoxTests/Scheduling*`) |
| **Full suite command** | `mcp__XcodeBuildMCP__test_sim` (full `DeluluDetoxTests` target) |
| **Estimated runtime** | ~30–60 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick (Scheduling* tests)
- **After every plan wave:** Run full `DeluluDetoxTests`
- **Before `/gsd-verify-work`:** Full suite must be green on iPhone 17 (iOS 26.2) simulator
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

*Populated by gsd-planner when PLAN.md files are created. Every task with `<automated>` verify must appear here mapped to its REQ-ID and Wave 0 test stub.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| *(TBD by planner)* | | | SCH-01..SCH-04 | | | | | | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `DeluluDetoxTests/Scheduling/ScheduleRepositoryTests.swift` — stubs for SCH-01, SCH-02 (schedule CRUD + persistence)
- [ ] `DeluluDetoxTests/Scheduling/ScheduleShieldRepositoryTests.swift` — stubs for SCH-03 (shield apply/clear on named store)
- [ ] `DeluluDetoxTests/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift` — stubs for SCH-03 (DAS register/unregister, cross-midnight split)
- [ ] `DeluluDetoxTests/Scheduling/SyncScheduleWithSystemUseCaseTests.swift` — stubs for SCH-02, SCH-03 (toggle + weekday filter)
- [ ] `DeluluDetoxTests/Scheduling/SelfHealScheduleUseCaseTests.swift` — stubs for SCH-03 (self-heal on scenePhase)
- [ ] `DeluluDetoxTests/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift` — stubs for SCH-03 (marker consume + clear)
- [ ] Mocks: `MockScheduleStore`, `MockScheduleShieldStoreWriter`, `MockScheduleActivityCenterRunner`, `MockScheduleEventMarkerStore`, `MockClock`, `MockSchedulePathsProvider`, `MockScheduleEventDispatcher`

*Reuse existing test infrastructure from Phase 3/4 — ManagedSettingsStoreWriter, DeviceActivityCenterRunner, Clock, Darwin notification seams.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Recurring DAS fires `intervalDidStart`/`intervalDidEnd` reliably on real device | SCH-03 | iOS 26 system callback timing cannot be mocked; requires wall-clock observation | Register a 2-min schedule for current day, wait for interval, observe shield apply + marker write |
| Cross-midnight schedule (e.g. 22:00–06:00) applies shields continuously across midnight | SCH-03 | Requires sleeping through midnight on a physical device | Set schedule 22:00–06:00 today, leave device, check shield still active at 00:15 and 05:45 |
| Shield overlay during scheduled block matches quick-session shield | SCH-04 | Visual parity check; auto-merge of `ManagedSettingsStore` named stores is runtime behavior | Start quick session AND active schedule overlap; open blocked app; verify identical shield render |
| Schedule survives app termination + device restart | SCH-02 | Extension lifecycle cannot be mocked; App Group persistence only visible on device | Create schedule, force-quit app, restart device, verify schedule still fires at window |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (Scheduling test files + 7 mocks)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
