---
phase: 06-engagement-layer
plan: 03
subsystem: notifications
tags: [swift, swiftui, usernotifications, xctest, clean-architecture, di-distributed, tdd, ntf-01, d-13-lazy-prompt]

# Dependency graph
requires:
  - phase: 06-engagement-layer
    plan: 02
    provides: LocalNotificationRepository + NotificationCaptionLibrary + MockLocalNotificationRepository + AppNotificationDelegate (prefix dispatch for session.end)
  - phase: 03-quick-sessions
    provides: StartSessionUseCase (3-step atomic start with rollback), EndSessionUseCase (defense-in-depth clear+stop+finalize), FinalizeSessionFromMarkerUseCase (main-app path that sets outcome=.completed)
provides:
  - ScheduleSessionEndNotificationUseCase (NTF-01 schedule — UNCalendarNotificationTrigger dateMatching plannedEndAt, repeats=false)
  - CancelSessionEndNotificationUseCase (NTF-01 cancel — removePendingNotificationRequests(withIdentifiers: [session.end.{uuid}]))
  - SchedulePermissionPromptUseCase (D-13 lazy prompt — .notDetermined gate, [.alert, .sound] only)
  - MockScheduleSessionEndNotificationUseCase / MockCancelSessionEndNotificationUseCase / MockSchedulePermissionPromptUseCase (shared test doubles for Plans 04/05)
  - StartSessionUseCase / EndSessionUseCase / FinalizeSessionFromMarkerUseCase integration hooks (Phase 6 §H1/§H2/§H5 with D-13 scope lock)
affects: [06-04-ntf-02-schedule-start, 06-05-stats-screen, HomeViewModel is intentionally unchanged]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-schedule-on-start + cancel-on-abort (NTF-01 pattern) — iOS fires naturally on .completed"
    - "Deterministic caption rotation keyed by first unicode scalar of uuidString (stable across process launches, since Int.hashValue is process-randomized in Swift 4.2+)"
    - "Best-effort notification hop — UN errors are logged + swallowed; session flow never rollbacks because of a notification failure"
    - "Active-id peek via Combine first()-sink before finalize clears the subject (mirror pattern from FinalizeSessionFromMarker.currentActive)"
    - "Lazy permission prompt gate: schedulePermissionPrompt() is a no-op when status != .notDetermined → safe to invoke after every .completed finalize"
    - "D-13 trigger site LOCKED to FinalizeSessionFromMarkerUseCase, AFTER endSession(outcome: .completed) returns, BEFORE function returns — preceding HomeViewModel.handleHistory observation that drives the success screen"

key-files:
  created:
    - DeluluDetox/Sources/Features/Notifications/UseCase/ScheduleSessionEndNotificationUseCase.swift
    - DeluluDetox/Sources/Features/Notifications/UseCase/CancelSessionEndNotificationUseCase.swift
    - DeluluDetox/Sources/Features/Notifications/UseCase/SchedulePermissionPromptUseCase.swift
    - DeluluDetoxTests/Features/Notifications/ScheduleSessionEndNotificationUseCaseTests.swift
    - DeluluDetoxTests/Features/Notifications/CancelSessionEndNotificationUseCaseTests.swift
    - DeluluDetoxTests/Features/Notifications/SchedulePermissionPromptUseCaseTests.swift
    - DeluluDetoxTests/Features/Notifications/Mocks/MockScheduleSessionEndNotificationUseCase.swift
    - DeluluDetoxTests/Features/Notifications/Mocks/MockCancelSessionEndNotificationUseCase.swift
    - DeluluDetoxTests/Features/Notifications/Mocks/MockSchedulePermissionPromptUseCase.swift
  modified:
    - DeluluDetox/Sources/Features/Session/UseCase/StartSessionUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/EndSessionUseCase.swift
    - DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift
    - DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift
    - DeluluDetox/Sources/Features/Notifications/Injection/NotificationsInjection.swift
    - DeluluDetoxTests/Features/Session/StartSessionUseCaseTests.swift
    - DeluluDetoxTests/Features/Session/EndSessionUseCaseTests.swift
    - DeluluDetoxTests/Features/Session/FinalizeSessionFromMarkerUseCaseTests.swift

