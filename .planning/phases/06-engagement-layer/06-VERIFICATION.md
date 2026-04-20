---
phase: 06-engagement-layer
verified: 2026-04-21T00:00:00Z
status: human_needed
score: 13/13 must-haves verified (programmatic)
overrides_applied: 0
human_verification:
  - test: "GAM-01 total count visible on screen"
    expected: "After completing a blocking session, both the Home dashboard card ('UKOŃCZONYCH' quick stat) and the Stats screen footer ('Łącznie ukończonych sesji: N.') show the correct incremented integer from sessions.json history."
    why_human: "Visual/UI rendering — requires running the app, finishing a session, and visually confirming the displayed number matches the underlying SessionRepository data."
  - test: "GAM-02 current streak and longest streak visible"
    expected: "Stats screen top row shows AKTUALNY (current streak) and REKORD (longest streak) cards with correct integers; Home dashboard violet hero card shows current streak; 7-day mini row shows checkmarks for days with at least one completed session, with violet border around today's column."
    why_human: "Requires seeded multi-day history + on-device visual inspection of the flame hero and weekday flag row."
  - test: "GAM-02 broken-streak branch renders correctly"
    expected: "When currentStreak == 0 && longestStreak >= 3, the Home hero card switches from the violet-flame regular card to the gray-flame SERIA ZERWANA card displaying a shame caption (e.g., 'Straciłeś 12-dniową serię. Imponujące.'). Tap still navigates to the Stats screen."
    why_human: "Branch rendering depends on Stats state transition that is visible only at runtime; caption text rotation is deterministic but must look correct."
  - test: "NTF-01 session-end notification fires at scheduled time"
    expected: "Start a 1-minute session with notification permission granted. When the timer naturally expires, iOS delivers a banner with the Polish caption body (e.g., 'Przetrwałeś 1 min bez scrollowania. Świat się nie zawalił.'). In foreground: NO banner (silent); in background/lockscreen: banner + sound."
    why_human: "Requires iOS to actually fire UNCalendarNotificationTrigger; cannot be unit-tested end-to-end. Also validates D-16 foreground silent policy."
  - test: "NTF-01 cancels on early-end and revoke"
    expected: "(a) Start a session, open the shield pre-emptively and tap Cancel before the timer expires → no notification delivers later. (b) Start a session, revoke Screen Time permission (settings toggle) to simulate broken outcome → no notification delivers later."
    why_human: "Requires observing absence of a notification over a wall-clock window after a real cancel/revoke."
  - test: "NTF-02 weekday schedule reminder fires at scheduled time"
    expected: "Create an enabled schedule with daysOfWeek including today and startHour 1-2 minutes in the future (wall clock). At the trigger time, iOS delivers a banner with the Polish scheduleStart caption. Foreground: banner+sound; background: banner+sound."
    why_human: "UNCalendarNotificationTrigger with repeats:true requires real-time iOS delivery; cannot be unit-tested."
  - test: "NTF-02 reconcile on save/toggle/foreground"
    expected: "(a) Save a Mon-Fri 09:00 schedule → 5 `schedule.start.{uuid}.{2..6}` pending requests visible in simulator logs. (b) Toggle schedule OFF → all 5 removed. (c) Kill & cold-relaunch app with enabled schedule → foreground reconcile re-populates pending set idempotently."
    why_human: "Requires inspecting UNUserNotificationCenter pending requests or observing banner firing vs. not firing at the trigger time."
  - test: "D-13 lazy permission prompt on first completed session"
    expected: "Fresh install (no prior .authorized/.denied state). Complete the first blocking session. Permission prompt appears BEFORE the success screen. Subsequent completed sessions do NOT re-prompt."
    why_human: "iOS closes the .notDetermined window after first response; must be tested on a fresh install/simulator."
  - test: "SHL-03 shield deep-link preserved through AppNotificationDelegate"
    expected: "Trigger a shield notification from ShieldActionExtension (block a tokenized app; tap Open DeluluDetox on the shield). Banner appears with title 'DeluluDetox'; tapping the banner opens the app and routes through ingestShieldDeepLink URL — NOT affected by NTF-01/NTF-02 routing."
    why_human: "Requires ShieldActionExtension + real-device/simulator family-controls permission state to fire the shield notification pathway."
