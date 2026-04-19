---
phase: 02
plan: 03
subsystem: app-selection
tags:
  - wave-3
  - usecase
  - dependency-injection
  - bootstrap
  - mocks
requirements:
  - SEL-01
  - SEL-04
  - SEL-05
dependency_graph:
  requires:
    - Plan 02-02 Blocklist domain + BlocklistRepository (commit a079b50)
    - Phase 01.1 DIContainer (scopes .application / .unique, MainActor-isolated factories)
    - Phase 01.1 OnboardingInjection (reference shape for feature-owner registration)
  provides:
    - ObserveBlocklistUseCase protocol + Impl (publisher passthrough)
    - UpdateBlocklistUseCase protocol + Impl (commit selection from FamilyActivityPicker)
    - RemoveTokenRecordUseCase protocol + Impl (swipe-to-delete row action)
    - ReconcileBlocklistUseCase protocol + Impl (scenePhase .active trigger in Plan 02-05)
    - AppSelectionInjection.register — feature-owner DI wiring (Repo .application + 4 UCs .unique)
    - DeluluDetoxApp bootstrap line between Onboarding and Denial
    - 5 test mocks (MockBlocklistRepository + 4 UC mocks) for Plans 04/05/06 consumption
  affects:
    - Plan 02-04 BlockedViewModel — @LazyInjected against ObserveBlocklistUseCase + RemoveTokenRecordUseCase
    - Plan 02-05 AppRootViewModel.onScenePhaseActive — will call ReconcileBlocklistUseCase
    - Plan 02-06 HomeViewModel — @LazyInjected against ObserveBlocklistUseCase + UpdateBlocklistUseCase
    - Plan 02-07 human-verify — end-to-end exercise of all 4 UCs on device
tech_stack:
  added: []
  patterns:
    - "UseCase thin-wrapper pattern: one protocol + one impl per file, init-injected Repository, callAsFunction() boundary"
    - "Distributed DI registration: feature-owner enum with a static register(in:) method, called from DeluluDetoxApp.init()"
    - "Scope discipline: Repository = .application (shared state via CurrentValueSubject), UseCases = .unique (stateless wrappers)"
    - "@preconcurrency import FamilyControls carried into UpdateBlocklistUseCase + MockUpdateBlocklistUseCase + MockBlocklistRepository (Sendable gap on FamilyActivitySelection, inherited from Plan 02-02)"
    - "Feature-mirror test layout for mocks: DeluluDetoxTests/Features/<Feature>/Mocks/ — matches Phase 01.1 Onboarding-mock discipline"
key_files:
  created:
    - path: DeluluDetox/Sources/Features/AppSelection/UseCase/ObserveBlocklistUseCase.swift
      purpose: "Publisher passthrough — surface BlocklistRepository.blocklistPublisher to ViewModels"
    - path: DeluluDetox/Sources/Features/AppSelection/UseCase/UpdateBlocklistUseCase.swift
      purpose: "Commit FamilyActivitySelection from picker into repository.update(with:)"
    - path: DeluluDetox/Sources/Features/AppSelection/UseCase/RemoveTokenRecordUseCase.swift
      purpose: "Swipe-to-delete pathway for TokenRecord by UUID"
    - path: DeluluDetox/Sources/Features/AppSelection/UseCase/ReconcileBlocklistUseCase.swift
      purpose: "scenePhase .active reconcile trigger (SEL-05; full token-rotation verification lands Phase 3+)"
    - path: DeluluDetox/Sources/Features/AppSelection/Injection/AppSelectionInjection.swift
      purpose: "Distributed DI registration — Repo (.application) + 4 UCs (.unique)"
    - path: DeluluDetoxTests/Features/AppSelection/Mocks/MockBlocklistRepository.swift
      purpose: "Full repository double with CurrentValueSubject + per-op error stubs + capture + counters"
    - path: DeluluDetoxTests/Features/AppSelection/Mocks/MockObserveBlocklistUseCase.swift
      purpose: "Publisher mock exposing CurrentValueSubject<Blocklist, Never> + callCount"
    - path: DeluluDetoxTests/Features/AppSelection/Mocks/MockUpdateBlocklistUseCase.swift
      purpose: "Captures selection, counts calls, throws stubbedError"
    - path: DeluluDetoxTests/Features/AppSelection/Mocks/MockRemoveTokenRecordUseCase.swift
      purpose: "Captures recordID, counts calls, throws stubbedError"
    - path: DeluluDetoxTests/Features/AppSelection/Mocks/MockReconcileBlocklistUseCase.swift
      purpose: "Counts calls, throws stubbedError"
  modified:
    - path: DeluluDetox/Sources/App/DeluluDetoxApp.swift
      purpose: "Added AppSelectionInjection.register(in: container) between OnboardingInjection and DenialInjection; updated comment to reflect feature-owner ordering rule"
