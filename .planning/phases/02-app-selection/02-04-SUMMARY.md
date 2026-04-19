---
phase: 02
plan: 04
subsystem: app-selection
tags:
  - wave-4
  - viewmodel
  - view
  - swiftui
  - swipe-to-delete
  - observable
  - tdd
requirements:
  - SEL-01
  - SEL-02
  - SEL-03
  - SEL-04
dependency_graph:
  requires:
    - Plan 02-02 Blocklist domain + BlocklistRepository (CurrentValueSubject publisher)
    - Plan 02-03 ObserveBlocklistUseCase + RemoveTokenRecordUseCase protocols + Impls + mocks (MockObserveBlocklistUseCase, MockRemoveTokenRecordUseCase)
    - Phase 01.1 DIContainer + @LazyInjected property wrapper
    - DesignSystem/Theme.swift (Theme.accent)
  provides:
    - BlockedViewModel — @MainActor @Observable VM, no SwiftUI import
    - BlockedView — SwiftUI List with 3 fixed-order Sections, full-swipe delete, bottom CTA
    - onChangeSelection callback hook for HomeView (Plan 06) to wire picker launch
    - 6 BlockedViewModelTests covering filter, publisher updates, delete happy + error, change-selection callback (incl. nil-safety)
  affects:
    - Plan 02-06 HomeViewModel + HomeView — will embed BlockedView as non-empty branch + assign onChangeSelection closure that opens picker Destination
    - Plan 02-07 device human-verify — exercises picker → delete → list re-render round trip
tech_stack:
  added: []
  patterns:
    - "@MainActor @Observable final class + @unchecked Sendable (mirrors OnboardingViewModel / AppRootViewModel)"
    - "@ObservationIgnored on @LazyInjected, cancellables, logger — prevents Observation from tracking DI plumbing (02-RESEARCH.md §Pitfall 6)"
    - "Combine .sink { [weak self] ... } + .store(in: &cancellables) for publisher subscription (mirrors AppRootViewModel)"
    - "onChangeSelection closure hook pattern — VM exposes `var onChangeSelection: (() -> Void)?` so HomeView owns picker Destination while BlockedViewModel stays SwiftUI-free (02-RESEARCH.md §BlockedViewModel)"
    - "SwiftUI .safeAreaInset(edge: .bottom) for primary CTA — list scrolls underneath, CTA always visible"
    - "List + .swipeActions(edge: .trailing, allowsFullSwipe: true) + Button(role: .destructive) — no confirmation dialog per 02-UI-SPEC.md §Destructive actions"
    - "Apple Label(token) — only supported renderer for opaque ApplicationToken / ActivityCategoryToken / WebDomainToken"
    - "Conditional Section rendering — `if !model.xRecords.isEmpty { Section(...) }` prevents blank headers when a kind is empty"
key_files:
  created:
    - path: DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift
      purpose: "@MainActor @Observable VM that subscribes to ObserveBlocklistUseCase, filters records into appRecords/categoryRecords/webRecords, exposes deleteTapped + changeSelectionTapped"
    - path: DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
      purpose: "SwiftUI View — 3 fixed-order conditional Sections, per-row full-swipe delete, bottom 'Zmień wybór' CTA in safeAreaInset"
    - path: DeluluDetoxTests/Features/AppSelection/BlockedViewModelTests.swift
      purpose: "6 unit tests covering init filter, publisher emission, delete happy-path, delete error-path, changeSelection callback fire + nil-safety"
  modified: []
decisions:
  - "Kept the Logger subsystem `com.kksw.DeluluDetox` and category `BlockedVM`. Only scalar values are logged (record UUID as `uuidString` with `privacy: .public`, error description via `String(describing: error)`). Never logs raw token bytes or FamilyActivitySelection contents — mirrors the T-02-04-01 mitigation in the plan's threat register."
  - "No @preconcurrency anywhere in this plan's new files. BlockedViewModel does NOT `import FamilyControls` (the token types arrive from TokenRecord.applicationToken() etc., all declared in Plan 02-02's types). BlockedView imports FamilyControls + ManagedSettings because Label(token) needs the Apple renderer, but the View is not Sendable-constrained so the Sendable gap on FamilyActivitySelection is irrelevant here."
  - "Rule 3 deviation (carried from Plans 02-01 / 02-02 / 02-03) — host iPhone 17 simulator UUID is `6D73311F-3541-4B74-92E8-8014FABC3329` on this machine (CLAUDE.md canonical `C958163F-...` not present). Used raw `xcodebuild` via Bash because XcodeBuildMCP simulator tools (`session_show_defaults` / `build_sim` / `test_sim`) were not callable in this runtime even though the MCP server descriptor lists them. All other CLAUDE.md conventions honored (project.yml source of truth, `xcodegen generate` after every source-file addition, zero .xcodeproj hand-edits)."