---

# Phase 6: Engagement Layer Verification Report

**Phase Goal:** User gets feedback on their blocking habits and timely notifications about session events
**Verified:** 2026-04-21
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

Roadmap Success Criteria (contractual):

| #   | Truth                                                                                          | Status                | Evidence                                                                                                                                    |
| --- | ---------------------------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | User can see a total count of completed blocking sessions (GAM-01)                             | ✓ VERIFIED (needs UAT) | `StatsView.swift:61` renders `model.stats.totalCount`; `HomeDashboardView.swift:61` renders `statsCard.stats.totalCount`; upstream pipeline ObserveSessionHistory → ComputeStats → Stats verified in unit tests (22 tests). |
| 2   | User can see their current streak (consecutive days with at least one completed session, GAM-02) | ✓ VERIFIED (needs UAT) | `StatsView.swift:43` renders `model.stats.currentStreak`; `HomeDashboardView.swift:100` renders streak in violet hero card; D-03 trailing-edge tested in `ComputeStatsUseCaseTests`. |
| 3   | User receives a local notification when a blocking session ends (NTF-01)                       | ✓ VERIFIED (needs UAT) | `ScheduleSessionEndNotificationUseCase.swift:67` builds UNCalendarNotificationTrigger(dateMatching:plannedEndAt, repeats:false); wired in `StartSessionUseCase.swift:85` after monitoring success; cancel wired in `EndSessionUseCase.swift:50` before finalize. |
| 4   | User receives a local notification when a scheduled block starts (NTF-02)                      | ✓ VERIFIED (needs UAT) | `ReconcileScheduleNotificationsUseCase.swift:84` builds per-weekday UNCalendarNotificationTrigger(repeats:true); wired in `SyncScheduleWithSystemUseCase.swift:60,70` on both enable + disable paths and in `AppRootViewModel.swift:174` on foreground. |

Plan-level truths (aggregated from plans 01-05 frontmatter — all passing programmatically):

