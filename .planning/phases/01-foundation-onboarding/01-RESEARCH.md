# Phase 1: Foundation & Onboarding - Research

**Researched:** 2026-04-18
**Domain:** iOS multi-target project scaffold (XcodeGen) + Screen Time authorization flow (FamilyControls)
**Confidence:** HIGH

## Summary

Phase 1 has two orthogonal pillars: (1) scaffold a multi-target Xcode project with main app + three extension targets (DeviceActivityMonitor, ShieldConfiguration, ShieldAction) sharing an App Group, and (2) implement an onboarding flow that explains Screen Time permission, triggers `AuthorizationCenter.shared.requestAuthorization(for: .individual)`, and gates the entire app on authorization success.

The project already has a working XcodeGen `project.yml` with a single main app target (`DeluluDetox`, bundle ID `com.kksw.DeluluDetox`, iOS 26.0, Swift 6.2). Extension targets must be added as `type: app-extension` with correct `NSExtensionPointIdentifier` values and shared App Group entitlements. The architecture guide mandates Clean Architecture MVVM with `@Observable` ViewModels, constructor injection via `DependencyContainer`, and state-driven navigation using `swift-navigation` (pointfreeco).

Screen Time authorization works fully on device with the development entitlement (no Apple approval needed yet). On the simulator, `requestAuthorization(for: .individual)` fails with `FamilyControlsError Code=2 (invalid account type)` -- the planner must account for this by making the authorization call conditional or catchable, so the onboarding UI can still be developed/tested on simulator with a mock. The real authorization flow is testable only on a physical device.

**Primary recommendation:** Structure tasks as two parallel tracks -- (A) XcodeGen project scaffold with all targets + App Group + entitlements, (B) onboarding UI flow with ViewModel + mock-able authorization -- then integrate at the end.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Playful / irreverent tone -- self-aware humor matching the "DeluluDetox" brand name
- **D-02:** Single screen before permission request -- one explanation screen with WHY + "Grant Access" button
- **D-03:** SF Symbol + bold text for visual -- large SF Symbol with punchy headline and brief explanation. No custom illustrations
- **D-04:** Hard gate -- app is completely unusable without Screen Time permission
- **D-05:** Non-dismissible denial screen -- denial screen IS the app until permission is granted. Shows witty fallback message with Retry button
- **D-06:** Land on home screen with empty state -- "No apps blocked yet" with prominent call-to-action
- **D-07:** Subtle transition after granting permission -- quick fade/slide to home screen. No celebration screen
- **D-08:** Clean white + bold accent color palette. Light/white background with one strong brand color
- **D-09:** Colors must be centralized from the start (e.g., Theme or Colors enum) for future theming
- **D-10:** Minimal UI + punchy copy -- clean iOS-native layouts, personality from words not widgets