metrics:
  completed_date: "2026-04-19"
  duration: "~5 minutes"
  tasks_completed: 2
  files_created: 3
  files_modified: 0
---

# Phase 02 Plan 04: BlockedViewModel + BlockedView Summary

Wave 4 plan — ships the review-and-edit surface for the persisted blocklist. A `@MainActor @Observable` ViewModel that subscribes to `ObserveBlocklistUseCase` and filters records into three kind-partitioned arrays, plus a SwiftUI `List` with fixed-order Sections, full-swipe destructive delete, and a bottom `Zmień wybór` CTA hosted in `safeAreaInset(.bottom)`. Closes SEL-04 ("user can view persisted selections") at the VM level and readies the View for Plan 06 to embed as the non-empty branch of `HomeView`.

## What Was Built

### ViewModel (1 file)

**`DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift`** — `@MainActor @Observable final class BlockedViewModel: @unchecked Sendable`.

Public surface:
- `private(set) var appRecords: [TokenRecord]` / `categoryRecords` / `webRecords` / `errorMessage: String?`
- `var onChangeSelection: (() -> Void)?` — assigned by `HomeView` (Plan 06) to forward the "Zmień wybór" tap to `HomeViewModel`'s picker Destination. The plan-sanctioned pattern per 02-RESEARCH.md §"BlockedViewModel": VM lifetime is bounded by `HomeView`'s `@State private var blockedModel`, closure captures `[weak model]` in the parent to avoid retain cycles.
- `func deleteTapped(recordID: TokenRecord.ID) async` — clears `errorMessage`, calls `removeRecord(recordID)`, sets localized error string on throw (`"Nie udało się usunąć."`), logs scalar-only via `os.Logger`.
- `func changeSelectionTapped()` — fires `onChangeSelection?()` (no-op when nil).

DI/state plumbing:
- `@ObservationIgnored @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase`
- `@ObservationIgnored @LazyInjected private var removeRecord: RemoveTokenRecordUseCase`
- `@ObservationIgnored private var cancellables: Set<AnyCancellable> = []`
- `@ObservationIgnored private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "BlockedVM")`

Init body subscribes to `observeBlocklist()` on the main queue and splits `blocklist.records` into the three arrays by `TokenKind`. No `import SwiftUI` — imports are `Combine / Foundation / Observation / os` only.

### View (1 file)

**`DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift`** — `struct BlockedView: View` with a single `@Bindable var model: BlockedViewModel`.

- Three conditional `Section` blocks in fixed order: `"Aplikacje"` → `"Kategorie"` → `"Strony www"`. Empty kind → section not rendered.
- Each row: `Label(token)` (the only renderer Apple exposes for opaque tokens) wrapped in `if let token = record.xToken() { ... }` so a record whose `encodedToken` fails to decode is silently skipped (T-02-04-02 mitigation).
- Per-row `.swipeActions(edge: .trailing, allowsFullSwipe: true)` with a single `Button(role: .destructive)` that fires `Task { await model.deleteTapped(recordID: record.id) }`. No confirmation dialog per 02-UI-SPEC.md §Destructive actions.
- `.listStyle(.insetGrouped)` + `.navigationTitle("Zablokowane")` + `.navigationBarTitleDisplayMode(.large)`.
- `.safeAreaInset(edge: .bottom) { Button { model.changeSelectionTapped() } label: { Text("Zmień wybór") ... } }` — primary CTA on `Theme.accent`, 50pt height, 12pt corner radius, 24pt horizontal + 16pt vertical padding.
- No `NavigationStack` in the production body (HomeView hosts the outer stack via `AppRootView`). `#Preview` wraps in `NavigationStack` only so the Xcode Canvas renders the large title.

Imports: `FamilyControls`, `ManagedSettings`, `SwiftUI`.

### Tests (1 file)

**`DeluluDetoxTests/Features/AppSelection/BlockedViewModelTests.swift`** — `@MainActor final class BlockedViewModelTests: XCTestCase` with 6 methods:

| Test | Asserts |
|------|---------|
| `testInitFiltersInitialEmissionIntoThreeArrays` | Initial `Blocklist(apps: 1, cat: 2, web: 1)` → `appRecords.count == 1`, `categoryRecords.count == 2`, `webRecords.count == 1` |
| `testPublisherEmissionUpdatesAllThreeArrays` | `mockObserve.subject.send(...)` + `await Task.yield()` propagates new arrays |
| `testDeleteTappedInvokesRemoveUseCaseWithRecordID` | `mockRemove.callCount == 1`, `capturedRecordID == id`, `errorMessage == nil` |
| `testDeleteFailureSetsErrorMessage` | `stubbedError` set → `errorMessage == "Nie udało się usunąć."` |
| `testChangeSelectionTappedInvokesCallback` | Closure fires |
| `testChangeSelectionTappedWhenCallbackNilIsNoOp` | No crash on nil callback |

`setUp()` resets `DIContainer.shared`, allocates fresh mocks, registers them at `.unique` scope. The first test re-registers `MockObserveBlocklistUseCase` with a seeded initial blocklist to exercise `init`-time filtering.

## Grep Audit

```
$ grep -n "@MainActor" DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift
16:@MainActor

$ grep -n "@Observable" DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift
17:@Observable

$ grep -n "final class BlockedViewModel: @unchecked Sendable" DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift
18:final class BlockedViewModel: @unchecked Sendable {

$ grep -c "import SwiftUI" DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift
0

$ grep -c "@ObservationIgnored" DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift
4

$ grep -n "@LazyInjected private var observeBlocklist: ObserveBlocklistUseCase" DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift
33:    @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase

$ grep -n "@LazyInjected private var removeRecord: RemoveTokenRecordUseCase" DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift
36:    @LazyInjected private var removeRecord: RemoveTokenRecordUseCase

$ grep -n "struct BlockedView: View" DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
19:struct BlockedView: View {

$ grep -n '@Bindable var model: BlockedViewModel' DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
20:    @Bindable var model: BlockedViewModel

$ grep -n 'Section("Aplikacje")'  DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
25:                Section("Aplikacje") {

$ grep -n 'Section("Kategorie")' DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
42:                Section("Kategorie") {

$ grep -n 'Section("Strony www")' DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
59:                Section("Strony www") {

$ grep -n '.navigationTitle("Zablokowane")' DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
76:        .navigationTitle("Zablokowane")

$ grep -n '.listStyle(.insetGrouped)' DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
75:        .listStyle(.insetGrouped)

$ grep -c "allowsFullSwipe: true" DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
3

$ grep -n "Theme.accent" DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
90:            .tint(Theme.accent)

$ grep -c "NavigationStack {" DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift
1     # Preview only — confirmed by reading line 106 in BlockedView.swift
```

Section order confirmed by line-number ascent (25 < 42 < 59). `allowsFullSwipe: true` appears exactly 3× (once per Section). `NavigationStack {` appears exactly once — in `#Preview` at the bottom.

## Test Output Excerpt

Full suite run on iPhone 17 simulator UUID `6D73311F-3541-4B74-92E8-8014FABC3329` (iOS 26.3 SDK via Xcode 26.3):

```
Test Suite 'BlockedViewModelTests' started at 2026-04-19 13:31:46.727.
Test Case '-[DeluluDetoxTests.BlockedViewModelTests testChangeSelectionTappedInvokesCallback]' passed (0.002 seconds).
Test Case '-[DeluluDetoxTests.BlockedViewModelTests testChangeSelectionTappedWhenCallbackNilIsNoOp]' passed (0.000 seconds).
Test Case '-[DeluluDetoxTests.BlockedViewModelTests testDeleteFailureSetsErrorMessage]' passed (0.003 seconds).
Test Case '-[DeluluDetoxTests.BlockedViewModelTests testDeleteTappedInvokesRemoveUseCaseWithRecordID]' passed (0.001 seconds).
Test Case '-[DeluluDetoxTests.BlockedViewModelTests testInitFiltersInitialEmissionIntoThreeArrays]' passed (0.001 seconds).
Test Case '-[DeluluDetoxTests.BlockedViewModelTests testPublisherEmissionUpdatesAllThreeArrays]' passed (0.004 seconds).
Test Suite 'BlockedViewModelTests' passed at 2026-04-19 13:31:46.739.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.011 (0.012) seconds

Test Suite 'DeluluDetoxTests.xctest' passed
	 Executed 41 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.183 (0.192) seconds
Test Suite 'All tests' passed
	 Executed 41 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.183 (0.192) seconds
** TEST SUCCEEDED **
```

