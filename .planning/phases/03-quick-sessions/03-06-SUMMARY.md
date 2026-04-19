---
phase: 03-quick-sessions
plan: "06"
subsystem: Session/ViewModel+View+AppRoot
tags: [viewmodel, view, swiftui, observable, casepathable, countdown, tick-clock, success-screen, home-routing, approot-foreground, tdd]
dependency_graph:
  requires:
    - "03-01: SessionRecord + plannedEndAt + plannedDurationSeconds"
    - "03-03: EndSessionUseCase + FinalizeSessionFromMarkerUseCase + SelfHealExpiredSessionUseCase + DetectRevocationUseCase + MarkSuccessShownUseCase + CheckSuccessShownUseCase + all 9 mocks"
    - "03-05: SessionStartViewModel.Destination.countdownHandoff(SessionRecord)"
    - "02-05: ReconcileBlocklistUseCase (existing AppRoot chain)"
  provides:
    - TickClock protocol + SystemTickClock (DispatchSourceTimer, cancel-on-deinit)
    - CountdownViewModel (@Observable, @MainActor, Destination.confirmEarlyEnd, 1-Hz tick, onDisappear cancel)
    - SessionSuccessViewModel (@Observable, @MainActor, Identifiable, stable sarcastic caption)
    - CountdownView (progress ring, MM:SS / HH:MM:SS, confirmationDialog, navigationBarBackButtonHidden)
    - SessionSuccessView (sparkles, caption, Dzięki wiem CTA, tap-to-dismiss)
    - HomeViewModel extended (5 Destination cases; gotoCountdown bridge; active+history sinks; Mark/CheckSuccessShown UC boundary)
    - HomeView extended (sessionStart + countdown navigationDestination; sessionSuccess sheet; start-session toolbar button)
    - AppRootViewModel extended (FinalizeFromMarker + SelfHeal + DetectRevocation in refreshStatus eager-capture pattern)
  affects:
    - "03-07: P07 UAT walks the full user flow on a physical device"
tech_stack:
  added:
    - "DispatchSourceTimer (SystemTickClock) — 1-Hz main-queue tick with leeway: .milliseconds(50)"
    - "SwiftUINavigation @CasePathable Destination.confirmEarlyEnd(SessionRecord) — confirmationDialog binding"
    - "SessionSuccessViewModel: Identifiable via nonisolated let id: UUID (required by .sheet(item:))"
    - "HomeView body split into contentLayer + sessionStartDestination(@ViewBuilder) helpers — fixes Swift type-checker timeout on complex body"
    - "AppRootViewModel eager UC capture in refreshStatus() — resolves @LazyInjected before Task spawn to prevent DIContainer-reset race in tests"
  patterns:
    - "FakeTickClock + DateBox(@unchecked Sendable) — deterministic tick stepping without captured-var Swift 6 error"
    - "Eager @LazyInjected capture in async spawner (Rule 1 fix) — capture UC refs synchronously on MainActor before Task{} to avoid post-tearDown resolution crash"
    - "nonisolated let id: UUID on @MainActor @Observable class — satisfies Identifiable without crossing MainActor isolation"
key_files:
  created:
    - DeluluDetox/Sources/Features/Session/ViewModel/TickClock.swift
    - DeluluDetox/Sources/Features/Session/ViewModel/CountdownViewModel.swift
    - DeluluDetox/Sources/Features/Session/ViewModel/SessionSuccessViewModel.swift
    - DeluluDetox/Sources/Features/Session/View/CountdownView.swift
    - DeluluDetox/Sources/Features/Session/View/SessionSuccessView.swift
    - DeluluDetoxTests/Features/Session/CountdownViewModelTests.swift
    - DeluluDetoxTests/Features/Session/SessionSuccessViewModelTests.swift
  modified:
    - DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift
    - DeluluDetox/Sources/Features/Home/View/HomeView.swift
    - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
    - DeluluDetox/Sources/DesignSystem/Theme+Session.swift
    - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift
    - DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift
