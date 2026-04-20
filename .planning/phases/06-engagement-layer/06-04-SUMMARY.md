---
phase: 06-engagement-layer
plan: 04
subsystem: notifications
tags: [swift, swiftui, usernotifications, xctest, clean-architecture, di-distributed, tdd, ntf-02, reconcile, cross-midnight]

# Dependency graph
requires:
  - phase: 06-engagement-layer
    plan: 02
    provides: LocalNotificationRepository (add / removePendingNotificationRequests(withIdentifierPrefix:) / authorizationStatus) + NotificationCaptionLibrary.scheduleStartCopy + MockLocalNotificationRepository
  - phase: 06-engagement-layer
    plan: 03
    provides: NotificationsInjection (extends the same DI file with the new UC registration) — NOT a behavioral dependency, just DI co-location
  - phase: 05-scheduled-blocking
    provides: Schedule model (daysOfWeek / startHour / crossesMidnight) + SyncScheduleWithSystemUseCase (extended in-place with the new dep) + AppRootViewModel.refreshStatus chain (extended with the foreground hook) + ObserveScheduleUseCase publisher
provides:
  - ReconcileScheduleNotificationsUseCase (NTF-02 full-replace reconcile — remove-then-add per-weekday UNCalendarNotificationTrigger with explicit calendar+TZ)
  - MockReconcileScheduleNotificationsUseCase (shared test double for downstream tests)
  - Integration hooks at §H3 (SyncScheduleWithSystemUseCase — both enable + disable paths, skipped on throw) and §H4 (AppRootViewModel.refreshStatus foreground)
