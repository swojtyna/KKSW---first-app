---
phase: 01-foundation-onboarding
fixed_at: 2026-04-18T19:28:44Z
review_path: .planning/phases/01-foundation-onboarding/01-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-04-18T19:28:44Z
**Source review:** .planning/phases/01-foundation-onboarding/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: AppRootViewModel lacks MainActor isolation for state mutations

**Files modified:** `DeluluDetox/Sources/Features/Root/AppRootViewModel.swift`, `DeluluDetoxTests/AppRootViewModelTests.swift`
**Commit:** 20aa69d
**Applied fix:** Added `@MainActor` annotation to `AppRootViewModel` class to enforce main-thread isolation for all state mutations under Swift 6.2 strict concurrency. Also annotated `AppRootViewModelTests` with `@MainActor` to match the isolation requirement so tests compile correctly.

### WR-02: OnboardingView does not display authorization errors to the user

**Files modified:** `DeluluDetox/Sources/Features/Onboarding/OnboardingView.swift`
**Commit:** 3e80d80
**Applied fix:** Added conditional error text display below the "Grant Access" button. When `model.error` is non-nil, a red footnote-sized `Text` shows the error message with center alignment and horizontal padding, giving the user visible feedback when Screen Time authorization fails.

### WR-03: DenialViewModel silently swallows authorization errors

**Files modified:** `DeluluDetox/Sources/Features/Denial/DenialViewModel.swift`, `DeluluDetox/Sources/Features/Denial/DenialView.swift`
**Commit:** bea78fc
**Applied fix:** Added `private(set) var error: String?` property to `DenialViewModel`, mirroring the pattern already established in `OnboardingViewModel`. Updated `retryTapped()` to clear the error at the start and set it in the catch block. Added matching error display in `DenialView` below the retry button, identical in style to the `OnboardingView` error display from WR-02.

---

_Fixed: 2026-04-18T19:28:44Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