| Truth | Status | Evidence |
|-------|--------|----------|
| Stats pure compute: totalCount counts only .completed outcomes; trailing-edge streak; DST-safe Calendar arithmetic | ✓ VERIFIED | `ComputeStatsUseCase.swift:21,27,34,44,54`; 22 tests in ComputeStatsUseCaseTests (ROADMAP SC covered) |
| AppNotificationDelegate dispatches by identifier prefix (shield→banner, session.end→silent, schedule.start→banner+sound) | ✓ VERIFIED | `AppNotificationDelegate.swift:38-43` (presentationOptions seam) + 9 AppNotificationDelegateTests |
| DeluluDetoxApp.init() no longer calls requestAuthorization at launch (D-13 lazy prompt) | ✓ VERIFIED | `DeluluDetoxApp.swift` grep: requestAuthorization = 0; `SchedulePermissionPromptUseCase.swift:36` performs prompt gated on .notDetermined |
| ScheduleSessionEndNotification skips add when auth != .authorized (D-15) | ✓ VERIFIED | `ScheduleSessionEndNotificationUseCase.swift:28-32` + tests |
| Cancel on session end for outcome != .completed; iOS fires naturally on .completed | ✓ VERIFIED | `EndSessionUseCase.swift:48-51` `if outcome != .completed`; EndSessionUseCaseTests cover .cancelledByUser / .brokenByRevoke / .completed branches |
| D-13 prompt fires from FinalizeSessionFromMarkerUseCase AFTER endSession(.completed) returns | ✓ VERIFIED | `FinalizeSessionFromMarkerUseCase.swift:57` `await schedulePermissionPrompt()` after line 55 `try await endSession(outcome: .completed, …)` |
| Reconcile creates one UNNotificationRequest per weekday with identifier `schedule.start.{id}.{weekday}` and explicit calendar+timezone | ✓ VERIFIED | `ReconcileScheduleNotificationsUseCase.swift:66,77-82` + 10 ReconcileScheduleNotificationsUseCaseTests |
| Cross-midnight produces evening-only notifications (D-18) | ✓ VERIFIED | UC notifies only at `schedule.startHour`; `testCrossMidnight_schedulesOnlyEveningSegment` asserts hour=22 with no hour=6 |
| Reconcile full-replace: removes ALL pending `schedule.start.{id}.*` before adding | ✓ VERIFIED | `ReconcileScheduleNotificationsUseCase.swift:38` removePendingNotificationRequests(withIdentifierPrefix:); tested by `testRemovesStaleFirst_beforeAdd` |
| Foreground reconcile for every schedule (AppRootViewModel hook) | ✓ VERIFIED | `AppRootViewModel.swift:172-175` iterates `firstSchedulesSnapshot` → `reconcileScheduleNotifications(schedule:)`; covered by `testForegroundHook_reconcilesAllSchedules` |
| HomeStatsCardViewModel.brokenStreakCopy non-nil iff currentStreak==0 && longestStreak>=3 (D-10) | ✓ VERIFIED | `HomeStatsCardViewModel.swift:20-23`; uses `GetBrokenStreakCopyUseCase` (VM → UC rule honored) |
| Home card tap → `.stats(StatsViewModel)` destination | ✓ VERIFIED | `HomeViewModel.swift:169-171` statsCardTapped sets destination; `HomeView.swift:39-41` .navigationDestination(item: $model.destination.stats) |
| StatsView + HomeDashboardView are VM-driven (no hardcoded mocks for stats data) | ✓ VERIFIED | `StatsView.swift` binds to `model.stats.currentStreak/longestStreak/totalCount/completedDaysSet`; `HomeDashboardView.swift` binds to `statsCard.stats.*`. Greeting + nextBlock card kept mock (explicitly out of Phase 6 scope) |

