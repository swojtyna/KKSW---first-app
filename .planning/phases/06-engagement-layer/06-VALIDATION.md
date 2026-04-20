---
phase: 6
slug: engagement-layer
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-20
updated: 2026-04-20
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (DeluluDetoxTests target) |
| **Config file** | `project.yml` — DeluluDetoxTests target |
| **Quick run command** | `xcodebuild test -project DeluluDetox.xcodeproj -scheme DeluluDetox -destination 'platform=iOS Simulator,id=C958163F-49E1-4B46-8A6D-C2056CD25A37' -only-testing:DeluluDetoxTests/<TestClass>` |
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

Paths below match the real test locations created by each Plan task. Plans create their own test stubs via TDD within the same task — this is an acceptable Wave 0 pattern because every task lands its tests and implementation together in a RED→GREEN commit cycle.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 6-01-01 | 01 | 1 | GAM-01, GAM-02 | — | Pure streak compute; no side effects | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests` → `DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift` | ⬜ pending |
| 6-01-02 | 01 | 1 | GAM-02 | — | DST/timezone day boundary handled via Calendar.date(byAdding:) | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testStreak_acrossDSTBoundary_springForward_contiguous` → `DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift` | ⬜ pending |
| 6-01-03 | 01 | 1 | GAM-02 | — | D-03 trailing-edge rule: today empty + yesterday .completed → streak alive | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testCurrentStreak_todayEmptyYesterdayCompleted_returnsYesterdayStreak` → `DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift` | ⬜ pending |
| 6-01-04 | 01 | 1 | GAM-01 | — | Total count = only `.completed` outcomes | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testTotalCount_countsOnlyCompletedOutcomes` → `DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift` | ⬜ pending |
| 6-02-01 | 02 | 2 | NTF-01, NTF-02 | — | LocalNotificationRepository schedule/cancel via narrow `authorizationStatus()` seam | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/LocalNotificationRepositoryTests` → `DeluluDetoxTests/Features/Notifications/LocalNotificationRepositoryTests.swift` | ⬜ pending |
| 6-02-02 | 02 | 2 | NTF-01, NTF-02 | T-06-02-01..05 | AppNotificationDelegate dispatches by identifier prefix; Phase 4 SHL-03 preserved | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/AppNotificationDelegateTests` → `DeluluDetoxTests/Features/Notifications/AppNotificationDelegateTests.swift` | ⬜ pending |
| 6-02-03 | 02 | 2 | NTF-01, NTF-02 | — | Skip add when authorizationStatus != .authorized | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/LocalNotificationRepositoryTests/testAuthorizationStatus_returnsStubValue` → `DeluluDetoxTests/Features/Notifications/LocalNotificationRepositoryTests.swift` | ⬜ pending |
| 6-03-01 | 03 | 3 | NTF-01 | T-06-03-02 | StartSessionUseCase schedules `session.end.{uuid}` on start (after monitoring success only) | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/StartSessionUseCaseTests/testSchedulesNotification_afterMonitoringSuccess` → `DeluluDetoxTests/Features/Session/StartSessionUseCaseTests.swift` | ⬜ pending |
| 6-03-02 | 03 | 3 | NTF-01 | T-06-03-03 | EndSessionUseCase cancels pending `session.end.{uuid}` on non-.completed outcome | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/EndSessionUseCaseTests/testCancelsNotification_onCancelledByUserOutcome` → `DeluluDetoxTests/Features/Session/EndSessionUseCaseTests.swift` | ⬜ pending |
| 6-03-03 | 03 | 3 | NTF-01 | T-06-03-04 | Lazy permission prompt fires on first .completed only — FROM FinalizeSessionFromMarkerUseCase (D-13 locked decision: prompt inside session-finalization flow, before success screen) | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/SchedulePermissionPromptUseCaseTests` → `DeluluDetoxTests/Features/Notifications/SchedulePermissionPromptUseCaseTests.swift` | ⬜ pending |
| 6-03-04 | 03 | 3 | NTF-01 | T-06-03-04 | D-13 integration: FinalizeSessionFromMarkerUseCase triggers prompt AFTER successful `.completed` finalize, BEFORE returning | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/FinalizeSessionFromMarkerUseCaseTests/testSchedulesPermissionPrompt_afterCompletedFinalize` → `DeluluDetoxTests/Features/Session/FinalizeSessionFromMarkerUseCaseTests.swift` | ⬜ pending |
| 6-04-01 | 04 | 3 | NTF-02 | T-06-04-04 | ReconcileScheduleNotificationsUseCase removes then adds per weekday | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/ReconcileScheduleNotificationsUseCaseTests/testEnabledMonToFri_createsFiveWeekdayRequests` → `DeluluDetoxTests/Features/Notifications/ReconcileScheduleNotificationsUseCaseTests.swift` | ⬜ pending |
| 6-04-02 | 04 | 3 | NTF-02 | T-06-04-01 | Cross-midnight schedule: notification only for evening segment | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/ReconcileScheduleNotificationsUseCaseTests/testCrossMidnight_schedulesOnlyEveningSegment` → `DeluluDetoxTests/Features/Notifications/ReconcileScheduleNotificationsUseCaseTests.swift` | ⬜ pending |
| 6-04-03 | 04 | 3 | NTF-02 | — | SyncScheduleWithSystemUseCase reconciles on enable AND disable paths; skips on throw | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/SyncScheduleWithSystemUseCaseTests/testReconcilesNotifications_afterStartMonitoringSuccess` → `DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift` | ⬜ pending |
| 6-05-1a-01 | 05 | 4 | GAM-01, GAM-02 | — | ObserveStatsUseCase emits Stats on every history change, with injected clock | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/ObserveStatsUseCaseTests` → `DeluluDetoxTests/Features/Stats/ObserveStatsUseCaseTests.swift` | ⬜ pending |
| 6-05-1a-02 | 05 | 4 | GAM-02 | — | GetBrokenStreakCopyUseCase wraps NotificationCaptionLibrary (VM→UC rule) | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/GetBrokenStreakCopyUseCaseTests` → `DeluluDetoxTests/Features/Notifications/GetBrokenStreakCopyUseCaseTests.swift` | ⬜ pending |
| 6-05-1b-01 | 05 | 4 | GAM-01, GAM-02 | — | StatsViewModel exposes current/longest/total from ObserveStatsUseCase | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/StatsViewModelTests` → `DeluluDetoxTests/Features/Stats/StatsViewModelTests.swift` | ⬜ pending |
| 6-05-1b-02 | 05 | 4 | GAM-02 | — | HomeStatsCardViewModel broken-streak branch when current==0 && longest>=3 | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/HomeStatsCardViewModelTests/testBrokenStreakCopy_nonNil_whenCurrentZeroAndLongestAtLeastThree` → `DeluluDetoxTests/Features/Stats/HomeStatsCardViewModelTests.swift` | ⬜ pending |
| 6-05-3-01 | 05 | 4 | GAM-01, GAM-02 | — | Home card tap pushes Destination.stats | unit | `xcodebuild test … -only-testing:DeluluDetoxTests/HomeViewModelTests/testStatsCardTapped_setsStatsDestination` → `DeluluDetoxTests/Features/Home/HomeViewModelTests.swift` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Task IDs for Plan 05 reflect the 3-task split (1a UC layer / 1b VM layer / 3 View rewrite).