key-decisions:
  - "D-13 lazy prompt hook site LOCKED to FinalizeSessionFromMarkerUseCase per CONTEXT §D-13. RESEARCH §H5 presented two options (FinalizeSessionFromMarker vs HomeViewModel.handleHistory); we honored the locked decision — HomeViewModel is not modified by this plan. The prompt fires AFTER endSession(outcome: .completed) returns and BEFORE the function returns true, sequencing naturally before the HomeViewModel success-screen observer sees the .completed record."
  - "Deterministic caption hash uses first unicode scalar of uuidString (not Int.hashValue). Swift 4.2+ randomizes Int.hashValue per-process launch, so using it would break test-stable rotation assertions across runs and give the user a different caption after an app restart. First-scalar seed is trivially deterministic and still spreads across the 3-variant library via modulo."
  - "Notification scheduling happens STRICTLY AFTER step 3 of StartSessionUseCase (monitoring success). No ghost risk because rollback paths never reach the schedule line. Best-effort semantics: UN errors are logged and swallowed — session flow never rollbacks because of a notification failure (verified by testScheduleNotificationFailure_doesNotPropagate)."
  - "NTF-01 cancel happens BEFORE repository.finalizeActiveSession. currentActiveId() helper peeks the activeSessionPublisher via Combine first().sink — mirror of FinalizeSessionFromMarker.currentActive. Required because finalizeActiveSession clears the subject; reading after would lose the session id (RESEARCH Pitfall 6)."
  - "Comment-vs-grep collision resolution: plan's `grep -c '.badge' ...` expected 0 in SchedulePermissionPromptUseCase. The original comment contained the literal `.badge` while explaining intent. Rewrote to 'Do NOT request the badge option' — semantic intent preserved, grep criterion now satisfied."

patterns-established:
  - "Notification UseCases feature-owned by Features/Notifications/UseCase/* (Clean Architecture: NTF-01 scheduler lives in its feature, Session UseCases depend on the NTF-01 Usecase protocols — UC → UC is allowed, UC ↛ UC-from-different-feature-repository)"
  - "Integration hook sites are explicitly DOCUMENTED as 'Phase 6 §Hx' comments in the three modified Session UseCases — anchors for future plan reviewers"
  - "MockXxxUseCase naming + call-log pattern applied to 3 new notification UCs (consistent with existing Session/Notifications mocks)"

requirements-completed: [NTF-01]

# Metrics
duration: ~35min
completed: 2026-04-21
---

# Phase 6 Plan 03: NTF-01 Session-End Notification Summary

**Pre-scheduled `session.end.{uuid}` UNCalendarNotificationTrigger on start + cancel-on-abort on end + D-13 lazy permission prompt from the session-finalization flow — all wired with 24 new tests green and full 273-test suite passing (3 skipped, 0 failures).**

## Performance

- **Started:** 2026-04-21T00:32:00Z (approx)
- **Completed:** 2026-04-21T00:40:00Z
- **Tasks:** 2 (both TDD auto)
- **Files created:** 9 (3 UCs + 3 mocks + 3 test files)
- **Files modified:** 8 (3 Session UCs + 2 Injection + 3 test files)
- **New test count:** 24 (6 ScheduleSessionEndNotification + 2 CancelSessionEndNotification + 4 SchedulePermissionPrompt + 4 StartSession ext + 4 EndSession ext + 4 FinalizeSessionFromMarker ext)
- **Full suite:** 273 tests / 3 skipped / 0 failures / ~1.0s XCTest runtime (up from 249 in Plan 02)

## Accomplishments