affects: [06-05-stats-screen (unaffected — stats UCs do not touch notifications)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Full-replace reconcile (remove-prefix then add) — simpler + more robust than diffing per-identifier state (RESEARCH §Pattern 3)"
    - "Explicit `calendar = .gregorian` + `timeZone = .current` on every DateComponents (RESEARCH Pitfall 7 — prevents wall-clock drift when system calendar/TZ differs)"
    - "Cross-midnight (endH,endM <= startH,startM): notify ONLY at user-visible start (CONTEXT §D-18). Morning DAS segment does NOT get a notification"
    - "Auth gate inside reconcile: non-authorized status still clears stale pending defensively (removes-then-early-return)"
    - "Empty daysOfWeek still clears stale pending (defensive); adds zero new"
    - "Deterministic caption rotation via first unicode scalar of uuidString &+ weekday — same weekday across restarts gives the same caption, but different weekdays can rotate"
    - "SyncScheduleWithSystemUseCase reconciles on BOTH enable (after startMonitoring success) AND disable (early-return); on startMonitoring throw we SKIP reconcile — pending state is allowed to stay in lockstep with the prior-snapshot rollback"
    - "AppRootViewModel foreground reconcile: pass-through for enabled AND disabled schedules — the UC itself handles enabled=false by removing stale. No gating at the VM layer"
    - "Combine `.first().sink` → `CheckedContinuation` bridge: reused from `SyncScheduleWithSystemUseCaseImpl.currentSnapshot(for:)` pattern — cancellable cancels after resume"

key-files:
  created:
    - DeluluDetox/Sources/Features/Notifications/UseCase/ReconcileScheduleNotificationsUseCase.swift
    - DeluluDetoxTests/Features/Notifications/ReconcileScheduleNotificationsUseCaseTests.swift
    - DeluluDetoxTests/Features/Notifications/Mocks/MockReconcileScheduleNotificationsUseCase.swift
  modified:
    - DeluluDetox/Sources/Features/Notifications/Injection/NotificationsInjection.swift
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift
    - DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift
    - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
    - DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift
    - DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift

key-decisions:
  - "Cross-midnight notifies ONLY at evening start (user-visible startHour/Minute). Per CONTEXT §D-18 + Phase 5 §D-03, the morning DAS segment (00:00 → endHour) is a technical artifact of the DAS split; notifying the user at 00:00 would be confusing and is already implied by the evening banner. Verified by testCrossMidnight_schedulesOnlyEveningSegment."
  - "On startMonitoring throw: SKIP reconcile. Pending state is left reflecting the prior-snapshot state that `repository.upsert(prior)` rolls back to. Proactively removing pending on throw would create a mismatch between schedule.json (restored to prior) and pending (cleaned). Verified by testDoesNotReconcileNotifications_whenStartMonitoringThrows."
  - "Foreground reconcile passes BOTH enabled and disabled schedules through the UC. The UC's disabled branch removes stale pending — which is exactly what we want after an external schedule.json mutation or an iOS eviction event. Verified by testForegroundHook_reconcilesAllSchedules."
  - "Deterministic caption rotation uses first-unicode-scalar &+ weekday (Plan 06-03 pattern) so the same weekday across restarts yields the same caption. Different weekdays rotate across the 3-variant library — user gets varied copy within a week."
  - "Full-replace (remove-prefix then add-all) over diffing: simpler + robust against iOS pending-eviction edge cases. No pending-count concern — MVP has ≤7 schedule.start + ≤1 session.end ≪ 64 cap (RESEARCH Pitfall 10)."

patterns-established:
  - "Reconcile UCs own the full-replace contract end-to-end (remove-prefix + add-all in one atomic sequence) — callers never need to know about the prefix or per-identifier formation"
  - "AppRootViewModel.refreshStatus is the single foreground coalescing point — Phase 2/3/5/6 UCs all cascade through it in documented order. Publisher-backed UCs (ObserveScheduleUseCase) are captured via Combine first().sink inside the fire-and-forget Task"
  - "SUT factory pattern in SyncScheduleWithSystemUseCaseTests — returns a tuple of (uc, repo, monitoring, reconcile) so integration tests can assert on any mock without re-constructing dependencies"

requirements-completed: [NTF-02]

# Metrics
duration: ~12min
completed: 2026-04-21
---

# Phase 6 Plan 04: NTF-02 Schedule Reminder Reconciliation Summary

**Full-replace `schedule.start.{id}.*` reconcile on save/toggle/foreground — evening-only on cross-midnight schedules — explicit calendar+TZ on every DateComponents — auth-gated + defensive stale cleanup — all wired with 14 new tests green and full 287-test suite passing (3 skipped, 0 failures).**

## Performance

- **Started:** 2026-04-21T00:46:00Z (approx)
- **Completed:** 2026-04-21T00:58:00Z
- **Tasks:** 2 (both TDD auto)
- **Files created:** 3 (1 UC + 1 mock + 1 test file)
- **Files modified:** 6 (4 production + 2 test files)
- **New test count:** 14 (10 ReconcileScheduleNotificationsUseCase + 3 SyncScheduleWithSystemUseCase ext + 1 AppRootViewModel ext)
- **Full suite:** 287 tests / 3 skipped / 0 failures / ~1.2s XCTest runtime (up from 273 in Plan 03)

## Accomplishments

- **ReconcileScheduleNotificationsUseCase** — full-replace reconcile: `await repository.removePendingNotificationRequests(withIdentifierPrefix: "schedule.start.{id}.")` FIRST, then (only when enabled + authorized + non-empty daysOfWeek) per-weekday `UNCalendarNotificationTrigger(dateMatching: DateComponents(calendar: .gregorian, timeZone: .current, hour: schedule.startHour, minute: schedule.startMinute, weekday: weekday), repeats: true)` added via `repository.add(_:)`. Best-effort per-request (UN add errors are logged + swallowed).
- **MockReconcileScheduleNotificationsUseCase** — appends each received schedule to `receivedSchedules` for ordering + count + id assertions.
- **SyncScheduleWithSystemUseCaseImpl** — gained `reconcileNotifications: ReconcileScheduleNotificationsUseCase` dep. Reconcile fires on BOTH the enabled path (after `startMonitoring` succeeds) AND the disabled early-return path (so pending get cleaned). On `startMonitoring` throw we intentionally SKIP reconcile — the catch block's `repository.upsert(prior)` rollback leaves pending in lockstep with the restored prior snapshot.
- **SchedulingInjection** — resolver-closure threaded with `reconcileNotifications: c.resolve()`. NotificationsInjection runs FIRST in DeluluDetoxApp.init() bootstrap so the container has the UC by the time SchedulingInjection resolves.
- **AppRootViewModel.refreshStatus (Phase 6 §H4)** — added two `@LazyInjected` properties (`observeSchedule` + `reconcileScheduleNotifications`); in the foreground Task, AFTER the existing Phase 2/3/5 UC chain, snapshot `observeSchedule()` via a new static `firstSchedulesSnapshot(_:)` helper (Combine first+sink → CheckedContinuation) and reconcile each schedule (enabled + disabled both passed through). Idempotent — safe to call every foreground.
- **NotificationsInjection** — appended `ReconcileScheduleNotificationsUseCase` registration (scope `.unique`) AFTER Plan 06-03's 3 UC registrations (LocalNotificationRepository + captions library + NTF-01 UCs + D-13 prompt). Merged cleanly, no overwrite.
- **SyncScheduleWithSystemUseCaseTests** — refactored to a `makeSUT(...)` factory that constructs `(uc, repo, monitoring, reconcile)` tuples. All 4 pre-existing tests preserved (unchanged behavior); 3 new `testReconcilesNotifications*` tests cover the §H3 hook surface.
- **AppRootViewModelTests** — setUp registers two new mocks (`MockObserveScheduleUseCase` + `MockReconcileScheduleNotificationsUseCase`) in DIContainer; new `testForegroundHook_reconcilesAllSchedules` seeds publisher with one enabled + one disabled schedule, calls `vm.refreshStatus()`, sleeps 100ms, and asserts BOTH schedules reached the mock reconcile.

## Task Commits

1. **Task 1: ReconcileScheduleNotificationsUseCase + mock + 10 tests (TDD green)** — `5ab075a` (feat)
2. **Task 2: Wire reconcile into Sync/SchedulingInjection/AppRootViewModel + 4 integration tests — full 287-suite green** — `59ee564` (feat)

## Reconcile Algorithm — Decision Table

| `schedule.enabled` | `authorizationStatus` | `daysOfWeek` | Behavior |
|---|---|---|---|
| false | any | any | Remove prefix → return (no add) |
| true | `.denied` / `.notDetermined` / `.ephemeral` / `.provisional` | any | Remove prefix → return (no add, defensive cleanup) |
| true | `.authorized` | empty | Remove prefix → return (no add, defensive cleanup) |
| true | `.authorized` | non-empty | Remove prefix → iterate weekdays → add one UNCalendarNotificationTrigger each |

The remove-prefix step ALWAYS runs first — whether or not we'll add. That's the "full replace with defensive cleanup" contract: a schedule that was enabled yesterday and is disabled today still gets its pending requests cleared today.

## Integration Hook Sites

| UseCase | Hook | Position | Guard |
|---------|------|----------|-------|
| `SyncScheduleWithSystemUseCaseImpl.callAsFunction` (enabled path) | `await reconcileNotifications(schedule:)` | AFTER `try await monitoring.startMonitoring(schedule:)` succeeds, BEFORE `Self.log.info("schedule synced ...")` | None — reconcile owns its own gates internally |
| `SyncScheduleWithSystemUseCaseImpl.callAsFunction` (disabled early-return) | `await reconcileNotifications(schedule:)` | AFTER `monitoring.stopMonitoring` + inside the `guard schedule.enabled else {}` block, BEFORE the disabled log and `return` | Reached only when `!schedule.enabled` — schedule's disabled flag drives the UC's internal skip |
| `AppRootViewModel.refreshStatus` foreground Task | `for schedule in schedules { await reconcileScheduleNotifications(schedule:) }` | AFTER the Phase 05 `selfHealSchedules(now:)` call, BEFORE the Task closure ends | None — pass-through for all schedules (enabled + disabled) |

## Cross-Midnight Fixture Proof (D-18)

Test: `testCrossMidnight_schedulesOnlyEveningSegment`

```swift
let sch = schedule(daysOfWeek: [2, 3], startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)
XCTAssertTrue(sch.crossesMidnight, "fixture sanity")

await sut(schedule: sch)

XCTAssertEqual(repo.addedRequests.count, 2, "two weekdays × one segment (evening only)")
for req in repo.addedRequests {
    let trigger = try XCTUnwrap(req.trigger as? UNCalendarNotificationTrigger)
    XCTAssertEqual(trigger.dateComponents.hour, 22, "MUST be evening start, not morning segment")
    XCTAssertEqual(trigger.dateComponents.minute, 0)
    XCTAssertNotEqual(trigger.dateComponents.hour, 6, "morning segment MUST be skipped per D-18")
}
```

Zero requests with `hour == 6` are added. The morning DAS segment (Phase 5 §D-03) is a technical detail of the DAS split — it does NOT surface to NTF-02.

## New DI Registration (merged with Plan 06-03)

Final `NotificationsInjection.register(in:)` body after Plan 06-04:

```swift
container.register(LocalNotificationRepository.self, scope: .application) { _ in LiveLocalNotificationRepository() }
container.register(NotificationCaptionLibrary.self, scope: .application) { _ in NotificationCaptionLibrary() }
// NTF-01 (Plan 06-03)
container.register(ScheduleSessionEndNotificationUseCase.self, scope: .unique) { c in ... }
container.register(CancelSessionEndNotificationUseCase.self, scope: .unique) { c in ... }
// D-13 lazy prompt (Plan 06-03)
container.register(SchedulePermissionPromptUseCase.self, scope: .unique) { c in ... }
// NTF-02 reconcile (Plan 06-04) — NEW, appended after 06-03 registrations
container.register(ReconcileScheduleNotificationsUseCase.self, scope: .unique) { c in
    ReconcileScheduleNotificationsUseCaseImpl(repository: c.resolve(), captions: c.resolve())
}
```

Registration order: NotificationsInjection runs FIRST in `DeluluDetoxApp.init()` (Plan 02 Summary §"Bootstrap ordering" — confirmed unchanged in Plan 03). SchedulingInjection runs later and its `SyncScheduleWithSystemUseCase` resolver closure successfully resolves `ReconcileScheduleNotificationsUseCase` because Notifications registered it first.

## SchedulingInjection Diff (resolver closure)

**Before:**
```swift
container.register(SyncScheduleWithSystemUseCase.self, scope: .unique) { c in
    SyncScheduleWithSystemUseCaseImpl(
        monitoring: c.resolve(),
        repository: c.resolve()
    )
}
```

**After:**
```swift
container.register(SyncScheduleWithSystemUseCase.self, scope: .unique) { c in
    SyncScheduleWithSystemUseCaseImpl(
        monitoring: c.resolve(),
        repository: c.resolve(),
        reconcileNotifications: c.resolve()   // NEW — Plan 06-04 §H3
    )
}
```

## AppRootViewModel Diff Summary

- 2 new `@LazyInjected` properties: `observeSchedule` + `reconcileScheduleNotifications`
- 2 new local captures in `refreshStatus()` Task: `let observeSchedule = self.observeSchedule` + `let reconcileScheduleNotifications = self.reconcileScheduleNotifications`
- 4 new lines at the end of the Task body: `firstSchedulesSnapshot` call + `for ... await reconcileScheduleNotifications(schedule:)`
- 1 new static helper: `firstSchedulesSnapshot(_ observe:) async -> [Schedule]` (Combine first+sink → CheckedContinuation; cancellable cancels after resume)

## Test Methods Added

### `ReconcileScheduleNotificationsUseCaseTests` (10 — Task 1)

| Test | Assertion |
|------|-----------|
| `testEnabledMonToFri_createsFiveWeekdayRequests` | 5 requests added, sorted identifiers match `schedule.start.{id}.{2..6}`, each is UNCalendarNotificationTrigger with repeats=true and hour=9/minute=0 |
| `testExplicitCalendarAndTimeZone_onDateComponents` | `trigger.dateComponents.calendar?.identifier == .gregorian` AND `timeZone == TimeZone.current` (RESEARCH Pitfall 7) |
| `testRemovesStaleFirst_beforeAdd` | `removedPrefixes` contains the id prefix; unrelated `schedule.start.OTHER.3` stays in stubPending |
| `testDisabled_removesAllPendingForId_addsNothing` | enabled=false → no adds; `removedPrefixes == ["schedule.start.{id}."]` |
| `testNotAuthorized_removesStaleButDoesNotAdd` | auth=.denied → no adds; stale cleanup still runs |
| `testCrossMidnight_schedulesOnlyEveningSegment` | 22:00→06:00 → 2 requests, each hour=22 (never 6) |
| `testSingleDay_endHourGreaterThanStartHour_createsOneRequestPerWeekday` | 1 weekday → 1 request with weekday=6, hour=9 |
| `testCaption_usesCaptionLibrary` | body is one of `captions.scheduleStartCaptions`, no raw `%d` |
| `testContent_carriesScheduleIdAndKindInUserInfo` | userInfo `kind == "schedule-start"` AND `scheduleId == id.uuidString` |
| `testEmptyDaysOfWeek_addsNothing` | daysOfWeek=[] + enabled=true → no adds; stale still cleared |

### `SyncScheduleWithSystemUseCaseTests` (+3 — Task 2)

| Test | Assertion |
|------|-----------|
| `testReconcilesNotifications_afterStartMonitoringSuccess` | Enabled + startMonitoring OK → `reconcile.receivedSchedules == [s]`, last enabled=true |
| `testReconcilesNotifications_onDisabledEarlyReturn` | enabled=false → `reconcile.receivedSchedules == [s]`, last enabled=false (stale cleanup still fires in UC) |
| `testDoesNotReconcileNotifications_whenStartMonitoringThrows` | Enabled + startMonitoring throws → `reconcile.receivedSchedules.isEmpty` (skip reconcile; rollback handles prior-snapshot restoration) |

### `AppRootViewModelTests` (+1 — Task 2)

| Test | Assertion |
|------|-----------|
| `testForegroundHook_reconcilesAllSchedules` | Publisher emits [enabled, disabled] → `refreshStatus()` fires → `mockReconcileScheduleNotifications.receivedSchedules.count == 2` (both ids present — VM does not gate on enabled flag; UC handles it) |

## Decisions Made

- **Cross-midnight = evening-only notification** (CONTEXT §D-18). The morning segment (00:00 → endHour) is a Phase 5 DAS split detail; surfacing it to the user as a 00:00 banner would be confusing and duplicative. Evening start (e.g., 22:00) is the user-visible "blockade starts" moment.
- **On startMonitoring throw: skip reconcile.** Rollback semantics are already handled by the catch block's `repository.upsert(prior)` which restores the prior schedule snapshot. If we also removed pending notifications, we'd be cleaner-than-source-of-truth; leaving them reflecting prior state keeps the two surfaces in lockstep. Documented inline as a comment in the catch block.
- **Full-replace over diffing.** Removing all `schedule.start.{id}.*` and re-adding is simpler and more defensively correct against iOS pending-eviction. Pending-cap isn't a concern: MVP ≤7 per schedule ≪ 64 (RESEARCH Pitfall 10).
- **Foreground reconcile passes enabled AND disabled schedules.** The VM doesn't know the UC's gating logic — it delegates. The UC handles enabled=false by removing stale, which is exactly what we want if iOS evicted requests and the schedule happened to be disabled since.
- **Explicit `calendar = .gregorian` + `timeZone = .current`** on every DateComponents. Pitfall 7 mandate; without it, iOS uses the currentCalendar at trigger-fire time and a weekday interpretation can drift if system calendar changes between scheduling and firing.

## Deviations from Plan

None. Plan executed exactly as written. Both tasks compiled + tested green on first attempt.

No Rule 1 bugs, no Rule 2 missing functionality, no Rule 3 blocking issues, no Rule 4 architectural changes. No comment-vs-grep collisions (unlike Plans 02 and 03).

## Auth Gates

None encountered — this plan is entirely unit-testable against `MockLocalNotificationRepository` (authorized / denied / notDetermined stubs). No actual iOS notification authorization was triggered during execution; the D-13 lazy prompt is upstream in Plan 06-03's `FinalizeSessionFromMarkerUseCase`.

## Known Stubs

None. `ReconcileScheduleNotificationsUseCase` is fully wired, implemented, and exercised by 10 dedicated unit tests + 3 integration tests + 1 foreground test. No TODO markers, no placeholder bodies.

Caption drafts in `NotificationCaptionLibrary.scheduleStartCaptions` were seeded by Plan 02; Plan 04 consumes them via `scheduleStartCopy(for: hashBase &+ weekday)`. Drafts are pending pre-ship polish per CONTEXT §D-17 (already called out in Plan 02 SUMMARY) but are NOT blocking stubs — the array is non-empty and the UC renders real copy.

## Threat Flags

None new. All 5 threats from the plan's `<threat_model>` are addressed:

| Threat | Disposition | Verified by |
|--------|-------------|-------------|
| T-06-04-01 (wall-clock drift) | mitigate — explicit .gregorian + TimeZone.current | `testExplicitCalendarAndTimeZone_onDateComponents` |
| T-06-04-02 (lock-screen scheduleId leak) | accept — opaque UUID, captions have no PII | manual caption review + userInfo shape test |
| T-06-04-03 (64-pending cap) | accept — MVP ≪ 64 | RESEARCH Pitfall 10 analysis |
| T-06-04-04 (spoofing on disabled) | mitigate — reconcile called on disable path | `testDisabled_removesAllPendingForId_addsNothing` + `testReconcilesNotifications_onDisabledEarlyReturn` |
| T-06-04-05 (externally-mutated schedule.json) | accept — MVP main-app sole writer | Phase 2/5 invariant (no test) |

No new security surface beyond the plan's threat register.

## Issues Encountered

- **Simulator UUID drift (carried from Plans 06-01/02/03).** CLAUDE.md lists `C958163F-…` but the booted simulator is `6D73311F-3541-4B74-92E8-8014FABC3329`. Used the booted UUID. Future CLAUDE.md update should capture this.

No other issues. Clean run.

## User Setup Required

None — all changes compile + link + test on the existing simulator with no new entitlements, no new frameworks, no external services.

## Next Phase Readiness

- **Plan 05 (Stats screen) unblocked.** Stats UCs don't touch notifications; no surface overlap.
- **NTF-02 end-to-end complete.** Manual device UAT candidates for Plan 06's phase-wide validation sweep:
  1. Save a Mon-Fri 09:00 schedule with `.authorized` — UNUserNotificationCenter should have 5 pending `schedule.start.{uuid}.{2..6}` requests.
  2. Toggle the schedule OFF — all 5 should vanish from pending.
  3. Save a cross-midnight 22:00→06:00 schedule — only the evening weekdays at hour=22 should be pending (zero hour=6).
  4. Kill + cold-relaunch app with schedule enabled — foreground reconcile should re-populate pending idempotently (test passes in unit; device UAT confirms iOS pending DB round-trip).
- **Phase 5 regression-proof.** All Phase 5 Scheduling tests green in the 287-suite run. `SyncScheduleWithSystemUseCase` SUT factory refactor is backward-compatible: 4 pre-existing tests unchanged in assertions.

## Self-Check: PASSED

**Files exist:**
- `DeluluDetox/Sources/Features/Notifications/UseCase/ReconcileScheduleNotificationsUseCase.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/Mocks/MockReconcileScheduleNotificationsUseCase.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/ReconcileScheduleNotificationsUseCaseTests.swift` — FOUND

**Files modified:**
- `DeluluDetox/Sources/Features/Notifications/Injection/NotificationsInjection.swift` — MODIFIED (NTF-02 registration appended after Plan 06-03 block)
- `DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift` — MODIFIED (init gained 3rd param; reconcile called on both enable + disable paths)
- `DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` — MODIFIED (resolver closure threaded with `reconcileNotifications: c.resolve()`)
- `DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` — MODIFIED (2 @LazyInjected props + foreground reconcile loop + firstSchedulesSnapshot static helper)
- `DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift` — MODIFIED (SUT factory + 3 new tests)
- `DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift` — MODIFIED (2 new mocks registered + 1 new test)

**Commits exist:**
- `5ab075a` (Task 1 — `feat(06-04): add NTF-02 ReconcileScheduleNotificationsUseCase + mock + 10 tests green`) — FOUND
- `59ee564` (Task 2 — `feat(06-04): wire NTF-02 reconcile into Sync/AppRoot + DI — 287/287 suite green`) — FOUND

**Test suite:**
- `xcrun xcodebuild test -project DeluluDetox.xcodeproj -scheme DeluluDetox -destination 'platform=iOS Simulator,id=6D73311F-3541-4B74-92E8-8014FABC3329'` → 287/287 passed, 3 skipped, 0 failures, exit 0

**Acceptance-criteria greps (all met):**
- `protocol ReconcileScheduleNotificationsUseCase` in UC = 1 ✓
- `schedule.start.\(schedule.id.uuidString)` in UC = 2 (≥2 ✓)
- `repeats: true` in UC = 1 ✓
- `Calendar(identifier: .gregorian)` in UC = 1 ✓
- `TimeZone.current` in UC = 1 ✓
- `components.weekday = weekday` in UC = 1 ✓
- `reconcileNotifications: ReconcileScheduleNotificationsUseCase` in SyncScheduleWithSystemUseCase.swift = 2 (≥2 ✓)
- `await reconcileNotifications(schedule:` in SyncScheduleWithSystemUseCase.swift = 2 ✓
- `reconcileNotifications: c.resolve()` in SchedulingInjection.swift = 1 ✓
- `ReconcileScheduleNotificationsUseCase.self` in NotificationsInjection.swift = 1 ✓
- `reconcileScheduleNotifications` in AppRootViewModel.swift = 3 (≥2 ✓)
- `testReconcilesNotifications` in SyncScheduleWithSystemUseCaseTests.swift = 2 (≥2 ✓)
- Dedicated test count = 10 (≥10 ✓)

---
*Phase: 06-engagement-layer*
*Completed: 2026-04-21*
