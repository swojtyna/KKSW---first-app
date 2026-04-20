---
phase: 05
plan: 04
type: execute
wave: 2
depends_on: [05-02, 05-03]
files_modified:
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ObserveScheduleUseCase.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ToggleScheduleUseCase.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ComputeScheduleWindowUseCase.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SelfHealSchedulesUseCase.swift
  - DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift
  - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
  - DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockComputeScheduleWindowUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockObserveScheduleUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockToggleScheduleUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockSyncScheduleWithSystemUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockSelfHealSchedulesUseCase.swift
  - DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift
autonomous: true
requirements: [SCH-01, SCH-02, SCH-03]
must_haves:
  truths:
    - "ComputeScheduleWindowUseCase is pure: given (schedule, now, calendar) it returns ScheduleWindow.State — testable without mocks, deterministic"
    - "SyncScheduleWithSystemUseCase implements D-14: stopMonitoring(scheduleId:) → if enabled → startMonitoring(schedule:). On start throw: rollback schedule.json to prior snapshot + rethrow"
    - "ToggleScheduleUseCase composes repo.upsert(enabled=flip) + sync(schedule:)"
    - "SelfHealSchedulesUseCase iterates enabled schedules: compute window, diff vs last-applied state, apply/clear shield accordingly (D-18)"
    - "SchedulingInjection registers 3 repositories (application scope) + 7 UseCases (unique scope) + ObserveScheduleUseCase wrapper"
    - "AppRootViewModel.refreshStatus() extended to consume schedule markers + self-heal schedules on scenePhase.active (between Phase 3 detectRevocation and the end of refreshStatus())"
    - "Darwin notifications `com.kksw.DeluluDetox.scheduleStarted` and `com.kksw.DeluluDetox.scheduleEnded` are observed by AppRootViewModel — foreground reconcile fires immediately"
  artifacts:
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ObserveScheduleUseCase.swift"
      provides: "Thin publisher passthrough — ObserveScheduleUseCaseImpl(repository:)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ToggleScheduleUseCase.swift"
      provides: "ToggleScheduleUseCaseImpl(repository:sync:) — callAsFunction(scheduleId:enabled:)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift"
      provides: "SyncScheduleWithSystemUseCaseImpl(monitoring:repository:) — stop → start with rollback"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ComputeScheduleWindowUseCase.swift"
      provides: "Pure ComputeScheduleWindowUseCase — ScheduleWindow.State enum + callAsFunction(schedule:now:calendar:)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SelfHealSchedulesUseCase.swift"
      provides: "SelfHealSchedulesUseCaseImpl composing repository + shield + monitoring + blocklist + compute"
    - path: "DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift"
      provides: "register(in:) body with 3 repo (.application) + 7 UC (.unique) registrations"
    - path: "DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift"
      provides: "+2 @LazyInjected UCs (consumeScheduleMarker + selfHealSchedules), Darwin observer extended, refreshStatus() adds 2 steps"
  key_links:
    - from: "SchedulingInjection.register(in:)"
      to: "3 repositories + 7 UseCases registered in DIContainer"
      via: "container.register(Protocol.self, scope: .application | .unique)"
      pattern: "container.register\\(.*ScheduleRepository.self, scope: .application"
    - from: "AppRootViewModel.refreshStatus()"
      to: "consumeScheduleMarker() + selfHealSchedules(now:)"
      via: "eager-capture + Task { ... }"
      pattern: "let consumeScheduleMarker|let selfHealSchedules"
    - from: "AppRootViewModel darwin observer"
      to: "com.kksw.DeluluDetox.scheduleStarted / scheduleEnded"
      via: "registerDarwinFinalizeObserver extended"
      pattern: "com.kksw.DeluluDetox.scheduleStarted"
---

<objective>
Ship the domain/coordination layer (5 UseCases) + DI + AppRoot foreground wiring that bind the three Plan 02/03 repositories together into a coherent feature. After this plan, Plan 05 (DAM extension) can write markers knowing they will be consumed on next foreground; Plans 06/07 (UI) can construct ViewModels that resolve real UCs via `@LazyInjected`.

Purpose:
- SCH-01 (create schedule): `CreateOrUpdateScheduleUseCase` (Plan 02) now has a real `SyncScheduleWithSystemUseCase` to delegate to for DAS registration.
- SCH-02 (enable/disable): `ToggleScheduleUseCase` flips repo + triggers sync.
- SCH-03 (schedule executes via DAM): `SelfHealSchedulesUseCase` covers the case where DAM callbacks are missed (iOS 26 reliability risk per PROJECT.md blockers) — main app reconciles on next foreground. `ConsumeScheduleEventMarkerUseCase` (Plan 02) pulled into AppRoot here.
- Architecture rule (CLAUDE.md): Repository ↛ Repository. `SelfHealSchedulesUseCase` sits at UC layer so it can consume `BlocklistRepository` (Phase 2) via the AppSelection feature UC `ObserveBlocklistUseCase` (cross-feature UC — sanctioned per Phase 3 StartSessionUseCase precedent).

Output:
- 5 new UseCase files + their mocks updated.
- `SchedulingInjection.register(in:)` body filled in.
- `AppRootViewModel` extended with 2 new `@LazyInjected` UCs + Darwin observer for 2 new notification names.
- 17 tests turned green (6 Compute + 4 Sync + 3 Toggle + 4 SelfHeal). AppRootViewModelTests + 2 new tests (`testRefreshStatusCallsScheduleUCs`, `testScheduleDarwinNotificationTriggersRefresh`).
- Full suite green.
</objective>

<execution_context>
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/workflows/execute-plan.md
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/05-scheduled-blocking/05-CONTEXT.md
@.planning/phases/05-scheduled-blocking/05-RESEARCH.md
@.planning/phases/05-scheduled-blocking/05-02-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-03-SUMMARY.md
@.planning/phases/03-quick-sessions/03-03-SUMMARY.md
@.planning/phases/03-quick-sessions/03-06-SUMMARY.md
@DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift
@DeluluDetox/Sources/Features/Session/UseCase/SelfHealExpiredSessionUseCase.swift
@DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift
@DeluluDetox/Sources/Features/Session/UseCase/ObserveActiveSessionUseCase.swift
@DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift
@DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift
@DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift
@DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift

<interfaces>
Final protocol bodies (Plan 04 replaces empty bodies):
```swift
protocol ObserveScheduleUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<[Schedule], Never>
}

protocol ToggleScheduleUseCase: Sendable {
    func callAsFunction(scheduleId: UUID, enabled: Bool) async throws
}

protocol SyncScheduleWithSystemUseCase: Sendable {
    func callAsFunction(schedule: Schedule) async throws
}
// (signature already added by Plan 02 — implementation lands here in Plan 04)

protocol ComputeScheduleWindowUseCase: Sendable {
    func callAsFunction(schedule: Schedule, now: Date, calendar: Calendar) -> ScheduleWindow
}

struct ScheduleWindow: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case active(endsAt: Date)
        case upcomingToday(startsAt: Date)
        case notToday(nextDate: Date?)
        case inactive
    }
    let state: State
    let currentWeekday: Int    // 1..7 (Calendar.weekday)
}

protocol SelfHealSchedulesUseCase: Sendable {
    /// Iterates enabled schedules; compares computed window vs current shield
    /// state (recorded via UserDefaults or an in-memory map) and applies/clears.
    /// Returns number of shield operations performed.
    @discardableResult
    func callAsFunction(now: Date) async throws -> Int
}

enum ScheduleUseCaseError: Error {
    case scheduleNotFound
    case blocklistMissing
}
```

ObserveBlocklistUseCase signature (Phase 2 — consumed by SelfHealSchedulesUseCase across feature boundary):
```swift
// From DeluluDetox/Sources/Features/AppSelection/UseCase/ObserveBlocklistUseCase.swift:
protocol ObserveBlocklistUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<Blocklist, Never>
}
```

AppRootViewModel insertion points (see the existing file — extend refreshStatus + add Darwin observers):
```swift
// Before:
// 1) reconcileBlocklist, 2) finalizeFromMarker, 3) selfHealExpiredSession, 4) detectRevocation.
// After Plan 04:
// 1) reconcileBlocklist, 2) finalizeFromMarker, 3) selfHealExpiredSession, 4) detectRevocation,
// 5) consumeScheduleMarker (NEW), 6) selfHealSchedules (NEW).
```
</interfaces>

<compute_window_algorithm>
Reference algorithm for `ComputeScheduleWindowUseCaseImpl.callAsFunction(schedule:now:calendar:)`:

```
if !schedule.enabled: return ScheduleWindow(state: .inactive, currentWeekday: 0)

let weekday = calendar.component(.weekday, from: now)  // 1=Sun..7=Sat
let startOfToday = calendar.startOfDay(for: now)
let todayStartTime = startOfToday + startHour*3600 + startMinute*60
let todayEndTime = startOfToday + endHour*3600 + endMinute*60

if schedule.crossesMidnight:
  // evening segment started yesterday OR today (yesterday still running if now < today's end)
  let yesterdayStart = startOfToday - 24*3600 + startHour*3600 + startMinute*60
  let yesterdayWeekday = ((weekday - 2 + 7) % 7) + 1   // 1-based Sun..Sat, roll back 1
  // Case A: yesterday's evening is still running (now is before today's end, yesterday was in daysOfWeek)
  if now < todayEndTime && schedule.daysOfWeek.contains(yesterdayWeekday):
    return .active(endsAt: todayEndTime)
  // Case B: today's evening about to start
  if schedule.daysOfWeek.contains(weekday):
    if now >= todayStartTime:
      // active: started today, ends tomorrow same time-of-end
      return .active(endsAt: todayEndTime + 24*3600)
    else:
      return .upcomingToday(startsAt: todayStartTime)
  // Case C: neither today nor yesterday — find next occurrence
  return .notToday(nextDate: findNextOccurrence(after: now, weekdays: schedule.daysOfWeek, hm: (startHour, startMinute), calendar))

else:  // single-day
  if !schedule.daysOfWeek.contains(weekday):
    return .notToday(nextDate: findNextOccurrence(after: now, weekdays: schedule.daysOfWeek, hm: (startHour, startMinute), calendar))
  if now < todayStartTime: return .upcomingToday(startsAt: todayStartTime)
  if now < todayEndTime: return .active(endsAt: todayEndTime)
  return .notToday(nextDate: findNextOccurrence(after: now, weekdays: schedule.daysOfWeek, hm: (startHour, startMinute), calendar))
```

`findNextOccurrence` helper: iterate days 1..7 from tomorrow, find first weekday match, build Date with `calendar.date(bySettingHour:minute:second:of:)`.