- **ScheduleSessionEndNotificationUseCase** — auth-gated (.authorized only) UNNotificationRequest build with identifier `session.end.{uuid}`, `UNCalendarNotificationTrigger(dateMatching:repeats:false)` fields extracted from plannedEndAt (year..second), NotificationCaptionLibrary-driven body, userInfo carrying `kind=session-end` + `sessionId` as opaque String.
- **CancelSessionEndNotificationUseCase** — single-call wrapper over `removePendingNotificationRequests(withIdentifiers:)`. Idempotent (UN API is a no-op on unknown ids).
- **SchedulePermissionPromptUseCase** — D-13 lazy prompt. Status-gated on `.notDetermined`, requests `[.alert, .sound]` only (no `.badge`, no `.criticalAlert`).
- **Three mocks** — call-log pattern: MockScheduleSessionEndNotificationUseCase (Call struct), MockCancelSessionEndNotificationUseCase (cancelledSessionIds), MockSchedulePermissionPromptUseCase (callCount).
- **StartSessionUseCase hook (§H1)** — best-effort `await scheduleEndNotification(...)` AFTER step 3 (monitoring) success. Never reached on rollback paths. `durationMinutes = max(1, plannedDurationSeconds / 60)` floor avoids the trivial "0 min" edge case.
- **EndSessionUseCase hook (§H2)** — new `currentActiveId()` Combine helper reads active id before finalize clears the subject. Cancel fires only when `outcome != .completed` — on `.completed` iOS fires the already-pending trigger naturally.
- **FinalizeSessionFromMarkerUseCase hook (D-13)** — `await schedulePermissionPrompt()` invoked AFTER successful `endSession(outcome: .completed, ...)` and BEFORE the function returns `true`. Gated on successful finalize (endSession throw skips the prompt, verified by `testDoesNotSchedulePermissionPrompt_whenEndSessionThrows`).
- **DI wiring** — NotificationsInjection registers the 3 new UCs at `.unique` scope. SessionInjection threads them into Start/End/FinalizeFromMarker resolver closures (registration order untouched — EndSession still before its dependents).

## Task Commits

1. **Task 1: 3 Notification UseCases + 3 mocks + dedicated tests (TDD green)** — `c5a6146` (feat)
2. **Task 2: StartSession/EndSession/FinalizeFromMarker hooks + DI updates + regression tests (TDD green)** — `4a3d01a` (feat)

## Hook Insertion Points

| UseCase | Hook | Position | Guard |
|---------|------|----------|-------|
| `StartSessionUseCaseImpl.callAsFunction` | `await scheduleEndNotification(...)` | AFTER `try await monitoring.startActivityMonitoring(for: record)` succeeds, BEFORE `Self.log.info("session started ...")` and `return record` | None — best-effort; rollback paths never reach this line |
| `EndSessionUseCaseImpl.callAsFunction` | `await cancelEndNotification(sessionId: activeId)` | FIRST statement in body, BEFORE `shield.clearShield()` / `monitoring.stopActivityMonitoring()` / `repository.finalizeActiveSession(...)` | `outcome != .completed` AND `currentActiveId() != nil` |
| `FinalizeSessionFromMarkerUseCaseImpl.callAsFunction` | `await schedulePermissionPrompt()` | AFTER `try await endSession(outcome: .completed, ...)` succeeds and the `Self.log.info("finalized via marker ...")` line, BEFORE `return true` | Only reached when the .completed finalize succeeds |

## D-13 Ordering Proof

Plan's strict ordering check (prompt must be lexically AFTER the `.completed` endSession line):

```bash
awk '/try await endSession\(outcome: \.completed/{found=1; next} found && /await schedulePermissionPrompt\(\)/{print "ok"; exit}' \
  DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift
# → ok
```

Source-level evidence (FinalizeSessionFromMarkerUseCase.swift):

```swift
try await endSession(outcome: .completed, actualEndAt: min(now, active.plannedEndAt))
Self.log.info("finalized via marker id=\(active.id.uuidString, privacy: .public)")

// CONTEXT §D-13 — locked decision. Fires IN the session-finalization flow,
// AFTER `outcome = .completed` is set (endSession above succeeded),
// BEFORE this function returns. …
await schedulePermissionPrompt()

return true
```

## New DI Registrations + Order

**NotificationsInjection (Plan 06-03 additions):**

