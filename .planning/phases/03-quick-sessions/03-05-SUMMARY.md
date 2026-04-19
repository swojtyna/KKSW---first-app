---
phase: 03-quick-sessions
plan: "05"
subsystem: Session/ViewModel+View
tags: [viewmodel, view, swiftui, observable, casequpathable, preset-chips, datepicker, tdd, re-entry-guard]
dependency_graph:
  requires:
    - "03-03: StartSessionUseCase + ObserveActiveSessionUseCase + ObserveBlocklistUseCase + SessionInjection"
    - "03-01: SessionRecord + SessionDuration models"
    - "02-03: Blocklist + TokenRecord + ObserveBlocklistUseCase"
  provides:
    - SessionStartViewModel (@Observable, @MainActor, Destination: sessionInProgress/countdownHandoff/errorAlert)
    - SessionStartView (preset chips + wheel picker + empty-state + alert)
    - Theme.chipBackground (Theme+Session.swift extension)
  affects:
    - "03-06: P06 consumes Destination.countdownHandoff(SessionRecord) to construct CountdownViewModel"
    - "03-06: HomeView will push SessionStartView via NavigationStack; P06 wires the entry point"
tech_stack:
  added:
    - "Combine.AnyCancellable — VM subscribes ObserveBlocklistUseCase + ObserveActiveSessionUseCase on init"
    - "SwiftUINavigation (@CasePathable on Destination enum)"
    - "DatePicker(.hourAndMinute, .wheel) — custom duration wheel with seconds↔Date Binding bridge"
    - "Theme+Session.swift extension — chipBackground (systemGray6) added without editing Phase 01 Theme.swift"
  patterns:
    - "isStarting re-entry guard — prevents double-tap from spawning two StartSessionUseCase calls (T-03-05-01)"
    - "customDurationSeconds didSet clamping — silently enforces [minSeconds, maxSeconds] range (T-03-05-02)"
    - "manual Binding<Bool> for alert isPresented — used instead of case-path binding because errorAlert payload is String (not Identifiable)"
    - "@ObservationIgnored on @LazyInjected + cancellables — avoids spurious observation invalidation"
key_files:
  created:
    - DeluluDetox/Sources/Features/Session/ViewModel/SessionStartViewModel.swift
    - DeluluDetox/Sources/Features/Session/View/SessionStartView.swift
    - DeluluDetox/Sources/DesignSystem/Theme+Session.swift
    - DeluluDetoxTests/Features/Session/SessionStartViewModelTests.swift
  modified: []
decisions:
  - "Theme.chipBackground placed in Theme+Session.swift (not Theme.swift) — Phase 01 ownership preserved; Phase 03 can extend the design system without merge risk"
  - "Alert binding implemented as manual Binding<Bool> — String is not Identifiable so .alert(item:$model.destination.errorAlert) would not compile; manual binding is the correct pattern per SwiftUI docs and matches HomeView precedent"
  - "canStart = blocklistHasRecords && !isStarting && resolvedDuration != nil — three-part guard ensures CTA is always safe to enable; isStarting prevents double-tap AND acts as natural UI feedback to disable CTA mid-flight"
metrics:
  duration_minutes: 7
  completed_date: "2026-04-19"
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 0
  tests_added: 14
  test_results: "112 total, 3 skipped, 0 failures"
requirements:
  - QSN-01
  - QSN-02
---

# Phase 03 Plan 05: Session Start Screen Summary

**One-liner:** `SessionStartViewModel` (@Observable, @MainActor, no SwiftUI) with 4-gate `startTapped()` and `SessionStartView` rendering preset chips (15/30/60/90 min) + custom wheel DatePicker + empty-state nudge + errorAlert, all wired to `SessionInjection`-provided UseCases via `@LazyInjected`.

## What Was Built

### Task 1: SessionStartViewModel + SessionStartViewModelTests (commit `de54dd0`)

**`SessionStartViewModel.swift`** — 150-line @Observable ViewModel:

- `@CasePathable Destination` with three cases: `.sessionInProgress(SessionRecord)`, `.countdownHandoff(SessionRecord)`, `.errorAlert(String)`.
- `selectedPresetMinutes: Int?` (default 30) + `customDurationSeconds: Int` (default 1800, clamped via `didSet`).
- `resolvedDuration: SessionDuration?` — reads preset first, falls back to custom; returns nil if custom is out of range.
- `canStart: Bool` — `blocklistHasRecords && !isStarting && resolvedDuration != nil`.
- `startTapped(now:)` — 4 sequential gates: (1) active session → `.sessionInProgress`, (2) empty blocklist → log+return, (3) nil duration → log+return, (4) `isStarting` re-entry guard. On success: `.countdownHandoff(record)`. On throw: `.errorAlert` with sarcastic Polish copy.
- `@LazyInjected` for all three UseCases (`ObserveBlocklistUseCase`, `ObserveActiveSessionUseCase`, `StartSessionUseCase`).
- Zero `import SwiftUI` — uses `import SwiftUINavigation` (the swift-navigation library) and `import Observation`.

**`SessionStartViewModelTests.swift`** — 14 XCTestCase methods, all @MainActor:

| Test | Result |
|------|--------|
| testInitialStateHasPreset30MinutesAndCustom30MinutesAndNilDestination | PASS |
| testSelectPresetUpdatesSelectedPresetAndKeepsCustomUntouched | PASS |
| testSwitchToCustomClearsSelectedPreset | PASS |
| testResolvedDurationReadsPresetFirst | PASS |
| testResolvedDurationReadsCustomWhenNoPresetSelected | PASS |
| testResolvedDurationClampsCustomBelowMin | PASS |
| testCanStartIsFalseWhenBlocklistIsEmpty | PASS |
| testCanStartIsTrueWhenBlocklistHasRecordsAndDurationValid | PASS |
| testStartTappedRoutesToSessionInProgressWhenActiveExists | PASS |
| testStartTappedCallsStartSessionUseCaseWithResolvedDurationAndBlocklistId | PASS |
| testStartTappedSuccessRoutesDestinationToCountdownHandoff | PASS |
| testStartTappedFailureRoutesDestinationToErrorAlertWithPolishCopy | PASS |
| testStartTappedIsNoOpWhileIsStartingTrue | PASS |
| testClearDestinationResetsToNil | PASS |

### Task 2: SessionStartView + Theme+Session.swift (commit `f9ff0cf`)

**`SessionStartView.swift`** — SwiftUI screen:

- `@Bindable var model: SessionStartViewModel` — View is data-binding-only, no logic.
- `header` — "Na ile odłączamy świat?" title + subtitle.
- `emptyBlocklistNudge` — shown when `!model.blocklistHasRecords`. Contains SF Symbol + bold nudge text ("Najpierw wybierz aplikacje do blokady").
- `presetChips` — `HStack` with `ForEach(Self.presets, id: \.self)` rendering 4 chips (15/30/60/90 min). Selected chip fills with `Theme.accent`, unselected with `Theme.chipBackground`.
- `customWheelSection` — toggle row + `DatePicker("Czas sesji", selection: customDurationBinding, displayedComponents: [.hourAndMinute]).datePickerStyle(.wheel)`. Shown only when `selectedPresetMinutes == nil`.
- `safeAreaInset(.bottom)` primary CTA — "Uruchom sesję" / "Startuję…"; `.disabled(!model.canStart)`.
- `.alert(...)` via manual `Binding<Bool>` — presents Polish error copy from `.errorAlert(message)`.

**`Theme+Session.swift`** — extension on `Theme`:
- `static let chipBackground = Color(.systemGray6)` — avoids editing Phase 01 `Theme.swift`.

## Test Results

```
Test Suite 'SessionStartViewModelTests' passed at 2026-04-19 21:47:47.135.
    Executed 14 tests, with 0 failures (0 unexpected) in 0.016 seconds.

Test Suite 'All tests' passed at 2026-04-19 21:50:16.652.
    Executed 112 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.581 seconds.
** TEST SUCCEEDED **
```

14 new Phase 3 Plan 5 tests added. Phase 02 + P01-P04 baseline (98 tests + 3 skipped) fully preserved. Total: 112 tests, 3 skipped, 0 failures.

## Grep Audit