### Claude's Discretion
- Specific accent color choice (bold, works on white, matches playful tone)
- SF Symbol selection for onboarding screen
- Exact onboarding copy / microcopy
- Home screen empty state layout and copy
- Architecture folder structure details
- Extension target naming conventions

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ONB-01 | User sees explanation screen describing why Screen Time permission is needed before the request | Single-screen onboarding view with SF Symbol + bold text, driven by `OnboardingViewModel` with `@Observable` pattern. Must be shown before calling `requestAuthorization`. |
| ONB-02 | User can grant Screen Time permission (individual) via system prompt | `AuthorizationCenter.shared.requestAuthorization(for: .individual)` triggers system Face ID/Touch ID/passcode prompt. Works on device with development entitlement, fails on simulator. |
| ONB-03 | User sees graceful fallback with retry option if permission is denied | `authorizationStatus` property on `AuthorizationCenter.shared` -- check on app foreground. Denial screen with retry button re-calls `requestAuthorization(for: .individual)`. Non-dismissible per D-05. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Screen Time authorization | Frontend (SwiftUI) | -- | `AuthorizationCenter` is a system API called from the app process; ViewModel orchestrates, View triggers |
| Onboarding UI | Frontend (SwiftUI) | -- | Pure presentation layer with state-driven navigation |
| Authorization status persistence | System (iOS) | Frontend (check) | iOS persists Screen Time authorization; app only reads `authorizationStatus` |
| App Group container setup | Build System (XcodeGen) | -- | Entitlements and capabilities configured in `project.yml`, validated at build time |
| Root navigation (onboarding vs home) | Frontend (SwiftUI + ViewModel) | -- | `AppRootViewModel` checks authorization status, routes to onboarding or home |
| Extension targets scaffold | Build System (XcodeGen) | -- | `project.yml` defines targets; source files are minimal stubs in Phase 1 |
| Color/Theme system | Frontend (SwiftUI) | -- | Centralized `Theme` enum providing `Color` values; Asset Catalog for named colors |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 26 SDK | All UI screens | Project-mandated; no UIKit except `UIViewControllerRepresentable` bridges |
| FamilyControls | iOS 26 SDK | `AuthorizationCenter.requestAuthorization(for: .individual)` | Apple's only API for Screen Time authorization [VERIFIED: Apple docs] |
| ManagedSettings | iOS 26 SDK | `ManagedSettingsStore` (stub in Phase 1, used later) | Required for shield application in extensions [VERIFIED: Apple docs] |
| DeviceActivity | iOS 26 SDK | `DeviceActivityMonitor` extension base class (stub in Phase 1) | Required for schedule-based blocking [VERIFIED: Apple docs] |
| swift-navigation (SwiftUINavigation) | 2.8.0 | `@CasePathable` Destination enum, case-path bindings | Project-mandated for state-driven navigation [VERIFIED: GitHub releases page -- 2.8.0 released April 1, 2025] |
| Observation | Swift stdlib | `@Observable` macro for ViewModels | Project-mandated; ViewModels never import SwiftUI |
| XcodeGen | 2.45.3 | Project generation from `project.yml` | Project-mandated; never edit `.xcodeproj` manually [VERIFIED: local install] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| os (OSLog) | System | `Logger(subsystem:category:)` for structured logging | All extension and app logging -- `print()` does not work from extensions [VERIFIED: research docs] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| swift-navigation | Raw SwiftUI navigation | Project locks swift-navigation; raw SwiftUI lacks `@CasePathable` enum bindings |
| XcodeGen | Tuist | Project locks XcodeGen; Tuist adds Swift DSL complexity not needed here |
| @Observable | @Published + ObservableObject | @Observable is iOS 17+ modern pattern; project requires it |

**Installation (SPM via project.yml):**
```yaml
packages:
  swift-navigation:
    url: https://github.com/pointfreeco/swift-navigation
    from: "2.8.0"
```

**Version verification:**
- swift-navigation: 2.8.0 (latest stable, April 2025) [VERIFIED: GitHub releases page]
- XcodeGen: 2.45.3 [VERIFIED: `xcodegen --version` on local machine]
- Xcode: 26.3 (Build 17C529) [VERIFIED: `xcodebuild -version`]
- Swift: 6.2.4 [VERIFIED: `swift --version`]

## Architecture Patterns

### System Architecture Diagram

```
                    App Launch
                        |
                        v
              ┌─────────────────┐
              │ DeluluDetoxApp   │ (@main)
              │ DependencyContainer
              └────────┬────────┘
                       │ creates
                       v
              ┌─────────────────┐
              │ AppRootViewModel │ (@Observable)
              │ - checks authorizationStatus
              │ - routes: .onboarding | .home
              └────────┬────────┘
                       │
            ┌──────────┴──────────┐
            │                     │
            v                     v
    ┌───────────────┐    ┌────────────────┐
    │ OnboardingView │    │   HomeView      │
    │ + ViewModel    │    │   (empty state) │
    │ "Grant Access" │    │   "No apps      │
    │    button      │    │    blocked yet" │
    └───────┬───────┘    └────────────────┘
            │ tap
            v
    ┌───────────────────┐
    │ AuthorizationCenter│ (system)
    │ .requestAuthorization
    │   (for: .individual)
    └───────┬───────────┘
            │
    ┌───────┴───────┐
    │               │
    v               v
  Granted        Denied
    │               │
    v               v
  → Home        ┌──────────────┐
                │ DenialView    │
                │ (non-dismiss) │
                │ "Retry" button│
                └──────────────┘

    ┌─────────────────────────────────────┐
    │         App Group Container          │
    │   group.com.kksw.DeluluDetox        │
    │   (shared: app + 3 extensions)       │
    │   UserDefaults(suiteName:)           │
    │   File container for future JSON     │
    └─────────────────────────────────────┘
```

