---
phase: 02
plan: 01
subsystem: app-selection
tags:
  - wave-0
  - spike
  - tests-only
  - familycontrols
  - codable
requirements:
  - SEL-01
  - SEL-02
  - SEL-03
  - SEL-05
dependency_graph:
  requires:
    - Phase 01.1 DIContainer + feature layout (touched: none; inherited as environment)
  provides:
    - A1 assumption test harness (JSON round-trip of FamilyActivitySelection / per-kind tokens)
    - A2 compile-time guard (FamilyActivityPicker inside NavigationStack + .sheet(item:) with Identifiable PickerSession)
  affects:
    - Plan 02-02 Blocklist persistence — confirms JSONEncoder path is safe
    - Plan 02-06 PickerHostView — confirms the exact SwiftUI shape compiles
    - Plan 02-07 device human-verify — inherits skip-flagged device-only cases
tech_stack:
  added: []
  patterns:
    - "XCTSkipIf(... .isEmpty) for simulator-only harness tests that need device tokens"
    - "Mirror-only test spikes: private test-target structs replicate production shape without touching Sources/"
key_files:
  created:
    - path: DeluluDetoxTests/Features/AppSelection/BlockedTokenCodableTests.swift
      purpose: "A1 JSON round-trip harness — proves FamilyActivitySelection + per-kind tokens Codable shape; PropertyListEncoder regression guard"
    - path: DeluluDetoxTests/Features/AppSelection/PickerPresentationSpikeTests.swift
      purpose: "A2 compile-time guard — FamilyActivityPicker in NavigationStack + .sheet(item:) with Identifiable wrapper under Swift 6.2 strict concurrency"
  modified: []
decisions:
  - "Rule 1 deviation: PropertyListEncoder regression guard INVERTED. Forum 721973 (dropped includeEntireCategory) appears fixed on Xcode 26.3 / iOS 26.3 SDK — control test now asserts equality directly and flags a failure only if Apple re-introduces the bug. JSONEncoder remains Plan 02's canonical persistence path regardless."
  - "Rule 3 deviation: Simulator UUID in plan (C958163F-49E1-4B46-8A6D-C2056CD25A37) not present on this host. Used local iPhone 17 UUID 6D73311F-3541-4B74-92E8-8014FABC3329 for test_sim; build/simulator is host-local and not committed."
  - "Rule 3 deviation: Used raw xcodebuild via Bash because XcodeBuildMCP tools (session_show_defaults / build_sim / test_sim) are not exposed in this runtime. All CLAUDE.md XcodeGen/xcodebuild conventions otherwise honored (project.yml source of truth, xcodegen generate, skipMacroValidation flag)."
metrics:
  completed_date: "2026-04-19"
  duration: "~5 minutes"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 02 Plan 01: Wave 0 Assumption Spikes Summary

Wave 0 XCTest harness validates A1 (per-kind token JSON round-trip) and A2 (FamilyActivityPicker inside custom NavigationStack + `.sheet(item:)`) before the phase build kicks off — Plan 02-02…02-06 may now proceed on verified foundations.

## What Was Built

Two pure test-target files under `DeluluDetoxTests/Features/AppSelection/`:

### 1. `BlockedTokenCodableTests.swift` (A1 — JSON round-trip)

5 XCTest methods under `@MainActor final class BlockedTokenCodableTests`:

| Test | Behavior | Result |
|------|----------|--------|
| `testFamilyActivitySelectionJSONRoundTripPreservesEmptySelection` | `FamilyActivitySelection() → JSONEncoder → JSONDecoder → equal` | **PASS** |
| `testApplicationTokenExtractedFromSelectionRoundTripsViaJSON` | `ApplicationToken` round-trip; skip-if-empty on simulator | **skipped** (device-seeded) |
| `testCategoryTokenExtractedFromSelectionRoundTripsViaJSON` | `ActivityCategoryToken` round-trip; skip-if-empty on simulator | **skipped** (device-seeded) |
| `testWebDomainTokenExtractedFromSelectionRoundTripsViaJSON` | `WebDomainToken` round-trip; skip-if-empty on simulator | **skipped** (device-seeded) |
| `testPropertyListEncoderRoundTripPreservesIncludeEntireCategoryFlagOnCurrentSDK` | PropertyList encoder control — **inverted after Rule 1 deviation** (see below) | **PASS** |

