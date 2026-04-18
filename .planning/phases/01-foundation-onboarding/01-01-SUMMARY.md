---
phase: 01-foundation-onboarding
plan: 01
subsystem: project-scaffold
tags: [xcodegen, multi-target, extensions, domain-layer, design-system, di-container]
dependency_graph:
  requires: []
  provides:
    - multi-target XcodeGen project (main app + 3 extensions + test target)
    - App Group entitlement on all targets
    - swift-navigation SPM dependency
    - Theme design system with centralized colors
    - ScreenTimeAuthRepository protocol + impl
    - RequestScreenTimeAuthUseCase protocol + impl
    - DependencyContainer with factory methods
  affects:
    - project.yml
    - DeluluDetox/Sources/App/DependencyContainer.swift
    - DeluluDetox/Sources/DesignSystem/Theme.swift
    - DeluluDetox/Sources/Domain/
    - DeluluDetox/Sources/Data/
    - Extensions/
tech_stack:
  added:
    - swift-navigation (SwiftUINavigation) 2.8.0 via SPM
    - FamilyControls framework (domain layer)
    - DeviceActivity framework (extension stub)
    - ManagedSettings framework (extension stubs)
    - ManagedSettingsUI framework (extension stub)
  patterns:
    - settingGroups for DRY XcodeGen config
    - protocol in Domain + impl in Data (dependency inversion)
    - callAsFunction UseCase convention
    - constructor injection via DependencyContainer factory methods
key_files:
  created:
    - project.yml (updated)
    - Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
    - Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift
    - Extensions/ShieldActionExtension/ShieldActionExtension.swift
    - DeluluDetox/Sources/DesignSystem/Theme.swift
    - DeluluDetox/Sources/Domain/Repositories/ScreenTimeAuthRepository.swift
    - DeluluDetox/Sources/Domain/UseCases/RequestScreenTimeAuthUseCase.swift
    - DeluluDetox/Sources/Data/Repositories/ScreenTimeAuthRepositoryImpl.swift
    - DeluluDetox/Sources/App/DependencyContainer.swift
    - DeluluDetox/Resources/Assets.xcassets/AccentColor.colorset/Contents.json (updated)
    - DeluluDetoxTests/DeluluDetoxTests.swift
    - DeluluDetox/DeluluDetox.entitlements
    - Extensions/*/Info.plist (3 generated)
    - Extensions/*/*.entitlements (3 generated)
  modified:
    - project.yml
    - DeluluDetox/Resources/Assets.xcassets/AccentColor.colorset/Contents.json
decisions:
  - "Electric violet (#7C3AED / sRGB 0.486, 0.227, 0.929) chosen as accent color -- bold, works on white, matches playful brand tone"
  - "DependencyContainer defines ViewModel factory method contracts for Plan 02 -- intentional compile errors until ViewModels exist"
  - "Extension stubs return default ShieldConfiguration and .close actions -- customized in Phase 4"
  - "@unchecked Sendable on ScreenTimeAuthRepositoryImpl -- AuthorizationCenter.shared is safe from MainActor but not formally Sendable"
metrics:
  duration: 4 minutes
  completed: 2026-04-18T18:31:00Z
  tasks: 2/2
  files_created: 18
  files_modified: 2
---

# Phase 01 Plan 01: Project Scaffold & Domain Layer Summary

Multi-target XcodeGen project with 3 Screen Time extension stubs, App Group entitlements, swift-navigation SPM dependency, Theme design system (electric violet accent), Clean Architecture domain layer (ScreenTimeAuthRepository + RequestScreenTimeAuthUseCase), and DependencyContainer with constructor injection factories.

## Task Results

### Task 1: Configure XcodeGen multi-target project with extensions, SPM deps, and entitlements
**Commit:** 70cd77e
**Status:** Complete

- Updated `project.yml` with `settingGroups` (shared-ios), `packages` (swift-navigation 2.8.0), and 5 targets
- Main app target: dependencies on 3 extension targets + SwiftUINavigation, entitlements with App Group + family-controls
- DeviceActivityMonitorExtension: `com.apple.deviceactivity.monitor-extension` NSExtensionPointIdentifier
- ShieldConfigurationExtension: `com.apple.ManagedSettings.shield-configuration-service` NSExtensionPointIdentifier
- ShieldActionExtension: `com.apple.ManagedSettings.shield-action-service` NSExtensionPointIdentifier
- DeluluDetoxTests: unit test target depending on main app
- All 4 targets share `group.com.kksw.DeluluDetox` App Group and `com.apple.developer.family-controls: true`
- AccentColor.colorset updated with electric violet sRGB values (0.486, 0.227, 0.929)
- `xcodegen generate` exits 0; build succeeds for all targets on simulator (with CFBundleVersion warnings only)

### Task 2: Create domain layer, design system, and DI container
**Commit:** beed2f4
**Status:** Complete

- `Theme.swift`: enum with 5 static color properties (accent via AccentColor asset, background/primaryText/secondaryText/tertiaryText via system colors)
- `ScreenTimeAuthRepository.swift`: protocol with `authorizationStatus` and `requestAuthorization()` in Domain layer
- `ScreenTimeAuthRepositoryImpl.swift`: wraps `AuthorizationCenter.shared` in Data layer with `@unchecked Sendable`
- `RequestScreenTimeAuthUseCase.swift`: protocol + impl with `callAsFunction` pattern, delegates to repository
- `DependencyContainer.swift`: struct with factory methods for all 4 ViewModels (AppRoot, Onboarding, Denial, Home)
- DependencyContainer intentionally does not compile until Plan 02 creates the ViewModel types -- this is by design
- All other files compile cleanly; only DependencyContainer references missing types
- XcodeGen-generated .entitlements and Info.plist files for all 3 extensions committed

## Deviations from Plan

None -- plan executed exactly as written.

## Known Build State

The project does NOT fully compile after this plan. `DependencyContainer.swift` references 4 ViewModel types (`AppRootViewModel`, `OnboardingViewModel`, `DenialViewModel`, `HomeViewModel`) that will be created in Plan 02. This is expected and documented in the plan. All other files compile cleanly.

## Verification Results

- `xcodegen generate`: exits 0
- Build (pre-Task 2): all targets build successfully on simulator
- Build (post-Task 2): fails only on DependencyContainer.swift (4 "cannot find type" errors for ViewModel types -- expected)
- All acceptance criteria verified via automated grep checks
- No stubs, no threat surface additions beyond plan scope

## Self-Check: PASSED

- All 12 key files exist on disk
- Commit 70cd77e (Task 1) found in git log
- Commit beed2f4 (Task 2) found in git log