---

## Wave 0 Status

Each Plan task creates its own test stubs via TDD in the same RED→GREEN commit. No separate Wave 0 test scaffolding is required — the plans ARE Wave 0 for their respective surfaces. All test files below land as part of the tasks that own them:

- Plan 01 Task 1 → `DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift` + `DeluluDetoxTests/Features/Stats/Fixtures/SessionRecordFixtures.swift`
- Plan 02 Task 1 → `DeluluDetoxTests/Features/Notifications/LocalNotificationRepositoryTests.swift` + `DeluluDetoxTests/Features/Notifications/Mocks/MockLocalNotificationRepository.swift`
- Plan 02 Task 2 → `DeluluDetoxTests/Features/Notifications/AppNotificationDelegateTests.swift`
- Plan 03 Task 1 → `DeluluDetoxTests/Features/Notifications/ScheduleSessionEndNotificationUseCaseTests.swift` + `DeluluDetoxTests/Features/Notifications/CancelSessionEndNotificationUseCaseTests.swift` + `DeluluDetoxTests/Features/Notifications/SchedulePermissionPromptUseCaseTests.swift` (plus 3 mocks under `DeluluDetoxTests/Features/Notifications/Mocks/`)
- Plan 03 Task 2 → `DeluluDetoxTests/Features/Session/StartSessionUseCaseTests.swift` + `DeluluDetoxTests/Features/Session/EndSessionUseCaseTests.swift` + `DeluluDetoxTests/Features/Session/FinalizeSessionFromMarkerUseCaseTests.swift` (D-13 coverage)
- Plan 04 Task 1 → `DeluluDetoxTests/Features/Notifications/ReconcileScheduleNotificationsUseCaseTests.swift` + `DeluluDetoxTests/Features/Notifications/Mocks/MockReconcileScheduleNotificationsUseCase.swift`
- Plan 04 Task 2 → `DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift` (extend)
- Plan 05 Task 1a → `DeluluDetoxTests/Features/Stats/ObserveStatsUseCaseTests.swift` + `DeluluDetoxTests/Features/Notifications/GetBrokenStreakCopyUseCaseTests.swift` (plus 3 mocks across Stats + Notifications Mocks directories)
- Plan 05 Task 1b → `DeluluDetoxTests/Features/Stats/StatsViewModelTests.swift` + `DeluluDetoxTests/Features/Stats/HomeStatsCardViewModelTests.swift`
- Plan 05 Task 3 → `DeluluDetoxTests/Features/Home/HomeViewModelTests.swift` (extend)

