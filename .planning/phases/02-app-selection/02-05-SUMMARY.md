---
phase: 02
plan: 05
subsystem: app-selection
tags:
  - wave-4
  - scenephase
  - approot
  - reconcile
  - sel-05
requirements:
  - SEL-05
dependency_graph:
  requires:
    - Plan 02-03 ReconcileBlocklistUseCase protocol + Impl + DI registration (commit e00a03a)
    - Plan 02-03 MockReconcileBlocklistUseCase test mock (commit e636229)
    - Phase 01.1 AppRootViewModel + AppRootView scenePhase wiring (refreshStatus entrypoint already in place)
    - Phase 01.1 DIContainer.shared + @LazyInjected (.unique scope for UCs)
  provides:
    - AppRootViewModel.refreshStatus() now also fires-and-forgets ReconcileBlocklistUseCase
    - os.Logger (subsystem com.kksw.DeluluDetox / category AppRoot) for reconcile failure logging
    - testRefreshStatusAlsoCallsReconcileBlocklist — reconcile hook smoke test
    - testRefreshStatusReconcileFailureDoesNotCrashOrChangeDestination — failure isolation test
  affects:
    - Plan 02-07 human-verify — will exercise scenePhase → reconcile on device
    - Phase 3+ token rotation hardening — will extend the reconcile hook but not its wiring point
tech_stack:
  added:
    - "os.Logger (OSLog modern API) — subsystem/category identification for OSLog console filtering during human-verify"
  patterns:
    - "Fire-and-forget MainActor-bound Task { ... } with guarded weak self, do/catch, logger.error — SEL-05 isolation pattern for side-effect UCs that must never crash the scenePhase handler"
    - "Cross-feature UC consumption: AppRoot (Root feature-owner) reaches across to AppSelection via @LazyInjected — same precedent Root already uses for Onboarding's ScreenTimeAuth UCs (D-27 / 02-RESEARCH §Pattern 3)"
    - "Test sync: Task.sleep(50ms) for MainActor-bound fire-and-forget Task assertions (Task.yield() x2 proved insufficient — caller and Task body are both MainActor-isolated, so the Task does not run during the caller's yield windows)"
key_files:
  created: []
  modified:
    - path: DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
      purpose: "+@LazyInjected ReconcileBlocklistUseCase + private os.Logger + refreshStatus() now fires reconcile in a do/catch Task"
    - path: DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift
      purpose: "+mockReconcile field + DI registration in setUp + 2 new tests (happy path + thrown-error isolation)"
decisions:
  - "Used Task.sleep(nanoseconds: 50_000_000) for test synchronization instead of repeated Task.yield(). The plan's <action> block prescribed two yields, but the actual behavior on Xcode 26.3 / iOS 26.3 SDK MainActor is that a fire-and-forget Task created inside a MainActor method does not run during the enclosing MainActor test function's yields — both sides share the same actor and yield only schedules the next job on the same executor which the caller continues to hold. A 50ms sleep releases the MainActor long enough for the Task body to execute and return before the assertion. Logger output (`[AppRoot] reconcile failed: boom`) during the failing run proved the Task eventually ran but after the assertion. This is the minimal correct fix; switching to an XCTestExpectation would be heavier for the same semantics. Documented inline in both tests."
  - "Carry-forward Rule 3 from Plans 02-01/02/03: used simulator UUID 6D73311F-3541-4B74-92E8-8014FABC3329 (local iPhone 17) because the CLAUDE.md-canonical C958163F-... is not present on this machine. XcodeBuildMCP simulator tools were advertised in the session descriptor but not callable in the executing runtime; fell back to raw xcodebuild via Bash with -skipMacroValidation. No repo change — per-developer environment detail."
metrics:
  completed_date: "2026-04-19"
  duration: "~5 minutes"
  tasks_completed: 1
  files_created: 0
  files_modified: 2
---

# Phase 02 Plan 05: AppRoot scenePhase → ReconcileBlocklistUseCase Wiring Summary

Wave 4 plan (parallel with 02-04). Extends `AppRootViewModel.refreshStatus()` — the method AppRootView already invokes on `scenePhase == .active` — to fire-and-forget the `ReconcileBlocklistUseCase` provisioned by Plan 02-03. Closes SEL-05 "token rotation handled" by ensuring blocklists.json gets reconciled every time the app returns to foreground, with failure isolated via a private os.Logger.

## What Was Built

### `AppRootViewModel.swift` (modified)

Three additive changes, zero behavior change to existing fields:

1. **`@LazyInjected private var reconcileBlocklist: ReconcileBlocklistUseCase`** — second cross-feature UC consumption on AppRoot (first was `ObserveScreenTimeAuthStatusUseCase` from Onboarding). Uses `@ObservationIgnored` like the other injected fields.
2. **`private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "AppRoot")`** — modern OSLog identification so reconcile failures surface in the Console app under a filterable category during Plan 02-07 human-verify. Added `import os` at the top of the file.
3. **`refreshStatus()` body extended**:

   ```swift
   func refreshStatus() {
       refreshStatusUseCase()                             // existing — D-14 auth refresh
       Task { [weak self] in                              // new — SEL-05 reconcile hook
           guard let self else { return }
           do {
               try await self.reconcileBlocklist()
           } catch {
               self.logger.error(
                   "reconcile failed: \(String(describing: error), privacy: .public)"
               )
           }
       }
   }
   ```

   The Task is fire-and-forget (not stored, not awaited), weak-self-captured (no retain cycle against the VM), and catches every error path — thrown errors log but never touch `destination`. That satisfies T-02-05-01 (DoS mitigation) and T-02-05-02 (no PII surfaced; BlocklistStoreError / FileManager errors don't contain user data — `privacy: .public` is safe).

### `AppRootViewModelTests.swift` (modified)

- **`mockReconcile: MockReconcileBlocklistUseCase!`** field added, initialized in `setUp`, registered against `ReconcileBlocklistUseCase.self` at `.unique` scope alongside the existing two mocks. `DIContainer.shared.register` call count in setUp: 3 (exactly matches the acceptance criterion).
- **`testRefreshStatusAlsoCallsReconcileBlocklist`** — calls `vm.refreshStatus()`, sleeps 50 ms, asserts `mockReconcile.callCount == 1`.
- **`testRefreshStatusReconcileFailureDoesNotCrashOrChangeDestination`** — stubs `mockReconcile.stubbedError = TestError.boom`, boots VM in `.approved` state (destination `.home`), calls `refreshStatus()`, sleeps 50 ms, asserts all three: `mockReconcile.callCount == 1`, `mockRefresh.callCount == 1`, `vm.destination == .home`. Logger output `[AppRoot] reconcile failed: boom` visible in test log confirms the error was caught and logged by the VM, not by XCTest.
- **All 6 existing tests** retained verbatim (`testInitialDestinationForNotDetermined`, `testInitialDestinationForApproved`, `testEmissionOfApprovedRoutesToHome`, `testEmissionOfDeniedRoutesToDenial`, `testRefreshStatusCallsUseCase`, `testMultipleEmissionsUpdateDestination`). Only `testRefreshStatusCallsUseCase` was converted from sync to `async` + `await Task.yield()` to remain consistent with the new sibling that also fires the reconcile Task under the hood (the reconcile Task is now spawned on every `refreshStatus()` call, not just in the new tests).

### `AppRootView.swift` — untouched

`git diff 7d9b4a58..HEAD -- DeluluDetox/Sources/Features/Root/View/AppRootView.swift` is empty. Phase 01.1 already wired `model.refreshStatus()` on `scenePhase == .active`; that call now also reconciles the blocklist by virtue of the VM body change. No view layer change needed.

## Grep Audit

```
$ grep -n "import os" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
5:import os

$ grep -n "@LazyInjected private var reconcileBlocklist: ReconcileBlocklistUseCase" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
30:    @LazyInjected private var reconcileBlocklist: ReconcileBlocklistUseCase

$ grep -n "try await self.reconcileBlocklist()" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
58:                try await self.reconcileBlocklist()

$ grep -n "category: \"AppRoot\"" DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
38:        category: "AppRoot"

$ grep -c "DIContainer.shared.register" DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift
5    # 3 in setUp (Observe/Refresh/Reconcile) + 2 per-test overrides for .approved scenarios

$ git diff --stat 7d9b4a58..HEAD -- DeluluDetox/Sources/Features/Root/View/AppRootView.swift DeluluDetox/Sources/Features/Home DeluluDetox/Sources/Features/AppSelection
    # empty — only Root/ViewModel + Root/tests touched
```

## Test Output Excerpt

Filtered `AppRootViewModelTests` run (immediately after GREEN commit):

```
Test Case '-[DeluluDetoxTests.AppRootViewModelTests testRefreshStatusAlsoCallsReconcileBlocklist]' started.
Test Case '-[DeluluDetoxTests.AppRootViewModelTests testRefreshStatusAlsoCallsReconcileBlocklist]' passed (0.052 seconds).
Test Case '-[DeluluDetoxTests.AppRootViewModelTests testRefreshStatusCallsUseCase]' started.
Test Case '-[DeluluDetoxTests.AppRootViewModelTests testRefreshStatusCallsUseCase]' passed (0.001 seconds).
Test Case '-[DeluluDetoxTests.AppRootViewModelTests testRefreshStatusReconcileFailureDoesNotCrashOrChangeDestination]' started.
2026-04-19 13:32:38.859172+0200 DeluluDetox[29310:286119] [AppRoot] reconcile failed: boom
Test Case '-[DeluluDetoxTests.AppRootViewModelTests testRefreshStatusReconcileFailureDoesNotCrashOrChangeDestination]' passed (0.054 seconds).
Test Suite 'AppRootViewModelTests' passed at 2026-04-19 13:32:38.910.
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.109 (0.111) seconds
** TEST SUCCEEDED **
```

Full suite (regression check):

```
Test Suite 'DeluluDetoxTests.xctest' passed at 2026-04-19 13:32:46.947.
	 Executed 37 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.286 (0.300) seconds
Test Suite 'All tests' passed at 2026-04-19 13:32:46.947.
	 Executed 37 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.286 (0.301) seconds
** TEST SUCCEEDED **
```

Baseline from Plan 02-03 was 35 tests; Plan 02-05 adds 2 → 37, exactly as expected. 3 device-seeded skips unchanged. Zero regressions.

## Commits

| Phase | Commit | Message |
|-------|--------|---------|
| RED | `7e8c6c3` | `test(02-05): add failing tests for scenePhase reconcile hook` |
| GREEN | `a1237c3` | `feat(02-05): wire scenePhase reconcile hook into AppRootViewModel` |

(No REFACTOR commit — implementation is already minimal: one field, one logger, one Task block.)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Test sync bug] `Task.yield() x2` was insufficient; switched to `Task.sleep(50ms)` for both new tests**