decisions:
  - "Added @preconcurrency import FamilyControls to UpdateBlocklistUseCase.swift (protocol signature exposes FamilyActivitySelection) and to MockBlocklistRepository.swift + MockUpdateBlocklistUseCase.swift (same reason). This matches the Plan 02-02 precedent — FamilyActivitySelection is Codable/Equatable but not Sendable in iOS 26.3 SDK, so any Sendable-conforming type that touches it needs the escape hatch. No architectural drift: Plan 02-02 SUMMARY decisions table already records this for Blocklist.swift + BlocklistRepository.swift."
  - "HomeInjection stays no-op per 02-PATTERNS.md §9 — cross-feature UseCase consumption is the sanctioned path. Plan 06 HomeViewModel will @LazyInjected ObserveBlocklistUseCase + UpdateBlocklistUseCase from the AppSelection registration, NOT re-register them under Home. Confirmed by the AppSelection-first bootstrap ordering (Onboarding → AppSelection → Denial → Home → Root)."
  - "Rule 3 deviation (carried from Plans 02-01 / 02-02): host iPhone 17 simulator UUID is 6D73311F-3541-4B74-92E8-8014FABC3329 on this machine (CLAUDE.md canonical C958163F-... not present). Used raw xcodebuild via Bash because XcodeBuildMCP simulator tools were not exposed in this runtime even though they are advertised in the MCP server descriptor — session_show_defaults / build_sim / test_sim were not callable. All other CLAUDE.md conventions honored (project.yml source of truth, xcodegen generate after every source-file addition, zero .xcodeproj hand-edits)."
metrics:
  completed_date: "2026-04-19"
  duration: "~4 minutes"
  tasks_completed: 2
  files_created: 10
  files_modified: 1
---

# Phase 02 Plan 03: AppSelection UseCases + DI Wiring + Test Mocks Summary

Wave 3 plan — binds the Plan 02-02 Blocklist repository into the UseCase boundary (protocol+impl × 4), registers the feature in the DIContainer via the feature-owner `AppSelectionInjection` enum, inserts the bootstrap call into `DeluluDetoxApp.init()`, and ships the 5-file test-mock kit consumed by Plans 04/05/06.

## What Was Built

### UseCases (4 files under `DeluluDetox/Sources/Features/AppSelection/UseCase/`)

Every file: one `protocol ...: Sendable { func callAsFunction(...) ... }` + one `final class ...Impl` with `init(repository: BlocklistRepository)` init-injection. Impls are stateless thin wrappers that forward to `BlocklistRepository` — no logic layer, no state, no persistence.

| File | Purpose | Signature |
|------|---------|-----------|
| `ObserveBlocklistUseCase.swift` | Publisher passthrough | `callAsFunction() -> AnyPublisher<Blocklist, Never>` |
| `UpdateBlocklistUseCase.swift` | Commit selection | `callAsFunction(_ selection: FamilyActivitySelection) async throws` |
| `RemoveTokenRecordUseCase.swift` | Delete record by UUID | `callAsFunction(_ recordID: TokenRecord.ID) async throws` |
| `ReconcileBlocklistUseCase.swift` | scenePhase reconcile | `callAsFunction() async throws` |