decisions:
  - "Eager UC capture before Task spawn in AppRootViewModel.refreshStatus() — @LazyInjected resolves on first access; if Task defers access past tearDown reset, DIContainer throws fatal. Capturing all 4 UC references on @MainActor before Task{} ensures resolution while container is live."
  - "nonisolated let id: UUID satisfies Identifiable on @MainActor @Observable class — computed `var id` on @MainActor crosses into actor-isolated code and fails Identifiable conformance; nonisolated stored let sidesteps this"
  - "HomeView body split into contentLayer + sessionStartDestination — Swift type-checker times out on deeply-chained modifier expressions; extracting into @ViewBuilder computed properties is the canonical fix"
  - "DateBox(@unchecked Sendable) wrapper in tests instead of var capture — Swift 6 prohibits mutable var capture in @Sendable closures; class box is the idiomatic workaround"
  - "SessionSuccessViewModel.id == sessionId — both set to session.id in init; the duplication is intentional: id satisfies Identifiable (nonisolated), sessionId preserves API surface expected by tests"
metrics:
  duration_minutes: 30
  completed_date: "2026-04-19"
  tasks_completed: 4
  tasks_total: 4
  files_created: 7
  files_modified: 6
  tests_added: 25
  test_results: "133 total, 3 skipped, 0 failures"
requirements:
  - QSN-03
  - QSN-04
  - QSN-05
  - QSN-06
---

# Phase 03 Plan 06: Countdown + Success Screen + AppRoot Foreground Hook + HomeView Wiring Summary

**One-liner:** `CountdownViewModel` (1-Hz `TickClock`-driven, `confirmEarlyEnd` dialog, `@LazyInjected EndSessionUseCase`) + `CountdownView` (progress ring + monospaced digits + `confirmationDialog`) + `SessionSuccessViewModel` + `SessionSuccessView` + `HomeViewModel` extended to 5 destinations + `HomeView` with `SessionStart/Countdown/SessionSuccess` routing + `AppRootViewModel.refreshStatus()` extended with `FinalizeFromMarker + SelfHeal + DetectRevocation` chain, all fully tested (133 tests, 0 failures).

## What Was Built

### Task 1: TickClock + CountdownViewModel + SessionSuccessViewModel + tests (commit `fad0535`)

**`TickClock.swift`** — Protocol + production impl:
- `TickCancellable: AnyObject, Sendable` protocol with `cancel()`.
- `TickClock: Sendable` protocol — `schedule(interval:onTick:) -> any TickCancellable` on `@MainActor`.
- `SystemTickClock` — `DispatchSourceTimer` on `.main` queue, `leeway: .milliseconds(50)`, cancel on deinit via `TimerToken`.

**`CountdownViewModel.swift`** — 100-line `@Observable @MainActor` ViewModel:
- `Destination.confirmEarlyEnd(SessionRecord)` — `@CasePathable`, `Equatable`.
- `remainingSeconds` / `progress` computed from `plannedEndAt - now`, clamped to `[0, plannedDuration]`.
- `startTicking()` schedules 1-Hz tick via `clock.schedule`; each tick recomputes from `dateProvider()` for clock-drift resilience.
- `earlyEndTapped()` → `.confirmEarlyEnd`; `confirmEarlyEnd()` async → `EndSessionUseCase(.cancelledByUser)`; on error keeps destination for retry.
- `onDisappear()` cancels tick token — T-03-06-01 leak prevention.

**`SessionSuccessViewModel.swift`** — Pure-value VM:
- `nonisolated let id: UUID` — `Identifiable` conformance without `@MainActor` crossing.
- `durationMinutes = plannedDurationSeconds / 60` (integer division per plan).
- Stable 4-string caption pool, selected by `abs(id.uuidString.hashValue) % 4`.

**`CountdownViewModelTests.swift`** — 9 tests (all pass):
- `FakeTickClock` + `DateBox(@unchecked Sendable)` for deterministic time stepping (Swift 6 `@Sendable` var-capture workaround).
- Tests: init clamp, progress, tick reduce, tick stops at zero, earlyEnd destination, confirmEarlyEnd UC call, throws keeps destination, dismissConfirm, onDisappear cancels token.

**`SessionSuccessViewModelTests.swift`** — 3 tests: durationMinutes, integer division, stable caption.

### Task 2: HomeViewModel extended + HomeViewModelTests (commit `13838ee`)

**`HomeViewModel.swift`** — Full rewrite preserving `.picker` + `.errorAlert`:

New `Destination` cases:
- `.sessionStart(SessionStartViewModel)` — identity-equal via `===`
- `.countdown(CountdownViewModel)` — identity-equal via `===`
- `.sessionSuccess(SessionSuccessViewModel)` — identity-equal via `===`

