---
phase: 01-foundation-onboarding
reviewed: 2026-04-18T12:00:00Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - DeluluDetox/Sources/App/DeluluDetoxApp.swift
  - DeluluDetox/Sources/App/DependencyContainer.swift
  - DeluluDetox/Sources/Data/Repositories/ScreenTimeAuthRepositoryImpl.swift
  - DeluluDetox/Sources/DesignSystem/Theme.swift
  - DeluluDetox/Sources/Domain/Repositories/ScreenTimeAuthRepository.swift
  - DeluluDetox/Sources/Domain/UseCases/RequestScreenTimeAuthUseCase.swift
  - DeluluDetox/Sources/Features/Denial/DenialView.swift
  - DeluluDetox/Sources/Features/Denial/DenialViewModel.swift
  - DeluluDetox/Sources/Features/Home/HomeView.swift
  - DeluluDetox/Sources/Features/Home/HomeViewModel.swift
  - DeluluDetox/Sources/Features/Onboarding/OnboardingView.swift
  - DeluluDetox/Sources/Features/Onboarding/OnboardingViewModel.swift
  - DeluluDetox/Sources/Features/Root/AppRootView.swift
  - DeluluDetox/Sources/Features/Root/AppRootViewModel.swift
  - DeluluDetoxTests/AppRootViewModelTests.swift
  - DeluluDetoxTests/DeluluDetoxTests.swift
  - DeluluDetoxTests/Mocks/MockScreenTimeAuthRepository.swift
  - DeluluDetoxTests/OnboardingViewModelTests.swift
  - Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
  - Extensions/ShieldActionExtension/ShieldActionExtension.swift
  - Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift
  - project.yml
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-18T12:00:00Z
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Overall the codebase is well-structured for a Phase 1 foundation. The Clean Architecture layering (Repository protocol, UseCase, ViewModel, View) is correctly applied. ViewModels correctly use `@Observable` and import `Observation` rather than SwiftUI. The XcodeGen project.yml is comprehensive and properly configures all three Screen Time extensions with correct entitlements.

Three warnings relate to potential concurrency safety issues under Swift 6 strict concurrency and missing user-facing error feedback. Three info items cover minor code quality observations.

## Warnings

### WR-01: AppRootViewModel lacks MainActor isolation for state mutations

**File:** `DeluluDetox/Sources/Features/Root/AppRootViewModel.swift:6-58`
**Issue:** `AppRootViewModel` is an `@Observable` class whose `screen` property drives the entire UI. Neither the class, its `init`, nor `checkAuthorization()` are annotated with `@MainActor`. Under Swift 6.2 strict concurrency, accessing `AuthorizationCenter.shared.authorizationStatus` (which is `@MainActor`-isolated in FamilyControls) from a non-isolated context on lines 26 and 42 is a concurrency violation. Additionally, mutating `screen` from a non-main-actor context would be a data race for the SwiftUI observation system.

Currently all call sites happen to run on `@MainActor` (SwiftUI view body, `onChange`, and `@MainActor`-annotated ViewModel methods), but the method itself has no enforcement. Any future caller from a background context would introduce a data race.

**Fix:** Annotate the entire class with `@MainActor`:
```swift
@Observable
@MainActor
final class AppRootViewModel {
    // ... rest unchanged
}
```

### WR-02: OnboardingView does not display authorization errors to the user

**File:** `DeluluDetox/Sources/Features/Onboarding/OnboardingView.swift:1-63`
**Issue:** `OnboardingViewModel` correctly captures the error in its `error: String?` property (line 29 of OnboardingViewModel.swift), but `OnboardingView` never reads or displays this property. If the Screen Time authorization prompt fails (e.g., the user denies, the device is in an invalid state, or `AuthorizationCenter` throws), the user sees no feedback -- the button simply re-enables with no indication of what happened.

**Fix:** Add an error display below the button, for example:
```swift
// After the Button's .padding(.horizontal, 24)
if let errorMessage = model.error {
    Text(errorMessage)
        .font(.footnote)
        .foregroundStyle(.red)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 12)
}
```

### WR-03: DenialViewModel silently swallows authorization errors

**File:** `DeluluDetox/Sources/Features/Denial/DenialViewModel.swift:19-29`
**Issue:** Unlike `OnboardingViewModel` which at least stores the error in a property, `DenialViewModel.retryTapped()` only logs the error (line 26) and provides no `error` property for the view to display. If the retry fails, the user sees the button re-enable with no feedback. The denial screen is specifically shown when the user previously denied access, so communicating errors clearly is especially important here.

**Fix:** Add an `error` property and set it in the catch block, mirroring `OnboardingViewModel`:
```swift
@Observable
final class DenialViewModel {
    private(set) var isRequesting = false
    private(set) var error: String?
    // ...

    @MainActor
    func retryTapped() async {
        isRequesting = true
        error = nil
        do {
            try await requestAuth()
            logger.info("Screen Time authorization granted on retry")
            onAuthorized?()
        } catch {
            logger.error("Retry authorization failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }
        isRequesting = false
    }
}
```
Then display it in `DenialView` similarly to WR-02.

## Info

### IN-01: Test name does not match test behavior

**File:** `DeluluDetoxTests/OnboardingViewModelTests.swift:42-49`
**Issue:** `testIsRequestingDuringRequest` only asserts `isRequesting` is false before any request is made. It does not actually verify that `isRequesting` becomes `true` during the async request, which is what the name implies. This test provides no value beyond what `testGrantAccessSuccess` already covers (which asserts `isRequesting` is false after completion).

**Fix:** Either remove the test or implement it properly by using a mock that suspends mid-request so you can observe the intermediate `isRequesting == true` state. For example, use a `CheckedContinuation` in the mock to pause execution and assert the in-flight state.

### IN-02: Placeholder test should be removed

**File:** `DeluluDetoxTests/DeluluDetoxTests.swift:1-9`
**Issue:** `testPlaceholder` asserts `true` unconditionally. The comment says "replaced in Plan 02" but it still exists. This provides zero test coverage and adds noise to test runs.

**Fix:** Delete `DeluluDetoxTests/DeluluDetoxTests.swift` entirely, or replace with a meaningful test if one is needed.

### IN-03: DependencyContainer creates new ViewModel instances on every screen transition

**File:** `DeluluDetox/Sources/Features/Root/AppRootViewModel.swift:41-57`
**Issue:** Every call to `checkAuthorization()` creates a fresh ViewModel via `container.makeHomeViewModel()`, `container.makeDenialViewModel()`, or `container.makeOnboardingViewModel()`. This means that each time the app returns to foreground (`scenePhase == .active`), if the status is still `.approved`, a brand new `HomeViewModel` replaces the existing one, losing any transient state. In Phase 1 this is harmless since `HomeViewModel` is stateless, but in Phase 2+ when `HomeViewModel` holds app selections and other state, this will silently discard user state on every foreground transition.

**Fix:** Guard against redundant transitions. For example:
```swift
func checkAuthorization() {
    let status = container.screenTimeAuthRepository.authorizationStatus
    switch status {
    case .approved:
        if case .home = screen { return } // already on home
        screen = .home(container.makeHomeViewModel())
    case .denied:
        if case .denial = screen { return }
        // ... create denial VM
    default:
        if case .onboarding = screen { return }
        // ... create onboarding VM
    }
}
```

---

_Reviewed: 2026-04-18T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
