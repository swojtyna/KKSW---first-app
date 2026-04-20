---
phase: 5
slug: scheduled-blocking
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-20
updated: 2026-04-20
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (via XcodeBuildMCP `test_sim`) |
| **Config file** | project.yml (scheme: DeluluDetox, target: DeluluDetoxTests) |
| **Quick run command** | `mcp__XcodeBuildMCP__test_sim` (scoped to `DeluluDetoxTests/Features/Scheduling/*`) |
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

Every task with `<automated>` verify is mapped below to its REQ-ID and Wave 0 test stub. Wave 0 scaffolds are created by Plan 05-01 Task 3 — until that runs, every "File Exists" cell reads "❌ W0" (blocking on Wave 0).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 05-01 | 0 | SCH-01..04 | — | Wave 0 spike verdict recorded in DISCUSSION-LOG before downstream plans commit DAS strategy | manual (checkpoint) | `grep -c "## Wave 0 Spike Verdict" .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` | ✅ (Plan 01 output) | ⬜ pending |
| 05-01-02 | 05-01 | 0 | SCH-01..04 | T-05-01-01..03 | Feature scaffold + project.yml source-shares committed without regressing Phase 1-4 suite | integration (build) | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox` (expect Phase 4 baseline count, 0 failures) | ✅ (Plan 01 output) | ⬜ pending |
| 05-01-03 | 05-01 | 0 | SCH-01..04 | T-05-01-04 | 51 XCTSkipIf stubs + 10 mocks land as skipped — no silent failures | integration (build) | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox` (expect ≥204 tests, ≥54 skipped, 0 failures) | ✅ (Plan 01 output) | ⬜ pending |
| 05-02-01 | 05-02 | 1 | SCH-01, SCH-02 | T-05-02-01..07 | Atomic JSON persistence + multi-marker consume resolves RESEARCH OQ#4 | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests` (5 passed) | ❌ W0 | ⬜ pending |
| 05-02-02 | 05-02 | 1 | SCH-01, SCH-02 | T-05-02-01..07 | CreateOrUpdate composes repo.upsert → sync; ConsumeEventMarker appends in chronological order | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests -only-testing:DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests` (7 passed) | ❌ W0 | ⬜ pending |
| 05-03-01 | 05-03 | 1 | SCH-02, SCH-03, SCH-04 | T-05-03-01..07 | Schedule-named ManagedSettingsStore isolated from session store; clock-skew defense via requireAutomaticDateAndTime=true | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests` (4 passed) | ❌ W0 | ⬜ pending |
| 05-03-02 | 05-03 | 1 | SCH-02, SCH-03 | T-05-03-03, T-05-03-07 | 1 or 2 DAS per schedule (cross-midnight split); stopMonitoring defensively clears all 3 segment variants | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests` (6 passed) | ❌ W0 | ⬜ pending |
| 05-04-01 | 05-04 | 2 | SCH-01, SCH-02, SCH-03 | T-05-04-04, T-05-04-08 | Pure compute of schedule window state (cross-midnight-aware, weekday-aware, testable without mocks) | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests` (6 passed) | ❌ W0 | ⬜ pending |
| 05-04-02 | 05-04 | 2 | SCH-01, SCH-02 | T-05-04-01, T-05-04-02 | Sync UC implements stop→start with rollback on throw; Toggle flips + syncs; Observe passthroughs publisher | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests -only-testing:DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests` (7 passed) | ❌ W0 | ⬜ pending |
| 05-04-03 | 05-04 | 2 | SCH-03 | T-05-04-03, T-05-04-05 | SelfHeal reconciles shield state on foreground; cross-feature UC uses AppSelection via ObserveBlocklistUseCase (not Repository) | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests` (4 passed) + full suite 0 failures | ❌ W0 | ⬜ pending |
| 05-04-04 | 05-04 | 2 | SCH-03 | T-05-04-06, T-05-04-07 | AppRoot consumes schedule markers + self-heals on scenePhase.active; Darwin observers (scheduleStarted/Ended) trigger refreshStatus | integration | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Root/AppRootViewModelTests` (prior + 2 new pass) + full suite 0 failures | ❌ W0 | ⬜ pending |
| 05-05-01 | 05-05 | 2 | SCH-03, SCH-04 | T-05-05-01..09 | DAM dispatches by activity-name prefix; schedule path applies tokens to deluludetox.schedule store; session path untouched; marker + Darwin emitted | integration (build) | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox` (full suite; 0 failures — no new tests; DAM behavior is manual-only per Manual-Only Verifications below) | ❌ W0 | ⬜ pending |
| 05-06-01 | 05-06 | 3 | SCH-01, SCH-02 | T-05-06-01..06 | Draft state + Destination.errorAlert; Save routes to CreateOrUpdateScheduleUseCase with sarcastic PL error copy on throw | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests` (8 passed) | ❌ W0 | ⬜ pending |
| 05-06-02 | 05-06 | 3 | SCH-01, SCH-02 | T-05-06-02 | SwiftUI Form compiles with 2 wheel DatePickers + 7 day chips + 3 presets + cross-midnight marker + Save CTA + error alert | integration (build) | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox` (full suite green; SwiftUI compiles) | ❌ W0 | ⬜ pending |
| 05-07-01 | 05-07 | 3 | SCH-01, SCH-02 | T-05-07-01..06 | List observes ScheduleRepository publisher; createTapped/editTapped instantiate editor VM; toggleSchedule routes to ToggleScheduleUseCase | unit | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests` (4 passed) | ❌ W0 | ⬜ pending |
| 05-07-02 | 05-07 | 3 | SCH-01, SCH-02 | T-05-07-06 | HomeViewModel.scheduleList destination case + HomeView toolbar entry + navigationDestination compile; 1 new Home test passes | integration (build + unit) | `mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox` (full suite green; includes testScheduleListTappedRoutesToScheduleListDestination) | ❌ W0 | ⬜ pending |
| 05-08-01 | 05-08 | 4 | SCH-01, SCH-02, SCH-03, SCH-04 | T-05-08-01..05 | Device UAT exercises SCH-01..04 on physical iOS 26+ device; 7 scenarios recorded in 05-UAT.md with Final Verdict | manual (checkpoint: human-verify) | `grep -c "^## Final Verdict" .planning/phases/05-scheduled-blocking/05-UAT.md` (>= 1) | N/A (doc) | ⬜ pending |

**Legend:**
- ✅ = scaffold exists after Plan 01 runs
- ❌ W0 = file will exist only after Wave 0 (Plan 01 Task 3) creates the XCTSkipIf stubs; blocking prerequisite
- N/A (doc) = document-only verification (UAT report)

---

## Wave 0 Requirements

- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift` — stubs for SCH-01, SCH-02 (schedule CRUD + persistence)
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift` — stubs for SCH-03, SCH-04 (shield apply/clear on named store)
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift` — stubs for SCH-03 (DAS register/unregister, cross-midnight split)
- [ ] `DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift` — stubs for SCH-01, SCH-02, SCH-03 (pure window computation)
- [ ] `DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift` — stubs for SCH-02, SCH-03 (toggle + weekday filter + rollback)
- [ ] `DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift` — stubs for SCH-02
- [ ] `DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift` — stubs for SCH-03 (self-heal on scenePhase)
- [ ] `DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift` — stubs for SCH-01, SCH-02
- [ ] `DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift` — stubs for SCH-03 (marker consume + clear)
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift` — stubs for SCH-01, SCH-02
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift` — stubs for SCH-01, SCH-02
- [ ] Mocks: `MockScheduleRepository`, `MockScheduleShieldRepository`, `MockScheduleActivityMonitoringRepository`, `MockComputeScheduleWindowUseCase`, `MockObserveScheduleUseCase`, `MockSyncScheduleWithSystemUseCase`, `MockCreateOrUpdateScheduleUseCase`, `MockToggleScheduleUseCase`, `MockSelfHealSchedulesUseCase`, `MockConsumeScheduleEventMarkerUseCase`