**Score:** 13/13 programmatic truths verified; 4 ROADMAP Success Criteria each require human UAT for final sign-off because all require real iOS notification delivery or visual rendering validation.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `DeluluDetox/Sources/Features/Stats/Repository/Models/Stats.swift` | Stats value type | ✓ VERIFIED | Exists; 6 fields + `Stats.empty` |
| `DeluluDetox/Sources/Features/Stats/UseCase/ComputeStatsUseCase.swift` | Pure compute | ✓ VERIFIED | protocol + Impl; Calendar-injected; DST-safe (byAdding:.day only) |
| `DeluluDetox/Sources/Features/Stats/UseCase/ObserveStatsUseCase.swift` | Reactive Stats projection | ✓ VERIFIED | Combine pipeline history → compute → Stats |
| `DeluluDetox/Sources/Features/Stats/ViewModel/StatsViewModel.swift` | @Observable full-screen VM | ✓ VERIFIED | Monday-first calendar + isMarked + prev/next month |
| `DeluluDetox/Sources/Features/Stats/ViewModel/HomeStatsCardViewModel.swift` | @Observable card VM | ✓ VERIFIED | stats + brokenStreakCopy computed branch |
| `DeluluDetox/Sources/Features/Stats/Injection/StatsInjection.swift` | DI for Stats UCs | ✓ VERIFIED | Registers ComputeStatsUseCase + ObserveStatsUseCase |
| `DeluluDetox/Sources/Features/Stats/View/StatsView.swift` | VM-driven Stats screen | ✓ VERIFIED | Bindable model; no hardcoded stats constants remain |
| `DeluluDetox/Sources/Features/Notifications/Repository/LocalNotificationRepository.swift` | UN facade | ✓ VERIFIED | protocol + LiveLocalNotificationRepository |
| `DeluluDetox/Sources/Features/Notifications/Repository/NotificationCaptionLibrary.swift` | 3-variant caption rotation | ✓ VERIFIED | 3 arrays × 3 captions; deterministic rotation |
| `DeluluDetox/Sources/Features/Notifications/Notification/AppNotificationDelegate.swift` | Prefix-dispatch composite | ✓ VERIFIED | presentationOptions seam + dispatchResponse seam + SHL-03 preserved |
| `DeluluDetox/Sources/Features/Notifications/Injection/NotificationsInjection.swift` | DI for all notification UCs | ✓ VERIFIED | Registers 7 UCs (repo + captions + NTF-01 pair + permission prompt + NTF-02 reconcile + broken-streak copy) |
| `DeluluDetox/Sources/Features/Notifications/UseCase/ScheduleSessionEndNotificationUseCase.swift` | NTF-01 schedule | ✓ VERIFIED | Auth-gated; UNCalendarNotificationTrigger dateMatching plannedEndAt |
| `DeluluDetox/Sources/Features/Notifications/UseCase/CancelSessionEndNotificationUseCase.swift` | NTF-01 cancel | ✓ VERIFIED | removePendingNotificationRequests by identifier |
| `DeluluDetox/Sources/Features/Notifications/UseCase/SchedulePermissionPromptUseCase.swift` | D-13 lazy prompt | ✓ VERIFIED | .notDetermined gate; [.alert, .sound] only |
| `DeluluDetox/Sources/Features/Notifications/UseCase/ReconcileScheduleNotificationsUseCase.swift` | NTF-02 reconcile | ✓ VERIFIED | Full-replace + cross-midnight evening-only + explicit calendar/TZ |
| `DeluluDetox/Sources/Features/Notifications/UseCase/GetBrokenStreakCopyUseCase.swift` | Shame copy wrapper for VM→UC rule | ✓ VERIFIED | Wraps NotificationCaptionLibrary.brokenStreakCopy |
| `DeluluDetox/Sources/App/DeluluDetoxApp.swift` | Composite delegate + NotificationsInjection first + no launch requestAuthorization | ✓ VERIFIED | AppNotificationDelegate wired (line 42); NotificationsInjection.register first (line 13); grep `requestAuthorization` returns 0; StatsInjection.register on line 25 (after SessionInjection) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| AppNotificationDelegate | ShieldNotificationConstants.identifierPrefix | hasPrefix dispatch | ✓ WIRED | `AppNotificationDelegate.swift:39,50` — both seams route shield prefix identically |
| AppNotificationDelegate | `session.end.` | willPresent → `[]` | ✓ WIRED | line 40; returns `[]` (D-16 silent in foreground) |
| AppNotificationDelegate | `schedule.start.` | willPresent → `[.banner, .sound]` | ✓ WIRED | line 41 |
| DeluluDetoxApp.init() | AppNotificationDelegate | stored property + center delegate assignment | ✓ WIRED | lines 7, 42, 45 |
| StartSessionUseCase | ScheduleSessionEndNotificationUseCase | await call after monitoring success | ✓ WIRED | `StartSessionUseCase.swift:85` |
| EndSessionUseCase | CancelSessionEndNotificationUseCase | await when outcome != .completed | ✓ WIRED | `EndSessionUseCase.swift:50` |
| FinalizeSessionFromMarkerUseCase | SchedulePermissionPromptUseCase | await after successful endSession(.completed) | ✓ WIRED | `FinalizeSessionFromMarkerUseCase.swift:57` — lexically AFTER line 55 endSession(.completed); verified awk check documented in Plan 03 Summary |
| SyncScheduleWithSystemUseCase (enabled path) | ReconcileScheduleNotificationsUseCase | await after startMonitoring success | ✓ WIRED | `SyncScheduleWithSystemUseCase.swift:70` |
| SyncScheduleWithSystemUseCase (disabled path) | ReconcileScheduleNotificationsUseCase | await on early-return | ✓ WIRED | `SyncScheduleWithSystemUseCase.swift:60` |
| AppRootViewModel.refreshStatus | ReconcileScheduleNotificationsUseCase | per-schedule loop after Phase 5 UCs | ✓ WIRED | `AppRootViewModel.swift:172-175` |
| HomeViewModel | `.stats(StatsViewModel)` | destination setter on statsCardTapped | ✓ WIRED | `HomeViewModel.swift:170` |
| HomeView | StatsView(model:) | `.navigationDestination(item: $model.destination.stats)` | ✓ WIRED | `HomeView.swift:39-41` |
| HomeDashboardView | HomeStatsCardViewModel | @Bindable + onStatsCardTap callback | ✓ WIRED | `HomeDashboardView.swift:14,52,57`; `HomeView.swift:81,83` |
| HomeStatsCardViewModel.brokenStreakCopy | GetBrokenStreakCopyUseCase | @LazyInjected UC | ✓ WIRED | `HomeStatsCardViewModel.swift:22,26` |
| StatsInjection.register | DeluluDetoxApp.init() | called after SessionInjection | ✓ WIRED | `DeluluDetoxApp.swift:25` (after `SessionInjection.register` on line 21) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| StatsView | `model.stats` | StatsViewModel.stats ← ObserveStatsUseCase().sink | Yes — pipeline consumes Phase 3 ObserveSessionHistoryUseCase (real sessions.json) through ComputeStatsUseCase | ✓ FLOWING |
| HomeDashboardView | `statsCard.stats` | HomeStatsCardViewModel.stats ← ObserveStatsUseCase().sink | Same pipeline as StatsView | ✓ FLOWING |
| HomeDashboardView brokenStreakCopy | Computed from stats.currentStreak + stats.longestStreak; calls GetBrokenStreakCopyUseCase → NotificationCaptionLibrary | Real library entries (NotificationCaptionLibrary.brokenStreakCaptions has 3 non-empty strings) | ✓ FLOWING |
| NTF-01 notification | content.body | NotificationCaptionLibrary.sessionEndCopy(for:durationMinutes:) | Real 3-template library with interpolation | ✓ FLOWING |
| NTF-02 notification | content.body | NotificationCaptionLibrary.scheduleStartCopy(for:) | Real 3-template library | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Xcode test suite green | `xcrun xcodebuild test -scheme DeluluDetox …` | Plan 05 summary reports 309/309 passing, 3 skipped, 0 failures | ? SKIP (not re-run during verification; last run per Plan 05 SUMMARY: 2026-04-21, all green) |