Treat the "weekday of the schedule START" as authoritative for cross-midnight (the evening segment's weekday). So `daysOfWeek: [2]` (Monday) + 22:00-06:00 means: Monday 22:00 → Tuesday 06:00. The weekday filter in DAM extension (Plan 05-05) uses the START weekday. This matches user intuition ("sleep block every Monday night").

The UCaseImpl should also expose a helper `static func lastAppliedKey(scheduleId: UUID) -> String` for the UserDefaults-based "last applied state" tracking used by SelfHealSchedulesUseCase. Pattern: `"schedule_applied_\(scheduleId.uuidString)"` stored as Bool in a `UserDefaults(suiteName: "com.kksw.DeluluDetox.scheduleState")` suite. Default false → no prior apply recorded.
</compute_window_algorithm>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: ComputeScheduleWindowUseCase (pure) + 6 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ComputeScheduleWindowUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockComputeScheduleWindowUseCase.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/UseCase/SelfHealExpiredSessionUseCase.swift (analogue — pure UC with clock injection pattern)
    - DeluluDetoxTests/Features/Session/SelfHealExpiredSessionUseCaseTests.swift (analogue — deterministic time tests via fixed Date)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift (consumes — uses crossesMidnight, daysOfWeek, startHour/Minute, endHour/Minute, enabled)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-18 (self-heal logic requirements — "powinno być aktywne" / "nie powinno być aktywne")
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Pattern 2 (Compute UC rationale + example)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Pitfall 7 (Calendar.weekday 1=Sunday semantics)
  </read_first>
  <behavior>
    1. RED — Turn 6 XCTSkipIf stubs in ComputeScheduleWindowUseCaseTests into real assertions:

       Every test constructs `let calendar = Calendar(identifier: .gregorian)` with fixed timezone (set `timeZone = TimeZone(identifier: "Europe/Warsaw")!`) for determinism, a fixed `now` Date via ISO8601 parsing, and a test Schedule. Then asserts the returned ScheduleWindow.State.

       - `testSingleDayActiveMidWindow`:
         - schedule startHour=9 startMinute=0 endHour=17 endMinute=0 daysOfWeek=[2,3,4,5,6] enabled=true (Mon-Fri)
         - now = Wednesday 12:00
         - Expected: `.active(endsAt: Wednesday 17:00)`
       - `testSingleDayUpcomingToday`:
         - same schedule, now = Wednesday 07:00
         - Expected: `.upcomingToday(startsAt: Wednesday 09:00)`
       - `testCrossMidnightBeforeMidnightActive`:
         - schedule startHour=22 startMinute=0 endHour=6 endMinute=0 daysOfWeek=[1,2,3,4,5,6,7] enabled=true (every day)
         - now = some Wednesday 23:30
         - Expected: `.active(endsAt: Thursday 06:00)`
       - `testCrossMidnightAfterMidnightActive`:
         - same schedule, now = Thursday 03:00
         - Expected: `.active(endsAt: Thursday 06:00)`. (Yesterday Wed's evening segment still in-window.)
       - `testWeekdayExclusionReturnsNotToday`:
         - schedule startHour=9 endHour=17 daysOfWeek=[2,3,4,5,6] (Mon-Fri)
         - now = Saturday 10:00
         - Expected: `.notToday(nextDate: next Monday 09:00)`. Non-nil nextDate required.
       - `testDisabledScheduleReturnsInactive`:
         - schedule enabled=false
         - now = any
         - Expected: `.inactive`, currentWeekday can be 0 (UC signals via the Inactive state).

    2. GREEN — Replace empty `protocol ComputeScheduleWindowUseCase: Sendable {}` in ScheduleProtocols.swift with the full protocol body per `<interfaces>`. Add `ScheduleWindow` struct.

       Create `ComputeScheduleWindowUseCase.swift`:
       ```swift
       import Foundation

       final class ComputeScheduleWindowUseCaseImpl: ComputeScheduleWindowUseCase, @unchecked Sendable {
           func callAsFunction(schedule: Schedule, now: Date, calendar: Calendar) -> ScheduleWindow {
               guard schedule.enabled else {
                   return ScheduleWindow(state: .inactive, currentWeekday: 0)
               }

               let weekday = calendar.component(.weekday, from: now)
               let startOfToday = calendar.startOfDay(for: now)

               let todayStart = startOfToday.addingTimeInterval(TimeInterval(schedule.startHour * 3600 + schedule.startMinute * 60))
               let todayEnd = startOfToday.addingTimeInterval(TimeInterval(schedule.endHour * 3600 + schedule.endMinute * 60))

               if schedule.crossesMidnight {
                   // Case A: yesterday's evening still running in today before "end time"
                   let yesterdayWeekday = ((weekday - 2 + 7) % 7) + 1   // roll back 1 day
                   if now < todayEnd, schedule.daysOfWeek.contains(yesterdayWeekday) {
                       return ScheduleWindow(state: .active(endsAt: todayEnd), currentWeekday: weekday)
                   }
                   // Case B: today's evening starts
                   if schedule.daysOfWeek.contains(weekday) {
                       if now >= todayStart {
                           let tomorrowEnd = todayEnd.addingTimeInterval(24 * 3600)
                           return ScheduleWindow(state: .active(endsAt: tomorrowEnd), currentWeekday: weekday)
                       } else {
                           return ScheduleWindow(state: .upcomingToday(startsAt: todayStart), currentWeekday: weekday)
                       }
                   }
                   // Case C: neither today nor yesterday
                   let next = findNextOccurrence(after: now, daysOfWeek: schedule.daysOfWeek, hour: schedule.startHour, minute: schedule.startMinute, calendar: calendar)
                   return ScheduleWindow(state: .notToday(nextDate: next), currentWeekday: weekday)
               }

               // Single-day
               if !schedule.daysOfWeek.contains(weekday) {
                   let next = findNextOccurrence(after: now, daysOfWeek: schedule.daysOfWeek, hour: schedule.startHour, minute: schedule.startMinute, calendar: calendar)
                   return ScheduleWindow(state: .notToday(nextDate: next), currentWeekday: weekday)
               }
               if now < todayStart {
                   return ScheduleWindow(state: .upcomingToday(startsAt: todayStart), currentWeekday: weekday)
               }
               if now < todayEnd {
                   return ScheduleWindow(state: .active(endsAt: todayEnd), currentWeekday: weekday)
               }
               let next = findNextOccurrence(after: now, daysOfWeek: schedule.daysOfWeek, hour: schedule.startHour, minute: schedule.startMinute, calendar: calendar)
               return ScheduleWindow(state: .notToday(nextDate: next), currentWeekday: weekday)
           }

           private func findNextOccurrence(
               after date: Date,
               daysOfWeek: [Int],
               hour: Int,
               minute: Int,
               calendar: Calendar
           ) -> Date? {
               guard !daysOfWeek.isEmpty else { return nil }
               for dayOffset in 1...7 {
                   guard let candidate = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
                   let candidateWeekday = calendar.component(.weekday, from: candidate)
                   if daysOfWeek.contains(candidateWeekday) {
                       return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: candidate)
                   }
               }
               return nil
           }

           // Internal constant for UserDefaults state tracking (used by SelfHealSchedulesUseCase).
           static func lastAppliedKey(scheduleId: UUID) -> String {
               "schedule_applied_\(scheduleId.uuidString)"
           }
           static let scheduleStateSuiteName = "com.kksw.DeluluDetox.scheduleState"
       }
       ```

       Update MockComputeScheduleWindowUseCase:
       ```swift
       final class MockComputeScheduleWindowUseCase: ComputeScheduleWindowUseCase, @unchecked Sendable {
           var stubbedResult: ScheduleWindow = ScheduleWindow(state: .inactive, currentWeekday: 0)
           private(set) var callCount = 0
           private(set) var lastSchedule: Schedule?
           private(set) var lastNow: Date?
           func callAsFunction(schedule: Schedule, now: Date, calendar: Calendar) -> ScheduleWindow {
               callCount += 1
               lastSchedule = schedule
               lastNow = now
               return stubbedResult
           }
       }
       ```

    3. REFACTOR — `findNextOccurrence` may need a timezone-sensitive test if UAT reveals bugs. For Plan 04 MVP, single TZ tests suffice.

    4. `mcp__XcodeBuildMCP__test_sim` scoped to `ComputeScheduleWindowUseCaseTests` — 6 tests PASS.

    Commit: `feat(05-04): ship ComputeScheduleWindowUseCase pure logic + tests`.
  </behavior>
  <action>
    See `<behavior>`. Exact identifiers:
    - `final class ComputeScheduleWindowUseCaseImpl: ComputeScheduleWindowUseCase, @unchecked Sendable`
    - `struct ScheduleWindow: Equatable, Sendable { let state: State; let currentWeekday: Int }`
    - `enum ScheduleWindow.State: Equatable, Sendable { case active(endsAt:), upcomingToday(startsAt:), notToday(nextDate:), inactive }`
    - Static helpers: `lastAppliedKey(scheduleId:)` and `scheduleStateSuiteName` for Task 4 reuse
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests — expect 6 passed, 0 failed</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ComputeScheduleWindowUseCase.swift` exits 0
    - `grep -c "final class ComputeScheduleWindowUseCaseImpl: ComputeScheduleWindowUseCase, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ComputeScheduleWindowUseCase.swift` == 1
    - `grep -c "struct ScheduleWindow: Equatable, Sendable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "case active(endsAt: Date)" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "case upcomingToday(startsAt: Date)" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "case notToday(nextDate: Date?)" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "case inactive" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "static let scheduleStateSuiteName" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ComputeScheduleWindowUseCase.swift` == 1
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped: 6 passed, 0 failed, 0 skipped
  </acceptance_criteria>
  <done>
    ComputeScheduleWindowUseCase + ScheduleWindow types + 6 tests green. Mock complete. Committed.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: SyncScheduleWithSystemUseCase + ToggleScheduleUseCase + ObserveScheduleUseCase + 7 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ToggleScheduleUseCase.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ObserveScheduleUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockObserveScheduleUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockToggleScheduleUseCase.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/UseCase/StartSessionUseCase.swift (analogue — atomic "step A then step B, rollback on throw" pattern with best-effort cleanup)
    - DeluluDetox/Sources/Features/Session/UseCase/ObserveActiveSessionUseCase.swift (analogue — thin publisher passthrough)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-14 (Sync UC contract: stopMonitoring old → if enabled → startMonitoring; error → rollback schedule.json)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-11 (toggle from-next-window: disable doesn't force-clear shield; but the UC must stopMonitoring so no future intervalDidStart fires)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift (consumed — `upsert`, `schedulesPublisher`)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift (consumed — `startMonitoring`/`stopMonitoring`)
  </read_first>
  <behavior>
    1. RED:

       **SyncScheduleWithSystemUseCaseTests (4 real assertions):**
       - `testSyncStopsOldThenStartsNewWhenEnabled` — enabled schedule. Inject MockScheduleActivityMonitoringRepository + MockScheduleRepository. Call `sync(schedule: enabledSchedule)`. Assert `monitoring.stopMonitoringCallCount == 1 && monitoring.stoppedScheduleIds.last == schedule.id`. Assert `monitoring.startMonitoringCallCount == 1`. Assert call order: use a shared array `callOrder: [String]` in mock that tracks both method names in order; assert `callOrder == ["stopMonitoring", "startMonitoring"]`.
       - `testSyncOnlyStopsWhenScheduleDisabled` — disabled schedule. After sync: `stopMonitoringCallCount == 1`, `startMonitoringCallCount == 0`.
       - `testSyncRollsBackScheduleJSONWhenStartMonitoringThrows` — `monitoring.startMonitoringError = ScheduleActivityMonitoringError.startFailed(NSError(...))`. Pre-populate MockScheduleRepository with an existing "prior" version of the schedule. Call sync with a "new" version. Expect throw. Assert MockScheduleRepository.upsertCallCount == 1 AND the last upserted Schedule equals the PRIOR version (rollback). Sync UC must read prior from `repository.schedulesPublisher` snapshot before starting.
       - `testSyncLogsErrorWhenStopMonitoringThrows` — stopMonitoring is `async` non-throwing in our protocol, so this test is actually about: `monitoring.stopMonitoring` never throws; the test verifies that startMonitoring-throw does NOT re-call stopMonitoring (no infinite loop). Rename if confusion: `testSyncDoesNotRetryStopMonitoringAfterStartFailure`. Assert after catch: `stopMonitoringCallCount == 1` (not 2).

       **ToggleScheduleUseCaseTests (3 real assertions):**
       - `testToggleEnableCallsUpsertThenSync` — pre-populate MockScheduleRepository with `enabled=false` Schedule. Call `toggle(scheduleId: s.id, enabled: true)`. Assert `repo.upsertCallCount == 1 && repo.lastUpserted?.enabled == true`. Assert `sync.callCount == 1 && sync.lastCalledSchedule?.enabled == true`.
       - `testToggleDisableCallsUpsertThenSyncWhichStopsMonitoring` — starting `enabled=true` Schedule. Call `toggle(..., enabled: false)`. Assert `repo.lastUpserted?.enabled == false`. Assert `sync.lastCalledSchedule?.enabled == false`.
       - `testToggleMissingScheduleThrowsNotFound` — empty MockScheduleRepository. Call `toggle(scheduleId: UUID(), enabled: true)`. Expect `XCTAssertThrowsError` with `ScheduleUseCaseError.scheduleNotFound`.

    2. GREEN:

       Fill protocol bodies in ScheduleProtocols.swift:
       ```swift
       protocol ObserveScheduleUseCase: Sendable {
           func callAsFunction() -> AnyPublisher<[Schedule], Never>
       }
       protocol ToggleScheduleUseCase: Sendable {
           func callAsFunction(scheduleId: UUID, enabled: Bool) async throws
       }
       // SyncScheduleWithSystemUseCase signature already present from Plan 02 — keep it.

       enum ScheduleUseCaseError: Error {
           case scheduleNotFound
           case blocklistMissing
       }
       ```

       Create `ObserveScheduleUseCase.swift`:
       ```swift
       import Combine
       import Foundation

       final class ObserveScheduleUseCaseImpl: ObserveScheduleUseCase, @unchecked Sendable {
           private let repository: ScheduleRepository
           init(repository: ScheduleRepository) { self.repository = repository }
           func callAsFunction() -> AnyPublisher<[Schedule], Never> {
               repository.schedulesPublisher
           }
       }
       ```

       Create `SyncScheduleWithSystemUseCase.swift`:
       ```swift
       import Combine
       import Foundation
       import os

       final class SyncScheduleWithSystemUseCaseImpl: SyncScheduleWithSystemUseCase, @unchecked Sendable {
           private let monitoring: ScheduleActivityMonitoringRepository
           private let repository: ScheduleRepository
           private static let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "SyncScheduleWithSystemUseCase")

           init(monitoring: ScheduleActivityMonitoringRepository, repository: ScheduleRepository) {
               self.monitoring = monitoring
               self.repository = repository
           }

           func callAsFunction(schedule: Schedule) async throws {
               // Snapshot prior state for rollback.
               let priorSnapshot = await currentSnapshot(for: schedule.id)

               // Step 1: stop any existing DAS for this scheduleId (all 3 segment variants).
               await monitoring.stopMonitoring(scheduleId: schedule.id)

               // Step 2: if disabled, we're done (D-11 — disable kills future fires; current shield cleared by intervalDidEnd or next scenePhase self-heal).
               guard schedule.enabled else {
                   Self.log.info("schedule disabled id=\(schedule.id.uuidString, privacy: .public)")
                   return
               }

               // Step 3: start new DAS.
               do {
                   try await monitoring.startMonitoring(schedule: schedule)
                   Self.log.info("schedule synced id=\(schedule.id.uuidString, privacy: .public) enabled=true")
               } catch {
                   Self.log.error("startMonitoring failed id=\(schedule.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
                   // Rollback: re-persist prior snapshot if it existed.
                   if let prior = priorSnapshot {
                       try? await repository.upsert(prior)
                       Self.log.info("rolled back schedule.json to prior snapshot")
                   }
                   throw error
               }
           }

           private func currentSnapshot(for id: UUID) async -> Schedule? {
               // Best-effort read from repository's in-memory subject.
               await withCheckedContinuation { continuation in
                   var cancellable: AnyCancellable?
                   cancellable = repository.schedulesPublisher.first().sink { schedules in
                       continuation.resume(returning: schedules.first(where: { $0.id == id }))
                       cancellable?.cancel()
                   }
               }
           }
       }
       ```

       Create `ToggleScheduleUseCase.swift`:
       ```swift
       import Combine
       import Foundation

       final class ToggleScheduleUseCaseImpl: ToggleScheduleUseCase, @unchecked Sendable {
           private let repository: ScheduleRepository
           private let sync: SyncScheduleWithSystemUseCase

           init(repository: ScheduleRepository, sync: SyncScheduleWithSystemUseCase) {
               self.repository = repository
               self.sync = sync
           }

           func callAsFunction(scheduleId: UUID, enabled: Bool) async throws {
               // Read current schedule from repository snapshot.
               let current = await withCheckedContinuation { (continuation: CheckedContinuation<Schedule?, Never>) in
                   var cancellable: AnyCancellable?
                   cancellable = repository.schedulesPublisher.first().sink { schedules in
                       continuation.resume(returning: schedules.first(where: { $0.id == scheduleId }))
                       cancellable?.cancel()
                   }
               }
               guard let existing = current else { throw ScheduleUseCaseError.scheduleNotFound }
               var updated = existing
               updated.enabled = enabled
               try await repository.upsert(updated)
               try await sync(schedule: updated)
           }
       }
       ```

       Update MockObserveScheduleUseCase + MockToggleScheduleUseCase + extend MockSyncScheduleWithSystemUseCase (from Plan 02) with `callOrder` tracking. Simplest: add a shared `callOrder: [String]` property to MockScheduleActivityMonitoringRepository.

    3. `mcp__XcodeBuildMCP__test_sim` scoped to three test files: 7 tests PASS.

    Commit: `feat(05-04): ship Sync + Toggle + Observe schedule UseCases`.
  </behavior>
  <action>
    See `<behavior>`. Concrete names:
    - `final class ObserveScheduleUseCaseImpl` / `SyncScheduleWithSystemUseCaseImpl` / `ToggleScheduleUseCaseImpl` — each `, @unchecked Sendable`.
    - Error enum: `ScheduleUseCaseError.scheduleNotFound`, `.blocklistMissing` in ScheduleProtocols.swift.
    - Logger categories: `"SyncScheduleWithSystemUseCase"`, `"ToggleScheduleUseCase"` (optional for the latter — short flow).
    - `MockScheduleActivityMonitoringRepository` gains `callOrder: [String]` — order-of-call verification.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests -only-testing:DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests — expect 7 passed total, 0 failed</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ObserveScheduleUseCase.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ToggleScheduleUseCase.swift` exits 0
    - `grep -c "final class SyncScheduleWithSystemUseCaseImpl: SyncScheduleWithSystemUseCase, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift` == 1
    - `grep -c "final class ToggleScheduleUseCaseImpl: ToggleScheduleUseCase, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ToggleScheduleUseCase.swift` == 1
    - `grep -c "final class ObserveScheduleUseCaseImpl: ObserveScheduleUseCase, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ObserveScheduleUseCase.swift` == 1
    - `grep -c "enum ScheduleUseCaseError" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "case scheduleNotFound" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "await monitoring.stopMonitoring(scheduleId:" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift` == 1
    - `grep -c "try await monitoring.startMonitoring(schedule:" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift` == 1
    - `grep -c "try? await repository.upsert(prior)" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift` == 1 (rollback)
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped: 7 passed, 0 failed
  </acceptance_criteria>
  <done>
    Sync + Toggle + Observe UseCases implemented. 7 tests green. Mocks complete. Committed.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: SelfHealSchedulesUseCase + SchedulingInjection registrations + 4 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SelfHealSchedulesUseCase.swift,
    DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift,
    DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockSelfHealSchedulesUseCase.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/UseCase/SelfHealExpiredSessionUseCase.swift (analogue — self-heal UC pattern with repository + dependency composition)
    - DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift (analogue — DI registration pattern, application vs unique scope, dependency order)
    - DeluluDetox/Sources/Features/AppSelection/UseCase/ObserveBlocklistUseCase.swift (cross-feature UC consumed by SelfHealSchedulesUseCase — verify signature returns `AnyPublisher<Blocklist, Never>`)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-18 (self-heal requirements: active → apply, not active → clear, compare against last-applied state)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Pitfall 8 (consume marker BEFORE self-heal — already handled by AppRoot orchestration in Task 4)
  </read_first>
  <behavior>
    1. RED — 4 tests in SelfHealSchedulesUseCaseTests:

       Setup helpers: `MockScheduleRepository` + `MockScheduleShieldRepository` + `MockScheduleActivityMonitoringRepository` + `MockObserveBlocklistUseCase` (already exists from Phase 2 or create minimal local test double) + `MockComputeScheduleWindowUseCase` + a test-isolated `UserDefaults(suiteName: "test.schedule.state.\(UUID())")` to track last-applied flags (via `defaultsOverride` test seam similar to Phase 3 MarkSuccessShownUseCase).

       - `testAppliesShieldWhenShouldBeActiveButStoreClear` — populate MockScheduleRepository with 1 enabled schedule. MockComputeScheduleWindowUseCase.stubbedResult = `.active(endsAt: ...)`. UserDefaults has no flag (last-applied=false). Call UC. Assert `shieldRepo.applyCallCount == 1`, `shieldRepo.lastAppliedBlocklist?.id == expectedBlocklistId`. Assert UC return value == 1.
       - `testClearsShieldWhenStoreDirtyButShouldNotBeActive` — 1 enabled schedule. Compute stub = `.inactive` or `.notToday(...)`. UserDefaults pre-set `schedule_applied_<id>=true` (prior apply recorded). Call UC. Assert `shieldRepo.clearCallCount == 1`. UserDefaults flag now false.
       - `testNoOpWhenStateMatches` — active schedule, compute=active, last-applied=true → no shield calls. OR inactive schedule, compute=inactive, last-applied=false → no shield calls. UC return 0.
       - `testIteratesOverAllEnabledSchedules` — 3 schedules (2 enabled, 1 disabled). Compute stub returns `.active` for all. Last-applied=false for both enabled ones. Call UC. Assert `shieldRepo.applyCallCount == 2` (not 3 — disabled one skipped).

    2. GREEN:

       Create `SelfHealSchedulesUseCase.swift`:
       ```swift
       import Combine
       import Foundation
       import os

       final class SelfHealSchedulesUseCaseImpl: SelfHealSchedulesUseCase, @unchecked Sendable {
           private let scheduleRepo: ScheduleRepository
           private let shieldRepo: ScheduleShieldRepository
           private let observeBlocklist: ObserveBlocklistUseCase
           private let compute: ComputeScheduleWindowUseCase
           private let calendar: Calendar
           private let defaults: UserDefaults
           private static let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "SelfHealSchedulesUseCase")

           /// Test seam for UserDefaults override (same pattern as Phase 3 MarkSuccessShownUseCase).
           nonisolated(unsafe) static var defaultsOverride: UserDefaults?

           init(
               scheduleRepo: ScheduleRepository,
               shieldRepo: ScheduleShieldRepository,
               observeBlocklist: ObserveBlocklistUseCase,
               compute: ComputeScheduleWindowUseCase,
               calendar: Calendar = .current
           ) {
               self.scheduleRepo = scheduleRepo
               self.shieldRepo = shieldRepo
               self.observeBlocklist = observeBlocklist
               self.compute = compute
               self.calendar = calendar
               self.defaults = Self.defaultsOverride ?? UserDefaults(suiteName: ComputeScheduleWindowUseCaseImpl.scheduleStateSuiteName) ?? .standard
           }

           @discardableResult
           func callAsFunction(now: Date) async throws -> Int {
               // Snapshot schedules.
               let schedules = await currentSchedules()
               let enabled = schedules.filter { $0.enabled }
               guard !enabled.isEmpty else { return 0 }

               // Need blocklist for apply path.
               let blocklist = await currentBlocklist()
               guard blocklist.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000") else {
                   Self.log.info("blocklist unavailable — skipping apply paths (clear-only still runs)")
                   // Fall through: can still clear orphan stores, just never apply.
                   return 0
               }

               var operations = 0
               for schedule in enabled {
                   let window = compute(schedule: schedule, now: now, calendar: calendar)
                   let shouldBeActive: Bool = {
                       if case .active = window.state { return true }
                       return false
                   }()
                   let key = ComputeScheduleWindowUseCaseImpl.lastAppliedKey(scheduleId: schedule.id)
                   let wasApplied = defaults.bool(forKey: key)

                   switch (shouldBeActive, wasApplied) {
                   case (true, false):
                       try await shieldRepo.applyShield(for: blocklist)
                       defaults.set(true, forKey: key)
                       operations += 1
                       Self.log.info("self-heal applied id=\(schedule.id.uuidString, privacy: .public)")
                   case (false, true):
                       await shieldRepo.clearShield()
                       defaults.set(false, forKey: key)
                       operations += 1
                       Self.log.info("self-heal cleared id=\(schedule.id.uuidString, privacy: .public)")
                   default:
                       // state matches; no-op
                       break
                   }
               }
               return operations
           }

           private func currentSchedules() async -> [Schedule] {
               await withCheckedContinuation { (continuation: CheckedContinuation<[Schedule], Never>) in
                   var cancellable: AnyCancellable?
                   cancellable = scheduleRepo.schedulesPublisher.first().sink { schedules in
                       continuation.resume(returning: schedules)
                       cancellable?.cancel()
                   }
               }
           }

           private func currentBlocklist() async -> Blocklist {
               await withCheckedContinuation { (continuation: CheckedContinuation<Blocklist, Never>) in
                   var cancellable: AnyCancellable?
                   cancellable = observeBlocklist().first().sink { blocklist in
                       continuation.resume(returning: blocklist)
                       cancellable?.cancel()
                   }
               }
           }
       }
       ```

       Fill in `SchedulingInjection.register(in:)` body:
       ```swift
       enum SchedulingInjection {
           static func register(in container: DIContainer) {
               // Repositories — singletons.
               container.register(ScheduleRepository.self, scope: .application) { _ in
                   ScheduleRepositoryImpl()
               }
               container.register(ScheduleShieldRepository.self, scope: .application) { _ in
                   LiveScheduleShieldRepository()
               }
               container.register(ScheduleActivityMonitoringRepository.self, scope: .application) { _ in
                   LiveScheduleActivityMonitoringRepository()
               }

               // Pure compute UC — no deps.
               container.register(ComputeScheduleWindowUseCase.self, scope: .unique) { _ in
                   ComputeScheduleWindowUseCaseImpl()
               }

               // Observe UC — thin passthrough.
               container.register(ObserveScheduleUseCase.self, scope: .unique) { c in
                   ObserveScheduleUseCaseImpl(repository: c.resolve())
               }

               // Sync UC — before Toggle (Toggle depends on Sync).
               container.register(SyncScheduleWithSystemUseCase.self, scope: .unique) { c in
                   SyncScheduleWithSystemUseCaseImpl(
                       monitoring: c.resolve(),
                       repository: c.resolve()
                   )
               }

               // CreateOrUpdate (depends on Sync).
               container.register(CreateOrUpdateScheduleUseCase.self, scope: .unique) { c in
                   CreateOrUpdateScheduleUseCaseImpl(
                       repository: c.resolve(),
                       sync: c.resolve()
                   )
               }

               // Toggle (depends on Sync).
               container.register(ToggleScheduleUseCase.self, scope: .unique) { c in
                   ToggleScheduleUseCaseImpl(
                       repository: c.resolve(),
                       sync: c.resolve()
                   )
               }

               // SelfHeal — depends on ObserveBlocklistUseCase (AppSelection) + Compute.
               container.register(SelfHealSchedulesUseCase.self, scope: .unique) { c in
                   SelfHealSchedulesUseCaseImpl(
                       scheduleRepo: c.resolve(),
                       shieldRepo: c.resolve(),
                       observeBlocklist: c.resolve(),
                       compute: c.resolve()
                   )
               }

               // ConsumeEventMarker (main-app foreground path).
               container.register(ConsumeScheduleEventMarkerUseCase.self, scope: .unique) { c in
                   ConsumeScheduleEventMarkerUseCaseImpl(repository: c.resolve())
               }
           }
       }
       ```

       Update MockSelfHealSchedulesUseCase:
       ```swift
       final class MockSelfHealSchedulesUseCase: SelfHealSchedulesUseCase, @unchecked Sendable {
           private(set) var callCount = 0
           private(set) var lastNow: Date?
           var stubbedResult: Int = 0
           var stubbedError: Error?
           @discardableResult
           func callAsFunction(now: Date) async throws -> Int {
               callCount += 1
               lastNow = now
               if let stubbedError { throw stubbedError }
               return stubbedResult
           }
       }
       ```

    3. `mcp__XcodeBuildMCP__test_sim` scoped: SelfHealSchedulesUseCaseTests 4 passed + full suite green.

    Commit: `feat(05-04): ship SelfHealSchedulesUseCase + SchedulingInjection registrations`.
  </behavior>
  <action>
    See `<behavior>`. Exact identifiers:
    - `final class SelfHealSchedulesUseCaseImpl: SelfHealSchedulesUseCase, @unchecked Sendable`
    - Test seam: `nonisolated(unsafe) static var defaultsOverride: UserDefaults?` — tests set it to isolated suite in `setUp`, nil-out in `tearDown`
    - Logger category: `"SelfHealSchedulesUseCase"`
    - `SchedulingInjection` registers 3 repos `.application` + 7 UCs `.unique` (ObserveSchedule, ComputeWindow, Sync, CreateOrUpdate, Toggle, SelfHeal, ConsumeEventMarker) = 10 total
    - Registration order inside `register(in:)` — put Sync before Toggle/CreateOrUpdate (container resolves bottom-up via closures, but explicit ordering helps readers)
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests — expect 4 passed, 0 failed. Then full suite test_sim: 0 failures.</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SelfHealSchedulesUseCase.swift` exits 0
    - `grep -c "final class SelfHealSchedulesUseCaseImpl: SelfHealSchedulesUseCase, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SelfHealSchedulesUseCase.swift` == 1
    - `grep -c "container.register(ScheduleRepository.self, scope: .application)" DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` == 1
    - `grep -c "container.register(ScheduleShieldRepository.self, scope: .application)" DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` == 1
    - `grep -c "container.register(ScheduleActivityMonitoringRepository.self, scope: .application)" DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` == 1
    - `grep -c "scope: .application" DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` == 3
    - `grep -c "scope: .unique" DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` == 7
    - `grep -c "nonisolated(unsafe) static var defaultsOverride" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SelfHealSchedulesUseCase.swift` == 1
    - `grep -c "observeBlocklist: c.resolve()" DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` == 1 (cross-feature UC resolve)
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped: 4 passed; full suite: 0 failed
  </acceptance_criteria>
  <done>
    SelfHeal UC + DI registrations complete. 4 tests green. Full suite green. MockSelfHealSchedulesUseCase complete. Committed.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: AppRootViewModel wiring — 2 new @LazyInjected UCs + refreshStatus extension + schedule Darwin observer + 2 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift,
    DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift (the file being modified — existing refreshStatus() has 5 eager-captured UCs and 1 Darwin observer for session)
    - DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift (analogue — existing tests pattern for DIContainer reset + mock injection + refreshStatus call assertions)
    - .planning/phases/03-quick-sessions/03-06-SUMMARY.md §Task 4 (Eager UC capture pattern to prevent DIContainer-reset race — MUST reuse for Plan 04)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-18 (self-heal on scenePhase.active)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Example 4 (AppRootViewModel.refreshStatus() extension — exact insertion pattern) + §Pitfall 8 (consume marker BEFORE self-heal)
  </read_first>
  <behavior>
    1. RED — Add 2 tests to AppRootViewModelTests:

       - `testRefreshStatusCallsScheduleUCsAfterSessionUCs` — register mocks for `ConsumeScheduleEventMarkerUseCase` + `SelfHealSchedulesUseCase` in DIContainer. Construct AppRootViewModel. Call `refreshStatus()`. Sleep 50ms (same pattern as existing test). Assert both mock.callCount == 1. Also assert CALL ORDER: consumeScheduleMarker must run BEFORE selfHealSchedules (RESEARCH Pitfall 8). Use a shared `callOrderLog: [String]` appended from each mock.

       - `testScheduleDarwinNotificationTriggersRefresh` — register all mocks including schedule UCs. Post Darwin `com.kksw.DeluluDetox.scheduleStarted` via `CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ...)`. Sleep 50ms. Assert `refreshStatusUseCase.callCount >= 1` AND `selfHealSchedules.callCount >= 1` (indirectly triggered via refreshStatus()). Repeat for `scheduleEnded`.

    2. GREEN — Modify AppRootViewModel.swift:

       Add 2 new @LazyInjected properties (alongside existing ones):
       ```swift
       @ObservationIgnored
       @LazyInjected private var consumeScheduleMarker: ConsumeScheduleEventMarkerUseCase
       @ObservationIgnored
       @LazyInjected private var selfHealSchedules: SelfHealSchedulesUseCase
       ```

       Add 2 static Darwin notification names:
       ```swift
       @ObservationIgnored
       private static let darwinScheduleStartedName = "com.kksw.DeluluDetox.scheduleStarted"
       @ObservationIgnored
       private static let darwinScheduleEndedName = "com.kksw.DeluluDetox.scheduleEnded"
       ```

       Modify `refreshStatus()` — extend the Task body with 2 new steps (eager-capture new UCs BEFORE Task spawn):
       ```swift
       func refreshStatus() {
           refreshStatusUseCase()
           let reconcile = reconcileBlocklist
           let finalize = finalizeFromMarker
           let selfHeal = selfHealExpiredSession
           let revocation = detectRevocation
           let consumeScheduleMarker = self.consumeScheduleMarker    // NEW
           let selfHealSchedules = self.selfHealSchedules            // NEW
           let log = logger
           Task {
               let now = Date()

               // Phase 02
               do { try await reconcile() } catch { log.error(...) }

               // Phase 03
               do { _ = try await finalize(now: now) } catch { log.error(...) }
               do { _ = try await selfHeal(now: now) } catch { log.error(...) }
               do { _ = try await revocation(now: now) } catch { log.error(...) }

               // Phase 05 — schedule marker consumption BEFORE self-heal (Pitfall 8).
               do { _ = try await consumeScheduleMarker() } catch {
                   log.error("consumeScheduleMarker failed: \(String(describing: error), privacy: .public)")
               }

               // Phase 05 — schedule self-heal.
               do { _ = try await selfHealSchedules(now: now) } catch {
                   log.error("selfHealSchedules failed: \(String(describing: error), privacy: .public)")
               }
           }
       }
       ```

       Extend `registerDarwinFinalizeObserver()` (rename to `registerDarwinObservers()` if cleaner, but keep backward-compat name on first call site):
       ```swift
       private func registerDarwinObservers() {
           registerDarwinObserver(name: Self.darwinSessionFinalizedName)
           registerDarwinObserver(name: Self.darwinScheduleStartedName)   // NEW
           registerDarwinObserver(name: Self.darwinScheduleEndedName)     // NEW
       }

       private func registerDarwinObserver(name: String) {
           let center = CFNotificationCenterGetDarwinNotifyCenter()
           let observer = Unmanaged.passUnretained(self).toOpaque()
           let cfName = CFNotificationName(name as CFString)
           CFNotificationCenterAddObserver(
               center, observer,
               { _, observer, _, _, _ in
                   guard let observer else { return }
                   let vm = Unmanaged<AppRootViewModel>.fromOpaque(observer).takeUnretainedValue()
                   Task { @MainActor in vm.refreshStatus() }
               },
               cfName.rawValue, nil, .deliverImmediately
           )
           logger.info("darwin observer registered: \(name, privacy: .public)")
       }
       ```

       Call `registerDarwinObservers()` from `init()` instead of the old `registerDarwinFinalizeObserver()`. Remove the old method if it's only called from init.

       For the existing `testRefreshStatusCallsAllFiveUseCases` test — rename to `testRefreshStatusCallsAllSevenUseCases` and update assertion: 5 Phase 1-3 UCs + 2 Phase 5 UCs = 7. Or keep the existing name green with count-delta semantics.

    3. `mcp__XcodeBuildMCP__test_sim` scoped to AppRootViewModelTests — previous 10 tests still pass + 2 new tests pass → 12 total. Full suite green.

    Commit: `feat(05-04): wire schedule UCs + Darwin observers into AppRootViewModel refreshStatus`.
  </behavior>
  <action>
    See `<behavior>`. Exact identifiers:
    - Properties: `consumeScheduleMarker: ConsumeScheduleEventMarkerUseCase`, `selfHealSchedules: SelfHealSchedulesUseCase` — both with `@ObservationIgnored @LazyInjected`
    - Darwin names: `"com.kksw.DeluluDetox.scheduleStarted"` / `"com.kksw.DeluluDetox.scheduleEnded"` — literals match Plan 05 DAM contract
    - refreshStatus() order: reconcile → finalize → selfHeal → revocation → **consumeScheduleMarker** → **selfHealSchedules** (Pitfall 8: consume marker before self-heal)
    - Test rename: existing `testRefreshStatusCallsAllFiveUseCases` → `testRefreshStatusCallsAllSevenUseCases`, assert all 7 mocks callCount == 1
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Root/AppRootViewModelTests — expect all prior tests + 2 new tests pass. Then full suite test_sim: 0 failures.</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "consumeScheduleMarker" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` >= 2 (property + eager capture + await call — typically 3)
    - `grep -c "selfHealSchedules" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` >= 2
    - `grep -c "com.kksw.DeluluDetox.scheduleStarted" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` == 1
    - `grep -c "com.kksw.DeluluDetox.scheduleEnded" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` == 1
    - The consumeScheduleMarker await appears BEFORE selfHealSchedules await in the Task body: `awk '/try await consumeScheduleMarker/{c=NR} /try await selfHealSchedules/{s=NR} END{exit !(c>0 && s>0 && c<s)}' DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` exits 0
    - `grep -c "testRefreshStatusCallsAllSevenUseCases\|testRefreshStatusCallsScheduleUCsAfterSessionUCs" DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift` >= 1
    - `grep -c "testScheduleDarwinNotificationTriggersRefresh" DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift` == 1
    - `mcp__XcodeBuildMCP__test_sim` full suite: 0 failures; test count grew by ~17 across Plan 04 (6+7+4 = 17 UC tests + 2 AppRoot tests = 19 compared with Plan 03 baseline)
  </acceptance_criteria>
  <done>
    AppRootViewModel wired for Phase 5 self-heal + Darwin observers. 2 new tests + prior tests green. Full suite green. Committed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| UI thread / async Task | `@LazyInjected` resolution race — fixed by eager-capture pattern (Phase 3 06 lesson) |
| Darwin notification center / MainActor | Cross-process signal may fire during tearDown in tests — MainActor.run hop guards |
| Feature boundary Scheduling → AppSelection | `SelfHealSchedulesUseCase` consumes `ObserveBlocklistUseCase` (UC-level cross-feature — sanctioned per Phase 3 precedent); NEVER reaches into BlocklistRepository |
| UserDefaults suite | `last-applied` flags stored in dedicated suite; concurrent writes from SelfHeal + ConsumeEventMarker are MainActor-serialized through UC chain |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-05-04-01 | Tampering | Sync UC rollback fails mid-way (upsert throws) | accept | `try? await repository.upsert(prior)` is best-effort; original error rethrows regardless |
| T-05-04-02 | DoS | DIContainer-reset race in async Task | mitigate | Eager UC capture before Task spawn in AppRootViewModel (Phase 3 06 pattern) |
| T-05-04-03 | Elevation of Privilege | Scheduling feature reaches into AppSelection Repository | mitigate | `SelfHealSchedulesUseCase` injects `ObserveBlocklistUseCase` (AppSelection's public UC surface), never `BlocklistRepository` |
| T-05-04-04 | Information Disclosure | Compute UC leaks schedule details via logs | mitigate | Compute UC has no logger; only SelfHeal logs — and only UUIDs + `.public` |
| T-05-04-05 | Repudiation | Self-heal silently no-ops on blocklist unavailable | mitigate | Log `"blocklist unavailable — skipping apply paths"` at `.info` so field reports can distinguish |
| T-05-04-06 | Spoofing | Attacker posts Darwin notification from another app | accept | Darwin notification names are not secret; attacker could spoof but App Group sandbox limits file reads to our targets — worst case: unnecessary refreshStatus() |
| T-05-04-07 | DoS | Darwin notification flood causes refreshStatus storm | accept | `.deliverImmediately` + `refreshStatus()` is idempotent; worst case: extra UC calls, no correctness impact |
| T-05-04-08 | Tampering | User clock-skew bypass defeats compute | mitigate | `ScheduleShieldRepository.applyShield` sets requireAutomaticDateAndTime=true when shield first applies; compute UC accepts `now: Date` injected from caller (could be tested with faked clock, production uses `Date()`) |
</threat_model>

<verification>
1. `mcp__XcodeBuildMCP__test_sim` full suite — 0 failures. Test count grew by ≥19 over Plan 03.
2. `git log --oneline -4` shows 4 commits from this plan.
3. Bootstrap order in `DeluluDetoxApp.init()` unchanged (Scheduling still between Session and Denial).
4. `SchedulingInjection.register(in:)` has exactly 3 `.application` + 7 `.unique` registrations.
5. `grep -c "await consumeScheduleMarker" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` == 1; same for `await selfHealSchedules`.
</verification>

<success_criteria>
- 5 new UseCase files implemented (ObserveSchedule, Sync, Toggle, Compute, SelfHeal).
- SchedulingInjection fully registers 10 types (3 repos + 7 UCs).
- AppRootViewModel.refreshStatus() extended with 2 schedule UC steps (consume marker BEFORE self-heal).
- 2 new Darwin observers (`scheduleStarted`, `scheduleEnded`) registered alongside existing session observer.
- 17 new UC tests + 2 new AppRoot tests green.
- MockObserve/Toggle/Sync/SelfHeal/Compute mocks complete with call-order tracking where tests require.
- All Phase 1-4 tests still green; no regressions.
</success_criteria>

<output>
After completion, create `.planning/phases/05-scheduled-blocking/05-04-SUMMARY.md`. List the 10 DI registrations, confirm AppRoot insertion order (session before schedule), and any resolution-race issues encountered.
</output>