New properties/methods:
- `@LazyInjected observeActive: ObserveActiveSessionUseCase` — sink in `init()` → `handleActive(_:)`
- `@LazyInjected observeHistory: ObserveSessionHistoryUseCase` — sink in `init()` → `handleHistory(_:)`
- `@LazyInjected markSuccessShown + checkSuccessShown` — Blocker 2 Option A (VM never touches UserDefaults)
- `startSessionTapped()` → `.sessionStart(SessionStartViewModel())`
- `gotoCountdown(_ record:)` — Blocker 1 cross-VM bridge; called by HomeView's `.onChange` when `SessionStartViewModel.destination == .countdownHandoff`
- `handleActive(_:)` — routes `.countdown(CountdownViewModel(session:))` on non-nil; clears on nil
- `handleHistory(_:)` — filters `.completed` outcomes, checks `checkSuccessShown`, marks before setting `.sessionSuccess`

**`HomeViewModelTests.swift`** — Extended: 7 original tests preserved + 7 new (14 total):
- `testStartSessionTappedRoutesToSessionStartDestination`
- `testGotoCountdownBridgeSetsCountdownDestinationWithProvidedRecord`
- `testActiveSessionEmissionRoutesToCountdown`
- `testActiveSessionBecomingNilClearsCountdownDestination`
- `testCompletedSessionInHistoryShowsSuccessDestinationOnceWhenNoActive`
- `testCompletedSessionAlreadyMarkedShownDoesNotReshow`
- `testCancelledByUserOrBrokenByRevokeDoesNotShowSuccess`

### Task 3: CountdownView + SessionSuccessView + HomeView extended (commit `590221c`)

**`CountdownView.swift`**:
- `@Bindable var model: CountdownViewModel`
- `ring` — `ZStack` with `Circle().stroke` track + `Circle().trim(from:0, to:progress).stroke(accent)` arc `.rotationEffect(.degrees(-90))`, animated `.linear(1.0s)`.
- `caption` — static encouragement text.
- `earlyEndButton` — `.bordered` style with `.destructive` tint + `model.earlyEndTapped()`.
- `confirmationDialog` — "Zakończyć wcześniej?" with "Tak, kończę wcześniej" (`.destructive`) + "Nie, wytrzymam" (`.cancel`).
- `.navigationBarBackButtonHidden(true)` — QSN-05 no-bypass policy.
- `.onDisappear { model.onDisappear() }` — T-03-06-01 tick leak prevention.

**`SessionSuccessView.swift`**:
- sparkles icon + "Wytrzymałeś N minut" + sarcastic caption + "Dzięki, wiem" CTA.
- `onDismiss` callback + `.onTapGesture` — two tap-to-dismiss paths.

**`Theme+Session.swift`** — Added `ringTrack` (`systemGray5`) + `destructive` (`systemRed`).

**`HomeView.swift`** — Extended with:
- `.toolbar` start-session button (`play.circle.fill`), disabled when blocklist empty.
- `.sheet(item: $model.destination.sessionSuccess)` → `SessionSuccessView`.
- `.navigationDestination(item: $model.destination.sessionStart)` → `sessionStartDestination(startModel:)` (extracted `@ViewBuilder func` to fix type-checker timeout).
- `.navigationDestination(item: $model.destination.countdown)` → `CountdownView`.
- Blocker 1 bridge: `.onChange(of: startModel.destination)` — when `.countdownHandoff(record)`, calls `model.gotoCountdown(record)` and resets child destination.

### Task 4: AppRootViewModel extended + AppRootViewModelTests (commit `3cf15a9`)

**`AppRootViewModel.swift`** — Added 3 `@LazyInjected` UCs + extended `refreshStatus()`:
- Eager capture of all 4 async UCs before `Task {}` spawn (Rule 1 fix for DIContainer-reset race).
- Chain: `reconcileBlocklist → finalizeFromMarker → selfHealExpiredSession → detectRevocation`, each wrapped in `do/catch` with logged errors.

**`AppRootViewModelTests.swift`** — Extended: 8 original tests preserved + 2 new (10 total):
- `testRefreshStatusCallsAllFiveUseCases` — verifies all 5 UC callCounts == 1 after 50ms sleep.
- `testRefreshStatusLogsButDoesNotPropagateSelfHealError` — stubbedError on selfHeal, detectRevocation still fires.

## Test Results