Behavioral notification delivery cannot be spot-checked without running iOS against a wall clock — deferred to human verification.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| GAM-01 | 06-01 (compute), 06-05 (presentation) | User sees total count of completed sessions | ✓ SATISFIED (programmatic) + ? NEEDS HUMAN (UX render) | `Stats.totalCount` counts only .completed; rendered at `StatsView.swift:61` + `HomeDashboardView.swift:61` |
| GAM-02 | 06-01 (compute), 06-05 (presentation) | User sees current streak (D-03 trailing edge) + longest streak + D-10 broken-streak branch | ✓ SATISFIED (programmatic) + ? NEEDS HUMAN (UX render) | `Stats.currentStreak/longestStreak` computed correctly; rendered at `StatsView.swift:43,51` + `HomeDashboardView.swift:100,62` + broken-streak branch at `HomeDashboardView.swift:48` |
| NTF-01 | 06-02 (infra), 06-03 (UCs + hooks) | User receives notification when session ends | ✓ SATISFIED (programmatic) + ? NEEDS HUMAN (delivery) | schedule/cancel/prompt UCs wired through StartSession/EndSession/FinalizeSessionFromMarker |
| NTF-02 | 06-02 (infra), 06-04 (UCs + hooks) | User receives notification when scheduled block starts | ✓ SATISFIED (programmatic) + ? NEEDS HUMAN (delivery) | reconcile UC wired through SyncScheduleWithSystemUseCase + AppRootViewModel foreground |

