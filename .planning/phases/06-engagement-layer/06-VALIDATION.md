---
phase: 6
slug: engagement-layer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-20
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (DeluluDetoxTests target) |
| **Config file** | `project.yml` — DeluluDetoxTests target |
| **Quick run command** | `xcodebuild test -project DeluluDetox.xcodeproj -scheme DeluluDetox -destination 'platform=iOS Simulator,id=C958163F-49E1-4B46-8A6D-C2056CD25A37' -only-testing:DeluluDetoxTests/Phase6_EngagementTests` |
| **Full suite command** | `xcodebuild test -project DeluluDetox.xcodeproj -scheme DeluluDetox -destination 'platform=iOS Simulator,id=C958163F-49E1-4B46-8A6D-C2056CD25A37'` |
| **Estimated runtime** | ~30 seconds for Phase 6 tests, ~90 seconds full suite |

Prefer `test_sim` XcodeBuildMCP tool over raw `xcodebuild` per CLAUDE.md.

---

## Sampling Rate

- **After every task commit:** Run phase-scoped test bundle via `test_sim` with `-only-testing` filter
- **After every plan wave:** Run full `DeluluDetoxTests` suite
- **Before `/gsd-verify-work`:** Full suite green + manual device UAT green
- **Max feedback latency:** 30 seconds for quick run

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 1 | GAM-01, GAM-02 | — | Pure streak compute; no side effects | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests` | ❌ W0 | ⬜ pending |
| 6-01-02 | 01 | 1 | GAM-02 | — | DST/timezone day boundary handled via Calendar.date(byAdding:) | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testDSTBoundary` | ❌ W0 | ⬜ pending |
| 6-01-03 | 01 | 1 | GAM-02 | — | D-03 trailing-edge rule: today empty + yesterday .completed → streak alive | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testTrailingEdge` | ❌ W0 | ⬜ pending |
| 6-01-04 | 01 | 1 | GAM-01 | — | Total count = only `.completed` outcomes | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testTotalCountOnlyCompleted` | ❌ W0 | ⬜ pending |
| 6-02-01 | 02 | 2 | NTF-01, NTF-02 | — | LocalNotificationRepository schedule/cancel with fake UNCenter | unit | `test_sim -only-testing:DeluluDetoxTests/LocalNotificationRepositoryTests` | ❌ W0 | ⬜ pending |
| 6-02-02 | 02 | 2 | NTF-01, NTF-02 | — | AppNotificationDelegate dispatches by identifier prefix | unit | `test_sim -only-testing:DeluluDetoxTests/AppNotificationDelegateTests` | ❌ W0 | ⬜ pending |
| 6-02-03 | 02 | 2 | NTF-01, NTF-02 | — | Skip add when authorizationStatus != .authorized | unit | `test_sim -only-testing:DeluluDetoxTests/LocalNotificationRepositoryTests/testSkipWhenNotAuthorized` | ❌ W0 | ⬜ pending |
| 6-03-01 | 03 | 3 | NTF-01 | — | StartSessionUseCase schedules `session.end.{uuid}` on start | unit | `test_sim -only-testing:DeluluDetoxTests/StartSessionUseCaseTests/testSchedulesEndNotification` | ❌ W0 | ⬜ pending |
| 6-03-02 | 03 | 3 | NTF-01 | — | EndSessionUseCase cancels pending `session.end.{uuid}` on non-.completed outcome | unit | `test_sim -only-testing:DeluluDetoxTests/EndSessionUseCaseTests/testCancelsOnEarlyEnd` | ❌ W0 | ⬜ pending |
| 6-03-03 | 03 | 3 | NTF-01 | — | Lazy permission prompt fires on first .completed only | unit | `test_sim -only-testing:DeluluDetoxTests/SchedulePermissionPromptUseCaseTests` | ❌ W0 | ⬜ pending |
| 6-04-01 | 04 | 3 | NTF-02 | — | ReconcileScheduleNotificationsUseCase removes then adds per weekday | unit | `test_sim -only-testing:DeluluDetoxTests/ReconcileScheduleNotificationsUseCaseTests` | ❌ W0 | ⬜ pending |
| 6-04-02 | 04 | 3 | NTF-02 | — | Cross-midnight schedule: notification only for evening segment | unit | `test_sim -only-testing:DeluluDetoxTests/ReconcileScheduleNotificationsUseCaseTests/testCrossMidnightOneNotificationOnly` | ❌ W0 | ⬜ pending |
| 6-05-01 | 05 | 4 | GAM-01, GAM-02 | — | StatsViewModel exposes current/longest/total from ObserveStatsUseCase | unit | `test_sim -only-testing:DeluluDetoxTests/StatsViewModelTests` | ❌ W0 | ⬜ pending |
| 6-05-02 | 05 | 4 | GAM-02 | — | HomeStatsCardViewModel broken-streak branch when current==0 && longest>=3 | unit | `test_sim -only-testing:DeluluDetoxTests/HomeStatsCardViewModelTests/testBrokenStreakCopy` | ❌ W0 | ⬜ pending |
| 6-05-03 | 05 | 4 | GAM-01, GAM-02 | — | Home card tap pushes Destination.stats | unit | `test_sim -only-testing:DeluluDetoxTests/HomeViewModelTests/testTapStatsCardPushesDestination` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Exact task IDs finalize during plan authoring; rows above mirror the recommended wave structure from RESEARCH.md.

