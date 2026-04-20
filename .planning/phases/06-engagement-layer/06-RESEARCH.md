# Phase 6: Engagement Layer - Research

**Researched:** 2026-04-20
**Domain:** `UserNotifications` + Foundation `Calendar` streak compute + SwiftUI monthly grid + Clean Architecture integration with Phase 3/5
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Streak Semantics (GAM-02)** — D-01..D-05
- D-01: `TimeZone.current` + `Calendar.current`, day = 00:00–23:59:59. Accepted corner case: TZ travel can stretch/shrink one day.
- D-02: "Completed day" = `SessionRecord.outcome == .completed` AND `Calendar.current.isDate(actualEndAt, inSameDayAs: day)`. `.cancelledByUser` / `.brokenByRevoke` do NOT count.
- D-03: Current streak = longest trailing run of days (from today backwards) with ≥1 `.completed`. If today has none but yesterday did → streak still alive (0–1 day gap tolerated on the "trailing" edge).
- D-04: Zero grace period / freeze in MVP.
- D-05: Longest streak = max run in full history.

**Stats Compute (GAM-01/02)** — D-06..D-08
- D-06: Compute on-demand on every foreground + every Stats screen open. Parse `sessions.json` → group by `Calendar.current` day.
- D-07: ZERO cache in MVP. No `stats.json`, no incremental counter. Single source of truth = `sessions.json`.
- D-08: Eager expiry — streak is NEVER persisted; compute sees gap > 1 day and returns 0. Deterministic.

**Stats Presentation (GAM-01/02)** — D-09..D-12
- D-09: Home screen card (top of Start screen) = 🔥 current streak + total count + mini 7-day dot row. Tap → push `Destination.stats`.
- D-10: Broken streak shame copy when `current == 0 && longest >= 3`: gray flame + "Straciłeś {longest}-dniową serię. Imponujące." (ostry tone consistent with Phase 4 D-03 shield).
- D-11: Stats screen = header "🔥 {current} | Rekord: {longest} | Σ {total}" + monthly calendar grid with violet dots on `.completed` days + month swipe navigation. NO per-session list, NO time-in-session charts.
- D-12: "Longest streak" shown on home card ONLY in broken context (D-10); on Stats screen always.

**Notification Permission Flow** — D-13..D-14
- D-13: **Lazy prompt** — after first `.completed` session, BEFORE success screen. Custom copy: "Chcesz dostać subtelny tap gdy sesja się kończy?"
- D-14: User changes decision in iOS Settings only — no in-app toggle in MVP.

**NTF-01 (Session End)** — D-15..D-17
- D-15: Pre-schedule in Phase 3 D-07 Start sequence: `UNNotificationRequest(identifier: "session.end.{uuid}", trigger: UNCalendarNotificationTrigger(dateMatching: components(from: plannedEndAt), repeats: false))`. Skip if `authorizationStatus != .authorized`.
- D-16: Cancel in Phase 3 D-08 End: `.completed` → do NOT cancel (iOS fires naturally); `.cancelledByUser` / `.brokenByRevoke` → `removePendingNotificationRequests(withIdentifiers:)`.
- D-17: Copy library (miękki sarkazm + celebracja), 3-5 warianty, rotacja po `hash(sessionId) % count`.

**NTF-02 (Schedule Start)** — D-18..D-20
- D-18: Pre-schedule per weekday × segment as `UNCalendarNotificationTrigger(dateMatching: DateComponents(weekday:hour:minute:), repeats: true)`, identifier `"schedule.start.{scheduleId}.{weekday}"`. Wired into Phase 5 D-14 `SyncScheduleWithSystemUseCase`. Cross-midnight: notify only for evening segment, NOT morning artifact. Reconcile = removePending all `schedule.start.{id}.*` before re-add.
- D-19: NTF-02 does NOT use `schedule_events.json` / Darwin notifications for delivery — iOS `UNCalendarNotificationTrigger(repeats: true)` fires reliably regardless of app state.
- D-20: Copy library (miękki sarkazm + info), rotation identical to D-17.

**Architecture** — D-21..D-22
- D-21: `StatsRepository` (read-only over `sessions.json`) + `ComputeStatsUseCase` (returns `Stats {currentStreak, longestStreak, totalCount, last7DaysFlags}`) + `SchedulePermissionPromptUseCase` + `ScheduleSessionEndNotificationUseCase` + `CancelSessionEndNotificationUseCase` (NTF-01) + `ReconcileScheduleNotificationsUseCase` (NTF-02). VMs: `StatsViewModel` + `HomeStatsCardViewModel`, both `@Observable` without SwiftUI.
- D-22: Navigation — `AppRootViewModel.Destination` gets `.stats` case. Home card tap → push.

### Claude's Discretion

- Exact copy strings (NTF-01 / NTF-02 / broken streak) — libraries of 3–5 variants, rotation hash vs round-robin.
- Visual design of home card (shadow, radius, padding, top-section placement on Start screen).
- Exact layout of monthly calendar (header style, dot size, today highlight).
- Last-7-day dot row orientation: today-right (reverse chrono) vs Monday-first.
- Monday-first (PL convention) vs Sunday-first for monthly calendar.
- `.willPresent` delegate behavior for foreground NTF-01: `[]` (silent) vs `[.banner]`.
- Permission prompt sequencing around success screen.
- Empty-state flame visual (opacity vs outlined).
- Stats screen empty state (0 sessions) — sarcastic copy.
- Month navigation bounds (past = first-session-month; future = allow empty? or block at current month).

### Deferred Ideas (OUT OF SCOPE)

Paid streak freeze (MON v2) · Per-session detail UI · DeviceActivityReport usage stats (STS-01/02) · Widget with streak · Live Activity countdown (LAC-01/02) · In-app daily reminder nudge · Per-notification granular toggles · A/B testing copy · Haptic feedback on streak increment · Share stats · `stats.json` cache · Cross-device iCloud sync · Streak-specific achievements / badges · Stats CSV/JSON export · Time-in-session aggregated charts.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GAM-01 | User sees total count of completed sessions | Pure compute over `sessions.json` — filter by `outcome == .completed`, count. Rendered on HomeDashboardView card (already has `completedCount` mock wired) + Stats screen header. See §Stats Compute + §Reusable Assets. |
| GAM-02 | User sees current streak (consecutive days with ≥1 completed session) | Pure compute over `[SessionRecord]` grouped by `Calendar.current` day; current/longest/total returned as `Stats` value. Uses D-03 trailing-edge rule. Tested as pure function. See §Streak Algorithm + §Code Examples. |
| NTF-01 | Local notification when session ends | Pre-schedule in `StartSessionUseCase` with `UNCalendarNotificationTrigger(repeats: false)` at `plannedEndAt`; cancel in `EndSessionUseCase` when outcome ≠ `.completed`. Killed-app delivery guaranteed by iOS. See §UserNotifications + §Integration Hooks. |
| NTF-02 | Local notification when scheduled block starts | Pre-schedule from `SyncScheduleWithSystemUseCase` with `UNCalendarNotificationTrigger(dateMatching: DateComponents(weekday:hour:minute:), repeats: true)` per (day × segment). Cross-midnight: evening segment only. Reconcile on every sync. See §Scheduled Notifications + §Pitfalls. |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Swift 6.2, SwiftUI, iOS 26.0+ locked.** Use `@Observable` (Observation) in VMs, never `ObservableObject`.
- **Architecture hard rules:** Repository ↛ Repository · UseCase → UC/Repo · ViewModel → only UC · View → only VM.
- **ViewModels never import SwiftUI** (only `Observation`). `StatsViewModel` + `HomeStatsCardViewModel` must follow this.
- **Feature-first layout:** `Features/Stats/` is the new feature owner. Repository + UseCase + VM + View all live under it. No global `FeatureCommons/`.
- **Distributed DI:** `Features/Stats/Injection/StatsInjection.swift` registers its own deps; called from `DeluluDetoxApp.init()`. Use `@LazyInjected` for VMs, init injection for Repo/UC.
- **iOS-native design patterns preferred.** UserNotifications + Calendar are both native — no third-party wrappers.
- **Navigation:** single `Destination?` enum per VM, `@CasePathable`, case-path bindings. `.stats` case goes on `HomeViewModel` (not AppRootViewModel — see §Decision Point below, mirrors Phase 5 D-22 amendment).
- **Build:** XcodeGen `project.yml` is source of truth. Regenerate with `xcodegen generate` after adding files/targets. Use XcodeBuildMCP for all build/run/test.

## Summary

Phase 6 closes the MVP engagement loop on top of **already-scaffolded infrastructure** — the codebase has a mock `StatsView`, a mock `HomeDashboardView` with streak hero card + quick stats + 7-day dot row, and a working `UNUserNotificationCenter` delegate/repo pattern (from Phase 4 SHL-03). No new libraries are required. Phase 6 is entirely Foundation + UserNotifications + SwiftUI.

Three concurrent workstreams: (1) **Stats** — introduce `StatsRepository` (read-only over existing `sessions.json`) + pure `ComputeStatsUseCase` (streak algorithm) + `StatsViewModel` + `HomeStatsCardViewModel`; wire both existing mock Views to real data. (2) **NTF-01** — hook `StartSessionUseCase` to pre-schedule a one-shot `UNCalendarNotificationTrigger` and `EndSessionUseCase` to cancel it on abort outcomes. (3) **NTF-02** — extend `SyncScheduleWithSystemUseCase` to reconcile a set of repeating weekday triggers via removePending-then-add.

**The main implementation risks are NOT API-level; they are integration-level:** co-existing with the existing `ShieldDeepLinkNotificationDelegate` (identifier-prefix routing must be preserved), running pre-start notification scheduling INSIDE the existing `StartSessionUseCase` rollback semantics without breaking atomicity, and writing a streak algorithm that is DST-safe + monotonic under session rollback.

