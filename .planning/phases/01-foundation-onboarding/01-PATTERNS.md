# Phase 1: Foundation & Onboarding - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 20 (new/modified files)
**Analogs found:** 3 / 20 (greenfield project -- most patterns sourced from project guides)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `project.yml` | config | N/A (build config) | `project.yml` (existing) | exact -- extend in-place |
| `DeluluDetox/Sources/App/DeluluDetoxApp.swift` | provider | request-response | `DeluluDetoxApp.swift` (existing) | exact -- modify in-place |
| `DeluluDetox/Sources/App/DependencyContainer.swift` | config | N/A (DI factory) | architecture guide example | guide-pattern |
| `DeluluDetox/Sources/Features/Root/AppRootView.swift` | component | request-response | `ContentView.swift` (existing) | partial -- replaces it |
| `DeluluDetox/Sources/Features/Root/AppRootViewModel.swift` | store | request-response | architecture guide `HomeViewModel` | guide-pattern |
| `DeluluDetox/Sources/Features/Onboarding/OnboardingView.swift` | component | request-response | `ContentView.swift` (existing) | partial |
| `DeluluDetox/Sources/Features/Onboarding/OnboardingViewModel.swift` | store | request-response | architecture guide `HomeViewModel` | guide-pattern |
| `DeluluDetox/Sources/Features/Denial/DenialView.swift` | component | request-response | `ContentView.swift` (existing) | partial |
| `DeluluDetox/Sources/Features/Denial/DenialViewModel.swift` | store | request-response | architecture guide `HomeViewModel` | guide-pattern |
| `DeluluDetox/Sources/Features/Home/HomeView.swift` | component | request-response | `ContentView.swift` (existing) | partial |
| `DeluluDetox/Sources/Features/Home/HomeViewModel.swift` | store | request-response | architecture guide `HomeViewModel` | guide-pattern |
| `DeluluDetox/Sources/Domain/UseCases/RequestScreenTimeAuthUseCase.swift` | service | request-response | architecture guide `FetchItemsUseCase` | guide-pattern |
| `DeluluDetox/Sources/Domain/Repositories/ScreenTimeAuthRepository.swift` | model (protocol) | request-response | architecture guide `ItemRepository` | guide-pattern |
| `DeluluDetox/Sources/Data/Repositories/ScreenTimeAuthRepositoryImpl.swift` | service | request-response | architecture guide `ItemRepositoryImpl` | guide-pattern |
| `DeluluDetox/Sources/DesignSystem/Theme.swift` | utility | N/A (constants) | none | research-pattern |
| `DeluluDetox/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` | config | N/A (asset) | existing AccentColor.colorset | exact -- modify in-place |
| `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` | middleware | event-driven | none | research-pattern |
| `Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift` | middleware | request-response | none | research-pattern |
| `Extensions/ShieldActionExtension/ShieldActionExtension.swift` | middleware | event-driven | none | research-pattern |
| `DeluluDetoxTests/AppRootViewModelTests.swift` | test | N/A | none | new |

## Pattern Assignments

### `project.yml` (config, extend in-place)

**Analog:** `project.yml` (existing, lines 1-32)

**Existing structure to preserve** (lines 1-9):
```yaml
name: DeluluDetox

options:
  bundleIdPrefix: com.kksw
  deploymentTarget:
    iOS: "26.0"
  createIntermediateGroups: true
  defaultConfig: Debug
  developmentLanguage: en
```

**Existing target block to extend** (lines 11-32):
```yaml
targets:
  DeluluDetox:
    type: application
    platform: iOS
    sources:
      - path: DeluluDetox/Sources
    resources:
      - path: DeluluDetox/Resources
    settings:
      base:
        SWIFT_VERSION: "6.2"
        GENERATE_INFOPLIST_FILE: true
        # ... existing settings preserved ...
        PRODUCT_BUNDLE_IDENTIFIER: com.kksw.DeluluDetox
```

**Pattern to add -- settingGroups for DRY extension config** (from RESEARCH.md):
```yaml
settingGroups:
  shared-ios:
    base:
      SWIFT_VERSION: "6.2"
```