XCTest framework already installed via DeluluDetoxTests target.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Lock-screen banner copy + sound on session end (killed app) | NTF-01 | Real iOS kills app; simulator notification behavior diverges from device | 1) Device build, 2) Start 2-min session, 3) Force-kill app, 4) Wait for end, 5) Confirm banner displays with session-end copy |
| Lock-screen banner on scheduled block start | NTF-02 | iOS delivers UNCalendarNotificationTrigger(repeats:true) in background/killed — needs real clock + killed state | 1) Device build, 2) Configure schedule starting in 3 min, 3) Kill app, 4) Confirm banner fires at interval start |
| Monthly calendar swipe + dot rendering | GAM-01, GAM-02 | Gesture + layout judgment (Monday-first, violet dot, today border) | 1) Build, 2) Complete 3+ sessions over 2 months, 3) Open Stats, 4) Swipe back/forward, 5) Verify dots on correct days, today border visible |
| Home card broken-streak copy register | GAM-02 | Brand voice calibration — verify shame copy does not cross into abusive register | 1) Seed 12-day streak then skip 2 days, 2) Open Home, 3) Review exact string + grey flame visual |
| D-13 permission prompt ordering | NTF-01 | Must fire BEFORE success screen appears — visually confirm sequence on first completed session after install | 1) Fresh install, 2) Complete a 1-min session, 3) Confirm iOS permission dialog shows FIRST, 4) Dismiss or grant, 5) Confirm success screen shows AFTER the dialog resolves |
| iOS 26.x notification delivery reliability (Assumption A1) | NTF-01, NTF-02 | Community reports of 26.2-26.4 delivery regressions; requires real-device beta | TestFlight beta users log actual vs scheduled fire times for 48h; compare against logged `nextTriggerDate` from repository |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (each plan task creates its tests inline)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covered by inline TDD in each task (paths above point at the real files each task creates)
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter
- [x] `wave_0_complete: true` set in frontmatter (acceptable Wave 0 pattern — each task creates its own test stubs within the same RED→GREEN cycle)
- [x] D-13 ordering (permission prompt inside session-finalization flow before success screen) covered by `FinalizeSessionFromMarkerUseCaseTests/testSchedulesPermissionPrompt_afterCompletedFinalize`

**Approval:** pending
</content>