41 = 35 baseline (Plan 02-03) + 6 new `BlockedViewModelTests`. Zero regressions from Plan 02-03 baseline.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 (RED) | `7b948d9` | `test(02-04): add failing tests for BlockedViewModel` |
| 1 (GREEN) | `acba135` | `feat(02-04): implement BlockedViewModel (SEL-04)` |
| 2 | `dd64f89` | `feat(02-04): implement BlockedView — 3-section list + swipe delete + CTA` |

TDD flow: RED commit is a separate artifact per `<task tdd="true">` protocol — it compiles against a missing type and was intentionally broken at that point. GREEN lands the minimal implementation that turns all 6 tests green. No refactor pass needed — the scaffold matched the plan's expected shape.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Doc-comment `\`import SwiftUI\`` broke `grep -c "import SwiftUI"` invariant**

- **Found during:** Task 1 verification. The plan's acceptance criteria requires `grep -c "import SwiftUI" BlockedViewModel.swift` → 0. My initial doc-block included the literal phrase `` `import SwiftUI` `` in a comment, which `grep -c` happily counts as a match (regardless of whether it's inside a comment). So the grep returned 1, not 0.
- **Fix:** Rewrote the comment to `"ViewModel is SwiftUI-free — clean Architecture Presentation-boundary discipline."` — still communicates intent, no longer contains the literal string `"import SwiftUI"`.
- **Files modified:** `DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift` line 15 (comment only).
- **Commits:** Folded into `acba135` (Task 1 GREEN) — the pre-fix comment never reached a committed state.

### Carry-over notes

**2. [Rule 3 — Environment, Plans 02-01 / 02-02 / 02-03]** Host's iPhone 17 simulator UUID is `6D73311F-3541-4B74-92E8-8014FABC3329`; CLAUDE.md canonical `C958163F-...` is not present on this machine. Used raw `xcodebuild` via Bash because XcodeBuildMCP simulator tools were not callable in this runtime even though the server descriptor listed them. All other CLAUDE.md conventions honored (project.yml edited by plan? No — no project.yml edits needed this plan; `xcodegen generate` run after each source-file addition; zero `.xcodeproj` hand-edits). No repo-level change needed.

## Findings

- **`onChangeSelection` callback is the cleanest way to keep the VM SwiftUI-free.** Any other pattern (VM owns a `Destination?` for the picker, or VM imports SwiftUINavigation) would have dragged UI-frame types into a VM that otherwise needs only `Combine + Foundation`. Keeping picker ownership in `HomeViewModel` (Plan 06) preserves the Single-Responsibility boundary: `BlockedViewModel` is "show + delete", `HomeViewModel` is "route", and they communicate by closure, not by coupling.
- **Conditional `Section` rendering matters more than it looks.** Wrapping each section in `if !model.xRecords.isEmpty { Section(...) }` prevents blank headers when a kind happens to be empty (very common — most users block apps but no web domains). Not in the raw List semantics by default; SwiftUI renders an empty Section as a visible header with zero rows below. The if-wrapper is the only clean fix.
- **`allowsFullSwipe: true` is correct for destructive-by-nature list actions per Apple HIG** — users expect iOS-style swipe-to-delete in lists of items they put there themselves. Adding a confirm dialog would be friction; users can add the token back immediately via the picker if they swipe by accident. (Matches 02-UI-SPEC.md §Destructive actions.)
- **`@ObservationIgnored` on `cancellables` and `logger`** — Plan 02-03's and Onboarding's patterns both mark these explicitly. Not strictly required for correctness (neither is user-visible state), but it future-proofs against Xcode's Observation macro creating unnecessary tracking paths on mutable `Set<AnyCancellable>`. Mirrors `AppRootViewModel.cancellables` exactly.
- **Threat T-02-04-02 (Tampering: corrupt encodedToken)** is automatically mitigated by the `if let token = record.xToken()` unwrap at each row. A decode failure returns nil → row not rendered → user sees no broken placeholder.
- **Threat T-02-04-01 (Information Disclosure: Logger)** is upheld by design: the two log statements only emit `recordID.uuidString` (public scalar) and `String(describing: error)` (error type description, not payload). Never prints raw `encodedToken` bytes or `FamilyActivitySelection` contents. Grep confirms: no `%@` format over a record/blocklist/selection in the file.

## Acceptance Criteria Check

### Task 1