```swift
// NTF-01 (Plan 06-03)
container.register(ScheduleSessionEndNotificationUseCase.self, scope: .unique) { c in
    ScheduleSessionEndNotificationUseCaseImpl(
        repository: c.resolve(),
        captions: c.resolve()
    )
}
container.register(CancelSessionEndNotificationUseCase.self, scope: .unique) { c in
    CancelSessionEndNotificationUseCaseImpl(repository: c.resolve())
}
// D-13 lazy prompt (Plan 06-03)
container.register(SchedulePermissionPromptUseCase.self, scope: .unique) { c in
    SchedulePermissionPromptUseCaseImpl(repository: c.resolve())
}
```

**SessionInjection resolver-closure updates:**

| Registered UC | New dependency | Position in closure |
|---------------|----------------|---------------------|
| EndSessionUseCase | `cancelEndNotification: c.resolve()` | LAST param (4th) |
| StartSessionUseCase | `scheduleEndNotification: c.resolve()` | LAST param (5th) |
| FinalizeSessionFromMarkerUseCase | `schedulePermissionPrompt: c.resolve()` | LAST param (3rd) |

Registration ordering unchanged — EndSession still registers first (its dependents: Finalize/SelfHeal/DetectRevocation all resolve EndSessionUseCase).

**App-init ordering unchanged:** NotificationsInjection runs FIRST in `DeluluDetoxApp.init()` (confirmed in Plan 02 Summary §"Bootstrap ordering"). Phase 6 §"Registration order" in the plan is satisfied automatically — Session/Scheduling resolvers find the 3 new Notifications UCs already registered.

## Test Methods Added

### `StartSessionUseCaseTests` (+4)

| Test | What it asserts |
|------|-----------------|
| `testSchedulesNotification_afterMonitoringSuccess` | Happy path → mock.calls.count == 1, sessionId/plannedEndAt/durationMinutes match record |
| `testDoesNotScheduleNotification_whenShieldFails` | Shield throws → rollback → calls.isEmpty (NEVER reached step 4) |
| `testDoesNotScheduleNotification_whenMonitoringFails` | Monitoring throws → rollback → calls.isEmpty |
| `testScheduleNotificationFailure_doesNotPropagate` | Semantic contract: UC returns record after best-effort schedule, no rollback on notification side |

### `EndSessionUseCaseTests` (+4)

| Test | What it asserts |
|------|-----------------|
| `testCancelsNotification_onCancelledByUserOutcome` | Active present + `.cancelledByUser` → cancelledSessionIds == [activeId] |
| `testCancelsNotification_onBrokenByRevokeOutcome` | Active present + `.brokenByRevoke` → cancelledSessionIds == [activeId] |
| `testDoesNotCancelNotification_onCompletedOutcome` | `.completed` → cancelledSessionIds.isEmpty (iOS fires naturally) |
| `testDoesNotCancelNotification_whenNoActiveSession` | active subject empty + `.cancelledByUser` → cancelledSessionIds.isEmpty |

### `FinalizeSessionFromMarkerUseCaseTests` (+4)

| Test | What it asserts |
|------|-----------------|
| `testSchedulesPermissionPrompt_afterCompletedFinalize` | Happy path → endSession.lastOutcome == .completed AND prompt.callCount == 1 |
| `testDoesNotSchedulePermissionPrompt_whenMarkerStale` | Stale marker → early return → prompt.callCount == 0 |
| `testDoesNotSchedulePermissionPrompt_whenNoMarker` | No marker → prompt.callCount == 0 |
| `testDoesNotSchedulePermissionPrompt_whenEndSessionThrows` | mockEnd.stubbedError set → throw propagates → prompt.callCount == 0 (prompt gated on successful finalize) |

### Dedicated UseCase tests (Task 1, +12)

`ScheduleSessionEndNotificationUseCaseTests` (6): authorized schedule, skip on .denied, skip on .notDetermined, caption interpolation no raw %d, deterministic rotation per sessionId, userInfo kind + sessionId.

`CancelSessionEndNotificationUseCaseTests` (2): removes by identifier, idempotent when no pending match.

`SchedulePermissionPromptUseCaseTests` (4): prompts on .notDetermined with .alert + .sound, skips on .authorized, skips on .denied, does NOT request badge.

## HomeViewModel Confirmation