| Check | Result |
|-------|--------|
| `struct SessionStartViewModel` in ViewModel file | PASS |
| `@MainActor` on ViewModel | PASS (line 13) |
| `@Observable` on ViewModel | PASS (line 14) |
| `@CasePathable` on Destination enum | PASS (line 16) |
| `case sessionInProgress(SessionRecord)` | PASS (line 21) |
| `case countdownHandoff(SessionRecord)` | PASS (line 25) |
| `case errorAlert(String)` | PASS (line 28) |
| `^import SwiftUI$` in VM file | 0 (PASS) |
| `struct SessionStartView: View` | PASS (line 4) |
| `@Bindable var model: SessionStartViewModel` | PASS (line 5) |
| `ForEach(Self.presets, id: \.self)` | PASS |
| `DatePicker(` | PASS |
| `.datePickerStyle(.wheel)` | PASS |
| `Uruchom sesję` | PASS |
| `Najpierw wybierz aplikacje` | PASS |
| `.disabled(!model.canStart)` | PASS |
| `@CasePathable` count in View (should be 0) | 0 (PASS) |
| `git diff DeluluDetox/Sources/Features/Home` | empty (PASS) |
| `git diff DeluluDetox/Sources/Features/Root` | empty (PASS) |
| `git diff DeluluDetox/Sources/App/DeluluDetoxApp.swift` | empty (PASS) |
| `git diff Extensions/` | empty (PASS) |
| Full `xcodebuild test` green | PASS (112 tests, 3 skipped, 0 failures) |

## Deviations from Plan

None — plan executed exactly as written.

All acceptance criteria matched on the first build pass. The `Theme.chipBackground` extension was placed in a new `Theme+Session.swift` file (exactly as the plan specified as the conditional branch for "if missing"). All 14 test method names and assertions match the plan's `<behavior>` spec verbatim.

## Auth Gates

None encountered. Mock-based unit tests only; no Screen Time API calls on simulator.

## Screenshot-Absence Note

No on-device or simulator screenshot captured in this plan. P07 walkthrough covers live UI verification of this screen. The `#Preview` in `SessionStartView.swift` can render the screen in Xcode Canvas.

## Known Stubs

None — the ViewModel is fully wired. `@LazyInjected` resolves to real `StartSessionUseCaseImpl` + `ObserveActiveSessionUseCaseImpl` + `ObserveBlocklistUseCaseImpl` via `SessionInjection` / `AppSelectionInjection` registered in `DeluluDetoxApp.init()`. The `Destination.countdownHandoff(SessionRecord)` case is the live P06 contract — not a placeholder.

## Threat Flags

No new network surface, auth paths, or file access introduced beyond the plan's `<threat_model>`. All five STRIDE threats (T-03-05-01 through T-03-05-05) are mitigated as specified:

- **T-03-05-01 (DoS: double-tap)** — `isStarting` guard + `.disabled(!model.canStart)`. Verified by `testStartTappedIsNoOpWhileIsStartingTrue`.
- **T-03-05-02 (Tampering: out-of-range duration)** — `didSet` clamp on `customDurationSeconds`. Verified by `testResolvedDurationClampsCustomBelowMin`.
- **T-03-05-03 (Info Disclosure: logs)** — `privacy: .public` on session UUID only; no blocklist tokens logged.
- **T-03-05-04 (Spoofing: stale blocklistId)** — accepted per plan; race window microseconds.
- **T-03-05-05 (Repudiation: failed starts)** — `logger.error` on failure path.

## Commits

| Hash | Scope | Message |
|------|-------|---------|
| `de54dd0` | ViewModel + Tests (2 files, 408 lines) | feat(03-05): ship SessionStartViewModel + SessionStartViewModelTests |
| `f9ff0cf` | View + Theme extension (2 files, 216 lines) | feat(03-05): ship SessionStartView + Theme+Session chipBackground |

## Next Steps

- **P06 (CountdownViewModel + CountdownView + AppRoot foreground + HomeView integration):** P06 constructs `CountdownViewModel(record:)` from `Destination.countdownHandoff(SessionRecord)` emitted by `SessionStartViewModel`. P06 also adds the `NavigationStack` push from `HomeView` to `SessionStartView`, wires `AppRootViewModel.onScenePhaseActive()` for SelfHeal/Finalize/DetectRevocation, and ships the success-shown HomeView banner.

## Self-Check: PASSED