### Recommended Project Structure
```
DeluluDetox/
├── Sources/
│   ├── App/
│   │   ├── DeluluDetoxApp.swift          # @main, DependencyContainer, root view
│   │   └── DependencyContainer.swift     # Constructor injection factory
│   ├── Features/
│   │   ├── Root/
│   │   │   ├── AppRootView.swift         # Routes onboarding vs home
│   │   │   └── AppRootViewModel.swift    # Checks auth status, Destination enum
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift      # Explanation screen (D-02, D-03)
│   │   │   └── OnboardingViewModel.swift # Calls requestAuthorization
│   │   ├── Denial/
│   │   │   ├── DenialView.swift          # Non-dismissible denial (D-05)
│   │   │   └── DenialViewModel.swift     # Retry logic
│   │   └── Home/
│   │       ├── HomeView.swift            # Empty state (D-06)
│   │       └── HomeViewModel.swift       # Future: blocked apps list
│   ├── Domain/
│   │   ├── UseCases/
│   │   │   └── RequestScreenTimeAuthUseCase.swift
│   │   └── Repositories/
│   │       └── ScreenTimeAuthRepository.swift  # Protocol
│   ├── Data/
│   │   └── Repositories/
│   │       └── ScreenTimeAuthRepositoryImpl.swift  # Wraps AuthorizationCenter
│   └── DesignSystem/
│       └── Theme.swift                   # Centralized colors (D-09)
├── Resources/
│   └── Assets.xcassets/
│       ├── AccentColor.colorset/         # Bold accent color
│       └── AppIcon.appiconset/
Extensions/
├── DeviceActivityMonitorExtension/
│   └── DeviceActivityMonitorExtension.swift  # Minimal stub
├── ShieldConfigurationExtension/
│   └── ShieldConfigurationExtension.swift    # Minimal stub
└── ShieldActionExtension/
    └── ShieldActionExtension.swift            # Minimal stub
```

### Pattern 1: Root Navigation with Authorization Gate
**What:** `AppRootViewModel` checks `AuthorizationCenter.shared.authorizationStatus` on launch and on every `scenePhase == .active` transition. Routes to onboarding, denial, or home accordingly.
**When to use:** App entry point -- the single source of truth for "where should the user be?"
**Example:**
```swift
// Source: Architecture Guide + Navigation Guide + FamilyControls docs
import Observation
import SwiftUINavigation
import FamilyControls

@Observable
final class AppRootViewModel {
    enum Screen {
        case onboarding(OnboardingViewModel)
        case denial(DenialViewModel)
        case home(HomeViewModel)
    }

    private(set) var screen: Screen

    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        // Initial route based on current auth status
        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .approved:
            self.screen = .home(container.makeHomeViewModel())
        default:
            self.screen = .onboarding(container.makeOnboardingViewModel())
        }
    }

    func checkAuthorization() {
        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .approved:
            screen = .home(container.makeHomeViewModel())
        case .denied:
            screen = .denial(container.makeDenialViewModel())
        default:
            screen = .onboarding(container.makeOnboardingViewModel())
        }
    }
}
```

### Pattern 2: Authorization Request with Error Handling
**What:** Wrapping `requestAuthorization(for: .individual)` in a UseCase with proper error handling for simulator vs device.
**When to use:** When user taps "Grant Access" button on onboarding screen.
**Example:**
```swift
// Source: Apple FamilyControls docs + research artifacts
import FamilyControls

protocol RequestScreenTimeAuthUseCase {
    func callAsFunction() async throws
}

final class RequestScreenTimeAuthUseCaseImpl: RequestScreenTimeAuthUseCase {
    func callAsFunction() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        // If we get here, authorization was granted.
        // The system prompted Face ID/Touch ID/passcode and user approved.
    }
}
```

