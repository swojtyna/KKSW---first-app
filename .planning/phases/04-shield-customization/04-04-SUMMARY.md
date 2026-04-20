---
phase: 04
plan: 04
subsystem: shield-customization
tags: [deep-link, navigation, home, shl-04]
requires:
  - HomeViewModel (Phase 03)
  - AppRootView (Phase 01)
  - ObserveActiveSessionUseCase (Phase 03)
  - CountdownViewModel (Phase 03)
provides:
  - HomeViewModel.handleDeepLink(_:) async
  - HomeViewModel.currentActiveSession() async -> SessionRecord? (private)
  - AppRootView.onOpenURL → homeModel.handleDeepLink bridge
affects:
  - DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift
  - DeluluDetox/Sources/Features/Root/View/AppRootView.swift
  - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift
tech-stack:
  added: []
  patterns:
    - swift-navigation @CasePathable destination routing
    - withCheckedContinuation over Publisher.first() (mirrors FinalizeSessionFromMarkerUseCase)
    - SwiftUI .onOpenURL → async ViewModel via Task { @MainActor }
key-files:
  created: []
  modified:
    - DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift
    - DeluluDetox/Sources/Features/Root/View/AppRootView.swift
    - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift
decisions:
  - Reuse existing handleActive(_:) routing from inside handleDeepLink to preserve countdown-idempotency (skip re-instantiating CountdownViewModel when same id already active).
  - Clear destination on the "no active session" branch and let the existing handleHistory() observer (Plan 03-06) surface the success screen autonomously — no special branch in handleDeepLink needed.
  - Use strict equality for url.path == "/active" (T-04-04-02 mitigation: no substring / prefix / path concatenation).
metrics:
  duration_minutes: 3
  completed_date: "2026-04-20"
  task_count: 2
  files_modified: 3
  commits: 3
  tests_added: 4
  tests_skipped_delta: -4
---

# Phase 4 Plan 4: Main app handles deep link from shield — Summary

**One-liner:** HomeViewModel now routes incoming `deluludetox://session/active` and `deluludetox://` URLs to `.countdown` or silent home via a new async `handleDeepLink(_:)`, delivered from AppRootView's `.onOpenURL` through a `Task { @MainActor }` bridge.

## What shipped

### Task 1 — HomeViewModel.handleDeepLink + tests green

**New public API** (`HomeViewModel.swift`, +56 lines):

```swift
func handleDeepLink(_ url: URL) async
private func currentActiveSession() async -> SessionRecord?
```

Routing matrix (implements CONTEXT §D-10):

| URL | Current active session | Resulting destination |
|---|---|---|
| `deluludetox://session/active` | present | `.countdown(CountdownViewModel(session:))` via `handleActive(_:)` |
| `deluludetox://session/active` | nil | `nil` (silent home) |
| `deluludetox://` (root) | — | `nil` |
| `https://…` / any other scheme | — | unchanged (early-return guard) |

`currentActiveSession()` mirrors `FinalizeSessionFromMarkerUseCase.currentActive()` (Plan 03-03): `withCheckedContinuation` over `observeActive().first().sink { … }`.

**Tests** (`HomeViewModelTests.swift`, 4 × XCTSkipIf → 4 real assertions):
- `testHandleDeepLink_sessionActiveURL_routesToCountdown` — passes
- `testHandleDeepLink_sessionActiveURL_noActiveSession_clearsDestination` — passes
- `testHandleDeepLink_rootURL_clearsDestination` — passes
- `testHandleDeepLink_unknownScheme_isIgnored` — passes

### Task 2 — AppRootView .onOpenURL

`AppRootView.swift` (+10 lines):

```swift
.onOpenURL { url in
    // SHL-04: deliver shield-originated URLs to HomeViewModel.
    Task { @MainActor in
        await homeModel.handleDeepLink(url)
    }
}
```