```
Test Suite 'CountdownViewModelTests' passed — Executed 9 tests, 0 failures
Test Suite 'SessionSuccessViewModelTests' passed — Executed 3 tests, 0 failures
Test Suite 'HomeViewModelTests' passed — Executed 14 tests, 0 failures (7 original + 7 new)
Test Suite 'AppRootViewModelTests' passed — Executed 10 tests, 0 failures (8 original + 2 new)

Test Suite 'All tests' passed
     Executed 133 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.706 seconds
** TEST SUCCEEDED **
```

Previous baseline (P05): 112 tests, 3 skipped, 0 failures.
This plan added 21 new tests (9 + 3 + 7 + 2).

## Acceptance Criteria Grep Audit

| Check | Result |
|-------|--------|
| `protocol TickClock: Sendable` in TickClock.swift | PASS |
| `final class SystemTickClock` in TickClock.swift | PASS |
| `@MainActor` on CountdownViewModel | PASS |
| `case confirmEarlyEnd(SessionRecord)` in CountdownViewModel | PASS |
| `import SwiftUI` in Session/ViewModel/*.swift | 0 occurrences (PASS) |
| `case sessionStart(SessionStartViewModel)` in HomeViewModel | PASS |
| `case countdown(CountdownViewModel)` in HomeViewModel | PASS |
| `case sessionSuccess(SessionSuccessViewModel)` in HomeViewModel | PASS |
| `case picker(PickerSession)` preserved | PASS |
| `case errorAlert(String)` preserved | PASS |
| `func gotoCountdown` count in HomeViewModel | 1 (PASS) |
| `@LazyInjected private var markSuccessShown` | PASS |
| `@LazyInjected private var checkSuccessShown` | PASS |
| `UserDefaults` in HomeViewModel | 0 (PASS — Blocker 2 Option A) |
| `SuccessShownFlag` in HomeViewModel | 0 (PASS) |
| `.navigationDestination(item: $model.destination.sessionStart)` in HomeView | PASS |
| `.navigationDestination(item: $model.destination.countdown)` in HomeView | PASS |
| `.sheet(item: $model.destination.sessionSuccess)` in HomeView | PASS |
| `.sheet(item: $model.destination.picker)` preserved | PASS |
| `.onChange(of: startModel.destination)` in HomeView | PASS (Blocker 1) |
| `gotoCountdown(` in HomeView | PASS (Blocker 1) |
| `startModel.destination = nil` in HomeView | PASS (edge-trigger reset) |
| `.confirmationDialog(` in CountdownView | PASS |
| `model.onDisappear()` in CountdownView | PASS |
| `struct SessionSuccessView: View` | PASS |
| `finalizeFromMarker` in AppRootViewModel | PASS |
| `selfHealExpiredSession` in AppRootViewModel | PASS |
| `detectRevocation` in AppRootViewModel | PASS |
| Full `xcodebuild test` green | PASS (133 tests, 3 skipped, 0 failures) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift type-checker timeout on HomeView body**
- **Found during:** Task 3, first build attempt
- **Issue:** HomeView's `body` had too many chained modifiers (5 `.sheet`/`.navigationDestination`/`.alert` modifiers on a `Group`) for the Swift type-checker to resolve in time.
- **Fix:** Extracted `contentLayer` (inner content + toolbar + `.onAppear`) and `sessionStartDestination(startModel:)` into separate `@ViewBuilder` properties/methods.
- **Files modified:** `HomeView.swift`
- **Commit:** `590221c`

**2. [Rule 1 - Bug] SessionSuccessViewModel Identifiable conformance crossing @MainActor isolation**
- **Found during:** Task 3, first build attempt
- **Issue:** `final class SessionSuccessViewModel: Identifiable` with `var id: UUID { sessionId }` produced "conformance crosses into main actor-isolated code" error because `id` was `@MainActor`-bound.
- **Fix:** Added `nonisolated let id: UUID` stored property (set in `init` alongside `sessionId`). Both hold `session.id`.
- **Files modified:** `SessionSuccessViewModel.swift`
- **Commit:** `590221c`

**3. [Rule 1 - Bug] DIContainer reset race: @LazyInjected in async Task resolves after tearDown**
- **Found during:** Task 4, full test run (1 failure: `testRefreshStatusLogsButDoesNotPropagateSelfHealError`)
- **Issue:** `AppRootViewModel.refreshStatus()` spawned `Task { [weak self] in ... self.selfHealExpiredSession(...) }`. The `@LazyInjected` resolves on first access — inside the async Task body — which can run after `XCTestCase.tearDown()` calls `DIContainer.shared.reset()`, causing a fatal crash "not registered".
- **Fix:** Capture all 4 async UC references eagerly (synchronously on `@MainActor`) in `refreshStatus()` before spawning `Task {}`. This forces `@LazyInjected` resolution while the container is still populated.
- **Files modified:** `AppRootViewModel.swift`
- **Commit:** `3cf15a9`

**4. [Rule 2 - Missing] DateBox wrapper for Swift 6 @Sendable var-capture in tests**
- **Found during:** Task 1, first test run
- **Issue:** `CountdownViewModelTests` used `var fakeNow = ...` captured in a `@Sendable () -> Date` closure — Swift 6 prohibits mutable var capture in `@Sendable` closures.
- **Fix:** Added inner `final class DateBox: @unchecked Sendable` with a mutable `var value: Date`, capturing the box (reference) instead of a var.
- **Files modified:** `CountdownViewModelTests.swift`
- **Commit:** `fad0535`

## Visual Posture Note

`CountdownView` and `SessionSuccessView` were not visually validated in this plan — simulator previews render but do not exercise the real `ManagedSettingsStore` shield. On-device UAT (P07) is the only path to validate:
- Progress ring animation clockwise from 12 o'clock.
- `confirmationDialog` presentation on "Zakończ wcześniej".
- `navigationBarBackButtonHidden` preventing swipe-back.
- `SessionSuccessView` sheet presentation after session completes.

## Known Stubs

None — all data paths are wired. `CountdownViewModel.endSession` resolves real `EndSessionUseCaseImpl` via `SessionInjection`. `HomeViewModel` observes real `ObserveActiveSessionUseCase` / `ObserveSessionHistoryUseCase`. `AppRootViewModel` calls real `FinalizeSessionFromMarkerUseCase`, `SelfHealExpiredSessionUseCase`, `DetectRevocationUseCase` on foreground.

## Threat Model Mitigations Applied

| Threat ID | Mitigation | Status |
|-----------|------------|--------|
| T-03-06-01 (Tick timer leak) | `CountdownViewModel.onDisappear()` cancels token; `TimerToken.deinit` defense-in-depth | Applied |
| T-03-06-02 (UserDefaults clear re-shows success) | Accepted per plan — success screen is cosmetic, not a blocking path | Accepted |
| T-03-06-03 (Background kill before confirmEarlyEnd) | `confirmEarlyEnd()` is `async @MainActor`; AppRoot self-heal on next foreground catches it | Applied |
| T-03-06-04 (No early-end audit trail) | `logger.info("early-end confirmed")` + `EndSessionUseCase` persists `.cancelledByUser` record | Applied |
| T-03-06-05 (Sarcastic caption shaming) | 4-string pool reviewed — all encouraging-light per CONTEXT §D-12 | Applied |
| T-03-06-06 (Double scenePhase fire) | `finalizeFromMarker` destructive-idempotent; `selfHeal` / `detectRevocation` idempotent | Applied |
| T-03-06-07 (Bypass via swipe-back) | `navigationBarBackButtonHidden(true)` in CountdownView | Applied |

## Commits

| Hash | Scope | Message |
|------|-------|---------|
| `fad0535` | 3 source + 2 test files | feat(03-06): ship TickClock + CountdownViewModel + SessionSuccessViewModel + tests |
| `13838ee` | HomeViewModel + HomeViewModelTests | feat(03-06): extend HomeViewModel with sessionStart/countdown/sessionSuccess destinations |
| `590221c` | 2 new Views + HomeView + Theme | feat(03-06): ship CountdownView + SessionSuccessView + extend HomeView with session routing |
| `3cf15a9` | AppRootViewModel + AppRootViewModelTests | feat(03-06): extend AppRootViewModel.refreshStatus with Session UCs + AppRootViewModelTests |

## Next Steps

- **P07 (wave 5 UAT):** Full end-to-end walkthrough on a physical iOS 26+ device — the only path to validate `intervalDidEnd` (DAM does not fire on simulator), real `ManagedSettingsStore` shield hold, and actual UI animations.

## Self-Check: PASSED

All 12 source/test files found on disk (verified via absolute paths in worktree).
SUMMARY.md written to `/Users/kked/Projects/KKSW---first-app/.planning/phases/03-quick-sessions/03-06-SUMMARY.md` (main repo `.planning/`).
Commits `fad0535`, `13838ee`, `590221c`, `3cf15a9` verified in git log.
Full test suite: 133 tests, 3 skipped, 0 failures (`** TEST SUCCEEDED **`).