All four requirement IDs declared in plan frontmatters (GAM-01, GAM-02, NTF-01, NTF-02) are accounted for. No orphaned REQUIREMENTS.md IDs — REQUIREMENTS.md maps exactly these four to Phase 6.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `HomeView.swift` | 78 | `StatsView(model: StatsViewModel())` inside tab switch reconstructs VM on every SwiftUI body re-eval (tab 3) | ⚠️ Warning | Combine subscription rebuilt on each render; displayed-month state resets on tab-switch. Identified in code review as WR-01; not goal-blocking but inconsistent with sibling tabs that use @State. |
| `HomeDashboardView.swift` | 22-29 | `greetingName`, `greetingSubtitle`, `nextBlockTitle`, `nextBlockSubtitle`, `nextBlockEnabled` still hardcoded | ℹ️ Info | Explicitly out-of-scope for Phase 6 per plan (non-stats bindings); not a goal-blocking stub. |
| `AppNotificationDelegate.swift` | 103-106 | `_SendableUserInfo` @unchecked Sendable box hides arbitrary non-Sendable userInfo types | ⚠️ Warning | No current regression (all writers use [String: String]) but future userInfo additions could silently smuggle non-Sendable values. Identified as WR-02 in code review; not goal-blocking. |
| `HomeViewModel.swift` | 34 | `.stats` case uses identity `===` equality → two taps produce unequal destinations | ℹ️ Info | Pre-existing pattern for VM-payload cases; documented as intentional in review (WR-03). |

No TODO/FIXME/placeholder comments, no empty implementations, no always-empty stub returns. All UCs have real implementations with real I/O calls (`repository.add(_:)`, `removePendingNotificationRequests(…)`, `requestAuthorization(options:)`, etc.).

### Human Verification Required

Nine items require physical-device or simulator UAT with real iOS UNUserNotificationCenter delivery and visual inspection (see frontmatter `human_verification` block for full detail). Grouped by area:

**GAM-01 / GAM-02 UX rendering (3 items):**
1. Total count + current/longest streak visible with correct integers after real sessions.
2. 7-day mini row + monthly calendar grid render correctly (violet dots on completed days, violet border on today, Monday-first layout).
3. Broken-streak branch switches to gray-flame SERIA ZERWANA card when currentStreak=0 ∧ longestStreak≥3.

**NTF-01 delivery (2 items):**
4. Banner actually fires at plannedEndAt for a completed session; silent in foreground vs. banner+sound in background/lockscreen.
5. Pre-empted cancellation (early-end, broken by revoke) suppresses delivery.

**NTF-02 delivery (2 items):**
6. Banner fires at startHour on included weekdays for an enabled schedule.
7. Reconcile behavior: save → pending created; disable → pending cleared; cold-relaunch → foreground reconcile re-populates idempotently.

**D-13 + SHL-03 (2 items):**
8. Lazy permission prompt appears on first-ever completed session post-install, BEFORE success screen.
9. Shield deep-link notification tap still opens the app and routes through `ingestShieldDeepLink` after the Phase 6 delegate swap.

### Gaps Summary

No programmatic gaps. Every must-have from every plan's frontmatter plus the four Roadmap Success Criteria have corresponding, substantive, wired, and data-flowing implementations in the codebase. Code review (`06-REVIEW.md`) identified 3 warnings + 6 info findings, none of which block goal achievement:

- WR-01 (Stats VM lifecycle on tab switch) — quality concern, month-state reset, not a feature regression.
- WR-02 (Sendable box breadth) — latent; no current regression.
- WR-03 (Destination identity equality) — documented design decision.
- IN-01..IN-06 — informational polish items.

Status is **human_needed** (not `passed`) because all four ROADMAP Success Criteria ultimately manifest as user-visible behavior — visual stats rendering and wall-clock iOS notification delivery — that cannot be confirmed by static or unit-test verification. The programmatic evidence is strong (309/309 passing unit tests across the phase per Plan 05 SUMMARY, all must-haves wired, data flows traced end-to-end), but goal achievement requires user-side validation of the 9 items enumerated above.

---

_Verified: 2026-04-21_
_Verifier: Claude (gsd-verifier)_
