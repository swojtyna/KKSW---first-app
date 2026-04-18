---
phase: 01-foundation-onboarding
plan: 02
subsystem: onboarding-flow
tags: [viewmodel, view, swiftui, tdd, onboarding, authorization, routing]
dependency_graph:
  requires:
    - DependencyContainer with factory methods (Plan 01-01)
    - ScreenTimeAuthRepository protocol + impl (Plan 01-01)
    - RequestScreenTimeAuthUseCase protocol + impl (Plan 01-01)
    - Theme design system (Plan 01-01)
  provides:
    - AppRootViewModel with enum Screen routing
    - OnboardingViewModel with grantAccessTapped authorization
    - DenialViewModel with retryTapped authorization
    - HomeViewModel with stubbed chooseAppsTapped
    - AppRootView with scenePhase auth check
    - OnboardingView with Grant Access CTA
    - DenialView non-dismissible with Let's Try Again
    - HomeView empty state with Choose Apps to Block
    - MockScreenTimeAuthRepository for test injection
    - Unit tests for routing and authorization logic
  affects:
    - DeluluDetox/Sources/App/DeluluDetoxApp.swift
    - DeluluDetox/Sources/App/DependencyContainer.swift
    - project.yml
tech_stack:
  added: []
  patterns:
    - enum Screen routing (not @CasePathable -- full-screen swap, not modal)
    - scenePhase onChange for foreground auth recheck
    - @MainActor on async ViewModel methods for Swift 6.2 concurrency
    - @unchecked Sendable on test mock for mutable stored properties
    - @MainActor on test class for strict concurrency compliance
    - screenTag computed property for animation value binding
key_files:
  created:
    - DeluluDetox/Sources/Features/Root/AppRootViewModel.swift
    - DeluluDetox/Sources/Features/Root/AppRootView.swift
    - DeluluDetox/Sources/Features/Onboarding/OnboardingViewModel.swift
    - DeluluDetox/Sources/Features/Onboarding/OnboardingView.swift
    - DeluluDetox/Sources/Features/Denial/DenialViewModel.swift
    - DeluluDetox/Sources/Features/Denial/DenialView.swift
    - DeluluDetox/Sources/Features/Home/HomeViewModel.swift
    - DeluluDetox/Sources/Features/Home/HomeView.swift
    - DeluluDetoxTests/Mocks/MockScreenTimeAuthRepository.swift
    - DeluluDetoxTests/AppRootViewModelTests.swift
    - DeluluDetoxTests/OnboardingViewModelTests.swift
  modified:
    - DeluluDetox/Sources/App/DeluluDetoxApp.swift
    - DeluluDetox/Sources/App/DependencyContainer.swift
    - project.yml
  deleted:
    - DeluluDetox/Sources/App/ContentView.swift
decisions:
  - "DependencyContainer changed from property initializer to init parameter with default for testability"
  - "MockScreenTimeAuthRepository uses @unchecked Sendable -- test-only, mutable properties needed for stubbing"
  - "OnboardingViewModelTests uses @MainActor class-level annotation for Swift 6.2 strict concurrency"
  - "AppRootViewModel.Screen enum is plain (not @CasePathable) -- full-screen routing, not modal navigation"
  - "screenTag computed property added to AppRootViewModel for animation value binding"
  - "MARKETING_VERSION and CURRENT_PROJECT_VERSION added to shared-ios settingGroup to fix extension install on simulator"
metrics:
  duration: 10 minutes
  completed: 2026-04-18T18:46:00Z
  tasks: 2/2
  files_created: 11
  files_modified: 3
  files_deleted: 1
---

# Phase 01 Plan 02: Onboarding Flow Summary

Complete onboarding flow with TDD: 4 ViewModels (AppRoot routing, Onboarding auth request, Denial retry, Home empty state), 4 Views matching UI spec (lock.iphone/hand.raised.fill/apps.iphone SF Symbols, Theme colors, 0.35s crossfade), 8 unit tests passing, scenePhase authorization recheck.

## Task Results

### Task 1: Create ViewModels with tests (TDD RED/GREEN)
**Commits:** d8fbe8e (RED), c88bb1c (GREEN)
**Status:** Complete