- **Found during:** GREEN verification run. The VM implementation was correct (logger output `[AppRoot] reconcile failed: boom` proved the Task body ran and the error was caught), but both new tests' `callCount` assertions read 0 instead of 1. Execution ordering issue, not a VM bug.
- **Root cause:** `vm.refreshStatus()` spawns `Task { [weak self] in ... }` which inherits the enclosing MainActor isolation. The test method is also `@MainActor`-bound and is currently running on the same executor. `await Task.yield()` from the test suspends the *test continuation* and enqueues it at the back of the MainActor job queue, but the reconcile Task is also on that queue — it has no privilege to run between the test's yield and the test's resumption. In practice on Xcode 26.3 / iOS 26.3 SDK the test resumed first and asserted before the reconcile Task's async body had executed. The Task eventually ran (logger line proves it) but after the XCTAssertEqual line.
- **Fix:** Replace `await Task.yield(); await Task.yield()` with `try await Task.sleep(nanoseconds: 50_000_000)` (50 ms). Sleep on the MainActor releases the executor for real-time long enough that the reconcile Task gets scheduled and its `async throws` body completes before the sleep returns. 50 ms is empirically sufficient (test runs in ~52 ms total including the sleep), well under any test-suite timeout, and the next-tier alternative (XCTestExpectation wired through the mock) is heavier for the same semantics — no new test infrastructure, no change to the mock's public surface.
- **Tests converted from `async` to `async throws`** to accommodate `try await Task.sleep`. `testRefreshStatusCallsUseCase` was converted from sync to `async` (no `throws`) + single `Task.yield()` — safe because `refreshStatusUseCase()` is called synchronously on MainActor in the VM, so one yield suffices for the original assertion (the spawned reconcile Task runs later but no longer affects this test). All other pre-existing tests kept the `Task.yield()` pattern — their assertions are on `destination`, which is set synchronously by the Combine `sink` closure, so yield remains correct for them.
- **Inline comment** in both new tests explains why sleep beats yield, to keep the next reader from "simplifying" it back.
- **Files modified:** `DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift` (within the same GREEN commit `a1237c3`).

### Carry-over from earlier Phase 02 plans

**2. [Rule 3 — Environment] Simulator UUID + XcodeBuildMCP absence**

Same as Plans 02-01 / 02-02 / 02-03. Used local iPhone 17 UUID `6D73311F-3541-4B74-92E8-8014FABC3329` because CLAUDE.md-canonical `C958163F-...` is not present on this machine. XcodeBuildMCP simulator tools were not callable; fell back to raw `xcodebuild` with `-skipMacroValidation`. No repo-level change; per-developer environment detail.

## Acceptance Criteria Check