**Pattern to add -- packages block** (from RESEARCH.md):
```yaml
packages:
  swift-navigation:
    url: https://github.com/pointfreeco/swift-navigation
    from: "2.8.0"
```

**Pattern to add -- extension target** (from RESEARCH.md, one example; repeat for all 3):
```yaml
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
```

**Pattern to add -- main app entitlements + dependencies** (from RESEARCH.md):
```yaml
  DeluluDetox:
    # ... existing settings ...
    dependencies:
      - target: DeviceActivityMonitorExtension
        embed: true
      - target: ShieldConfigurationExtension
        embed: true
      - target: ShieldActionExtension
        embed: true
      - package: swift-navigation
        product: SwiftUINavigation
    entitlements:
      path: DeluluDetox/DeluluDetox.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.kksw.DeluluDetox
        com.apple.developer.family-controls: true
```

**Critical rules from RESEARCH.md pitfalls:**
- Every extension MUST have `deploymentTarget: "26.0"` (inherited from `options:` or set explicitly)
- Extension bundle IDs MUST be prefixed by main app bundle ID: `com.kksw.DeluluDetox.<ExtensionName>`
- All targets MUST share the same App Group: `group.com.kksw.DeluluDetox`
- NSExtensionPointIdentifier values per extension type:
  - DeviceActivityMonitor: `com.apple.deviceactivity.monitor-extension`
  - ShieldConfiguration: `com.apple.ManagedSettings.shield-configuration-service`
  - ShieldAction: `com.apple.ManagedSettings.shield-action-service`

---

### `DeluluDetoxApp.swift` (provider, modify in-place)

**Analog:** `DeluluDetoxApp.swift` (existing, lines 1-10)

**Existing structure** (lines 1-10):
```swift
import SwiftUI

@main
struct DeluluDetoxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Target pattern** (from architecture guide `DependencyContainer` + DI pattern, lines 175-181):
```swift
@main
struct DeluluDetoxApp: App {
    private let container = DependencyContainer()
    var body: some Scene {
        WindowGroup {
            AppRootView(model: container.makeAppRootViewModel())
        }
    }
}
```

---

### `DependencyContainer.swift` (config, DI factory)

**Analog:** Architecture guide `.claude/guides/architecture/GUIDE.md` (lines 183-193)

**Core pattern:**
```swift
struct DependencyContainer {
    let itemRepository: ItemRepository = ItemRepositoryImpl(...)

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            fetchItems: FetchItemsUseCaseImpl(repository: itemRepository)
        )
    }
}
```

**Adapt for Phase 1:**
- Factory methods: `makeAppRootViewModel()`, `makeOnboardingViewModel()`, `makeDenialViewModel()`, `makeHomeViewModel()`
- Repository: `ScreenTimeAuthRepository` (protocol) / `ScreenTimeAuthRepositoryImpl` (concrete)
- UseCase: `RequestScreenTimeAuthUseCase` / `RequestScreenTimeAuthUseCaseImpl`
- Constructor injection only, no globals, no singletons

---

### `AppRootViewModel.swift` (store, request-response)

**Analog:** RESEARCH.md Pattern 1 (lines 210-251)

**Core pattern -- enum-based screen routing:**
```swift
import Observation
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

**Key rules:**
- Import `Observation` and `FamilyControls`, NEVER `SwiftUI`
- `Screen` is NOT `@CasePathable` Destination (this is full-screen routing, not modal navigation). Use a plain enum with a `switch` in the View
- Check `authorizationStatus` on every `scenePhase == .active`
- Callbacks from child ViewModels (e.g. `onAuthorized`) trigger `checkAuthorization()`

---

### `AppRootView.swift` (component, request-response)

**Analog:** Architecture guide View pattern (lines 91-99) + navigation guide

**Core pattern:**
```swift
struct HomeView: View {
    @Bindable var model: HomeViewModel

    var body: some View {
        List(model.items) { Text($0.title) }
            .task { await model.onAppear() }
    }
}
```

