---
phase: 02
slug: app-selection
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-19
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (established in Phase 01.1; `DeluluDetoxTests` target in `project.yml`) |
| **Config file** | `project.yml` (§`targets.DeluluDetoxTests`) |
| **Quick run command** | `test_sim` (XcodeBuildMCP) with `-only-testing:DeluluDetoxTests/Features/AppSelection` (scoped per-feature) — or scope to `Features/Home` / `Features/Root` when those are edited |
| **Full suite command** | `test_sim` (XcodeBuildMCP) against scheme `DeluluDetox`, no `-only-testing` filter |
| **Estimated runtime** | ~20 seconds full suite (Phase 01.1 baseline ~14s for 14 tests; +~40 new tests projected) |

---

## Sampling Rate

- **After every task commit:** Run quick run command scoped to the feature touched
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green + manual human-verify on physical iOS 26+ device
- **Max feedback latency:** ~20 seconds (full suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | SEL-01, SEL-02, SEL-03 | — | A1: ApplicationToken/ActivityCategoryToken/WebDomainToken round-trip via JSONEncoder preserves renderability | unit | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlockedTokenCodableTests` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | SEL-01 | — | A2: FamilyActivityPicker inside NavigationStack in `.sheet(item:)` presents/dismisses without crash | integration (UI spike) | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/PickerHostViewSpikeTests` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | SEL-01..05 | V5 (input validation), V12 (files) | Blocklist + TokenRecord Codable schema with UUID-keyed records, schemaVersion, needsRepair defaults; merge semantics preserve existing UUIDs | unit | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistTests` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | SEL-03, SEL-04 | V4 (access control), V5, V12 | BlocklistRepository atomic write to App Group, CurrentValueSubject emits on mutate, decoder falls back to empty on corrupt JSON, containerURL gated to `group.com.kksw.DeluluDetox` | integration | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 3 | SEL-01, SEL-04, SEL-05 | V4 | Four UseCases (Observe/Update/RemoveRecord/Reconcile) passthrough to Repo; AppSelectionInjection registers Repo=.application + UCs=.unique; DeluluDetoxApp.init wires it after OnboardingInjection | unit | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/UseCaseTests` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 3 | SEL-01, SEL-04, SEL-05 | — | Test mocks for Repository + 4 UseCases follow post-01.1 mock-in-feature-owner pattern | unit | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/Mocks` (compile-gate via full-suite build) | ❌ W0 | ⬜ pending |
| 02-04-01 | 04 | 4 | SEL-01, SEL-02, SEL-03, SEL-04 | V7 | BlockedViewModel filters appRecords/categoryRecords/webRecords by kind; deleteTapped invokes RemoveTokenRecordUseCase; failure sets errorMessage; no SwiftUI import | unit | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlockedViewModelTests` | ❌ W0 | ⬜ pending |
| 02-04-02 | 04 | 4 | SEL-01..SEL-04 | — | BlockedView renders insetGrouped list per kind, full-swipe delete no-confirm, safeAreaInset CTA "Zmień wybór"; UI-SPEC contract honored | integration (ViewInspector / snapshot) | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlockedViewTests` | ❌ W0 | ⬜ pending |
| 02-05-01 | 05 | 4 | SEL-05 | — | AppRootViewModel adds `@LazyInjected` ReconcileBlocklistUseCase; scenePhase == .active handler calls `reconcileBlocklist()` in parallel to `refreshStatus()` | unit | `test_sim -only-testing:DeluluDetoxTests/Features/Root/AppRootViewModelTests/testSceneActiveCallsReconcile` | ❌ W0 (file extended) | ⬜ pending |
| 02-06-01 | 06 | 5 | SEL-01, SEL-02, SEL-03 | — | HomeViewModel Destination enum (@CasePathable) with `.picker(FamilyActivitySelection)` case; chooseAppsTapped seeds from lastSelection; pickerDismissed invokes UpdateBlocklistUseCase; subscribes to ObserveBlocklistUseCase publisher on init | unit | `test_sim -only-testing:DeluluDetoxTests/Features/Home/HomeViewModelTests` | ❌ W0 (file extended) | ⬜ pending |
| 02-06-02 | 06 | 5 | SEL-01, SEL-02, SEL-03 | — | HomeView branches body on `snapshot.isEmpty` (onboarding-CTA vs BlockedView); PickerHostView wraps FamilyActivityPicker in `.sheet(item: $model.destination.picker)`; Polish copy matches UI-SPEC verbatim | integration | `test_sim -only-testing:DeluluDetoxTests/Features/Home/HomeViewTests` | ❌ W0 | ⬜ pending |
| 02-07-01 | 07 | 6 | SEL-01..05 | — | Full suite green on simulator before device checkpoint (pre-check gate) | gate | full `test_sim` with no `-only-testing` filter | existing | ⬜ pending |
| 02-07-02 | 07 | 6 | SEL-01..05 | — | Human verify on physical iOS 26+ device: picker opens with real apps, selection persists across cold relaunch, swipe-delete works, "Zmień wybór" re-opens picker with prior selection, scenePhase reconcile keeps UUIDs | manual | checkpoint:human-verify (gate="blocking") | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DeluluDetoxTests/Features/AppSelection/BlockedTokenCodableTests.swift` — A1 assumption validation (must run first)
- [ ] `DeluluDetoxTests/Features/AppSelection/PickerHostViewSpikeTests.swift` — A2 assumption validation
- [ ] `DeluluDetoxTests/Features/AppSelection/BlocklistTests.swift` — Blocklist merging semantics (SEL-02, SEL-03, SEL-05)
- [ ] `DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests.swift` — persistence + reconcile (SEL-04, SEL-05)
- [ ] `DeluluDetoxTests/Features/AppSelection/UseCaseTests.swift` — passthrough UC coverage (SEL-01, SEL-04, SEL-05)
- [ ] `DeluluDetoxTests/Features/AppSelection/BlockedViewModelTests.swift` — presentation filter + delete (SEL-01..04)
- [ ] `DeluluDetoxTests/Features/AppSelection/BlockedViewTests.swift` — UI-SPEC contract
- [ ] `DeluluDetoxTests/Features/AppSelection/Mocks/*.swift` — 5 mocks (Repository + 4 UseCases)
- [ ] **Extend** `DeluluDetoxTests/Features/Home/HomeViewModelTests.swift` — picker Destination + pickerDismissed + publisher subscription cases (file already exists)
- [ ] **Extend** `DeluluDetoxTests/Features/Home/HomeViewTests.swift` (create if absent) — empty-state vs list branch
- [ ] **Extend** `DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift` — scenePhase-triggered reconcile case (file already exists)
- [ ] Framework install: none — XCTest already in place from Phase 01.1.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| FamilyActivityPicker renders real user apps (not simulator stubs) | SEL-01, SEL-02, SEL-03 | `FamilyActivityPicker` behavior on simulator is documented-unreliable; real token bytes only on device | Install on physical iOS 26+ device with Screen Time authorized → tap "Zmień wybór" → select 2 apps, 1 category, 1 web domain → confirm selections appear in BlockedView |
| Selections survive cold relaunch | SEL-04 | Validates atomic write + containerURL reachability on real device | After device selection: force-quit app → relaunch → BlockedView still shows all records with same ordering |
| `Label(token)` renders real app icon + name on device | SEL-01 | Apple's opaque token rendering only works against real system app registry | Visually verify BlockedView rows show real app icon + display name for at least one app |
| Token rotation behavior across app session | SEL-05 | iOS 17.5–26.3.1 token rotation bug (FB14082790) only reproducible on device | Background app for >5 min → reopen → verify scenePhase .active triggers reconcile (check os.Logger in Console) → records retain same UUID, no duplicates |
| Extension read-only boundary | V4 (access control) | DeviceActivityMonitor extension exists in Phase 1; Phase 02 adds the file it will later read; manual grep-review catches regression | Grep all extension targets for `Data.write`, `FileManager.default.createFile`, or blocklist write APIs — should be zero matches |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (12/12 tasks covered above; 02-07-02 is the sole manual checkpoint, gated by `<how-to-verify>` + `<resume-signal>`)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every wave has at least one `test_sim` verify)
- [x] Wave 0 covers all MISSING references (7 new files + 3 extended)
- [x] No watch-mode flags (all commands are one-shot `test_sim`)
- [x] Feedback latency < 30s (quick run ~5s, full suite ~20s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-04-19 (populated from RESEARCH.md §Validation Architecture)