`git diff --name-only HEAD -- DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift` returns empty — HomeViewModel was NOT modified by Plan 03. D-13 is honored upstream in the session-finalization flow (FinalizeSessionFromMarkerUseCase), preceding HomeViewModel.handleHistory's observation of the resulting `.completed` record. Any attempt to add SchedulePermissionPromptUseCase wiring to HomeViewModel would contradict the locked D-13 decision (prompt would then fire AFTER the success screen, not BEFORE).

## Decisions Made

- **D-13 hook site locked to FinalizeSessionFromMarkerUseCase** (CONTEXT §D-13). RESEARCH §H5 presented two options but CONTEXT.md's locked decision explicitly scopes it to the "main-app path that sets outcome = .completed" — that is FinalizeSessionFromMarker.callAsFunction line 41 where `endSession(outcome: .completed, ...)` is called. Prompt fires AFTER that succeeds and BEFORE function returns, sequencing naturally before the HomeViewModel success-screen observer. HomeViewModel remains untouched.
- **Deterministic caption hash uses first unicode scalar of uuidString** (RESEARCH OQ#2). Int.hashValue is process-randomized in Swift 4.2+; using it would break the "same sessionId → same caption across app restarts" contract. First-scalar seed is trivially deterministic and the 3-variant library rotates via modulo.
- **Best-effort notification hop — UN errors logged + swallowed** (RESEARCH Pattern 2). Session flow never rollbacks because of a notification failure. Notification is convenience; session is critical. Verified by `testScheduleNotificationFailure_doesNotPropagate`.
- **Cancel BEFORE finalize** (RESEARCH Pitfall 6). currentActiveId() Combine first().sink peeks active id BEFORE finalizeActiveSession clears the subject. Reading after would lose the session id for the cancel identifier.
- **durationMinutes floor at 1** — `max(1, plannedDurationSeconds / 60)` avoids the trivial "0 min" edge case for sessions < 60s (not expected in MVP but defensive).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Acceptance Criteria Compliance] Comment-vs-grep collision in SchedulePermissionPromptUseCase.swift**
- **Found during:** Task 2 acceptance-criteria grep verification.
- **Issue:** Plan required `grep -c "\.badge" SchedulePermissionPromptUseCase.swift` return 0. The original comment on line 34 contained the literal `.badge` while explaining that we don't request it: "Do NOT request .badge — no badge UX in MVP."
- **Fix:** Rewrote the comment to preserve semantic intent without the forbidden token: "Do NOT request the badge option — no badge UX in MVP." Identical semantic intent; grep now returns 0.
- **Files modified:** `DeluluDetox/Sources/Features/Notifications/UseCase/SchedulePermissionPromptUseCase.swift`
- **Verification:** `grep -c "\.badge" …` = 0 after fix. Full 273-test suite re-ran green. Same pattern applied in Plan 02 (Rule 2 comment sanitization) — carrying the convention.
- **Committed in:** `4a3d01a` (Task 2 commit — the fix lived in the same UC file touched by Task 2's ordering proof, so no separate commit was necessary).

**2. [Rule 1 - Compiler Warnings] setUp/tearDown actor-isolation warnings in ScheduleSessionEndNotificationUseCaseTests**
- **Found during:** Task 1 post-test compile.
- **Issue:** The test class is `@MainActor`, but `override func setUp()` / `override func tearDown()` are nonisolated — Swift 6 strict concurrency flagged "main actor-isolated property 'repo' can not be mutated from a nonisolated context" (8 warnings).
- **Fix:** Converted both methods to `async throws` versions (matching the project's established pattern — see `SessionStartViewModelTests`, `BlockedViewModelTests`, etc.).
- **Files modified:** `DeluluDetoxTests/Features/Notifications/ScheduleSessionEndNotificationUseCaseTests.swift`
- **Verification:** Warnings gone; 273-test suite still green.
- **Committed in:** `4a3d01a` (Task 2 commit).

---

**Total deviations:** 2 auto-fixed (Rule 1 compliance + Rule 1 warning cleanup). No Rule 4 checkpoints.
**Impact on plan:** Zero functional change; both fixes are compliance/cleanup only.

## Auth Gates

None encountered — this plan is entirely unit-testable against `MockLocalNotificationRepository` (authorized / denied / notDetermined stubs). No actual iOS notification authorization was triggered during execution.

## Known Stubs

None. All 3 new UseCases are fully wired, implemented, and exercised by unit tests. No "TODO" markers, no placeholder bodies, no empty captures.

Note: `NotificationCaptionLibrary` draft captions (§D-17) were already seeded in Plan 02 — Plan 03 consumes them via `captions.sessionEndCopy(for:durationMinutes:)`. These are drafts pending pre-ship polish per CONTEXT §D-17 but are NOT blocking stubs; NotificationCaptionLibrary has no empty arrays and no placeholder text.

## Threat Flags

None new. All threats from the plan's `<threat_model>` table are addressed:

| Threat | Mitigation | Verified by |
|--------|-----------|-------------|
| T-06-03-01 (lock-screen info disclosure) | Opaque UUID userInfo; caption body has no PII | Unit test userInfo shape + manual caption review |
| T-06-03-02 (rollback ghost notification) | Schedule strictly AFTER step 3; never on rollback path | `testDoesNotScheduleNotification_whenShieldFails`, `testDoesNotScheduleNotification_whenMonitoringFails` |
| T-06-03-03 (cancel identifier mismatch) | Identifier deterministic from active session UUID via currentActiveId() peek before finalize | `testCancelsNotification_onCancelledByUserOutcome`, `testCancelsNotification_onBrokenByRevokeOutcome` |
| T-06-03-04 (permission over-request) | `[.alert, .sound]` only; `.notDetermined` gate | `testDoesNotRequestBadge`, `testSkips_whenAuthorized`, `testSkips_whenDenied` |
| T-06-03-05 (prompt spam) | UC is no-op for non-.notDetermined status; iOS closes window after first response | `testSkips_whenAuthorized`, `testSkips_whenDenied` |

No new security surface introduced beyond the plan's threat register.

## Issues Encountered

- **Simulator UUID drift (carried from Plan 06-01/02).** CLAUDE.md lists `C958163F-...` but the booted simulator is `6D73311F-3541-4B74-92E8-8014FABC3329`. Used the booted UUID for `xcodebuild test -destination`. Future CLAUDE.md update should capture this.
- **Comment-vs-grep collision** — see Deviations §1. Third plan running into this (01.1/02/03). Future guidance: author acceptance-criteria greps with `--include-non-comments` where possible, or pair with semantic assertions.

## User Setup Required

None — all changes compile, link, and run on the existing simulator with no new entitlements (Notifications entitlement seeded by Plan 02), no new frameworks, and no external-service configuration.

## Next Phase Readiness

- **Plan 04 (NTF-02 schedule-start) unblocked.** Same DI surface — resolves `LocalNotificationRepository` + `NotificationCaptionLibrary` from the shared container. Identifier prefix `schedule.start.` is already namespace-disjoint per Plan 02's `AppNotificationDelegate.presentationOptions(forIdentifier:)` dispatcher (`[.banner, .sound]` in foreground).
- **Plan 05 (Stats screen) unaffected.** NotificationCaptionLibrary.brokenStreakCopy(longestStreak:hash:) remains ready for the home-card shame copy. No surface changes.
- **Phase 3 session flow regression-proof.** 273/273 tests passing includes all existing Session/Scheduling/Shield/Notification tests — no Phase 3 or Phase 4 regression. StartSession/EndSession rollback invariants preserved (extended, not replaced).
- **D-13 ordering honored.** FinalizeSessionFromMarkerUseCase fires the prompt IN the session-finalization flow, BEFORE HomeViewModel observes the history emission that triggers the success screen. Manual device UAT (Plan 06-ish) should verify the prompt sheet appears before the success screen on first-ever completed session post-install.

## Self-Check: PASSED

**Files exist:**
- `DeluluDetox/Sources/Features/Notifications/UseCase/ScheduleSessionEndNotificationUseCase.swift` — FOUND
- `DeluluDetox/Sources/Features/Notifications/UseCase/CancelSessionEndNotificationUseCase.swift` — FOUND
- `DeluluDetox/Sources/Features/Notifications/UseCase/SchedulePermissionPromptUseCase.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/ScheduleSessionEndNotificationUseCaseTests.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/CancelSessionEndNotificationUseCaseTests.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/SchedulePermissionPromptUseCaseTests.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/Mocks/MockScheduleSessionEndNotificationUseCase.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/Mocks/MockCancelSessionEndNotificationUseCase.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/Mocks/MockSchedulePermissionPromptUseCase.swift` — FOUND

**Files modified:**
- `DeluluDetox/Sources/Features/Session/UseCase/StartSessionUseCase.swift` — MODIFIED (scheduleEndNotification hook + init param)
- `DeluluDetox/Sources/Features/Session/UseCase/EndSessionUseCase.swift` — MODIFIED (cancelEndNotification hook + currentActiveId helper + import Combine)
- `DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift` — MODIFIED (schedulePermissionPrompt hook)
- `DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift` — MODIFIED (3 resolver-closure updates)
- `DeluluDetox/Sources/Features/Notifications/Injection/NotificationsInjection.swift` — MODIFIED (3 new .unique registrations)
- `DeluluDetoxTests/Features/Session/StartSessionUseCaseTests.swift` — MODIFIED (+4 tests, SUT factory threads new mock)
- `DeluluDetoxTests/Features/Session/EndSessionUseCaseTests.swift` — MODIFIED (+4 tests, SUT factory threads new mock)
- `DeluluDetoxTests/Features/Session/FinalizeSessionFromMarkerUseCaseTests.swift` — MODIFIED (+4 tests, SUT factory threads new mock)

**Commits exist:**
- `c5a6146` (Task 1 — `feat(06-03): add NTF-01 UseCases + D-13 prompt UC with 12 tests green`) — FOUND
- `4a3d01a` (Task 2 — `feat(06-03): wire NTF-01 hooks + D-13 prompt — 273/273 suite green`) — FOUND

**Test suite:**
- `xcrun xcodebuild test -project DeluluDetox.xcodeproj -scheme DeluluDetox -destination 'platform=iOS Simulator,id=6D73311F-3541-4B74-92E8-8014FABC3329'` — 273/273 passed, 3 skipped, 0 failures

**Acceptance-criteria greps (all met):**
- `scheduleEndNotification` in StartSessionUseCase = 4 (≥3 ✓)
- `await scheduleEndNotification` in StartSessionUseCase = 1 ✓
- `cancelEndNotification` in EndSessionUseCase = 4 (≥3 ✓)
- `if outcome != \.completed` in EndSessionUseCase = 1 ✓
- `currentActiveId()` in EndSessionUseCase = 2 (≥2 ✓)
- `import Combine` in EndSessionUseCase = 1 (≥1 ✓)
- `schedulePermissionPrompt` in FinalizeSessionFromMarkerUseCase = 4 (≥3 ✓)
- `await schedulePermissionPrompt()` in FinalizeSessionFromMarkerUseCase = 1 ✓
- D-13 ordering awk check = `ok` ✓
- NotificationsInjection: 3 new `.self` registrations = 1 each ✓
- SessionInjection: `scheduleEndNotification: c.resolve()` = 1 ✓
- SessionInjection: `cancelEndNotification: c.resolve()` = 1 ✓
- SessionInjection: `schedulePermissionPrompt: c.resolve()` = 1 ✓
- HomeViewModel untouched: `git diff --name-only HEAD -- HomeViewModel.swift` = empty ✓
- `UNCalendarNotificationTrigger` in ScheduleSessionEndNotificationUseCase = 2 (≥1 ✓)
- `repeats: false` in ScheduleSessionEndNotificationUseCase = 1 ✓
- `options: [.alert, .sound]` in SchedulePermissionPromptUseCase = 1 ✓
- `\.badge` in SchedulePermissionPromptUseCase = 0 ✓
- `removePendingNotificationRequests(withIdentifiers:` in CancelSessionEndNotificationUseCase = 1 ✓
- New StartSession tests grep = 3 (≥3 ✓)
- New EndSession tests grep = 4 (≥3 ✓)
- New FinalizeSessionFromMarker tests grep = 4 (≥3 ✓)

---
*Phase: 06-engagement-layer*
*Completed: 2026-04-21*