- **RED:** Created MockScreenTimeAuthRepository, AppRootViewModelTests (4 tests), OnboardingViewModelTests (3 tests). Tests fail because ViewModel types don't exist yet.
- **GREEN:** Created AppRootViewModel (enum Screen routing via DependencyContainer), OnboardingViewModel (@MainActor grantAccessTapped with error handling), DenialViewModel (retryTapped), HomeViewModel (chooseAppsTapped no-op). Updated DependencyContainer to accept injectable repository. All 8 tests pass.
- Swift 6.2 concurrency fixes: @unchecked Sendable on mock, @MainActor on test class, MARKETING_VERSION/CURRENT_PROJECT_VERSION for simulator extension install.

### Task 2: Create Views and wire app entry point
**Commit:** 2d88026
**Status:** Complete

- AppRootView: switch on model.screen, scenePhase onChange calls checkAuthorization, .animation(.easeInOut(duration: 0.35)) crossfade
- OnboardingView: "Your Phone Is Winning" headline, lock.iphone at 72pt hierarchical, Grant Access CTA with ProgressView spinner
- DenialView: "Nice Try" headline, hand.raised.fill at 72pt, "Let's Try Again" CTA, non-dismissible (no nav bar, no dismiss)
- HomeView: "No Apps Blocked Yet" heading, apps.iphone at 56pt tertiaryLabel, "Choose Apps to Block" CTA, NavigationStack with large title
- DeluluDetoxApp wires DependencyContainer to AppRootView
- ContentView.swift deleted (replaced by feature views)
- All colors use Theme.* -- zero raw Color literals in any View file
- Build succeeds on simulator, all 8 tests pass

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6.2 Sendable conformance on mock**
- **Found during:** Task 1 GREEN phase
- **Issue:** MockScreenTimeAuthRepository has mutable stored properties but ScreenTimeAuthRepository inherits Sendable. Swift 6.2 strict concurrency rejects this.
- **Fix:** Added `@unchecked Sendable` to MockScreenTimeAuthRepository (test-only class, single-threaded test context).
- **Files modified:** DeluluDetoxTests/Mocks/MockScreenTimeAuthRepository.swift
- **Commit:** c88bb1c

**2. [Rule 1 - Bug] Swift 6.2 data race warning on async test methods**
- **Found during:** Task 1 GREEN phase
- **Issue:** `await vm.grantAccessTapped()` in test sends ViewModel across isolation boundary because grantAccessTapped is @MainActor.
- **Fix:** Added `@MainActor` annotation to OnboardingViewModelTests class.
- **Files modified:** DeluluDetoxTests/OnboardingViewModelTests.swift
- **Commit:** c88bb1c

**3. [Rule 3 - Blocking] Extension targets missing CFBundleVersion for simulator install**
- **Found during:** Task 1 GREEN phase
- **Issue:** Simulator refused to install app -- "bundleVersion must be set in placeholder attributes for an app extension placeholder."
- **Fix:** Added MARKETING_VERSION ("1.0") and CURRENT_PROJECT_VERSION ("1") to shared-ios settingGroup in project.yml.
- **Files modified:** project.yml
- **Commit:** c88bb1c

**4. [Rule 3 - Blocking] Test target missing GENERATE_INFOPLIST_FILE**
- **Found during:** Task 1 RED phase
- **Issue:** DeluluDetoxTests target could not code sign because no Info.plist was being generated.
- **Fix:** Added GENERATE_INFOPLIST_FILE: true to DeluluDetoxTests target in project.yml.
- **Files modified:** project.yml
- **Commit:** d8fbe8e

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| `chooseAppsTapped()` no-op | DeluluDetox/Sources/Features/Home/HomeViewModel.swift | 8 | Intentional -- wired to FamilyActivityPicker in Phase 2 (Plan 02-01). Button is visually active per UI spec D-06. |

## TDD Gate Compliance

- RED gate: `d8fbe8e` (test(01-02) commit with failing tests)
- GREEN gate: `c88bb1c` (feat(01-02) commit with passing implementations)
- REFACTOR gate: Skipped (no cleanup needed -- code is minimal and clean)

## Verification Results

- `xcodegen generate`: exits 0
- Build (DeluluDetox scheme): BUILD SUCCEEDED on iPhone 17 Pro simulator
- Tests (DeluluDetoxTests scheme): 8 tests, 0 failures -- TEST SUCCEEDED
- All acceptance criteria verified via automated grep checks (17 criteria Task 1, 21 criteria Task 2)
- No raw Color literals in any View file
- All ViewModels import Observation, never SwiftUI

## Self-Check: PASSED

- All 11 created files exist on disk
- All 3 commits found in git log (d8fbe8e, c88bb1c, 2d88026)
- ContentView.swift confirmed deleted