**Adapt for Phase 1:**
- Use `switch model.screen` to render `OnboardingView`, `DenialView`, or `HomeView`
- Listen to `.onChange(of: scenePhase)` and call `model.checkAuthorization()` when `.active`
- D-07: Subtle transition via `.animation(.default, value:)` or `.transition(.opacity)`

---

### `OnboardingViewModel.swift` (store, request-response)

**Analog:** RESEARCH.md Pattern 2 (lines 566-601)

**Core pattern -- authorization request with error handling:**
```swift
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

**Key rules:**
- Import `Observation` + `os`, NEVER `SwiftUI`
- Import `FamilyControls` only if directly referencing its types (prefer UseCase abstraction)
- `onAuthorized` callback wired by parent (`AppRootViewModel` or `DependencyContainer`)
- Logger subsystem: `"com.kksw.DeluluDetox"`, category per feature

---

### `OnboardingView.swift` (component, request-response)

**Analog:** Architecture guide View pattern (lines 91-99) + ContentView.swift (existing)

**Existing view structure** (`ContentView.swift` lines 1-17):
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "brain.head.profile")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("DeluluDetox")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

**Target pattern:**
- `@Bindable var model: OnboardingViewModel`
- D-02: Single screen with SF Symbol + bold headline + brief explanation + "Grant Access" button
- D-03: Large SF Symbol, punchy headline text, brief description
- D-08/D-10: Use `Theme.accent`, `Theme.background`, `Theme.primaryText` -- never raw colors
- Button calls `await model.grantAccessTapped()`
- Show `ProgressView` when `model.isRequesting`
- Include `#Preview` block

---

### `DenialView.swift` + `DenialViewModel.swift` (component + store)

**Analog:** Same as OnboardingView/ViewModel pattern above

**Key differences from OnboardingView:**
- D-05: Non-dismissible -- this IS the app when denied. No navigation, no dismiss
- Witty fallback message matching playful tone
- "Retry" button that re-calls `requestAuthorization`
- DenialViewModel has same shape as OnboardingViewModel (reuses `RequestScreenTimeAuthUseCase`)

---

### `HomeView.swift` + `HomeViewModel.swift` (component + store)

**Analog:** Architecture guide View + ViewModel pattern (lines 68-99)

**ViewModel pattern:**
```swift
@Observable
final class HomeViewModel {
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    var destination: Destination?   // see navigation guide

    private let fetchItems: FetchItemsUseCase

    init(fetchItems: FetchItemsUseCase) {
        self.fetchItems = fetchItems
    }

    func onAppear() async {
        isLoading = true
        defer { isLoading = false }
        items = (try? await fetchItems()) ?? []
    }
}
```

**Adapt for Phase 1:**
- D-06: Empty state -- "No apps blocked yet" with prominent CTA
- HomeViewModel in Phase 1 is minimal (no data fetching, no items)
- Just displays empty state UI
- Placeholder for future `@CasePathable` Destination enum

---

### `RequestScreenTimeAuthUseCase.swift` (service, request-response)

**Analog:** Architecture guide UseCase pattern (lines 112-125)

**Protocol + impl pattern:**
```swift
protocol FetchItemsUseCase {
    func callAsFunction() async throws -> [Item]
}

final class FetchItemsUseCaseImpl: FetchItemsUseCase {
    private let repository: ItemRepository
    init(repository: ItemRepository) { self.repository = repository }

    func callAsFunction() async throws -> [Item] {
        try await repository.allItems()
    }
}
```

**Adapted from RESEARCH.md Pattern 2:**
```swift
protocol RequestScreenTimeAuthUseCase {
    func callAsFunction() async throws
}

final class RequestScreenTimeAuthUseCaseImpl: RequestScreenTimeAuthUseCase {
    func callAsFunction() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}
```

**Key rules:**
- `callAsFunction` convention -- ViewModel calls it as `requestAuth()` not `requestAuth.execute()`
- Protocol in `Domain/UseCases/`, impl can live in same file or in `Data/` depending on whether it wraps system API
- Since this wraps `AuthorizationCenter` (system API), the impl should live in `Data/` or the UseCase itself is the thin wrapper
- Consider `@MainActor` isolation for Swift 6.2 strict concurrency (RESEARCH.md Pitfall 7)