### Pattern 3: Centralized Theme (D-09)
**What:** A single `Theme` enum providing all colors as static computed properties, backed by Asset Catalog named colors.
**When to use:** Every view that uses color. Never use raw `Color.blue` etc.
**Example:**
```swift
// Source: D-09 decision + SwiftUI best practices
import SwiftUI

enum Theme {
    // Primary brand color -- bold, works on white, playful
    static var accent: Color { Color("AccentColor") }
    static var background: Color { Color(.systemBackground) }
    static var primaryText: Color { Color(.label) }
    static var secondaryText: Color { Color(.secondaryLabel) }
}
```

### Anti-Patterns to Avoid
- **Importing SwiftUI in ViewModel.** Only import `Observation` (and `SwiftUINavigation` for `@CasePathable`). Never `Color`, `View`, `Binding` in a ViewModel. [VERIFIED: Architecture Guide]
- **Multiple Boolean navigation flags.** Use single `Destination?` enum per the navigation guide. Never `showOnboarding: Bool` + `showDenial: Bool`. [VERIFIED: Navigation Guide]
- **Calling requestAuthorization on simulator expecting success.** Simulator always fails with Code=2. Build the ViewModel to handle this gracefully. [VERIFIED: Research artifact -- Apple Forums thread 682257]
- **Testing Screen Time on simulator.** `FamilyActivityPicker` shows only categories, not apps. Authorization fails. Use physical device for integration testing. [VERIFIED: Research artifact]
- **Editing .xcodeproj directly.** All changes through `project.yml` + `xcodegen generate`. [VERIFIED: XcodeGen Guide]
- **Forgetting App Group on extension targets.** Each extension MUST have the same App Group entitlement as the main app. [VERIFIED: Research artifact -- Apple Forums, Quinn DTS]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Screen Time authorization | Custom authorization flow | `AuthorizationCenter.shared.requestAuthorization(for: .individual)` | Apple's only supported API; no alternative exists |
| Navigation state management | Multiple `@State` booleans | swift-navigation `@CasePathable` Destination enum | Prevents impossible states, testable, project-mandated |
| Color system | Scattered `Color(hex:)` calls | `Theme` enum + Asset Catalog named colors | D-09 requires centralization for future theming |
| Project configuration | Manual .xcodeproj edits | XcodeGen `project.yml` | Eliminates merge conflicts, project-mandated |
| Dependency injection | Service locator / singletons | `DependencyContainer` with constructor injection | Architecture guide mandates no singletons, no service locators |

**Key insight:** Phase 1 is infrastructure-heavy. The actual UI is simple (3 screens, no complex interactions). The risk is in getting the multi-target project scaffold right -- App Group, entitlements, extension Info.plist keys, and deployment target consistency across all targets.

## Common Pitfalls

### Pitfall 1: Extension Deployment Target Mismatch
**What goes wrong:** Extension targets default to an older iOS version when created. Callbacks in DeviceActivityMonitor silently don't fire.
**Why it happens:** XcodeGen/Xcode default deployment target for new targets may not match main app.
**How to avoid:** Explicitly set `deploymentTarget: "26.0"` on every extension target in `project.yml`. Use a `settingGroups` YAML anchor to share common settings.
**Warning signs:** Extension callbacks not firing; no error messages. [VERIFIED: Research artifact -- Apple Forums thread 724243]

### Pitfall 2: Missing App Group on Extension Targets
**What goes wrong:** `containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` in an extension.
**Why it happens:** App Group capability was added to main app but not to the extension target.
**How to avoid:** Add identical App Group entitlement to ALL targets in `project.yml` using shared entitlements configuration.
**Warning signs:** `nil` container URL, extension crash. [VERIFIED: Research artifact]