Only `UpdateBlocklistUseCase.swift` imports FamilyControls (with `@preconcurrency` to satisfy Sendable inference on its `FamilyActivitySelection` parameter). The other three import nothing beyond the default module (Observe: Combine; Remove/Reconcile: no imports — `TokenRecord.ID` is `UUID`, resolved via Foundation pull-through).

### Injection (1 file)

`DeluluDetox/Sources/Features/AppSelection/Injection/AppSelectionInjection.swift` — `enum AppSelectionInjection { static func register(in container: DIContainer) }` with 5 registrations:

| Type | Scope | Factory |
|------|-------|---------|
| `BlocklistRepository` | `.application` | `BlocklistRepositoryImpl()` (production App Group convenience init) |
| `ObserveBlocklistUseCase` | `.unique` | `ObserveBlocklistUseCaseImpl(repository: c.resolve())` |
| `UpdateBlocklistUseCase` | `.unique` | `UpdateBlocklistUseCaseImpl(repository: c.resolve())` |
| `RemoveTokenRecordUseCase` | `.unique` | `RemoveTokenRecordUseCaseImpl(repository: c.resolve())` |
| `ReconcileBlocklistUseCase` | `.unique` | `ReconcileBlocklistUseCaseImpl(repository: c.resolve())` |

### Bootstrap (`DeluluDetoxApp.swift` edit)

Added `AppSelectionInjection.register(in: container)` between `OnboardingInjection.register` and `DenialInjection.register`, keeping the feature-owner-first ordering documented in 01.1 / CLAUDE.md DI guide. Updated the in-code comment to reflect the new ownership split (Onboarding owns `ScreenTimeAuth*`, AppSelection owns Blocklist + TokenRecord).

Final ordering (line numbers from grep):

```
10: OnboardingInjection.register(in: container)
11: AppSelectionInjection.register(in: container)
12: DenialInjection.register(in: container)
13: HomeInjection.register(in: container)
14: RootInjection.register(in: container)
```

### Test Mocks (5 files under `DeluluDetoxTests/Features/AppSelection/Mocks/`)

All use `@unchecked Sendable` + `@testable import DeluluDetox` and mirror the Onboarding mock shape:

| File | Surface |
|------|---------|
| `MockBlocklistRepository.swift` | `stubbedBlocklist` with `didSet → subject.send`, per-op error stubs (`updateError` / `removeError` / `reconcileError`), capture properties + `private(set)` call counters |
| `MockObserveBlocklistUseCase.swift` | Exposed `CurrentValueSubject<Blocklist, Never>` + `callCount` |
| `MockUpdateBlocklistUseCase.swift` | `capturedSelection` + `callCount` + `stubbedError` |
| `MockRemoveTokenRecordUseCase.swift` | `capturedRecordID` + `callCount` + `stubbedError` |
| `MockReconcileBlocklistUseCase.swift` | `callCount` + `stubbedError` |

No new XCTest methods in this plan — mocks compile-green and are consumed by Plans 04/05/06 via `DIContainer.shared.register(...)` in their `setUp()`.

## Grep Audit

```
$ grep -c "scope: .application" DeluluDetox/Sources/Features/AppSelection/Injection/AppSelectionInjection.swift
1
$ grep -c "scope: .unique" DeluluDetox/Sources/Features/AppSelection/Injection/AppSelectionInjection.swift
4
$ grep -n "AppSelectionInjection.register(in: container)" DeluluDetox/Sources/App/DeluluDetoxApp.swift
11:        AppSelectionInjection.register(in: container)
$ grep -n "Injection.register(in: container)" DeluluDetox/Sources/App/DeluluDetoxApp.swift
10:        OnboardingInjection.register(in: container)
11:        AppSelectionInjection.register(in: container)
12:        DenialInjection.register(in: container)
13:        HomeInjection.register(in: container)
14:        RootInjection.register(in: container)
$ grep -c "import SwiftUI" DeluluDetox/Sources/Features/AppSelection/UseCase/*.swift
0 (across all 4 files)
$ grep -c "import SwiftUI" DeluluDetoxTests/Features/AppSelection/Mocks/*.swift
0 (across all 5 files)
```