---

### `ScreenTimeAuthRepository.swift` (protocol) + `ScreenTimeAuthRepositoryImpl.swift` (impl)

**Analog:** Architecture guide Repository pattern (lines 142-166)

**Protocol pattern:**
```swift
// Domain/Repositories/ItemRepository.swift
protocol ItemRepository {
    func allItems() async throws -> [Item]
    func save(_ item: Item) async throws
}
```

**Impl pattern:**
```swift
// Data/Repositories/ItemRepositoryImpl.swift
final class ItemRepositoryImpl: ItemRepository {
    private let remote: ItemRemoteSource
    private let local: ItemLocalStore

    func allItems() async throws -> [Item] {
        if let cached = try? await local.loadAll(), !cached.isEmpty { return cached }
        let fresh = try await remote.fetchAll()
        try? await local.saveAll(fresh)
        return fresh
    }
}
```

**Adapt for Phase 1:**
- Protocol: `requestAuthorization() async throws`, `var authorizationStatus: AuthorizationStatus { get }`
- Impl wraps `AuthorizationCenter.shared`
- Enables mocking in tests (simulator can't authorize)
- Consider whether UseCase is warranted or ViewModel can call Repository directly (KISS -- architecture guide lines 127-135)

---

### `Theme.swift` (utility, constants)

**Analog:** RESEARCH.md Pattern 3 (lines 276-290)

**Core pattern:**
```swift
import SwiftUI

enum Theme {
    // Primary brand color -- bold, works on white, playful
    static var accent: Color { Color("AccentColor") }
    static var background: Color { Color(.systemBackground) }
    static var primaryText: Color { Color(.label) }
    static var secondaryText: Color { Color(.secondaryLabel) }
}
```

**Key rules:**
- D-09: Centralized from the start for future theming
- Backed by Asset Catalog named colors where custom
- Uses system colors (`.systemBackground`, `.label`) for semantic colors
- `import SwiftUI` is required here (this is a design system utility, not a ViewModel)
- AccentColor.colorset in Asset Catalog must be populated with the chosen bold accent color

---

### Extension Stubs (3 files, middleware, event-driven)

**Analog:** RESEARCH.md code examples (lines 477-563)

**DeviceActivityMonitorExtension pattern:**
```swift
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

**ShieldConfigurationExtension pattern:**
```swift
import ManagedSettings
import ManagedSettingsUI

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration()
    }
    // ... overrides for category, webDomain, webDomain+category
}
```

**ShieldActionExtension pattern:**
```swift
import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }
    // ... overrides for webDomain, category
}
```

**Key rules:**
- Extensions use `os.Logger` (NOT `print()` -- print does not work from extensions)
- Logger subsystem matches bundle ID of the extension
- These are minimal stubs in Phase 1 -- just log and return defaults
- Each extension lives in its own directory under `Extensions/`

---

### Test Files

**Analog:** None (greenfield)

**Pattern from architecture guide:** Tests construct ViewModels directly with mock dependencies.

```swift
// Test construction pattern
func testAuthorizationGranted() async {
    let mockAuth = MockRequestScreenTimeAuthUseCase()
    let viewModel = OnboardingViewModel(requestAuth: mockAuth)
    // ...
}
```

**Files needed (from RESEARCH.md Wave 0 Gaps):**
- `DeluluDetoxTests/AppRootViewModelTests.swift` -- routing logic for ONB-01, ONB-03
- `DeluluDetoxTests/OnboardingViewModelTests.swift` -- authorization request with mock UseCase
- Mock `RequestScreenTimeAuthUseCase` for testing without real FamilyControls

---

## Shared Patterns

### ViewModel Convention
**Source:** `.claude/guides/architecture/GUIDE.md` (lines 66-86)
**Apply to:** All ViewModel files (`AppRootViewModel`, `OnboardingViewModel`, `DenialViewModel`, `HomeViewModel`)

```swift
import Observation
// NEVER import SwiftUI