### Pitfall 3: Simulator Authorization Failure
**What goes wrong:** `requestAuthorization(for: .individual)` throws `FamilyControlsError Code=2` on simulator.
**Why it happens:** Simulator doesn't have a real Apple ID with Screen Time capability.
**How to avoid:** Make authorization call conditional with `#if targetEnvironment(simulator)` or wrap in do/catch. Design ViewModel to work with a mock authorization repository for UI development on simulator.
**Warning signs:** Crash on simulator launch if authorization is called unconditionally. [VERIFIED: Research artifact -- Apple Forums thread 682257, 708050]

### Pitfall 4: Debug vs Release Entitlements Split
**What goes wrong:** Family Controls entitlement present in Debug but missing in Release (or vice versa).
**Why it happens:** Xcode can create separate `.entitlements` files for Debug and Release configurations.
**How to avoid:** Use a single `.entitlements` file per target. In XcodeGen, define entitlements via `entitlements:` block which generates one file.
**Warning signs:** Debug builds work, Release/TestFlight builds fail. [VERIFIED: Research artifact -- Apple Forums thread 806285]

### Pitfall 5: Extension Bundle ID Not Prefixed by Main App
**What goes wrong:** Extension doesn't load; shield shows default "Restricted" text instead of custom shield.
**Why it happens:** Apple requires extension bundle IDs to be prefix-matched children of the main app bundle ID.
**How to avoid:** Use pattern `com.kksw.DeluluDetox.MonitorExtension` etc. Never use an unrelated bundle ID for extensions.
**Warning signs:** Extension silently not invoked by iOS. [VERIFIED: Research artifact]

### Pitfall 6: Forgetting NSExtensionPointIdentifier in Extension Info.plist
**What goes wrong:** Extension is not discovered by iOS; DeviceActivityMonitor callbacks never fire, shield never customizes.
**Why it happens:** Missing or wrong `NSExtensionPointIdentifier` key in extension's Info.plist.
**How to avoid:** Set correct values in `project.yml` `info:` block for each extension:
- DeviceActivityMonitor: `com.apple.deviceactivity.monitor-extension`
- ShieldConfiguration: `com.apple.ManagedSettings.shield-configuration-service`
- ShieldAction: `com.apple.ManagedSettings.shield-action-service`
**Warning signs:** No callbacks, default system shield. [VERIFIED: Research artifact -- confirmed correct identifiers from Kairos and kingstinct projects]

### Pitfall 7: Swift 6.2 Strict Concurrency and AuthorizationCenter
**What goes wrong:** Compiler errors about `Sendable` conformance when using `AuthorizationCenter.shared` across async boundaries.
**Why it happens:** Swift 6.2 enables strict concurrency checking by default. `AuthorizationCenter` is not `@Sendable`.
**How to avoid:** Call `requestAuthorization` from a `@MainActor`-isolated context (the ViewModel or UseCase). Use `Task { @MainActor in ... }` if needed.
**Warning signs:** Compilation warnings/errors about sendability. [ASSUMED]

## Code Examples

Verified patterns from official sources:

### XcodeGen Extension Target Configuration
```yaml
# Source: XcodeGen ProjectSpec docs + research artifacts
# project.yml -- extension targets

settingGroups:
  shared-ios:
    base:
      SWIFT_VERSION: "6.2"

targets:
  DeluluDetox:
    type: application
    platform: iOS
    sources:
      - path: DeluluDetox/Sources
    resources:
      - path: DeluluDetox/Resources
    dependencies:
      - target: DeviceActivityMonitorExtension
        embed: true
      - target: ShieldConfigurationExtension
        embed: true
      - target: ShieldActionExtension
        embed: true
      - package: swift-navigation
        product: SwiftUINavigation
    settings:
      groups: [shared-ios]
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kksw.DeluluDetox
    entitlements:
      path: DeluluDetox/DeluluDetox.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.kksw.DeluluDetox
        com.apple.developer.family-controls: true

  DeviceActivityMonitorExtension:
    type: app-extension
    platform: iOS
    sources:
      - path: Extensions/DeviceActivityMonitorExtension
    settings:
      groups: [shared-ios]
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kksw.DeluluDetox.DeviceActivityMonitorExtension
        GENERATE_INFOPLIST_FILE: true
    info:
      path: Extensions/DeviceActivityMonitorExtension/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.deviceactivity.monitor-extension
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension
    entitlements:
      path: Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.kksw.DeluluDetox
        com.apple.developer.family-controls: true

  ShieldConfigurationExtension:
    type: app-extension
    platform: iOS
    sources:
      - path: Extensions/ShieldConfigurationExtension
    settings:
      groups: [shared-ios]
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kksw.DeluluDetox.ShieldConfigurationExtension
        GENERATE_INFOPLIST_FILE: true
    info:
      path: Extensions/ShieldConfigurationExtension/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.ManagedSettings.shield-configuration-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShieldConfigurationExtension
    entitlements:
      path: Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.kksw.DeluluDetox
        com.apple.developer.family-controls: true

  ShieldActionExtension:
    type: app-extension
    platform: iOS
    sources:
      - path: Extensions/ShieldActionExtension
    settings:
      groups: [shared-ios]
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kksw.DeluluDetox.ShieldActionExtension
        GENERATE_INFOPLIST_FILE: true
    info:
      path: Extensions/ShieldActionExtension/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.ManagedSettings.shield-action-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShieldActionExtension
    entitlements:
      path: Extensions/ShieldActionExtension/ShieldActionExtension.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.kksw.DeluluDetox
        com.apple.developer.family-controls: true

packages:
  swift-navigation:
    url: https://github.com/pointfreeco/swift-navigation
    from: "2.8.0"
```

### Minimal DeviceActivityMonitor Extension Stub
```swift
// Source: Apple DeviceActivity docs + Foqos/Kairos references
import DeviceActivity
import os

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox.DeviceActivityMonitorExtension",
        category: "Monitor"
    )

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart: \(activity.rawValue, privacy: .public)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("intervalDidEnd: \(activity.rawValue, privacy: .public)")
    }
}
```

### Minimal ShieldConfiguration Extension Stub
```swift
// Source: Apple ManagedSettingsUI docs + ScreenBreak/Kairos references
import ManagedSettings
import ManagedSettingsUI

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration()  // Default system shield -- customized in Phase 4
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }
}
```

### Minimal ShieldAction Extension Stub
```swift
// Source: Apple ManagedSettings docs + kingstinct/Kairos references
import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)  // Customized in Phase 4
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }
}
```

### Authorization Request in ViewModel
```swift
// Source: FamilyControls docs + Architecture Guide patterns
import Observation
import FamilyControls
import os

@Observable
final class OnboardingViewModel {
    private(set) var isRequesting = false
    private(set) var error: String?

    private let requestAuth: RequestScreenTimeAuthUseCase
    var onAuthorized: (() -> Void)?

    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "Onboarding")

    init(requestAuth: RequestScreenTimeAuthUseCase, onAuthorized: (() -> Void)? = nil) {
        self.requestAuth = requestAuth
        self.onAuthorized = onAuthorized
    }

    func grantAccessTapped() async {
        isRequesting = true
        error = nil
        do {
            try await requestAuth()
            logger.info("Screen Time authorization granted")
            onAuthorized?()
        } catch {
            logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }
        isRequesting = false
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.child` authorization only | `.individual` mode for adults | iOS 16 (WWDC22) | Enables self-control apps without Family Sharing |
| ObservableObject + @Published | @Observable macro | iOS 17 / Swift 5.9 | Simpler, more performant observation |
| NavigationView | NavigationStack | iOS 16 | Path-based navigation, deep linking |
| Multiple @State bools for nav | @CasePathable Destination enum | swift-navigation 2.x | Single source of truth, testable |
| Manual .xcodeproj | XcodeGen from YAML | Stable for years | Eliminates merge conflicts |