Ordering rule `Onboarding < AppSelection < Denial < Home < Root` upheld; `.application` count = 1 (Repo only); `.unique` count = 4 (UseCases only); zero SwiftUI imports in the Domain or test-mock trees.

## Test Output Excerpt

Full suite run on iPhone 17 simulator UUID `6D73311F-3541-4B74-92E8-8014FABC3329` (iOS 26.3 SDK via Xcode 26.3):

```
Test Suite 'DeluluDetoxTests.xctest' passed at 2026-04-19 13:24:31.980.
	 Executed 35 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.176 (0.202) seconds
Test Suite 'All tests' passed at 2026-04-19 13:24:31.980.
	 Executed 35 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.176 (0.203) seconds
** TEST SUCCEEDED **
```

Zero regressions from the Plan 02-02 baseline (35 tests, 3 device-seeded skips). Run twice during this plan — once after Task 1 (UseCases + DI) and once after Task 2 (mocks). Both green.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `e00a03a` | `feat(02-03): ship AppSelection UseCases + DI registration` |
| 2 | `e636229` | `test(02-03): ship 5 AppSelection test mocks (Repository + 4 UseCases)` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking issue] `@preconcurrency import FamilyControls` added to UpdateBlocklistUseCase + FamilyControls-touching mocks**

- **Found during:** Task 1 build after creating `UpdateBlocklistUseCase.swift`.
- **Issue:** `protocol UpdateBlocklistUseCase: Sendable` exposes `FamilyActivitySelection` in its `callAsFunction(_:)` signature. Under Swift 6.2 strict concurrency (Xcode 26.3, iOS 26.3 SDK), a protocol declared `Sendable` whose signature references a non-`Sendable` type emits a warning + correctness diagnostic. The plan's `<action>` scaffold specified a bare `import FamilyControls` for this file; that would surface the same diagnostic Plan 02-02 already hit on `Blocklist.lastSelection`.
- **Fix:** Used `@preconcurrency import FamilyControls` in `UpdateBlocklistUseCase.swift`, `MockBlocklistRepository.swift`, and `MockUpdateBlocklistUseCase.swift`. This is the identical pattern Plan 02-02 established for `Blocklist.swift` / `BlocklistRepository.swift` and is the compiler-suggested escape hatch. When Apple marks `FamilyActivitySelection` `Sendable` (expected iOS 27+), the prefix becomes a no-op.
- **Impact on plan:** None architecturally — Plan 02-02's decisions log already records this for the same framework. The protocol still advertises `Sendable`, impls still conform, and downstream `@LazyInjected` usage (Plans 04 / 06) is unaffected.
- **Files modified:** `UpdateBlocklistUseCase.swift`, `MockBlocklistRepository.swift`, `MockUpdateBlocklistUseCase.swift`.
- **Commits:** Folded into `e00a03a` (Task 1) and `e636229` (Task 2) — pre-fix state never committed.

**2. [Rule 3 — Carry-over from Plans 02-01 / 02-02] Simulator UUID + XcodeBuildMCP absence**

- Host's iPhone 17 simulator UUID is `6D73311F-3541-4B74-92E8-8014FABC3329` (plan / CLAUDE.md cite `C958163F-...` which is not present on this machine). Used the local UUID for both `xcodebuild build` and `xcodebuild test`.
- XcodeBuildMCP simulator tools (`session_show_defaults` / `build_sim` / `test_sim`) were not callable in this runtime despite the MCP server descriptor being advertised at session start. Fell back to raw `xcodebuild` via Bash with `-skipMacroValidation` and explicit `-destination`, matching the plan's `<verify>` shape exactly.
- Both are per-developer environment details — no repo-level change needed. Already documented in Plan 02-01 and Plan 02-02 SUMMARYs.

## Findings