| Criterion | Status |
|-----------|--------|
| `BlockedViewModel.swift` exists at `Features/AppSelection/ViewModel/` | PASS |
| `grep @MainActor` → line 16 | PASS |
| `grep @Observable` → line 17 | PASS |
| `grep final class BlockedViewModel: @unchecked Sendable` → line 18 | PASS |
| `grep -c import SwiftUI` in VM → 0 | PASS |
| `grep -c @ObservationIgnored` → 4 | PASS (matches 4 declarations: 2 LazyInjected + cancellables + logger) |
| `grep @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase` → line 33 | PASS |
| `grep @LazyInjected private var removeRecord: RemoveTokenRecordUseCase` → line 36 | PASS |
| `build_sim` green (raw `xcodebuild build`) | PASS |
| All 6 `BlockedViewModelTests` methods PASS | PASS |
| Full `test_sim` green | PASS (41 tests, 3 skipped, 0 failures) |

### Task 2

| Criterion | Status |
|-----------|--------|
| `BlockedView.swift` exists at `Features/AppSelection/View/` | PASS |
| `grep struct BlockedView: View` → line 19 | PASS |
| `grep @Bindable var model: BlockedViewModel` → line 20 | PASS |
| `grep Section("Aplikacje")` → line 25 | PASS |
| `grep Section("Kategorie")` → line 42 | PASS |
| `grep Section("Strony www")` → line 59 | PASS |
| `grep .navigationTitle("Zablokowane")` → line 76 | PASS |
| `grep .listStyle(.insetGrouped)` → line 75 | PASS |
| `grep -c allowsFullSwipe: true` → 3 | PASS (one per Section) |
| `grep Zmień wybór` (label) → line 82 | PASS (also in line 14 doc-comment, harmless) |
| `grep Theme.accent` → line 90 | PASS |
| `grep -c NavigationStack {` → 1 (preview only) | PASS |
| `grep -c import SwiftUI` in VM → 0 | PASS |
| `build_sim` green | PASS |
| Full `test_sim` green | PASS (41 tests, 3 skipped, 0 failures) |

### Plan-level verification

| Criterion | Status |
|-----------|--------|
| All 5 success criteria from `<success_criteria>` met | PASS |
| `git diff DeluluDetox/Sources/Features/Home` empty vs base `7d9b4a5` | PASS (HomeView rewire is Plan 06) |
| `git diff DeluluDetox/Sources/Features/Root` empty vs base `7d9b4a5` | PASS (scenePhase reconcile is Plan 05) |
| `BlockedView` `#Preview` compiles | PASS (full `xcodebuild build` green — previews compile as part of the main target) |

## Next Steps

Plan 02-04 closes the Wave-4 VM+View pair. Downstream work:

- **Plan 02-05 AppRootViewModel scenePhase hook** (parallel Wave 4 agent) — lands `ReconcileBlocklistUseCase` invocation on `.active` phase. Disjoint file set from this plan.
- **Plan 02-06 HomeViewModel + HomeView rewire** — will:
  - Embed `BlockedView` as the non-empty branch (when `blocklist.records.count > 0`).
  - Instantiate `BlockedViewModel` via `@State private var blockedModel = BlockedViewModel()` in HomeView.
  - Assign `blockedModel.onChangeSelection = { [weak homeModel] in homeModel?.chooseAppsTapped() }` in `.onAppear`.
  - Wire the picker Destination on `HomeViewModel`.
- **Plan 02-07 device human-verify** — end-to-end exercise of picker → persisted blocklist → BlockedView render → swipe-to-delete → re-render. Uses the VM + View shipped here.

No further writes to `Features/AppSelection/ViewModel/` or `Features/AppSelection/View/` are expected before Plan 02-07 unless device testing surfaces a Rule 2 gap.

## Self-Check: PASSED

- [x] `DeluluDetox/Sources/Features/AppSelection/ViewModel/BlockedViewModel.swift` exists (Read-verified + git-tracked in `acba135`).
- [x] `DeluluDetox/Sources/Features/AppSelection/View/BlockedView.swift` exists (Read-verified + git-tracked in `dd64f89`).
- [x] `DeluluDetoxTests/Features/AppSelection/BlockedViewModelTests.swift` exists (git-tracked in `7b948d9`).
- [x] Commit `7b948d9` present in `git log --oneline`.
- [x] Commit `acba135` present in `git log --oneline`.
- [x] Commit `dd64f89` present in `git log --oneline`.
- [x] Full test suite green on iPhone 17 simulator / iOS 26.3 — 41 tests, 3 device-seeded skips, 0 failures.
- [x] No `import SwiftUI` in `Features/AppSelection/ViewModel/BlockedViewModel.swift` (Clean Architecture Presentation-boundary upheld).
- [x] `NavigationStack {` appears exactly once in `BlockedView.swift` — inside `#Preview` only (HomeView hosts the outer stack per Plan 06).
- [x] `allowsFullSwipe: true` appears exactly 3× (one per Section).