**Deprecated/outdated:**
- `requestAuthorization(completionHandler:)` -- deprecated since iOS 16, use async version
- `NavigationView` -- deprecated since iOS 16, use `NavigationStack`
- `ObservableObject` + `@Published` -- superseded by `@Observable` for iOS 17+

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Swift 6.2 strict concurrency requires `@MainActor` isolation for `AuthorizationCenter` calls | Pitfall 7 | Compilation errors; easy to fix by adding isolation annotation |
| A2 | `app-extension` is the correct XcodeGen target type for Screen Time extensions (not `extensionkit-extension`) | Code Examples | Wrong type would cause build failures; XcodeGen docs confirm `app-extension` is the general type for `.appex` bundles |
| A3 | XcodeGen `entitlements:` block with `properties:` auto-generates the `.entitlements` file | Code Examples | If not, entitlements files must be created manually; XcodeGen docs show this pattern works |

## Open Questions

1. **Exact `NSExtensionPrincipalClass` format for Screen Time extensions**
   - What we know: Standard format is `$(PRODUCT_MODULE_NAME).ClassName`. Kairos and kingstinct use this pattern.
   - What's unclear: Whether iOS 26 with Swift 6.2 requires any `@objc` annotation on the extension class.
   - Recommendation: Build and test. If extension class not found at runtime, add `@objc(ClassName)` attribute.

2. **AuthorizationCenter.authorizationStatus observation method**
   - What we know: `AuthorizationCenter.shared` has `authorizationStatus` property and a `$authorizationStatus` Combine publisher. In iOS 17+ it may also support `@Observable` pattern.
   - What's unclear: Whether `authorizationStatus` changes are pushed in real-time when user toggles Screen Time in Settings, or only on app foreground.
   - Recommendation: Check status on every `scenePhase == .active` as belt-and-suspenders approach. This is confirmed best practice from research artifacts (FB18794535).

3. **AccentColor in Asset Catalog vs Theme enum**
   - What we know: D-09 requires centralized colors. SwiftUI's `AccentColor` in Asset Catalog automatically applies to tint colors.
   - What's unclear: Whether to define the bold accent in Asset Catalog (for system-wide tint) vs only in `Theme` enum.
   - Recommendation: Use both -- Asset Catalog `AccentColor` for system tint + `Theme.accent` reading from it for explicit usage. This is standard practice.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build system | Yes | 26.3 (17C529) | -- |
| Swift | Language | Yes | 6.2.4 | -- |
| XcodeGen | Project generation | Yes | 2.45.3 | -- |
| iOS Simulator | UI development | Yes | (via Xcode) | Physical device for auth testing |
| Physical iOS device | Screen Time auth testing | Unknown | -- | Simulator for UI-only work; auth testing requires device |

**Missing dependencies with no fallback:**
- Physical iOS device is required for testing Screen Time authorization flow (simulator fails with Code=2). UI development and layout testing work on simulator.

**Missing dependencies with fallback:**
- None

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode 26.3) |
| Config file | None -- see Wave 0 |
| Quick run command | `mcp__XcodeBuildMCP__test_sim()` |
| Full suite command | `mcp__XcodeBuildMCP__test_sim()` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ONB-01 | Onboarding screen displays explanation before permission request | unit (ViewModel state) | `mcp__XcodeBuildMCP__test_sim()` with test filter | No -- Wave 0 |
| ONB-02 | User can trigger system Screen Time authorization prompt | manual-only | Physical device required; simulator always fails | N/A |
| ONB-03 | Denial screen shows with retry option when permission denied | unit (ViewModel routing) | `mcp__XcodeBuildMCP__test_sim()` with test filter | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** Build verification via `mcp__XcodeBuildMCP__build_sim()`
- **Per wave merge:** Full test suite via `mcp__XcodeBuildMCP__test_sim()`
- **Phase gate:** All targets build on simulator + authorization flow verified on physical device