Status: `wave_0_complete: false` until Plan 05-01 Task 3 lands and the test suite reports ≥204 tests with ≥54 skipped (Phase 4 baseline + 51 Scheduling stubs). Do NOT set `wave_0_complete: true` until that's observed green.

*Reuse existing test infrastructure from Phase 3/4 — ManagedSettingsStoreWriter, DeviceActivityCenterRunner, Clock, Darwin notification seams.*

---

## Manual-Only Verifications

| Task ID | Behavior | Requirement | Why Manual | Test Instructions | Status |
|---------|----------|-------------|------------|-------------------|--------|
| 05-08-S1 | Recurring DAS fires `intervalDidStart`/`intervalDidEnd` reliably on real device | SCH-03 | iOS 26 system callback timing cannot be mocked; requires wall-clock observation | 05-UAT.md Scenario 1: register a 2-min schedule for current day, wait for interval, observe shield apply + marker write | ⬜ pending |
| 05-08-S2 | Disable toggle stops future fires | SCH-02 | DAM + DeviceActivityCenter stopMonitoring is system-level; requires wall-clock observation | 05-UAT.md Scenario 2: create 2-min schedule, toggle OFF after 1 min, verify no intervalDidStart log at original start time | ⬜ pending |
| 05-08-S3 | Weekday filter fires correctly (Calendar.weekday gate in DAM) | SCH-03 | Requires a day-specific test date; mocked Calendar insufficient for system DAS firing | 05-UAT.md Scenario 3: schedule for day-X-only, verify no shield apply on day-Y | ⬜ pending |
| 05-08-S4 | Cross-midnight schedule (22:00–06:00) applies shields continuously across midnight | SCH-03 | Requires sleeping through midnight on a physical device | 05-UAT.md Scenario 4: set schedule 22:00–06:00 today, observe shield still active at 00:15 and 05:45; check 2+ marker files in App Group container | ⬜ pending |
| 05-08-S5 | Shield overlay during scheduled block matches quick-session shield | SCH-04 | Visual parity check; auto-merge of `ManagedSettingsStore` named stores is runtime behavior | 05-UAT.md Scenario 5: start quick session AND active schedule overlap; open blocked app; verify identical shield render | ⬜ pending |
| 05-08-S6 | Marker consumption on foreground + Darwin refresh | SCH-03 | Extension-to-main-app Darwin signal + App Group file consumption is runtime behavior | 05-UAT.md Scenario 6: background app, wait for schedule fire, foreground, observe ConsumeScheduleEventMarkerUseCase log + clean marker dir | ⬜ pending |
| 05-08-S7 | Session × schedule coexistence (D-07): clearing one store does not affect the other | SCH-03 | ManagedSettings union behavior is iOS runtime; cannot be unit-tested | 05-UAT.md Scenario 7: overlap quick session + schedule; quick session ends → shield persists from schedule; schedule ends → shield clears | ⬜ pending |

Schedule survives app termination + device restart (SCH-02) is covered implicitly by Scenarios 1 and 4 — the DAS runtime is independent of app process state.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies (17 automated tasks + 7 manual UAT scenarios mapped above)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (DAM Plan 05-05 is the single auto task without new tests; all surrounding tasks have scoped tests)
- [ ] Wave 0 covers all MISSING references (11 Scheduling test files + 10 mocks listed above)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (scoped `-only-testing:` filter keeps per-task run to ~10-20s)
- [x] `nyquist_compliant: true` set in frontmatter (2026-04-20, planning iteration 1)
- [ ] `wave_0_complete: true` — NOT yet; will flip after Plan 05-01 Task 3 lands scaffolds green

**Approval:** pending