- **UseCase boundary is minimal by design.** All 4 impls are 4-line pass-throughs to the repository — no business logic, no state, no error translation. That matches the feature-structure guide: UseCase exists to give ViewModels a testable seam and to hide the repo type, not to add behavior.
- **Cross-feature UC consumption is the sanctioned path (D-27 / 02-RESEARCH §Pattern 3).** HomeInjection stays no-op; Plan 06 HomeViewModel will reach across and `@LazyInjected` from AppSelection's registrations. This keeps AppSelection as the single owner of Blocklist state at runtime (`BlocklistRepository` at `.application` scope = one `CurrentValueSubject` for the app lifetime).
- **Mock layout mirrors Onboarding 1:1.** The `stubbedX { didSet { subject.send } }` pattern on `MockBlocklistRepository` lets Plans 04 / 06 drive publisher emissions by mutation rather than by reaching into the subject directly — same ergonomics `MockScreenTimeAuthRepository` offers. `MockObserveBlocklistUseCase` exposes the subject publicly (convention: `subject` not `_subject`) so VM tests can drive `.send(...)` directly without the repository overhead when observation is all that's under test.
- **Bootstrap ordering is now `feature-owner-first`.** Onboarding (owns ScreenTimeAuth*) before AppSelection (owns Blocklist) before Denial / Home / Root (consumers). This ordering rule is the one thing 01.1 documented but wasn't yet exercised — Plan 02-03 is the first plan to insert a second feature-owner registration and confirms the pattern composes cleanly.

## Acceptance Criteria Check

### Task 1

| Criterion | Status |
|-----------|--------|
| 4 UseCase files exist, one protocol + one impl each | PASS |
| `grep protocol ObserveBlocklistUseCase: Sendable` | PASS (line 3) |
| `grep protocol UpdateBlocklistUseCase: Sendable` | PASS (line 3) |
| `grep protocol RemoveTokenRecordUseCase: Sendable` | PASS (line 1) |
| `grep protocol ReconcileBlocklistUseCase: Sendable` | PASS (line 1) |
| `grep enum AppSelectionInjection` | PASS (line 11) |
| `grep -c "scope: .application"` in Injection file | PASS (1 match) |
| `grep -c "scope: .unique"` in Injection file | PASS (4 matches) |
| `grep AppSelectionInjection.register(in: container)` in DeluluDetoxApp | PASS (1 match, line 11) |
| Register order: Onboarding → AppSelection → Denial → Home → Root | PASS (lines 10-14 ascend) |
| `grep -c import SwiftUI` in UseCase files | PASS (0 across 4 files) |
| `build_sim` green | PASS (raw xcodebuild, `** BUILD SUCCEEDED **`) |
| Full `test_sim` green, zero regressions | PASS (35 tests, 3 skipped, 0 failures) |

### Task 2

| Criterion | Status |
|-----------|--------|
| 5 files under `DeluluDetoxTests/Features/AppSelection/Mocks/` | PASS |
| `grep final class MockBlocklistRepository: BlocklistRepository, @unchecked Sendable` | PASS (line 5) |
| `grep final class MockObserveBlocklistUseCase: ObserveBlocklistUseCase, @unchecked Sendable` | PASS (line 4) |
| `grep final class MockUpdateBlocklistUseCase: UpdateBlocklistUseCase, @unchecked Sendable` | PASS (line 4) |
| `grep final class MockRemoveTokenRecordUseCase: RemoveTokenRecordUseCase, @unchecked Sendable` | PASS (line 3) |
| `grep final class MockReconcileBlocklistUseCase: ReconcileBlocklistUseCase, @unchecked Sendable` | PASS (line 3) |
| Each mock uses `@unchecked Sendable` + CurrentValueSubject (publisher) OR callCount+stubbedError (action) | PASS |
| `grep -c import SwiftUI` in Mocks files | PASS (0 across 5 files) |
| `build_sim` green | PASS (implicit via `test_sim`) |
| Full `test_sim` green | PASS (35 tests, 3 skipped, 0 failures) |

### Plan-level verification