### Wave 0 Gaps
- [ ] Test target in `project.yml` -- `DeluluDetoxTests` target with XCTest
- [ ] `DeluluDetoxTests/AppRootViewModelTests.swift` -- covers routing logic for ONB-01, ONB-03
- [ ] `DeluluDetoxTests/OnboardingViewModelTests.swift` -- covers authorization request with mock UseCase
- [ ] Mock `RequestScreenTimeAuthUseCase` for testing without real FamilyControls

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Screen Time auth is system-level, not app auth |
| V3 Session Management | No | No user sessions in Phase 1 |
| V4 Access Control | Yes (limited) | Authorization gate prevents app usage without Screen Time permission |
| V5 Input Validation | No | No user input beyond button taps in Phase 1 |
| V6 Cryptography | No | No crypto in Phase 1 |

### Known Threat Patterns for Screen Time Apps

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| User revokes Screen Time in Settings to bypass blocks | Elevation of Privilege | Check `authorizationStatus` on every foreground; re-request auth [VERIFIED: research -- FB18794535] |
| Extension fails to load, showing default system shield | Denial of Service (to UX) | Verify bundle ID prefix, NSExtensionPointIdentifier, entitlements [VERIFIED: research] |
| App Group data readable by any app in the same group | Information Disclosure | Only app's own extensions share the group; no sensitive user data stored in Phase 1 |

## Project Constraints (from CLAUDE.md)

- **Architecture:** Clean Architecture MVVM + UseCase + Repository. SOLID, KISS, DRY. ViewModels use `@Observable`, never import SwiftUI.
- **Navigation:** State-driven via swift-navigation. Single `Destination?` enum, `@CasePathable`.
- **XcodeGen:** Edit `project.yml`, run `xcodegen generate`. Never edit `.xcodeproj`.
- **Build & Test:** Use XcodeBuildMCP tools. Call `session_show_defaults` before first build. Fix compilation errors autonomously.
- **Research:** Read `.claude/research/` before architecture decisions.
- **Repo name:** `KKSW---first-app` (triple hyphen) -- preserve exactly.
- **No backend:** Everything on-device.
- **iOS 26.0+ only, Swift 6.2** -- locked.

## Sources

### Primary (HIGH confidence)
- `.claude/research/compass_artifact_wf-dee368a6-...` -- Entitlement process, `.individual` framing, per-bundle-ID requirement
- `.claude/research/compass_artifact_wf-280372a6-...` -- App Group architecture, extension communication, production snippets
- `.claude/research/compass_artifact_wf-14f18c53-...` -- iOS 26 API status, deployment target analysis
- `.claude/research/compass_artifact_wf-9f1fb5f8-...` -- Best public repos (Foqos, Kairos, ScreenBreak, kingstinct)
- `.claude/guides/architecture/GUIDE.md` -- Clean Architecture patterns
- `.claude/guides/navigation/GUIDE.md` -- swift-navigation patterns
- `.claude/guides/xcodegen/GUIDE.md` + `references/basics.md` -- XcodeGen configuration
- XcodeGen GitHub releases/docs (Context7 `/yonaskolb/xcodegen`) -- target types, entitlements, dependencies
- [swift-navigation GitHub releases](https://github.com/pointfreeco/swift-navigation/releases) -- version 2.8.0 confirmed

### Secondary (MEDIUM confidence)
- [AuthorizationCenter Apple docs](https://developer.apple.com/documentation/familycontrols/authorizationcenter) -- API shape (JS-rendered page, verified via WebSearch summaries)
- [XcodeGen issue #1431](https://github.com/yonaskolb/XcodeGen/issues/1431) -- `app-extension` target type confirmation
- [Julius Brussee Medium guide](https://medium.com/@juliusbrussee/a-developers-guide-to-apple-s-screen-time-apis-familycontrols-managedsettings-deviceactivity-e660147367d7) -- API usage patterns

### Tertiary (LOW confidence)
- None -- all claims verified or cited

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all libraries verified via local tools, GitHub, and project guides
- Architecture: HIGH -- patterns mandated by project guides with concrete examples
- Pitfalls: HIGH -- extensively documented in curated research artifacts with Apple Forums thread references
- XcodeGen extension config: MEDIUM -- `app-extension` type verified in docs, but exact NSExtension Info.plist generation via XcodeGen needs build verification

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stable domain -- XcodeGen, FamilyControls API frozen since iOS 16)