**Primary recommendation:** Keep `ComputeStatsUseCase` as a **pure function** over `[SessionRecord] + referenceDate + Calendar` — it becomes the easiest-to-test surface in the phase and eliminates the need for any time-of-day timer. Expose a `StatsDelegateRouter` that wraps the existing `ShieldDeepLinkNotificationDelegate` so both shield deep-link and session-end notifications coexist without identifier collisions.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `UserNotifications` | iOS 26 system | Local notifications (NTF-01, NTF-02) | Apple-native, only option for on-device scheduled local notifications. `UNCalendarNotificationTrigger(repeats:true)` delivers reliably even when app is killed [CITED: Apple docs]. |
| `Foundation.Calendar` | iOS 26 system | Day bucketing, DateComponents trigger construction, streak computation | Native, deterministic, zero dependencies. `Calendar.current.isDate(_:inSameDayAs:)` handles DST correctly [VERIFIED: Foundation docs]. |
| `Foundation.TimeZone` | iOS 26 system | Streak day boundary | Implicit via `Calendar.current` — uses device TZ; CONTEXT D-01 accepts TZ-travel artifacts. |
| `SwiftUI` | iOS 26 | Calendar grid (`LazyVGrid`), month header, swipe between months | Already used project-wide. `LazyVGrid` with 7 `GridItem(.flexible())` is the idiomatic monthly grid — already prototyped in `StatsView.swift` [VERIFIED: existing code]. |
| `Observation` | iOS 17+ | `@Observable` VMs | Project standard per CLAUDE.md + architecture GUIDE. |
| `Combine` | iOS 26 | History publisher pass-through from `SessionRepository` | Already the pattern in Phase 3 `ObserveSessionHistoryUseCase`. Phase 6 subscribes to `historyPublisher` via UC boundary. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `XCTest` | Xcode | Unit + integration tests | All stats compute + notification request-build tests. |
| `os.Logger` | iOS 14+ | Structured logging | Consistent with existing `subsystem: "com.kksw.DeluluDetox"` pattern. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom SwiftUI month grid | `CalendarView` (iOS 17+ `UICalendarView` wrapped) | Existing `StatsView.swift` already hand-rolls a `LazyVGrid` grid — reusable as-is. `UICalendarView` requires UIViewRepresentable bridging AND its selection/decoration APIs don't cleanly map to "violet dot on days with ≥1 .completed session". Stick with `LazyVGrid`. [VERIFIED: StatsView.swift prototype] |
| Pre-scheduling all `UNNotificationRequest` | Fire on Darwin notification from Phase 5 markers | D-19 explicitly chose pre-schedule because `UNCalendarNotificationTrigger(repeats: true)` fires when app killed; Darwin notifications only propagate to running processes. Locked decision — no alternative. |
| Cache `Stats` in `stats.json` | On-demand compute | D-07 explicitly chose no cache. Cost: ~200 records × 3 fields = negligible parse. Benefits: no sync bugs, no migration. Locked decision. |
| Single `UNNotificationRequest` for all schedule weekdays using `.weekdaySet`-style trigger | One request per weekday | iOS `UNCalendarNotificationTrigger` only supports `DateComponents` with ONE weekday value. You MUST create one request per selected weekday. [VERIFIED: Apple docs §DateComponents + §UNCalendarNotificationTrigger]. |

**Installation:** zero new packages. All functionality is in Foundation + UserNotifications + SwiftUI. `project.yml` already has UserNotifications linked (Phase 4 SHL-03).

## Architecture Patterns

### Recommended Project Structure

Phase 6 adds one feature directory + mutates three existing injections. Feature-first layout (per `.claude/guides/feature-structure/GUIDE.md`):

```
DeluluDetox/Sources/Features/Stats/
├── Repository/
│   ├── StatsRepository.swift              # Protocol + Impl in one file
│   └── Models/
│       └── Stats.swift                    # struct Stats { currentStreak, longestStreak, totalCount, last7DaysFlags, completedDatesByDay }
├── UseCase/
│   ├── ComputeStatsUseCase.swift          # Pure function over [SessionRecord] + referenceDate + Calendar
│   ├── ObserveStatsUseCase.swift          # Combine pipeline: historyPublisher.map(compute)
│   ├── SchedulePermissionPromptUseCase.swift
│   ├── ScheduleSessionEndNotificationUseCase.swift
│   ├── CancelSessionEndNotificationUseCase.swift
│   └── ReconcileScheduleNotificationsUseCase.swift
├── ViewModel/
│   ├── StatsViewModel.swift               # @Observable, monthly calendar state
│   └── HomeStatsCardViewModel.swift       # @Observable, trimmed projection for home card
├── View/
│   ├── StatsView.swift                    # Already exists — convert from mock to VM-driven
│   └── HomeStatsCard.swift                # Already exists inside HomeDashboardView — extract + wire VM
└── Injection/
    └── StatsInjection.swift               # register(in: DIContainer)

DeluluDetox/Sources/Features/Notifications/  (shared cross-feature — see §Decision Point below)
└── Repository/
    ├── LocalNotificationRepository.swift   # Wraps UNUserNotificationCenter (thin facade)
    └── AppNotificationDelegate.swift       # Replaces / wraps ShieldDeepLinkNotificationDelegate
```