| Criterion | Status |
|-----------|--------|
| `xcodegen generate` produces zero `project.yml` diff after each task | PASS (both Task 1 and Task 2 runs reported no diff) |
| `git diff DeluluDetox/Sources/Features/Home` empty | PASS (only AppSelection + App/ touched) |
| `git diff DeluluDetox/Sources/Features/Root` empty | PASS (scenePhase reconcile belongs to Plan 05) |
| All 6 success criteria from `<success_criteria>` met | PASS |

## Next Steps

Plan 02-03 closes the Wave-3 foundation. Downstream plans are unblocked:

- **Plan 02-04 BlockedViewModel + BlockedView** — will `@LazyInjected var observeBlocklist: ObserveBlocklistUseCase` + `@LazyInjected var removeTokenRecord: RemoveTokenRecordUseCase`. Test setup will register `MockObserveBlocklistUseCase` + `MockRemoveTokenRecordUseCase` into `DIContainer.shared` per-test.
- **Plan 02-05 AppRootViewModel scenePhase hook** — will add `@LazyInjected var reconcileBlocklist: ReconcileBlocklistUseCase` and call it on `.active` phase transitions.
- **Plan 02-06 HomeViewModel + PickerHostView** — cross-feature UC consumption of `ObserveBlocklistUseCase` + `UpdateBlocklistUseCase` from AppSelection. Confirms D-27 pattern end-to-end.
- **Plan 02-07 device human-verify** — exercises the full UC → Repository → JSON → App Group round trip on a physical device, including the picker commit path and the swipe-to-delete flow.

No Phase 02 files in the Repository or Domain trees need further writes in the remaining plans unless token-rotation hardening emerges as a Rule 2 candidate during Plan 02-07.

## Self-Check: PASSED

- [x] `DeluluDetox/Sources/Features/AppSelection/UseCase/ObserveBlocklistUseCase.swift` exists (Read-verified + git-tracked in `e00a03a`).
- [x] `DeluluDetox/Sources/Features/AppSelection/UseCase/UpdateBlocklistUseCase.swift` exists (Read-verified + git-tracked in `e00a03a`).
- [x] `DeluluDetox/Sources/Features/AppSelection/UseCase/RemoveTokenRecordUseCase.swift` exists (Read-verified + git-tracked in `e00a03a`).
- [x] `DeluluDetox/Sources/Features/AppSelection/UseCase/ReconcileBlocklistUseCase.swift` exists (Read-verified + git-tracked in `e00a03a`).
- [x] `DeluluDetox/Sources/Features/AppSelection/Injection/AppSelectionInjection.swift` exists (Read-verified + git-tracked in `e00a03a`).
- [x] `DeluluDetox/Sources/App/DeluluDetoxApp.swift` contains `AppSelectionInjection.register(in: container)` between Onboarding and Denial (Read-verified + modified in `e00a03a`).
- [x] `DeluluDetoxTests/Features/AppSelection/Mocks/MockBlocklistRepository.swift` exists (git-tracked in `e636229`).
- [x] `DeluluDetoxTests/Features/AppSelection/Mocks/MockObserveBlocklistUseCase.swift` exists (git-tracked in `e636229`).
- [x] `DeluluDetoxTests/Features/AppSelection/Mocks/MockUpdateBlocklistUseCase.swift` exists (git-tracked in `e636229`).
- [x] `DeluluDetoxTests/Features/AppSelection/Mocks/MockRemoveTokenRecordUseCase.swift` exists (git-tracked in `e636229`).
- [x] `DeluluDetoxTests/Features/AppSelection/Mocks/MockReconcileBlocklistUseCase.swift` exists (git-tracked in `e636229`).
- [x] Commit `e00a03a` present in `git log --oneline`.
- [x] Commit `e636229` present in `git log --oneline`.
- [x] Full test suite green on iPhone 17 simulator / iOS 26.3 — 35 tests, 3 device-seeded skips, 0 failures.
- [x] No `import SwiftUI` in `Features/AppSelection/UseCase/` or `Tests/Features/AppSelection/Mocks/` (Clean Architecture boundary upheld).