### 2. `PickerPresentationSpikeTests.swift` (A2 — compile-time guard)

2 XCTest methods under `@MainActor final class PickerPresentationSpikeTests` with a private `PickerHostViewSpike` (mirror of Plan 06's `PickerHostView`) and `SheetHostSpike` wrapping it:

| Test | Behavior | Result |
|------|----------|--------|
| `testPickerHostViewCompilesWithFamilyActivityPickerInsideNavigationStack` | `NavigationStack { FamilyActivityPicker(selection:) .toolbar { ToolbarItem(.confirmationAction) } }` | **PASS** |
| `testSheetItemBindingAcceptsIdentifiablePickerSession` | `.sheet(item: $activeSession) { PickerHostViewSpike }` with `PickerSession: Identifiable, Equatable` | **PASS** |

Both force `_ = view.body` to flush SwiftUI compile-time diagnostics that only surface during View graph evaluation.

## Test Output Excerpt

Full suite run on iPhone 17 simulator (iOS 26.3 SDK via Xcode 26.3):

```
Test Suite 'AppRootViewModelTests' passed — 6 tests
Test Suite 'BlockedTokenCodableTests' passed — 5 tests, 3 skipped
Test Suite 'DeluluDetoxTests' passed — 1 test
Test Suite 'DenialViewModelTests' passed — 3 tests
Test Suite 'HomeViewModelTests' passed — 1 test
Test Suite 'OnboardingViewModelTests' passed — 3 tests
Test Suite 'PickerPresentationSpikeTests' passed — 2 tests
Test Suite 'All tests' passed — Executed 21 tests, 3 skipped, 0 failures
** TEST SUCCEEDED **
```

Phase 01/01.1 baseline (14 tests) preserved: AppRoot 6 · DeluluDetoxTests 1 · Denial 3 · Home 1 · Onboarding 3. Plan 02-01 added 7 new tests (2 hard-pass + 3 device-skip + 2 hard-pass), no regressions.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `e8832a6` | `test(02-01): add BlockedTokenCodableTests A1 spike` |
| 2 | `0dc97d6` | `test(02-01): add PickerPresentationSpikeTests A2 compile-time guard` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Inverted PropertyListEncoder regression guard**

- **Found during:** Task 1, first `xcodebuild test` run after creating `BlockedTokenCodableTests`.
- **Issue:** The plan's scaffold used `XCTExpectFailure` to document the forum-721973 bug (PropertyListEncoder dropping `includeEntireCategory`). On Xcode 26.3 / iOS 26.3 SDK the round-trip now preserves the flag, so `XCTAssertEqual(original, decoded)` succeeded — and `XCTExpectFailure` had nothing to match, reporting *"Expected failure ... but none recorded"*. The regression guard was firing against its own premise.
- **Fix:** Renamed the test to `testPropertyListEncoderRoundTripPreservesIncludeEntireCategoryFlagOnCurrentSDK`, removed `XCTExpectFailure`, kept the encode/decode path, and tightened the assertion message to flag *if* Apple re-introduces the bug in a future SDK. The test now captures current SDK truth and guards against regression **of the fix**.
- **Impact on Plan 02 architecture:** None. Plan 02 (02-PATTERNS §persistence) still selects `JSONEncoder` as canonical; this control test's role is to track Apple's behavior, not to dictate persistence choice. JSON was already the safer path regardless of whether PropertyList also works.
- **Files modified:** `DeluluDetoxTests/Features/AppSelection/BlockedTokenCodableTests.swift` (lines 65–85 in the committed version).
- **Commit:** `e8832a6` (rolled into Task 1 commit — pre-refactor state never committed).

**2. [Rule 3 — Blocking issue] Canonical simulator UUID not present on host**

- **Found during:** Pre-Task 1, while preparing to run `xcodebuild test`.
- **Issue:** CLAUDE.md and the plan's `<verify>` blocks cite simulator UUID `C958163F-49E1-4B46-8A6D-C2056CD25A37` as the iPhone 17 / iOS 26.2 default. `xcrun simctl list` on this host shows iPhone 17 at UUID `6D73311F-3541-4B74-92E8-8014FABC3329` — the plan's UUID does not exist locally. Since simulator UUIDs are machine-local, any hard-coded UUID is host-specific.
- **Fix:** Used the host's local iPhone 17 UUID (`6D73311F-…`) for all `xcodebuild test -destination` invocations. Did NOT modify CLAUDE.md or the plan — this is a per-developer environment detail, not a repo-level change. Recommend updating the session guide (`.claude/guides/xcodebuild-mcp/xcode-session.json`) per developer.
- **Files modified:** none.

**3. [Rule 3 — Blocking issue] XcodeBuildMCP tools unavailable in this runtime**

- **Found during:** Pre-Task 1, when preparing to call `session_show_defaults`.
- **Issue:** CLAUDE.md mandates XcodeBuildMCP for all Apple-platform build/test actions. The MCP tool surface in this agent's runtime does not include `session_show_defaults`, `build_sim`, or `test_sim` (only the standard Claude Code tools are callable).
- **Fix:** Used raw `xcodebuild` via Bash with the exact command shape specified in the plan's `<verify>` blocks (`-skipMacroValidation`, explicit `-destination`, `-only-testing:` filter). All other CLAUDE.md conventions honored: `project.yml` is source of truth, `xcodegen generate` runs after each test-file addition, zero `.xcodeproj` hand-edits.
- **Files modified:** none.

## Findings

- **A1 partially validated on simulator.** Empty-selection `FamilyActivitySelection` Codable path is green. Real per-kind tokens (Application/Category/WebDomain) remain gated by simulator limitation — `XCTSkipIf` harness is installed for Plan 07 human-verify on a physical device. Device-only validation is **pending Plan 07 human-verify on physical device. PropertyListEncoder XCTExpectFailure is a regression guard, not a bug.** (Updated wording to match inverted guard: regression guard remains; inversion does not affect JSONEncoder path.)
- **A2 fully validated at compile time.** `PickerHostView` shape compiles clean: `NavigationStack { FamilyActivityPicker(selection:) .toolbar { confirmationAction } }`. `.sheet(item:)` binding to `PickerSession?` where `PickerSession: Identifiable, Equatable` compiles and renders `body` without diagnostics under Swift 6.2 strict concurrency. **A2 compilation status: PASS → Plan 06 can safely ship the real `PickerHostView`.**
- **PropertyListEncoder fix observation (side finding).** Apple appears to have fixed forum 721973 in the iOS 26.3 SDK. Not architecturally significant for Plan 02 (JSONEncoder stays canonical), but worth recording for future reviewers.

## Acceptance Criteria Check

| Criterion | Status |
|-----------|--------|
| `BlockedTokenCodableTests.swift` exists and non-empty | PASS (85 lines) |
| Grep `final class BlockedTokenCodableTests: XCTestCase` | PASS (line 16) |
| Grep `XCTExpectFailure` | **N/A** — removed per Rule 1 deviation; guard now inverted |
| Grep `JSONEncoder().encode` | PASS (4 matches: lines 20, 34, 46, 58) |
| `xcodegen generate` → zero `project.yml` diff | PASS |
| Targeted `test_sim` on `BlockedTokenCodableTests` | PASS (5 tests, 3 skipped, 0 failures) |
| `PickerPresentationSpikeTests.swift` exists | PASS (78 lines) |
| Grep `FamilyActivityPicker(selection: $session.selection)` | PASS (line 37) |
| Grep `NavigationStack {` | PASS (line 36) |
| Grep `@State private var activeSession: PickerSession?` | PASS (line 52) |
| Targeted `test_sim` on `PickerPresentationSpikeTests` | PASS (2 tests, 0 failures) |
| Full `test_sim` green; 14 pre-existing tests preserved | PASS (21 tests total, 3 skipped, 0 failures) |
| `git diff DeluluDetox/Sources` empty | PASS |

## Self-Check: PASSED

- [x] `DeluluDetoxTests/Features/AppSelection/BlockedTokenCodableTests.swift` exists (Read-verified + git-tracked in `e8832a6`).
- [x] `DeluluDetoxTests/Features/AppSelection/PickerPresentationSpikeTests.swift` exists (Read-verified + git-tracked in `0dc97d6`).
- [x] Commit `e8832a6` present in `git log --oneline`.
- [x] Commit `0dc97d6` present in `git log --oneline`.
- [x] Full test suite green on iPhone 17 / iOS 26.3 — 21 tests, 3 device-seeded skips, 0 failures.
- [x] `DeluluDetox/Sources` untouched (empty `git diff`).