**Decision point (Claude's Discretion per D-21):** `LocalNotificationRepository` could live under `Features/Stats/` (feature-owner of the UserNotifications *engagement* layer), OR under a new sibling `Features/Notifications/` (cross-feature facade). **Recommendation:** create `Features/Notifications/` — it will own both Phase 4 shield deep-link notification AND Phase 6 NTF-01/NTF-02, plus the single `UNUserNotificationCenterDelegate`. Keeps feature-structure GUIDE's "one feature-owner per shared repo" rule honored. Move the existing `ShieldNotificationRepository.swift` + `ShieldDeepLinkNotificationDelegate.swift` from `Features/Shield/` to `Features/Notifications/` as part of Phase 6 execute (low-risk refactor; identifiers and test paths update only).

### Pattern 1: Pure Streak Algorithm (Testable Core)

**What:** `ComputeStatsUseCase` takes `[SessionRecord] + Date + Calendar` and returns `Stats`. No I/O, no observation, no DI beyond `Calendar`.
**When to use:** Any derived aggregate that must be rebuildable from source of truth with zero drift. Ideal test subject — you feed it arrays and date fixtures, assert the numbers.
**Example:**
```swift
// Features/Stats/UseCase/ComputeStatsUseCase.swift
// Source: algorithm derived from CONTEXT D-01..D-05 + project architecture GUIDE.md
protocol ComputeStatsUseCase: Sendable {
    func callAsFunction(history: [SessionRecord], now: Date) -> Stats
}

final class ComputeStatsUseCaseImpl: ComputeStatsUseCase {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func callAsFunction(history: [SessionRecord], now: Date) -> Stats {
        // 1. Filter completed sessions and extract completion dates.
        let completedDates = history
            .filter { $0.outcome == .completed }
            .compactMap(\.actualEndAt)

        let totalCount = completedDates.count

        // 2. Group by day using Calendar.current.startOfDay.
        let completedDaysSet: Set<Date> = Set(completedDates.map { calendar.startOfDay(for: $0) })

        // 3. Last-7-days flags (index 0 = today, index 6 = 6 days ago).
        let today = calendar.startOfDay(for: now)
        let last7DaysFlags: [Bool] = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return completedDaysSet.contains(day)
        }

        // 4. Current streak with D-03 trailing-edge rule.
        //    - If today has completed: count today + consecutive past days.
        //    - If today empty but yesterday has completed: count from yesterday (streak "still alive").
        //    - Else 0.
        var currentStreak = 0
        let currentStart: Date? = {
            if completedDaysSet.contains(today) { return today }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               completedDaysSet.contains(yesterday) { return yesterday }
            return nil
        }()
        if let start = currentStart {
            var cursor = start
            while completedDaysSet.contains(cursor) {
                currentStreak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            }
        }

        // 5. Longest streak — scan sorted unique days, count runs.
        let sortedDays = completedDaysSet.sorted()
        var longestStreak = 0
        var run = 0
        var prev: Date?
        for day in sortedDays {
            if let p = prev, let next = calendar.date(byAdding: .day, value: 1, to: p), calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longestStreak = max(longestStreak, run)
            prev = day
        }

        return Stats(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalCount: totalCount,
            last7DaysFlags: last7DaysFlags,
            completedDaysSet: completedDaysSet
        )
    }
}
```

### Pattern 2: Pre-schedule + Cancel (NTF-01)

**What:** Notification is scheduled at session start with a deterministic identifier derived from the session UUID. It is cancelled on abort outcomes; for `.completed` outcome, iOS fires it naturally.
**When to use:** Any "event at a future point in time" that must survive app termination.
**Example:**
```swift
// Features/Stats/UseCase/ScheduleSessionEndNotificationUseCase.swift
// Source: extends CONTEXT §D-15 + shield notification patterns from Features/Shield/
protocol ScheduleSessionEndNotificationUseCase: Sendable {
    func callAsFunction(sessionId: UUID, plannedEndAt: Date, captionIndex: Int) async
}

final class ScheduleSessionEndNotificationUseCaseImpl: ScheduleSessionEndNotificationUseCase, @unchecked Sendable {
    private let center: LocalNotificationCenter
    private let captions: NotificationCaptionLibrary

    func callAsFunction(sessionId: UUID, plannedEndAt: Date, captionIndex: Int) async {
        let settings = await center.settings()
        guard settings.authorizationStatus == .authorized else {
            // D-15 explicit: skip silently on non-authorized. No error surfaced.
            return
        }

        let identifier = "session.end.\(sessionId.uuidString)"
        let content = UNMutableNotificationContent()
        content.title = "DeluluDetox"
        content.body = captions.sessionEndCopy(for: captionIndex)
        content.sound = .default
        content.userInfo = ["kind": "session-end", "sessionId": sessionId.uuidString]

        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: plannedEndAt)
        components.timeZone = TimeZone.current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
```

### Pattern 3: Reconcile (NTF-02)

**What:** On every schedule save, remove all pending `schedule.start.{id}.*` requests, then add one per (weekday × segment). Simpler and more robust than diffing.
**When to use:** Recurring-notification bundles where the set can grow/shrink per user action.
**Example:**
```swift
// Features/Stats/UseCase/ReconcileScheduleNotificationsUseCase.swift
// Source: extends CONTEXT §D-18 + Phase 5 SyncScheduleWithSystemUseCase
protocol ReconcileScheduleNotificationsUseCase: Sendable {
    func callAsFunction(schedule: Schedule) async
}

final class ReconcileScheduleNotificationsUseCaseImpl: ReconcileScheduleNotificationsUseCase, @unchecked Sendable {
    private let center: LocalNotificationCenter
    private let captions: NotificationCaptionLibrary

    func callAsFunction(schedule: Schedule) async {
        // 1. Remove ALL pending schedule.start.{id}.* for this id (no diff, full replace).
        let pending = await center.pendingNotificationRequests()
        let prefix = "schedule.start.\(schedule.id.uuidString)."
        let stale = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        // 2. If disabled, stop here.
        guard schedule.enabled else { return }

        // 3. Check authorization lazily.
        let settings = await center.settings()
        guard settings.authorizationStatus == .authorized else { return }

        // 4. Schedule only the "user-visible start time" — evening for cross-midnight,
        //    main for single-day. Skip .morning (technical artifact per D-18).
        for weekday in schedule.daysOfWeek {
            let identifier = "schedule.start.\(schedule.id.uuidString).\(weekday)"
            let content = UNMutableNotificationContent()
            content.title = "DeluluDetox"
            content.body = captions.scheduleStartCopy()
            content.sound = .default
            content.userInfo = ["kind": "schedule-start", "scheduleId": schedule.id.uuidString]

            // Calendar.weekday uses 1=Sunday..7=Saturday (same as schedule.daysOfWeek).
            let components = DateComponents(
                calendar: Calendar.current,
                timeZone: TimeZone.current,
                hour: schedule.startHour,
                minute: schedule.startMinute,
                weekday: weekday
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
```

### Pattern 4: @Observable VM Backed by Combine Subject

**What:** `StatsViewModel` subscribes to `observeStats()` publisher (derived from `ObserveSessionHistoryUseCase` via map). Re-emits on every history change — zero manual refresh logic.
**When to use:** Any screen whose state is a projection of a repository subject.

```swift
@MainActor
@Observable
final class StatsViewModel: @unchecked Sendable {
    private(set) var stats: Stats = .empty
    private(set) var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    var destination: Destination?

    @CasePathable
    enum Destination: Equatable {
        case emptyStateHint  // "pusto tu, odpal sesję"
    }

    @ObservationIgnored @LazyInjected private var observeStats: ObserveStatsUseCase
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    init() {
        observeStats()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in self?.stats = stats }
            .store(in: &cancellables)
    }

    func prevMonthTapped() { shift(by: -1) }
    func nextMonthTapped() { shift(by: +1) }

    private func shift(by months: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: months, to: displayedMonth) {
            displayedMonth = Calendar.current.startOfDay(for: next)
        }
    }

    // Pure derivation — View asks "which days this month have a dot?"
    func isMarked(day: Date) -> Bool {
        stats.completedDaysSet.contains(Calendar.current.startOfDay(for: day))
    }
}
```

### Anti-Patterns to Avoid

- **Storing computed streak in persisted JSON.** D-07 forbids; causes sync bugs after session rollback.
- **Using `Timer`/`Task.sleep` to tick streak at midnight.** D-08 "eager expiry" — compute on read; no ticker needed.
- **Pre-scheduling 100+ `UNNotificationRequest`** for NTF-02 (e.g., 14 days × 7 weekdays = 98). `repeats: true` on 7 weekdays = 7 requests total per schedule. iOS max per app = 64 pending; trivially fits.
- **Calling `removeAllPendingNotificationRequests()`** — this would nuke shield deep-link notifications too. Always filter by identifier prefix.
- **Setting `UNUserNotificationCenter.current().delegate` more than once.** iOS keeps only the last assignment. See §Pitfall 1.
- **Computing streak with `TimeInterval` arithmetic (86400s per day).** DST-broken — use `Calendar.date(byAdding:.day, value:, to:)` only.
- **Returning a `Binding<Destination?>` from the VM.** Violates "VM doesn't import SwiftUI." Expose `Destination?` as stored property; View uses `$model.destination.someCase`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Day bucketing for streak | Seconds-based arithmetic (`86400` per day) | `Calendar.current.startOfDay(for:)` + `Calendar.date(byAdding:.day, ...)` | DST transitions, leap seconds, TZ changes — all handled correctly by Foundation. Hand-rolled integer seconds code breaks ~twice/year. |
| Weekday extraction from Date | `Int(floor(timeInterval / 86400)) % 7` | `Calendar.current.component(.weekday, from:)` | Same as above + locale-aware. Phase 5 schedule already uses this; Phase 6 must match. |
| Monthly calendar grid | Custom `UICollectionView` layout with UIKit bridging | `LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7))` | Already prototyped in `StatsView.swift` (lines 157–176). Works. Portable. iOS 26 compatible. |
| Notification cancellation | Tracking identifiers in your own JSON file | `UNUserNotificationCenter.pendingNotificationRequests()` | iOS already tracks them. Filter by identifier prefix. One source of truth. |
| Streak "still alive today" logic | Midnight timer + scenePhase hack | D-08 eager compute — on every read, check gap from today vs latest completed day | Deterministic. No background work. No midnight bug. |
| Notification permission prompt UX | Sheet with custom UI, then call requestAuthorization | Direct `requestAuthorization` call + pre-prompt in a visible context (success screen prelude) | iOS only lets you request ONCE per install without Settings trip. Custom "priming screen" is standard but D-13 mandates simple direct prompt after first `.completed`. |
| Calendar-day equality | `== ` on `Date` or `dateComponents` comparison | `Calendar.current.isDate(_:inSameDayAs:)` | Handles TZ / DST correctly; `Date ==` is wall-clock nanoseconds. |

**Key insight:** The only novel algorithm in Phase 6 is the streak compute. Everything else is plumbing over existing Apple primitives. Write 20 tests for `ComputeStatsUseCase` and everything else follows.

## Runtime State Inventory

> Phase 6 is partially a refactor (mock StatsView + HomeDashboardView → VM-driven) and partially greenfield (NTF-01/02, streak compute). Runtime state audit still applies.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `sessions.json` at `group.com.kksw.DeluluDetox/sessions.json` already has full `SessionRecord` schema including `outcome` and `actualEndAt` (Phase 3 D-14). No Phase 6 schema migration needed. No `stats.json` will be written (D-07). | Code reads only. |
| Live service config | None — no external services. `UNUserNotificationCenter` pending requests set is runtime state owned by iOS. Existing shield deep-link requests use prefix `com.kksw.DeluluDetox.shield-deeplink.*`. Phase 6 adds `session.end.{uuid}` and `schedule.start.{id}.{weekday}` — disjoint prefix spaces, zero collision. | Confirm prefix disjointness in a contract test. Preserve existing filter in `ShieldDeepLinkNotificationDelegate` (it already checks `hasPrefix(identifierPrefix)`). |
| OS-registered state | `UNUserNotificationCenter.current().delegate` is set in `DeluluDetoxApp.init()` (line 32) to an instance of `ShieldDeepLinkNotificationDelegate`. This delegate ignores non-shield notifications (returns `[]` in `.willPresent`). Phase 6 notifications will fire with sound but no banner if this delegate stays unchanged. | Either (a) extend `ShieldDeepLinkNotificationDelegate` to route Phase 6 notifications too, or (b) replace with a composite `AppNotificationDelegate` that dispatches by prefix. **Recommend (b)** — cleaner responsibility split. Must update `DeluluDetoxApp.init()` assignment. |
| Secrets/env vars | None. | None. |
| Build artifacts | `StatsView.swift` (lines 10–33) has hardcoded mock data that will be deleted. `HomeDashboardView.swift` (lines 16–28) has hardcoded mock data that will be deleted. Stats feature directory currently contains ONLY View folder — no ViewModel/UseCase/Repository/Injection subfolders yet. | Phase 6 Wave 0 creates Repository/, UseCase/, ViewModel/, Injection/ subfolders under `Features/Stats/`. Run `xcodegen generate` after adding files — project.yml auto-globs sources. |

**Mock data to replace:**
- `StatsView.swift` lines 10–33: `markedDays`, `today`, `leadingEmptyCells`, `daysInMonth`, `currentStreak`, `recordStreak`, `sessionsThisMonth`, `weekdayHeaders` → all become VM properties except `weekdayHeaders` which stays a View-local constant (purely display concern).
- `HomeDashboardView.swift` lines 16–28: `streakDays`, `dayLabels`, `streakFlags`, `todayIndex`, `completedCount`, `recordCount`, `nextBlockTitle`, `nextBlockSubtitle` → first five become `HomeStatsCardViewModel` properties; `nextBlockTitle`/`nextBlockSubtitle`/`nextBlockEnabled` become a separate `NextBlockCardViewModel` (deferred — not in GAM-01/02/NTF scope, leave mock or remove per Claude's Discretion).

## Common Pitfalls

### Pitfall 1: Single-delegate iOS contract collides with Phase 4 shield notification

**What goes wrong:** Only ONE `UNUserNotificationCenterDelegate` can be installed per process. Phase 4 already installed `ShieldDeepLinkNotificationDelegate`. If Phase 6 overwrites `UNUserNotificationCenter.current().delegate`, shield banner taps stop deep-linking — user taps "DeluluDetox" banner after shield fires, nothing happens.

**Why it happens:** `UNUserNotificationCenter.current().delegate` is a simple property assignment. Last write wins. The existing delegate filters BY IDENTIFIER PREFIX; Phase 6 must do the same and **merge**, not replace.

**How to avoid:** Introduce an `AppNotificationDelegate` that dispatches to sub-handlers based on `UNNotification.request.identifier` prefix. Keep `ShieldDeepLinkNotificationDelegate` semantics for `com.kksw.DeluluDetox.shield-deeplink.*`; add Phase 6 handling for `session.end.*` and `schedule.start.*`. Update `DeluluDetoxApp.init()` to install the composite delegate. Move the file to `Features/Notifications/` (per §Architecture Patterns).

**Warning signs:** Post-Phase 6, shield deep-link notification tap does nothing. Unit test: assert `AppNotificationDelegate` routes a synthetic `UNNotification` with `shield-deeplink.X` identifier to the shield handler AND a `session.end.Y` to the engagement handler, without cross-contamination.

### Pitfall 2: Streak algorithm off-by-one at midnight (D-03 trailing edge)

**What goes wrong:** User completes session at 23:55 Saturday. At 00:05 Sunday, streak display shows 0 (new day, no completed session YET today) instead of yesterday's positive streak.

**Why it happens:** Naive algorithm: "does today have `.completed`? no → streak = 0." CONTEXT D-03 explicitly specifies a "trailing edge tolerance": if today is empty AND yesterday has `.completed`, the streak is still alive (counted from yesterday).

**How to avoid:** The algorithm in §Pattern 1 handles this: if today not in set, check yesterday; if yesterday in set, start counting from yesterday. Test with fixtures: (1) today and yesterday both completed → counts today + yesterday + ... (2) today empty, yesterday completed → counts yesterday + ... (3) today empty, yesterday empty → 0.

**Warning signs:** Sunday morning UX: streak reads "0" on the home card even though user had a 7-day run Saturday. Unit test: `givenCompletedOnDayOffsets([-1, -2, -3])_whenCompute_atTodayMorning_shouldReturnStreak(3)`.

### Pitfall 3: DST day with 23 or 25 hours breaks `Date` arithmetic

**What goes wrong:** Streak algorithm uses `date.addingTimeInterval(-86400)` to "go back one day." On a DST transition day, this lands in a date that is NOT `isDate(_:inSameDayAs:)` the previous calendar day. Streak scans miss a day.

**Why it happens:** DST transitions make civil days have 23 or 25 hours. `TimeInterval(86400)` arithmetic assumes 24-hour days. Happens twice a year. In Poland (CET/CEST) it's the last Sunday of March and October.

**How to avoid:** Exclusively use `Calendar.current.date(byAdding: .day, value: -1, to: day)`. It is DST-aware. Never add/subtract `TimeInterval` to get the "next day."

**Warning signs:** Streak resets from 30 to 1 on a DST Sunday. Test: fixture with completedDates spanning a CET→CEST transition (late March 2026); assert streak is contiguous.

### Pitfall 4: Session-end notification fires AFTER user already saw success screen

**What goes wrong:** Session completes at 12:00:00.000. iOS fires `UNCalendarNotificationTrigger(dateMatching: plannedEndAt, repeats: false)` at ~12:00:00.050. App is foregrounded. User sees success screen AND gets a banner saying "session ended!" — redundant, annoying.

**Why it happens:** `.willPresent` default behavior from `ShieldDeepLinkNotificationDelegate` returns `[]` for non-shield identifiers, which SILENCES them. If Phase 6 replaces with a composite delegate that returns `[.banner]` for `session.end.*`, redundancy occurs.

**How to avoid:** In composite delegate, for `session.end.*`:
- If app is foreground AND user has already navigated past countdown → return `[]` (silent).
- Else return `[.banner, .sound]` (e.g., app killed, user's on home screen).

Simpler alternative (CONTEXT D-16 Claude's Discretion): **always return `[]`** for `session.end.*` in foreground. iOS still delivers the notification to Notification Center (history), so user sees it in the pull-down. Success screen + notification-in-center = two independent channels, no banner race. **Recommend:** silent in foreground.

**Warning signs:** QA report "banner pops over success screen." UI test: foreground app during session end, assert no banner appears.

### Pitfall 5: Pre-scheduling inside `StartSessionUseCase` bypasses existing rollback

**What goes wrong:** `StartSessionUseCase` (existing code) has 3-step rollback: if shield-apply fails OR monitoring-start fails, it finalizes the record as `.cancelledByUser`. If Phase 6 adds "step 0: schedule notification" BEFORE shield-apply, and shield fails, the scheduled notification is now a ghost — it will fire at `plannedEndAt` with no active session.

**Why it happens:** New steps inserted into multi-step transactions need to be added to the rollback path.

**How to avoid:** Schedule the notification AS STEP 4 (after monitoring starts), OR include cancel of the notification in the rollback branch. **Recommend:** step 4 (no rollback needed because success already guaranteed). Example sequence:
1. Persist active record (existing)
2. Apply shield (existing) — throws → rollback (cancel step 4 not needed, haven't scheduled yet)
3. Start monitoring (existing) — throws → rollback (same)
4. **Schedule NTF-01** (new) — throws? Don't throw. Best-effort. Notification is convenience, session is critical.

**Warning signs:** Abort outcome test shows a `session.end.X` notification still pending for an aborted session. Unit test: rollback on step 2 failure, assert `pendingNotificationRequests()` filtered by prefix is empty.

### Pitfall 6: `EndSessionUseCase` doesn't know the sessionId it's ending

**What goes wrong:** NTF-01 cancel identifier is `session.end.{sessionId}`. `EndSessionUseCaseImpl.callAsFunction(outcome:, actualEndAt:)` takes no sessionId — it pulls the active session from the repository subject and finalizes it. The flow is correct for outcome ≠ `.completed` (cancel needed) but the UC doesn't currently expose the id to the notification layer.

**Why it happens:** Phase 3 End UC API was designed before Phase 6 existed.

**How to avoid:** Two patterns, pick one:
- **Option A (preferred, minimal diff):** Before calling `finalizeActiveSession`, peek the current active session (same `first()` pattern as `FinalizeSessionFromMarkerUseCase`) to get the id, cancel the notification conditionally on `outcome != .completed`, then proceed.
- **Option B:** Inject `CancelSessionEndNotificationUseCase` into `EndSessionUseCase` and call it inside. Cleaner dependency but requires updating every EndSession test (currently 0 direct tests; several use-sites in Finalize/SelfHeal/DetectRevocation).

**Recommend A** because it localizes the change; `EndSessionUseCaseImpl.callAsFunction` gets a new private helper `cancelPendingEndNotification(for: UUID?)` called before finalize, uses existing activeSubject read pattern. See §Integration Hooks.

**Warning signs:** User cancels session → minutes later an "ukończona sesja!" banner appears. Test: call `EndSessionUseCase(outcome: .cancelledByUser)`, assert pending requests with matching id-prefix become empty.

### Pitfall 7: `DateComponents(weekday:hour:minute:)` without explicit calendar/timezone drifts

**What goes wrong:** `DateComponents(hour: 22, minute: 0, weekday: 2)` with `repeats: true` — if iOS interprets these components with a calendar other than Gregorian + user's TZ, the trigger fires at a different wall-clock time. Symptom: notification fires at 23:00 not 22:00 after user travels.

**Why it happens:** `UNCalendarNotificationTrigger` uses the components with `Calendar.autoupdatingCurrent` by default, but ambiguity creeps in if you forget to set `components.calendar` and `components.timeZone`.

**How to avoid:** Always construct DateComponents with explicit calendar + timezone:
```swift
let components = DateComponents(
    calendar: Calendar(identifier: .gregorian),
    timeZone: TimeZone.current,
    hour: schedule.startHour,
    minute: schedule.startMinute,
    weekday: weekday
)
```
Note: `.autoupdatingCurrent` is also acceptable and tracks user's calendar/timezone changes live; Gregorian-explicit is defensive against future locale changes that add alternate calendars.

**Warning signs:** International test users report "schedule fires 1h early/late." Log the resolved `trigger.nextTriggerDate()` at schedule time and compare to user's displayed time.

### Pitfall 8: Monthly calendar grid first-weekday-of-month offset

**What goes wrong:** Month starts on Thursday. Grid renders April 1 in the first cell (Monday column) — calendar looks wrong. User confused.

**Why it happens:** `LazyVGrid` places cells sequentially; you must compute "leading empty cells" = `(weekday of first day of month) - (first-day-of-week)` accounting for 1-indexed `Calendar.weekday`.

**How to avoid:** Existing `StatsView.swift` already demonstrates the pattern with `leadingEmptyCells: Int`. In the VM, compute:
```swift
// Monday-first (PL convention, Claude's Discretion call) for displayedMonth
let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)  // 1=Sunday..7=Saturday
// For Monday-first: Monday=1, Tuesday=2, ..., Sunday=7
let pos = (weekdayOfFirst + 5) % 7   // maps Sun(1)→6, Mon(2)→0, Tue(3)→1, ..., Sat(7)→5
let leadingEmptyCells = pos
```

Set `calendar.firstWeekday = 2` (Monday) at Calendar init IF using `calendar.weekdaySymbols` / alignment APIs; otherwise compute offset manually as above.

**Warning signs:** Screenshot UI test for a known-month (e.g., April 2026, starts on Wednesday) — assert day 1 cell position.

### Pitfall 9: Permission prompt timing collides with shield's existing prompt

**What goes wrong:** `DeluluDetoxApp.init()` already calls `requestAuthorization(options: [.alert, .badge])` (Phase 4 SHL-03). iOS records this as THE authorization request; Phase 6 D-13 "lazy prompt on first .completed" will see `authorizationStatus == .authorized` or `.denied` already — the D-13 custom copy "Chcesz dostać subtelny tap gdy sesja się kończy?" never shows.

**Why it happens:** Phase 4 pre-empted the permission dialog at app launch (for shield deep-link notifications). The dialog can only show once.

**How to avoid:** Two options:
- **Option A:** Drop the shield auto-prompt. Shield deep-link notification is a *fallback* for SHL-03 (extensionContext.open might work anyway); making the user grant permission at first launch is heavy-handed for a fallback they may never hit. Move permission prompt to D-13 trigger (first `.completed`) — serves both Phase 4 fallback AND Phase 6 NTF-01.
- **Option B:** Keep shield auto-prompt; Phase 6 lazy prompt becomes a no-op when `authorizationStatus != .notDetermined`. Treat D-13 as "show rationale banner inside success screen if denied, instead of system dialog."

**Recommend A.** Remove the early prompt from `DeluluDetoxApp.init()`. Move to `FinalizeSessionFromMarkerUseCase` or `HomeViewModel.handleHistory` hook — `SchedulePermissionPromptUseCase` checks `.notDetermined` and calls `requestAuthorization([.alert, .sound])`. Notes: `.badge` probably not needed for either Phase 4 or Phase 6 (no badge UX planned).

**Warning signs:** Fresh install → user sees permission dialog on first app launch (before any session). Fix: assert `requestAuthorization` is not called from `DeluluDetoxApp.init()`.

### Pitfall 10: Pre-scheduling many schedule-start notifications hits 64-pending limit

**What goes wrong:** iOS caps pending local notifications per app at 64. If the user has many schedules × many weekdays × many segments, the add call silently drops.

**Why it happens:** Soft iOS cap. Most apps never hit it.

**How to avoid:** MVP math: 1 implicit schedule × max 7 weekdays × 1 segment (evening only for cross-midnight, main for single-day; never morning) = **max 7 requests for NTF-02**. Plus up to 1 session.end at a time. Shield deep-link is on-demand, not pre-scheduled. Total well under 64. No action needed for MVP; note for post-MVP multi-schedule.

**Warning signs:** `pendingNotificationRequests().count >= 64` — log when exceeded.

## Code Examples

### Example 1: `LocalNotificationRepository` (thin facade, testable)

```swift
// Features/Notifications/Repository/LocalNotificationRepository.swift
// Source: extends Phase 4 ShieldNotificationRepository pattern
import UserNotifications
import Foundation

protocol LocalNotificationRepository: Sendable {
    func settings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers ids: [String])
    func removePendingNotificationRequests(withIdentifierPrefix prefix: String) async
}

struct LiveLocalNotificationRepository: LocalNotificationRepository {
    private var center: UNUserNotificationCenter { .current() }

    func settings() async -> UNNotificationSettings {
        await center.notificationSettings()
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func removePendingNotificationRequests(withIdentifierPrefix prefix: String) async {
        let pending = await pendingNotificationRequests()
        let ids = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
```

### Example 2: Composite Notification Delegate

```swift
// Features/Notifications/AppNotificationDelegate.swift
// Source: merges Phase 4 ShieldDeepLinkNotificationDelegate with Phase 6 engagement notifications
import UserNotifications
import os

@MainActor
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    typealias DeepLinkHandler = @Sendable (URL) async -> Void
    private let shieldDeepLinkHandler: DeepLinkHandler
    private let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "AppNotificationDelegate")

    init(shieldDeepLinkHandler: @escaping DeepLinkHandler) {
        self.shieldDeepLinkHandler = shieldDeepLinkHandler
    }

    // MARK: - Foreground presentation

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let id = notification.request.identifier

        if id.hasPrefix(ShieldNotificationConstants.identifierPrefix) {
            // Phase 4: show banner when shield-origin tap arrives in foreground.
            completionHandler([.banner])
            return
        }

        if id.hasPrefix("session.end.") {
            // Phase 6 Pitfall 4: redundant with success screen → silent.
            completionHandler([])
            return
        }

        if id.hasPrefix("schedule.start.") {
            // Schedule start: app likely backgrounded (user doesn't know block is starting),
            // but if foreground, still banner+sound — user should know blocking begun.
            completionHandler([.banner, .sound])
            return
        }

        // Unknown source — default deny.
        completionHandler([])
    }

    // MARK: - Tap response

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        defer { completionHandler() }

        if id.hasPrefix(ShieldNotificationConstants.identifierPrefix) {
            // Phase 4 deep-link logic unchanged.
            guard let urlString = response.notification.request.content.userInfo[ShieldNotificationConstants.userInfoURLKey] as? String,
                  let url = URL(string: urlString),
                  url.scheme == "deluludetox" else { return }
            Task { @MainActor [shieldDeepLinkHandler] in
                await shieldDeepLinkHandler(url)
            }
            return
        }

        // Phase 6: notification tap → foreground app (iOS does this automatically);
        // if we want deep-link behavior (e.g., session.end.X → success screen, schedule.start.X → home),
        // add here. MVP: no special routing; the app foregrounds, existing observers pick up.
    }
}
```

### Example 3: `StatsRepository` (read-only facade over `sessions.json`)

```swift
// Features/Stats/Repository/StatsRepository.swift
// Source: passes through SessionRepository.historyPublisher per Architecture GUIDE
import Combine

protocol StatsRepository: Sendable {
    /// Publishes the full session history. Pure pass-through so ComputeStatsUseCase
    /// can map → Stats. No write methods — CONTEXT D-07 (no cache).
    var historyPublisher: AnyPublisher<[SessionRecord], Never> { get }
}

final class StatsRepositoryImpl: StatsRepository, @unchecked Sendable {
    private let sessionRepository: SessionRepository  // cross-feature dep injected

    init(sessionRepository: SessionRepository) {
        self.sessionRepository = sessionRepository
    }

    var historyPublisher: AnyPublisher<[SessionRecord], Never> {
        sessionRepository.historyPublisher
    }
}
```

Note: **Repository ↛ Repository rule** — does `StatsRepositoryImpl` depending on `SessionRepository` break it? **Yes, literally.** Remediation: expose `SessionRepository.historyPublisher` via `ObserveSessionHistoryUseCase` (already exists) and have `ObserveStatsUseCaseImpl` take that UC as dependency directly; skip a dedicated `StatsRepository`. Then `ComputeStatsUseCase` is purely `[SessionRecord] → Stats`, and `ObserveStatsUseCase` bridges the observation side. **Recommend this — cleaner, respects dependency rules:**

```swift
// Features/Stats/UseCase/ObserveStatsUseCase.swift
protocol ObserveStatsUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<Stats, Never>
}

final class ObserveStatsUseCaseImpl: ObserveStatsUseCase, @unchecked Sendable {
    private let observeHistory: ObserveSessionHistoryUseCase
    private let compute: ComputeStatsUseCase
    private let clock: @Sendable () -> Date

    init(
        observeHistory: ObserveSessionHistoryUseCase,
        compute: ComputeStatsUseCase,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.observeHistory = observeHistory
        self.compute = compute
        self.clock = clock
    }

    func callAsFunction() -> AnyPublisher<Stats, Never> {
        observeHistory()
            .map { [compute, clock] history in
                compute(history: history, now: clock())
            }
            .eraseToAnyPublisher()
    }
}
```

Result: **No StatsRepository needed.** Phase 6 has UC layer only over existing `SessionRepository`.

### Example 4: Caption Library with Hash-Based Rotation

```swift
// Features/Notifications/NotificationCaptionLibrary.swift
struct NotificationCaptionLibrary: Sendable {
    // D-17 drafts — finalized in execute.
    let sessionEndCaptions: [String] = [
        "Przetrwałeś %d min bez scrollowania. Świat się nie zawalił.",
        "Sesja zakończona. Możesz wrócić do chaosu.",
        "Gratuluję, %d min w realnym świecie. Teraz możesz pojeździć palcem."
    ]

    let scheduleStartCaptions: [String] = [
        "Schedule właśnie zaczął blokadę. Powodzenia.",
        "Apki wyłączone. Realny świat prosi o uwagę.",
        "Blokada zaczyna się teraz. Telefon idzie spać."
    ]

    func sessionEndCopy(for hash: Int, durationMinutes: Int) -> String {
        let idx = abs(hash) % sessionEndCaptions.count
        let template = sessionEndCaptions[idx]
        return template.contains("%d") ? String(format: template, durationMinutes) : template
    }

    func scheduleStartCopy(for hash: Int = Int.random(in: 0...999)) -> String {
        let idx = abs(hash) % scheduleStartCaptions.count
        return scheduleStartCaptions[idx]
    }
}
```

## Integration Hooks

> Precise code-level touch points needed in existing files. Plans should reference these verbatim.

### H1: `StartSessionUseCaseImpl.callAsFunction` — add step 4 (NTF-01 schedule)

**File:** `DeluluDetox/Sources/Features/Session/UseCase/StartSessionUseCase.swift`

**Current flow (lines 45–80):** Step 1 persist → Step 2 shield → Step 3 monitoring → return record.

**Change:** Inject `ScheduleSessionEndNotificationUseCase`; call after step 3, before return. Best-effort (no throw):

```swift
// AFTER step 3 (line 79, before `return record`)
await scheduleEndNotification(
    sessionId: record.id,
    plannedEndAt: record.plannedEndAt,
    captionIndex: abs(record.id.hashValue)
)
```

**DI update:** `SessionInjection.register` — add `scheduleEndNotification: c.resolve()` to `StartSessionUseCaseImpl` init. `StatsInjection` must register BEFORE `SessionInjection` OR the UC must be resolved lazily. **Preferred:** since `ScheduleSessionEndNotificationUseCase` depends only on `LocalNotificationRepository` (registered in a new `NotificationsInjection`), the order is: `NotificationsInjection` → `SessionInjection` → `SchedulingInjection` → `StatsInjection`.

### H2: `EndSessionUseCaseImpl.callAsFunction` — cancel NTF-01 on abort outcomes

**File:** `DeluluDetox/Sources/Features/Session/UseCase/EndSessionUseCase.swift`

**Current flow (lines 36–52):** `shield.clearShield()` → `monitoring.stopActivityMonitoring()` → `repository.finalizeActiveSession()`.

**Change:** Before finalize (which wipes active subject), read active session id, then if outcome ≠ `.completed`, cancel pending request. Inject `CancelSessionEndNotificationUseCase`:

```swift
// BEFORE finalize (line 46)
if outcome != .completed {
    if let active = await currentActive() {
        await cancelEndNotification(sessionId: active.id)
    }
}
try await repository.finalizeActiveSession(outcome: outcome, actualEndAt: actualEndAt)
```

Add `currentActive()` helper mirroring pattern from `FinalizeSessionFromMarkerUseCase.currentActive()` lines 47–57.

### H3: `SyncScheduleWithSystemUseCaseImpl.callAsFunction` — reconcile NTF-02

**File:** `DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift`

**Current flow (lines 44–72):** Snapshot prior → stop DAS → if disabled return → startMonitoring → rollback on error.

**Change:** AFTER `startMonitoring` succeeds (line 62), reconcile NTF-02. On early return (line 52, disabled), ALSO reconcile (which will remove all pending for this schedule). Best-effort (no throw):

```swift
// Step 2 amended — disabled path
guard schedule.enabled else {
    await reconcileNotifications(schedule: schedule)  // removes all pending for this id
    Self.log.info("schedule disabled id=\(schedule.id.uuidString, privacy: .public)")
    return
}

// AFTER step 3 success (line 63)
await reconcileNotifications(schedule: schedule)
```

Inject `ReconcileScheduleNotificationsUseCase`. Add to `SchedulingInjection`.

### H4: `DeluluDetoxApp.init` — replace delegate assignment, drop early `requestAuthorization`

**File:** `DeluluDetox/Sources/App/DeluluDetoxApp.swift`

**Current (lines 29–44):** Installs `ShieldDeepLinkNotificationDelegate`. Lazy prompts `[.alert, .badge]` at launch.

**Change:**
1. Replace with `AppNotificationDelegate(shieldDeepLinkHandler: ...)`.
2. **Delete** the `Task.detached { ... requestAuthorization ... }` block. Move prompt to D-13 hook (first `.completed` finalize). See H5.

### H5: `FinalizeSessionFromMarkerUseCaseImpl` — D-13 lazy permission prompt

**File:** `DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift`

**Change:** After successful `endSession(outcome: .completed, ...)` (line 43), invoke `SchedulePermissionPromptUseCase` (new). This is the "first `.completed`" trigger. The UC internally checks `.notDetermined` so subsequent completions are no-ops.

Alternative: invoke from `HomeViewModel.handleHistory()` line 258 (the "mostRecentCompleted" branch) — UX-friendlier because it runs on main actor and can sequence with success sheet. **Recommend:** `HomeViewModel.handleHistory` hook — it's already the single location where "new .completed detected" is recognized.

### H6: `HomeViewModel.Destination` — add `.stats` case

**File:** `DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift`

**Change:** Extend the existing `Destination` enum (lines 12–36):
```swift
case stats(StatsViewModel)
```
Update the custom `static func ==` to cover `.stats` (identity equality, same pattern as other cases).

Add intent:
```swift
func statsCardTapped() {
    destination = .stats(StatsViewModel())
}
```

Then `HomeView.body` adds:
```swift
.navigationDestination(item: $model.destination.stats) { statsModel in
    StatsView(model: statsModel)
}
```

`HomeDashboardView.streakHeroCard` wraps in a `Button` / `.onTapGesture` that calls `onStatsTap` closure, which `HomeView` provides and forwards to `model.statsCardTapped()`.

### H7: `StatsView` — convert from mock to VM-driven

**File:** `DeluluDetox/Sources/Features/Stats/View/StatsView.swift`

**Change:** Add `@Bindable var model: StatsViewModel`. Replace all hardcoded `markedDays`, `today`, `currentStreak`, `recordStreak`, `sessionsThisMonth` with `model.isMarked(day:)`, `model.stats.currentStreak`, etc. Month header becomes `model.displayedMonth` formatted via `DateFormatter` (reuse existing Theme formatter if any; otherwise local). Chevrons call `model.prevMonthTapped()` / `model.nextMonthTapped()`. Keep `weekdayHeaders` as View constant (display concern).

### H8: `HomeDashboardView` — wire `HomeStatsCardViewModel`

**File:** `DeluluDetox/Sources/Features/Home/View/HomeDashboardView.swift`

**Change:** Add `@Bindable var model: HomeStatsCardViewModel` (injected from parent `HomeView`). Replace mock data (lines 16–28) with `model.stats.*`. Keep layout intact.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `UILocalNotification` | `UNUserNotificationCenter` + `UNNotificationRequest` | iOS 10 (2016) | Phase 6 uses new API exclusively. |
| Completion-handler `UN*` APIs | Async/await (`try await center.add(...)`) | Swift 5.5 / iOS 15 | Use async overloads; they're Sendable-safe and cleaner in Swift 6. Existing `ShieldNotificationRepository` uses completion-handler + Logger capture (fine for extension; MVP Phase 6 main-app can use async directly). |
| `ObservableObject` + `@Published` | `@Observable` macro | iOS 17 | Project standard per CLAUDE.md. |
| `UICalendarView` via `UIViewRepresentable` | `LazyVGrid` with 7 columns | SwiftUI evolution | Project already chose LazyVGrid in existing scaffolding. |
| Centralized notification scheduling at App.init | Lazy / contextual request (Apple HIG) | iOS 12+ (notif-best-practices) | D-13 aligns with HIG. Apple has penalized apps that prompt at launch in App Review. [CITED: Apple HIG Notifications] |

**Deprecated/outdated:**
- `UILocalNotification` — removed. Never use.
- `.willPresent` returning `UNNotificationPresentationOptions.alert` — deprecated since iOS 14 in favor of `.banner` + `.list`. Use `[.banner, .sound]` or `[.banner]`.
- `UNNotificationSound.default` capital-D — deprecated alias, use `.default` (lowercase `d` method) — current code does this correctly.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `UNCalendarNotificationTrigger(repeats: true)` with `DateComponents(weekday:hour:minute:)` fires reliably on iOS 26 even when app is killed | §NTF-02 + Pitfall 7 | NTF-02 unreliable in production — users miss block-start notifications. Mitigate: ship to TestFlight beta, log `nextTriggerDate` vs actual delivery via debug log; if gap detected, fall back to Phase 5 Darwin-notification-based delivery (adds coupling). |
| A2 | iOS 26 pending-request cap is still 64 | §Pitfall 10 | If cap lowered, multi-weekday schedules could silently drop notifications. MVP math fits any reasonable cap. Re-verify post-beta if user reports. |
| A3 | `UNUserNotificationCenter.current().delegate` assignment is stable across the app lifetime | §Pitfall 1 | If iOS resets the delegate (e.g., on memory pressure), shield + engagement notifications lose handling. Install delegate in `App.init()` (already done); consider re-installing in `scenePhase` hook if instability observed. |
| A4 | `Calendar.current.date(byAdding: .day, value: -1, ...)` is DST-safe | §Pitfall 3 | If Foundation regressed here, streak would break during DST. Has been DST-safe since iOS 2.0; near-zero risk. |
| A5 | Single `implicit` blocklist assumption (Phase 2 MVP) holds for NTF-02 identifier uniqueness | §Pattern 3 | Multi-schedule v2 (MSC-01) will need per-schedule identifier namespacing. Current naming `schedule.start.{scheduleId}.{weekday}` already handles this — no change needed. |
| A6 | Notification content `body` can include emoji 🔥 without iOS truncation or sanitization | §Code Examples | If iOS strips emoji (unlikely), UX degradation only. User-visible, not functional. |
| A7 | `UNNotificationSound.default` plays without requiring `UNAuthorizationOptions.sound` — user can still get silent ringer notification | §H1 | If `.sound` option is required and D-13 prompt uses `[.alert]` only, notifications fire silent. **ACTION:** request `[.alert, .sound]`, not just `.alert`. Update D-13 Recommendation. |
| A8 | iOS 26 known notification-delivery issues (forums: intermittent, attachment-related) do NOT affect Phase 6 because we don't use attachments | §UserNotifications research + Sources | If plain text notifications also affected on 26.4+, Phase 6 reliability degrades. Mitigation: rely on `schedule_events.json` markers (Phase 5 D-17) as a secondary reconciliation source for analytics (not delivery). |

## Open Questions

1. **Should the permission prompt (D-13) show before or after the success screen?**
   - What we know: D-13 says "lazy permission prompt BEFORE displaying success screen" (line 72). HIG recommends context-driven prompts; success screen IS the context.
   - What's unclear: iOS system dialog appears modally on top of the success screen if presented first, producing a "which is blocking?" UX question. Post-dialog, user sees success screen with or without knowing if they granted.
   - Recommendation: (a) show dialog first, then success screen with caption acknowledging permission outcome ("okej, dostaniesz tap na końcu każdej sesji" vs "też dobrze, zostajemy bez"); (b) alternative, show success screen first with inline "chcesz na następnym razem dostać tapa?" prompt → user taps "tak" → iOS dialog. Option (b) feels more native but doubles taps. **Planner decides in Plan.**

2. **How does notification rotation (hash by `sessionId`) handle single-session case consistently?**
   - What we know: `abs(sessionId.hashValue) % captions.count` picks caption at start time.
   - What's unclear: `Int.hashValue` is randomized per process launch since Swift 4.2 (`Hasher` randomization). Same session persists across launches; a reconstructed rotation index might differ. Do we need a deterministic hash?
   - Recommendation: use `sessionId.uuidString.unicodeScalars.reduce(0, { $0 &+ Int($1.value) })` or simply `sessionId.uuidString.first?.asciiValue.map(Int.init) ?? 0`. The caption was chosen AT START TIME and persisted into the notification content (already frozen); at cancellation, we don't recompute. So the nondeterminism doesn't matter for behavior — only for test stability. **Use UUID.uuidString first char for test determinism.**

3. **Is the `last7DaysFlags` order in `Stats` Monday-first or today-right?**
   - What we know: `HomeDashboardView` mock shows Pn..Nd labels (Monday-first, offset-indexed).
   - What's unclear: Do we render "today" at a fixed position (e.g., right-most or Monday column)? The mock has `todayIndex: Int = 6` meaning "today is Sunday" — so order IS weekday-labeled.
   - Recommendation: `last7DaysFlags` = ordered by weekday (Mon..Sun) matching PL locale. Provide additional `todayWeekdayIndex` (0–6, 0=Monday) so View can highlight today's cell. Document explicitly in `Stats` struct DocC comment.

4. **Does `Theme` have a day/month formatter, or does `StatsViewModel` own its `DateFormatter`?**
   - What we know: Existing `StatsView.swift` hardcodes "Kwiecień 2026" as a String literal.
   - What's unclear: Project formatter conventions.
   - Recommendation: Check `Features/Design/` or similar; if absent, create `DateFormatter.dduMonthYear` static on `DateFormatter` (PL locale). VM exposes formatted string via computed property. Keep VM SwiftUI-free.

5. **Delegate ownership — who retains `AppNotificationDelegate`?**
   - What we know: `DeluluDetoxApp` holds `notificationDelegate: ShieldDeepLinkNotificationDelegate` as stored property. `UNUserNotificationCenter.current().delegate` is a weak reference.
   - Recommendation: new `AppNotificationDelegate` stored on `DeluluDetoxApp` (same pattern). Set `.delegate` once in `init`; property retains.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `UserNotifications` framework | NTF-01, NTF-02 | ✓ | iOS 26 SDK | — (system framework, always available) |
| `Foundation.Calendar`, `Foundation.TimeZone` | Streak compute | ✓ | iOS 26 SDK | — |
| `Observation` (@Observable macro) | StatsViewModel, HomeStatsCardViewModel | ✓ | iOS 17+ (have iOS 26) | — |
| `SwiftUINavigation` / `@CasePathable` | `HomeViewModel.Destination.stats` case addition | ✓ | Already linked via Phase 1 | — |
| `UNCalendarNotificationTrigger` | NTF-01, NTF-02 | ✓ | iOS 10+ | — |
| `sessions.json` in App Group | Stats compute source | ✓ | Populated by Phase 3 SessionRepository | — (no session data = empty stats → empty state path) |
| `Schedule.json` in App Group | NTF-02 reconciliation trigger | ✓ | Populated by Phase 5 ScheduleRepository | — |
| `SessionRepository.historyPublisher` | `ObserveStatsUseCase` upstream | ✓ | Phase 3 Complete | — |
| `SyncScheduleWithSystemUseCase` | NTF-02 integration hook | ✓ | Phase 5 Complete | — |
| `ShieldNotificationRepository` / `ShieldDeepLinkNotificationDelegate` | Must coexist (don't break SHL-03) | ✓ | Phase 4 Complete | — |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** none.

All phase prerequisites are complete (Phase 3 + Phase 5) or system-level (UserNotifications).

## Validation Architecture

> `workflow.nyquist_validation: true` in config.json — this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode 17, Swift 6.2, iOS 26 SDK) |
| Config file | none — `project.yml` `testTargets.DeluluDetoxTests` section auto-includes `DeluluDetoxTests/**/*.swift` |
| Quick run command | `xcrun xcodebuild test -scheme DeluluDetox -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DeluluDetoxTests/StatsTests -quiet` (via XcodeBuildMCP `test_sim` tool) |
| Full suite command | `xcrun xcodebuild test -scheme DeluluDetox -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` (via XcodeBuildMCP `test_sim`) |

Preferred invocation is XcodeBuildMCP `test_sim` with no arguments (uses session defaults) per `.claude/guides/xcodebuild-mcp/GUIDE.md`.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GAM-01 | Total completed-session count shown on home card + stats header | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testTotalCount_countsOnlyCompletedOutcomes` | ❌ Wave 0 |
| GAM-01 | Total count updates live after new `.completed` session | integration | `test_sim -only-testing:DeluluDetoxTests/ObserveStatsUseCaseTests/testPublisher_emitsNewTotal_whenHistoryAppended` | ❌ Wave 0 |
| GAM-02 | Current streak correct when today has completed session | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testCurrentStreak_todayAndPastDaysCompleted_returnsConsecutive` | ❌ Wave 0 |
| GAM-02 | Current streak "trailing edge" (D-03): today empty, yesterday completed → streak alive | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testCurrentStreak_todayEmptyYesterdayCompleted_returnsYesterdayStreak` | ❌ Wave 0 |
| GAM-02 | Broken streak: today empty + >1 day gap → 0 | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testCurrentStreak_twoDayGap_returnsZero` | ❌ Wave 0 |
| GAM-02 | `.cancelledByUser` / `.brokenByRevoke` do NOT count toward streak (D-02) | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testCurrentStreak_cancelledOutcomes_ignored` | ❌ Wave 0 |
| GAM-02 | Longest streak across full history | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testLongestStreak_scansFullHistory` | ❌ Wave 0 |
| GAM-02 | DST-safe day arithmetic (spring-forward + fall-back Poland 2026) | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testStreak_acrossDSTBoundary_contiguous` | ❌ Wave 0 |
| GAM-02 | `last7DaysFlags` matches Mon..Sun order with correct today index | unit | `test_sim -only-testing:DeluluDetoxTests/ComputeStatsUseCaseTests/testLast7DaysFlags_orderAndTodayIndex` | ❌ Wave 0 |
| GAM-02 | Stats screen renders violet dot on days with `.completed` | integration (VM) | `test_sim -only-testing:DeluluDetoxTests/StatsViewModelTests/testIsMarked_returnsTrue_forCompletedDay` | ❌ Wave 0 |
| NTF-01 | `ScheduleSessionEndNotificationUseCase` builds request with correct identifier, trigger, and payload | unit | `test_sim -only-testing:DeluluDetoxTests/ScheduleSessionEndNotificationUseCaseTests/testBuildsCorrectRequest` | ❌ Wave 0 |
| NTF-01 | Skipped silently when `authorizationStatus != .authorized` | unit | `test_sim -only-testing:DeluluDetoxTests/ScheduleSessionEndNotificationUseCaseTests/testSkips_whenNotAuthorized` | ❌ Wave 0 |
| NTF-01 | `CancelSessionEndNotificationUseCase` removes request for given session id | unit | `test_sim -only-testing:DeluluDetoxTests/CancelSessionEndNotificationUseCaseTests/testRemovesByIdentifier` | ❌ Wave 0 |
| NTF-01 | `EndSessionUseCase` cancels NTF-01 on `.cancelledByUser` outcome | integration | `test_sim -only-testing:DeluluDetoxTests/Features/Session/EndSessionUseCaseTests/testCancelsNotification_onCancelledOutcome` | ❌ Wave 0 (new file) |
| NTF-01 | `StartSessionUseCase` schedules NTF-01 after successful start | integration | `test_sim -only-testing:DeluluDetoxTests/Features/Session/StartSessionUseCaseTests/testSchedulesNotification_onSuccess` | ❌ Wave 0 (new file) |
| NTF-01 | Foreground + completion → no banner (delegate returns `[]`) | unit (delegate) | `test_sim -only-testing:DeluluDetoxTests/AppNotificationDelegateTests/testWillPresent_sessionEnd_returnsEmpty` | ❌ Wave 0 |
| NTF-01 | Killed-app delivery | manual / UAT | device test, not automatable | N/A |
| NTF-02 | `ReconcileScheduleNotificationsUseCase` creates one request per selected weekday | unit | `test_sim -only-testing:DeluluDetoxTests/ReconcileScheduleNotificationsUseCaseTests/testCreatesOneRequestPerWeekday` | ❌ Wave 0 |
| NTF-02 | Removes stale requests before adding new | unit | `test_sim -only-testing:DeluluDetoxTests/ReconcileScheduleNotificationsUseCaseTests/testRemovesStale_beforeAdd` | ❌ Wave 0 |
| NTF-02 | Cross-midnight schedule does NOT schedule morning-segment notification | unit | `test_sim -only-testing:DeluluDetoxTests/ReconcileScheduleNotificationsUseCaseTests/testCrossMidnight_skipsMorningSegment` | ❌ Wave 0 |
| NTF-02 | Disabled schedule removes all pending, schedules none | unit | `test_sim -only-testing:DeluluDetoxTests/ReconcileScheduleNotificationsUseCaseTests/testDisabled_removesAllPending` | ❌ Wave 0 |
| NTF-02 | `SyncScheduleWithSystemUseCase` calls reconcile on enable + disable paths | integration | `test_sim -only-testing:DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests/testReconcilesNotifications` | ❌ Wave 0 (new file) |
| NTF-02 | Delegate returns `[.banner, .sound]` for `schedule.start.*` in foreground | unit | `test_sim -only-testing:DeluluDetoxTests/AppNotificationDelegateTests/testWillPresent_scheduleStart_returnsBannerSound` | ❌ Wave 0 |
| NTF-02 | Killed-app delivery of weekly repeating trigger | manual / UAT | device test | N/A |
| D-13 | Permission prompt fires only on first `.completed` (subsequent no-op) | unit | `test_sim -only-testing:DeluluDetoxTests/SchedulePermissionPromptUseCaseTests/testPrompt_onlyWhenNotDetermined` | ❌ Wave 0 |
| H6 | `HomeViewModel.statsCardTapped` sets `.stats` destination | unit | extend existing `HomeViewModelTests` | partial (file exists) |
| Coexistence | `AppNotificationDelegate` routes shield deep-link identifier prefix to shield handler, not engagement | unit | `test_sim -only-testing:DeluluDetoxTests/AppNotificationDelegateTests/testRoutes_shieldPrefix_toShieldHandler` | ❌ Wave 0 |
| Coexistence | `AppNotificationDelegate` ignores unknown identifier prefixes | unit | `test_sim -only-testing:DeluluDetoxTests/AppNotificationDelegateTests/testUnknownPrefix_returnsEmpty` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** XcodeBuildMCP `test_sim` filtered to the currently-edited test file (e.g., only `ComputeStatsUseCaseTests`). Expect < 15 seconds.
- **Per wave merge:** Full `Features/Stats/` + `Features/Notifications/` + updated `Session/` + `Scheduling/` test subsets. Expect < 90 seconds.
- **Phase gate:** Full suite via `test_sim` with no filter. Expect < 3 minutes. Must be green before `/gsd-verify-work`.

### Wave 0 Gaps

Files to create (test file paths follow `Features/{FeatureName}/` convention already in `DeluluDetoxTests/Features/`):

- [ ] `DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift` — 20+ cases: total, current (day 0/1/2+ gap), longest, last7DaysFlags, DST boundaries, empty history, outcome filter, calendar injection for determinism.
- [ ] `DeluluDetoxTests/Features/Stats/ObserveStatsUseCaseTests.swift` — publisher emission test using a `CurrentValueSubject`-backed `MockObserveSessionHistoryUseCase`.
- [ ] `DeluluDetoxTests/Features/Stats/StatsViewModelTests.swift` — prevMonth/nextMonth state, `isMarked(day:)` correctness, empty state destination.
- [ ] `DeluluDetoxTests/Features/Stats/HomeStatsCardViewModelTests.swift` — stats projection, broken-streak display condition.
- [ ] `DeluluDetoxTests/Features/Notifications/LocalNotificationRepositoryTests.swift` — request-build assertions (identifier, trigger components, content). The `add`/`remove` wrappers are thin UNCenter pass-throughs; no unit test, covered by integration.
- [ ] `DeluluDetoxTests/Features/Notifications/AppNotificationDelegateTests.swift` — prefix routing, `.willPresent` options, `didReceive` routing for known + unknown prefixes.
- [ ] `DeluluDetoxTests/Features/Notifications/ScheduleSessionEndNotificationUseCaseTests.swift` — auth-gated skip, request content.
- [ ] `DeluluDetoxTests/Features/Notifications/CancelSessionEndNotificationUseCaseTests.swift` — identifier-based removal.
- [ ] `DeluluDetoxTests/Features/Notifications/ReconcileScheduleNotificationsUseCaseTests.swift` — one-per-weekday, skip-morning-segment, disabled path, prior-prefix removal.
- [ ] `DeluluDetoxTests/Features/Notifications/SchedulePermissionPromptUseCaseTests.swift` — `.notDetermined` gating.
- [ ] `DeluluDetoxTests/Features/Session/StartSessionUseCaseTests.swift` (NEW) — existing codebase has no `StartSessionUseCase` direct tests; Phase 6 integration hook H1 forces creation. Cover step-4 scheduling + rollback-doesn't-schedule.
- [ ] `DeluluDetoxTests/Features/Session/EndSessionUseCaseTests.swift` (NEW) — existing codebase has no direct tests; H2 forces creation. Cover conditional cancel + no-op on `.completed`.
- [ ] `DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift` (NEW) — H3 hook; existing tests only cover `ToggleScheduleUseCase`, `ConsumeScheduleEventMarkerUseCase`, `ComputeScheduleWindowUseCase`. Cover reconcile-on-enable + reconcile-on-disable.
- [ ] Mocks to add under `DeluluDetoxTests/Features/Notifications/Mocks/`:
  - `MockLocalNotificationRepository.swift` — configurable `settings`, captures `add`/`remove` calls.
  - `MockScheduleSessionEndNotificationUseCase.swift`
  - `MockCancelSessionEndNotificationUseCase.swift`
  - `MockReconcileScheduleNotificationsUseCase.swift`
- [ ] Mocks under `DeluluDetoxTests/Features/Stats/Mocks/`:
  - `MockObserveSessionHistoryUseCase.swift` — uses `CurrentValueSubject<[SessionRecord], Never>` so tests can push history snapshots.
  - `MockComputeStatsUseCase.swift` — for `ObserveStatsUseCaseTests` wiring + `StatsViewModelTests`.
- [ ] Fixture helpers under `DeluluDetoxTests/Support/`:
  - `SessionRecord+Fixtures.swift` — `completed(on: Date)`, `cancelled(on: Date)`, `broken(on: Date)` helpers using fixed blocklistId.
  - `Date+Fixtures.swift` — `at(y: m: d: h: m:)` convenience.

Framework install: NONE — XCTest already in project, XcodeBuildMCP already in use.

## Security Domain

> `security_enforcement` not present in `.planning/config.json` — enabled by default. Phase 6 has minimal security surface but ASVS applies.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth in MVP (on-device, no backend) |
| V3 Session Management | no | App sessions (not user sessions) handled by iOS |
| V4 Access Control | partial | Notification content must not leak sensitive data (see V8) |
| V5 Input Validation | yes | Deep-link URL parsing in `AppNotificationDelegate.didReceive` — validate `url.scheme == "deluludetox"` before forwarding (existing shield code does this; new code must copy the guard) |
| V6 Cryptography | no | No crypto operations; no hand-rolled hashing (use Foundation for display-level `hashValue` only) |
| V7 Error Handling & Logging | yes | `os.Logger` with `privacy: .public` / `.private` tags. UUIDs are `.public` (opaque); user-generated content N/A here |
| V8 Data Protection | yes | Notification `userInfo` carries session/schedule UUIDs only — opaque identifiers, no PII. Content body/title is fixed copy (no user data interpolation beyond duration in minutes). `sessions.json` protected by `.completeFileProtectionUntilFirstUserAuthentication` per existing `SessionRepository.writeAtomic` |
| V11 Business Logic | yes | Streak cannot be manipulated by malicious input — `sessions.json` is written only by main app (D-02 Phase 2) |
| V14 Configuration | partial | App Group identifier is not a secret; hard-coded per project conventions |

### Known Threat Patterns for iOS + UserNotifications

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Notification content leak on Lock Screen (user has lock-screen preview) | Information Disclosure | Do not embed PII in notification body. Session UUID in `userInfo` only (not body). Copy is brand-safe Polish, no leakage. |
| Deep-link URL injection via crafted notification (Phase 4 parity) | Tampering | Scheme allow-list: `url.scheme == "deluludetox"` — existing `ShieldDeepLinkNotificationDelegate` does this (line 66); `AppNotificationDelegate` copies the pattern. Phase 6 notifications DO NOT carry URLs → risk null. |
| Streak manipulation by tampering with `sessions.json` (jailbroken device) | Tampering | Out of scope — MVP accepts that a jailbroken user can manipulate local JSON. App Group protection provides standard iOS isolation against non-jailbroken peer apps. |
| Notification identifier collision with other apps | Tampering (low) | iOS identifier namespace is per-app. `com.kksw.DeluluDetox.*` prefix is our own. No collision risk. |
| Denial-of-service via pending-notification overflow | DoS (low) | iOS caps at 64 pending. MVP math fits; pre-flight count check optional. |

## Sources

### Primary (HIGH confidence)

- **Existing codebase (VERIFIED by Read tool):**
  - `DeluluDetox/Sources/Features/Session/Repository/Models/SessionRecord.swift` — schema confirmed
  - `DeluluDetox/Sources/Features/Session/Repository/Models/SessionOutcome.swift` — `.completed`, `.cancelledByUser`, `.brokenByRevoke`
  - `DeluluDetox/Sources/Features/Session/Repository/SessionRepository.swift` — `historyPublisher` already exposed
  - `DeluluDetox/Sources/Features/Session/UseCase/ObserveSessionHistoryUseCase.swift` — pass-through ready for Phase 6
  - `DeluluDetox/Sources/Features/Session/UseCase/StartSessionUseCase.swift` — integration hook H1 target
  - `DeluluDetox/Sources/Features/Session/UseCase/EndSessionUseCase.swift` — integration hook H2 target
  - `DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift` — currentActive pattern reference
  - `DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift` — integration hook H3 target
  - `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift` — `daysOfWeek: [Int]` Calendar.weekday
  - `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift` — `buildDeviceActivitySchedules()` pattern Phase 6 mirrors for notification-side
  - `DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift` — `.main`, `.evening`, `.morning`
  - `DeluluDetox/Sources/App/DeluluDetoxApp.swift` — integration hook H4 target
  - `DeluluDetox/Sources/Features/Shield/Repository/ShieldNotificationRepository.swift` — reference pattern for `LocalNotificationRepository`
  - `DeluluDetox/Sources/Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift` — pattern for `AppNotificationDelegate`
  - `DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift` — destination enum and navigation precedent
  - `DeluluDetox/Sources/Features/Home/View/HomeDashboardView.swift` — mock data to replace
  - `DeluluDetox/Sources/Features/Stats/View/StatsView.swift` — mock data to replace
  - `DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` — foreground `refreshStatus()` hook Phase 6 may extend if lazy permission prompt lives at AppRoot layer

- **Project guides (VERIFIED):**
  - `.claude/guides/architecture/GUIDE.md` — Clean Architecture rules (Repo ↛ Repo, VM → UC only)
  - `.claude/guides/navigation/GUIDE.md` — Destination?/CasePathable/Wzorzec A
  - `CLAUDE.md` — Swift 6.2 / iOS 26, feature-first, DIContainer + @LazyInjected, XcodeBuildMCP usage

- **Phase context files (VERIFIED):**
  - `.planning/phases/06-engagement-layer/06-CONTEXT.md` — 22 locked decisions
  - `.planning/phases/03-quick-sessions/03-CONTEXT.md` — D-07/D-08/D-13/D-14 schemas
  - `.planning/phases/04-shield-customization/04-CONTEXT.md` — tone register for broken streak shame
  - `.planning/phases/05-scheduled-blocking/05-CONTEXT.md` — D-14 sync hook, D-03 cross-midnight semantics
  - `.planning/phases/02-app-selection/02-CONTEXT.md` — App Group file bus contract

### Secondary (MEDIUM confidence)

- **Apple developer docs** (accessed via search results, not fully fetched in this session):
  - `UNCalendarNotificationTrigger` reference: https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger
  - `requestAuthorization` reference: https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:)
  - Apple HIG Notifications: (referenced, specific URL not pinned in this research pass)

### Tertiary (LOW confidence — flagged for validation)

- **iOS 26 notification reliability issue reports** — Apple Developer Forums threads indicate intermittent push delivery issues on iOS 26.2 / 26.3.1 / 26.4. Relevance: local notifications (Phase 6) are separately implemented from APNS, but similar underlying subsystem. Treat as awareness flag; no action unless repro'd in beta.
  - https://developer.apple.com/forums/topics/app-and-system-services/app-and-system-services-notifications
  - https://discussions.apple.com/thread/256185321

## Metadata

**Confidence breakdown:**

- Standard stack: **HIGH** — UserNotifications + Foundation are decades-stable; existing Phase 4 `ShieldNotificationRepository` already uses the target API surface correctly.
- Architecture: **HIGH** — CONTEXT.md prescribes the Clean Architecture pattern verbatim; existing `SessionRepository` + `ObserveSessionHistoryUseCase` provide the exact publisher surface Phase 6 needs.
- Integration hooks: **HIGH** — all touch points inspected in code; line numbers and patterns verified.
- Streak algorithm correctness: **HIGH** — Foundation `Calendar` APIs are canonical; DST safety is a 20-year-old property. Test coverage is the delivery mechanism.
- Notification delivery on iOS 26: **MEDIUM** — documented issues exist in forums; local notifications (vs push) typically unaffected but cannot be verified without device testing. Assumption A1 flagged.
- Copy (D-17, D-20, broken-streak variants): **LOW** — Claude's Discretion; will be drafted in execute. Not a correctness risk.

**Research date:** 2026-04-20
**Valid until:** 2026-05-20 (iOS 26 patch releases may alter Pitfall 8 / Assumption A1; UserNotifications API itself is stable)

---

*Phase: 06-engagement-layer*
*Research completed: 2026-04-20*