---

## Wave 0 Requirements

- [ ] `DeluluDetoxTests/Phase6/ComputeStatsUseCaseTests.swift` — stubs for GAM-01/GAM-02
- [ ] `DeluluDetoxTests/Phase6/LocalNotificationRepositoryTests.swift` — fake UNUserNotificationCenter harness
- [ ] `DeluluDetoxTests/Phase6/AppNotificationDelegateTests.swift` — identifier-prefix dispatch
- [ ] `DeluluDetoxTests/Phase6/SchedulePermissionPromptUseCaseTests.swift` — lazy prompt on first .completed
- [ ] `DeluluDetoxTests/Phase6/StartSessionUseCaseTests+NTF01.swift` — Phase 3 hook test extension
- [ ] `DeluluDetoxTests/Phase6/EndSessionUseCaseTests+NTF01.swift` — Phase 3 cancel hook
- [ ] `DeluluDetoxTests/Phase6/ReconcileScheduleNotificationsUseCaseTests.swift` — NTF-02 scheduling
- [ ] `DeluluDetoxTests/Phase6/StatsViewModelTests.swift` — observable state surface
- [ ] `DeluluDetoxTests/Phase6/HomeStatsCardViewModelTests.swift` — broken-streak branch
- [ ] `DeluluDetoxTests/Phase6/HomeViewModelTests+StatsDestination.swift` — nav case
- [ ] `DeluluDetoxTests/Phase6/Fixtures/SessionRecordFixtures.swift` — shared fixture builders for streak scenarios (all-completed, gap, DST-day, trailing-edge, empty)
- [ ] `DeluluDetoxTests/Phase6/Fakes/FakeUNUserNotificationCenter.swift` — in-memory pending/delivered stores

XCTest framework already installed via DeluluDetoxTests target.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Lock-screen banner copy + sound on session end (killed app) | NTF-01 | Real iOS kills app; simulator notification behavior diverges from device | 1) Device build, 2) Start 2-min session, 3) Force-kill app, 4) Wait for end, 5) Confirm banner displays with session-end copy |
| Lock-screen banner on scheduled block start | NTF-02 | iOS delivers UNCalendarNotificationTrigger(repeats:true) in background/killed — needs real clock + killed state | 1) Device build, 2) Configure schedule starting in 3 min, 3) Kill app, 4) Confirm banner fires at interval start |
| Monthly calendar swipe + dot rendering | GAM-01, GAM-02 | Gesture + layout judgment (Monday-first, violet dot, today border) | 1) Build, 2) Complete 3+ sessions over 2 months, 3) Open Stats, 4) Swipe back/forward, 5) Verify dots on correct days, today border visible |
| Home card broken-streak copy register | GAM-02 | Brand voice calibration — verify shame copy does not cross into abusive register | 1) Seed 12-day streak then skip 2 days, 2) Open Home, 3) Review exact string + grey flame visual |
| iOS 26.x notification delivery reliability (Assumption A1) | NTF-01, NTF-02 | Community reports of 26.2-26.4 delivery regressions; requires real-device beta | TestFlight beta users log actual vs scheduled fire times for 48h; compare against logged `nextTriggerDate` from repository |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter after planner finalizes task IDs

**Approval:** pending