Placed on the outer `Group { … }` modifier chain immediately before `.onChange(of: scenePhase)` so the URL is delivered regardless of which `AppRootViewModel.destination` case is currently rendered. The `Task { @MainActor }` wrapper is required because `.onOpenURL`'s closure is synchronous and `HomeViewModel` is `@MainActor`-annotated with `async` handler.

## Acceptance criteria — all met

Task 1:
- `grep -c "func handleDeepLink(_ url: URL) async" HomeViewModel.swift` = 1 ✓
- `grep -c "private func currentActiveSession() async -> SessionRecord?" HomeViewModel.swift` = 1 ✓
- `grep -c 'url.scheme == "deluludetox"' HomeViewModel.swift` = 1 ✓
- `grep -c 'url.host == "session"' HomeViewModel.swift` = 1 ✓
- `grep -c 'url.path == "/active"' HomeViewModel.swift` = 1 ✓
- `withCheckedContinuation` usage — 1 actual call site (grep shows 2: one doc comment, one code) ✓
- `grep -c "XCTSkipIf" HomeViewModelTests.swift` = 0 ✓
- `grep -c "func testHandleDeepLink_" HomeViewModelTests.swift` = 4 ✓
- HomeViewModelTests: 18 tests, 0 failures ✓

Task 2:
- `grep -c ".onOpenURL { url in" AppRootView.swift` = 1 ✓
- `grep -c "homeModel.handleDeepLink(url)" AppRootView.swift` = 1 ✓
- `grep -c "Task { @MainActor in" AppRootView.swift` = 1 ✓
- `.onOpenURL` (line 32) appears before `.onChange(of: scenePhase)` (line 42) ✓
- Full test suite: **147 tests executed, 0 failures, 13 skipped** (was 17 skipped → SHL-04 delta = -4, matches plan) ✓

## Threat model — mitigations in place

| Threat | Status | Evidence |
|---|---|---|
| T-04-04-01 Spoofing (faked active-session) | mitigated | `currentActiveSession()` reads live `activeSessionPublisher`; URL never parameterises session identity. |
| T-04-04-02 Tampering (path traversal) | mitigated | Strict `url.path == "/active"` equality. No concatenation. |
| T-04-04-06 EoP (deep link bypasses session guards) | mitigated | `grep -cE "endSession\|cancelSession\|finalize"` inside `handleDeepLink` body = **0**. Navigation only. |
| T-04-04-03/04/05 | accepted | Per plan. Logger fields all `.public`-safe; scheme squatting is documented iOS limitation; throttle is iOS-provided. |

## Deviations from plan

None — plan executed exactly as written.

## Authentication gates

None.

## Commits (3)

| Hash | Message |
|---|---|
| 4971517 | test(04-04): add failing handleDeepLink tests for SHL-04 |
| a7b14c4 | feat(04-04): implement HomeViewModel.handleDeepLink for SHL-04 |
| 7e66d1d | feat(04-04): wire AppRootView .onOpenURL to HomeViewModel |

TDD flow: RED (test commit) → GREEN (implementation) → Task 2 integration. No refactor commit needed — first pass was already minimal.

## What's next

- **Plan 04-02** (parallel wave 1) — registers `deluludetox://` URL scheme in `project.yml`. Runtime enablement of this deep link requires Plan 04-02 to land. Compile-time work in this plan is independent.
- **Plan 04-03** — wires ShieldActionExtension to emit the URL via local-push-notification fallback (extension → main app handoff).
- **Plan 04-05** — E2E validation on physical device (simulator FamilyControls limitations prevent full validation locally).

## Self-Check: PASSED

**Files verified exist:**
- FOUND: DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift
- FOUND: DeluluDetox/Sources/Features/Root/View/AppRootView.swift
- FOUND: DeluluDetoxTests/Features/Home/HomeViewModelTests.swift

**Commits verified in git log:**
- FOUND: 4971517
- FOUND: a7b14c4
- FOUND: 7e66d1d