| Criterion | Status |
|-----------|--------|
| `AppRootViewModel.swift` contains exactly one new `@LazyInjected` for `ReconcileBlocklistUseCase` | PASS (line 30) |
| `grep -n "@LazyInjected private var reconcileBlocklist: ReconcileBlocklistUseCase"` | PASS (line 30) |
| `grep -n "try await self.reconcileBlocklist()"` | PASS (line 58) |
| `grep -n "import os"` | PASS (line 5) |
| 6 existing `AppRootViewModelTests` still PASS | PASS (all 6 reported passed in the filtered run) |
| `testRefreshStatusAlsoCallsReconcileBlocklist` PASS | PASS (0.052s) |
| `testRefreshStatusReconcileFailureDoesNotCrashOrChangeDestination` PASS | PASS (0.054s) |
| `setUp` registers exactly 3 mocks (Observe/Refresh/Reconcile) | PASS (lines 23/26/29 in current file) |
| Full `test_sim` green; zero regressions in other test files | PASS (37/0 failures, 3 skipped) |
| `git diff AppRootView.swift` empty | PASS |

## Threat Register Audit

| Threat | Status | Evidence |
|--------|--------|----------|
| T-02-05-01 DoS — reconcile throws → app stuck | Mitigated | `testRefreshStatusReconcileFailureDoesNotCrashOrChangeDestination` proves `destination` stays `.home` after `TestError.boom` thrown; `refreshStatusUseCase.callCount` still 1 (auth refresh path not blocked) |
| T-02-05-02 Info disclosure — logger emits PII | Mitigated | `String(describing: error)` wrapped in `privacy: .public`; error types are BlocklistStoreError enum cases + FileManager URLError — no user data; logger namespaced under `com.kksw.DeluluDetox / AppRoot` for filtering |
| T-02-05-03 Tampering — rapid scenePhase toggles → concurrent reconciles | Accepted | `BlocklistRepositoryImpl.writeAndEmit` is MainActor-synchronous; `reconcile()` is idempotent (only bumps `updatedAt`) |

## Findings

- **Second cross-feature UC consumption on AppRoot lands cleanly.** Onboarding's `ScreenTimeAuth*` + AppSelection's `ReconcileBlocklistUseCase` now both live as `@LazyInjected` fields on `AppRootViewModel`. No special-case wiring; DIContainer's `.unique` scope gives AppRoot a fresh UC instance per resolution, which is exactly right — the UC is stateless, the Repository it holds is `.application`-scoped and thus shared. Pattern scales: when Plan 06 HomeViewModel later injects `UpdateBlocklistUseCase` (third cross-feature consumer), no DI change is needed.
- **Fire-and-forget Task + os.Logger is the right SEL-05 shape.** The reconcile call doesn't belong in the return path of `refreshStatus()` (caller is a SwiftUI scenePhase callback that shouldn't block), and it doesn't belong on the Combine pipeline (reconcile isn't triggered by status changes, it's triggered by foregrounding). A fire-and-forget Task with catching log is the minimal correct shape. OSLog modern API (`Logger(subsystem:category:)`) was picked over `print` so Plan 02-07 human-verify can filter the Console app by subsystem/category during on-device exercise.
- **Test sync pattern worth memorializing.** "Task.yield() is enough for Combine-sink emissions but not for enclosed Task bodies on the same actor" — this is the first place in the codebase where that distinction bites. Left inline comments in both new tests so the next contributor (likely Plan 02-07 or a future rotation-hardening plan) doesn't regress. Worth mentioning in `02-PATTERNS.md` after Plan 06 if more instances emerge.

## Known Stubs

None. All code paths wired to real UseCases + real Logger; no hardcoded empties, no "coming soon" placeholders, no unwired props.

## Self-Check: PASSED

- [x] `DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` — Read-verified, 6 grep matches against expected patterns (line 5/30/36-38/58), git-tracked in `a1237c3`.
- [x] `DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift` — Read-verified, 5 `DIContainer.shared.register` lines (3 in setUp + 2 per-test), 2 new test methods grep-matched, git-tracked in `a1237c3`.
- [x] Commit `7e8c6c3` present in `git log --oneline` (RED — test-only, 2 failures expected).
- [x] Commit `a1237c3` present in `git log --oneline` (GREEN — feat, 8/8 green).
- [x] AppRootView.swift untouched — `git diff` empty.
- [x] Features/Home untouched — `git diff` empty.
- [x] Features/AppSelection untouched — `git diff` empty.
- [x] Filtered `AppRootViewModelTests` run: 8/8 green, 0 failures.
- [x] Full `DeluluDetoxTests` run: 37 tests, 3 skipped, 0 failures (2-test increase from Plan 02-03 baseline of 35 — matches expected delta).