@Observable
final class FeatureViewModel {
    // State: private(set) for read-only, var for bindable
    private(set) var items: [Item] = []
    private(set) var isLoading = false

    // Dependencies: injected via constructor
    private let someUseCase: SomeUseCase

    init(someUseCase: SomeUseCase) {
        self.someUseCase = someUseCase
    }

    // Actions: called by the View
    func onAppear() async { /* ... */ }
}
```

### View Convention
**Source:** `.claude/guides/architecture/GUIDE.md` (lines 91-99)
**Apply to:** All View files (`AppRootView`, `OnboardingView`, `DenialView`, `HomeView`)

```swift
import SwiftUI

struct FeatureView: View {
    @Bindable var model: FeatureViewModel

    var body: some View {
        // Bind to model state, forward intent to model actions
    }
}
```

### UseCase Convention
**Source:** `.claude/guides/architecture/GUIDE.md` (lines 110-125)
**Apply to:** `RequestScreenTimeAuthUseCase`

```swift
protocol SomeUseCase {
    func callAsFunction() async throws -> ReturnType
}

final class SomeUseCaseImpl: SomeUseCase {
    private let repository: SomeRepository
    init(repository: SomeRepository) { self.repository = repository }
    func callAsFunction() async throws -> ReturnType {
        try await repository.someMethod()
    }
}
```

### Logging Convention
**Source:** RESEARCH.md (extension stubs)
**Apply to:** All files that need logging, especially extensions

```swift
import os

private let logger = Logger(
    subsystem: "com.kksw.DeluluDetox",  // or extension bundle ID
    category: "FeatureName"
)
```

### Color Usage Convention
**Source:** RESEARCH.md Pattern 3 (D-09)
**Apply to:** All View files

```swift
// ALWAYS use Theme enum, NEVER raw Color literals
Text("Hello")
    .foregroundStyle(Theme.primaryText)
Button("Action") { /* ... */ }
    .tint(Theme.accent)
```

### Simulator Safety for Screen Time
**Source:** RESEARCH.md Pitfall 3
**Apply to:** Any code calling `AuthorizationCenter` APIs

```swift
// Option A: Conditional compilation
#if targetEnvironment(simulator)
    // Skip real auth, use mock
#else
    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
#endif

// Option B (preferred): Protocol abstraction with mock injection
// DependencyContainer injects MockScreenTimeAuthRepository on simulator
```

---

## No Analog Found

Files with no close match in the codebase (use RESEARCH.md and guide patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` | middleware | event-driven | Greenfield -- no extensions exist yet. Use RESEARCH.md stub pattern (lines 477-498) |
| `Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift` | middleware | request-response | Greenfield -- use RESEARCH.md stub pattern (lines 500-531) |
| `Extensions/ShieldActionExtension/ShieldActionExtension.swift` | middleware | event-driven | Greenfield -- use RESEARCH.md stub pattern (lines 533-563) |
| `DeluluDetox/Sources/DesignSystem/Theme.swift` | utility | N/A | Greenfield -- use RESEARCH.md Theme pattern (lines 276-290) |
| `DeluluDetoxTests/*.swift` | test | N/A | No test infrastructure exists yet |

**Note:** This is a greenfield project. ALL files are new. The "analogs" above come from:
1. **Existing files** (3 files): `project.yml`, `DeluluDetoxApp.swift`, `ContentView.swift` -- modified in-place
2. **Architecture guide** (`.claude/guides/architecture/GUIDE.md`): ViewModel, View, UseCase, Repository, DependencyContainer patterns
3. **Navigation guide** (`.claude/guides/navigation/GUIDE.md`): `@CasePathable` Destination enum, case-path bindings
4. **RESEARCH.md code examples**: Extension stubs, authorization flow, Theme enum, project.yml extension config

---

## Metadata

**Analog search scope:** `/Users/kked/Projects/KKSW---first-app/` (entire repository)
**Files scanned:** 2 Swift files, 1 YAML config, 3 asset catalog JSON files
**Pattern extraction sources:** 3 project guides + RESEARCH.md verified code examples
**Pattern extraction date:** 2026-04-18
