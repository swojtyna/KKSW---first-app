# Phase 02: App Selection — Pattern Map

**Mapped:** 2026-04-19
**Files analyzed:** 17 new + 3 modified = 20
**Analogs found:** 20 / 20 (all strong, post-01.1 reference)

---

## Reference Feature

Post-01.1 canonical feature used as primary analog: **`DeluluDetox/Sources/Features/Onboarding/`**.
It is the only feature in the repo that exercises the full Simple layout (Repository + UseCase + ViewModel + View + Injection) with a Combine `CurrentValueSubject` publisher on the Repository. Every AppSelection file has a 1:1 Onboarding counterpart.

Secondary analogs used:
- **`Features/Root/`** (`AppRootViewModel` + `AppRootView`) — Combine `.sink` into Observable state in VM, child-VM-owned-by-View pattern, scenePhase wiring.
- **`Features/Home/`** (`HomeView`) — primary button styling + navigation title + empty-hero structure (reused by `BlockedView` footer CTA and Home edits).

---

## File Classification

### New files — `Features/AppSelection/`

| File | Role | Data Flow | Closest Analog | Match |
|------|------|-----------|----------------|-------|
| `Repository/BlocklistRepository.swift` | repository | event-driven (Combine subject) + file-I/O | `Features/Onboarding/Repository/ScreenTimeAuthRepository.swift` | exact |
| `Repository/Models/Blocklist.swift` | model | plain Codable struct | none in repo (first domain model) → use protocol conformances from `ScreenTimeAuthRepository` `Sendable` discipline | role-match |
| `Repository/Models/TokenRecord.swift` | model | plain Codable struct | none | role-match |
| `Repository/Models/TokenKind.swift` | model | plain Codable enum | none | role-match |
| `UseCase/ObserveBlocklistUseCase.swift` | usecase | event-driven (publisher passthrough) | `Features/Onboarding/UseCase/ObserveScreenTimeAuthStatusUseCase.swift` | exact |
| `UseCase/UpdateBlocklistUseCase.swift` | usecase | request-response (async throws) | `Features/Onboarding/UseCase/RequestScreenTimeAuthUseCase.swift` | exact |
| `UseCase/RemoveTokenRecordUseCase.swift` | usecase | request-response (async throws) | `Features/Onboarding/UseCase/RequestScreenTimeAuthUseCase.swift` | exact |
| `UseCase/ReconcileBlocklistUseCase.swift` | usecase | request-response (async throws) | `Features/Onboarding/UseCase/RequestScreenTimeAuthUseCase.swift` | exact |
| `ViewModel/BlockedViewModel.swift` | viewmodel | event-driven (subscribes to publisher + request-response mutations) | `Features/Root/ViewModel/AppRootViewModel.swift` | exact |
| `View/BlockedView.swift` | view | request-response + event-driven render | `Features/Home/View/HomeView.swift` (shell, CTA) + inline research example | role-match |
| `Injection/AppSelectionInjection.swift` | injection | registration | `Features/Onboarding/Injection/OnboardingInjection.swift` | exact |

### Modified files

| File | Role | Data Flow | Closest Analog | Match |
|------|------|-----------|----------------|-------|
| `Features/Home/ViewModel/HomeViewModel.swift` | viewmodel | event-driven + request-response (sheet trigger) | `Features/Root/ViewModel/AppRootViewModel.swift` (Destination + Combine sink) + `Features/Onboarding/ViewModel/OnboardingViewModel.swift` (async intent) | exact |
| `Features/Home/View/HomeView.swift` | view | sheet presentation + branch | self (existing Phase 1 body) + `Features/Root/View/AppRootView.swift` (child VM @State) | role-match |
| `Features/Home/Injection/HomeInjection.swift` | injection | registration | `Features/Denial/Injection/DenialInjection.swift` (intended no-op; Home consumes AppSelection UCs via DI) | exact |
| `App/DeluluDetoxApp.swift` | app entry | bootstrap | self — add `AppSelectionInjection.register(in:)` to existing `init()` | self-match |
| `project.yml` | config | build | self — no code change; sources path `DeluluDetox/Sources` already covers new files | self-match |

### New test files — `DeluluDetoxTests/Features/AppSelection/`

| File | Role | Data Flow | Closest Analog | Match |
|------|------|-----------|----------------|-------|
| `BlockedViewModelTests.swift` | test | request-response + event | `DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift` (Combine subject → destination) | exact |
| `BlocklistRepositoryTests.swift` | test | file-I/O | none in repo — use `ScreenTimeAuthRepository` test as structural template via temp-URL container | role-match |
| `Mocks/MockBlocklistRepository.swift` | test-mock | event-driven subject stub | `DeluluDetoxTests/Features/Onboarding/Mocks/MockScreenTimeAuthRepository.swift` | exact |
| `Mocks/MockObserveBlocklistUseCase.swift` | test-mock | publisher stub | `DeluluDetoxTests/Features/Onboarding/Mocks/MockObserveScreenTimeAuthStatusUseCase.swift` | exact |
| `Mocks/MockUpdateBlocklistUseCase.swift` | test-mock | call counter + error stub | `DeluluDetoxTests/Features/Onboarding/Mocks/MockRequestScreenTimeAuthUseCase.swift` | exact |
| `Mocks/MockRemoveTokenRecordUseCase.swift` | test-mock | call counter + error stub | `DeluluDetoxTests/Features/Onboarding/Mocks/MockRequestScreenTimeAuthUseCase.swift` | exact |
| `Mocks/MockReconcileBlocklistUseCase.swift` | test-mock | call counter | `DeluluDetoxTests/Features/Onboarding/Mocks/MockRefreshScreenTimeAuthStatusUseCase.swift` | exact |

---

## Pattern Assignments

### 1. `Features/AppSelection/Repository/BlocklistRepository.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Onboarding/Repository/ScreenTimeAuthRepository.swift`

**Imports + MARK layout** (lines 1–10):
```swift
import Combine
import FamilyControls

// MARK: - Protocol

protocol ScreenTimeAuthRepository: Sendable {
    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> { get }
    func requestAuthorization() async throws
    func refreshStatus()
}
```

**Implementation — CurrentValueSubject + @unchecked Sendable** (lines 12–33):
```swift
// MARK: - Implementation

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository, @unchecked Sendable {
    private let statusSubject: CurrentValueSubject<AuthorizationStatus, Never>

    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    init() {
        self.statusSubject = CurrentValueSubject(AuthorizationCenter.shared.authorizationStatus)
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        statusSubject.send(AuthorizationCenter.shared.authorizationStatus)
    }

    func refreshStatus() {
        statusSubject.send(AuthorizationCenter.shared.authorizationStatus)
    }
}
```

**Patterns to copy:**
- Protocol + impl in one file, separated by `// MARK: -` sections.
- `Sendable` on protocol, `@unchecked Sendable` on impl (required because of `CurrentValueSubject` storage).
- Private `CurrentValueSubject<T, Never>` seeded in `init()` with a best-effort initial value (here: `AuthorizationCenter.shared.authorizationStatus`; for Blocklist: `Self.readFromDisk() ?? Blocklist.empty()`).
- Public computed `…Publisher: AnyPublisher<T, Never>` returning `subject.eraseToAnyPublisher()`.
- Every mutation method ends with `subject.send(newValue)`.

**Delta for Blocklist:**
- Add file-I/O helpers: `static func fileURL() throws -> URL` using `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kksw.DeluluDetox")`, `static func writeToDisk(_:)` with `try data.write(to:options:[.atomic, .completeFileProtectionUntilFirstUserAuthentication])`, `static func readFromDisk() -> Blocklist?`.
- Add `import Foundation` and `import os` (Logger). Onboarding does not persist; AppSelection does.
- Mutations (`update`, `remove`, `reconcile`) go through a private `writeAndEmit(_:)` helper so the on-disk file and in-memory subject never drift.

---

### 2. `Features/AppSelection/UseCase/ObserveBlocklistUseCase.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Onboarding/UseCase/ObserveScreenTimeAuthStatusUseCase.swift`

**Entire file pattern** (lines 1–18):
```swift
import Combine
import FamilyControls

protocol ObserveScreenTimeAuthStatusUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<AuthorizationStatus, Never>
}

final class ObserveScreenTimeAuthStatusUseCaseImpl: ObserveScreenTimeAuthStatusUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func callAsFunction() -> AnyPublisher<AuthorizationStatus, Never> {
        repository.statusPublisher
    }
}
```

**Patterns to copy:**
- Protocol `Sendable` + `func callAsFunction() -> AnyPublisher<T, Never>`.
- Impl: `final class …Impl`, `private let repository: …Repository`, init-injection, 1-line `callAsFunction` returning `repository.…Publisher` directly (pure passthrough).

---

### 3. `Features/AppSelection/UseCase/{Update,RemoveTokenRecord,Reconcile}BlocklistUseCase.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Onboarding/UseCase/RequestScreenTimeAuthUseCase.swift`

**Entire file pattern** (lines 1–17):
```swift
import FamilyControls

protocol RequestScreenTimeAuthUseCase: Sendable {
    func callAsFunction() async throws
}

final class RequestScreenTimeAuthUseCaseImpl: RequestScreenTimeAuthUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws {
        try await repository.requestAuthorization()
    }
}
```

**Patterns to copy:**
- `async throws` signature. Parameters vary: `UpdateBlocklistUseCase.callAsFunction(_ selection: FamilyActivitySelection) async throws`, `RemoveTokenRecordUseCase.callAsFunction(_ recordID: TokenRecord.ID) async throws`, `ReconcileBlocklistUseCase.callAsFunction() async throws`.
- Pure passthrough to the matching repo method — one line inside `callAsFunction`.
- Reconcile is also a void-async analog of `RefreshScreenTimeAuthStatusUseCase.swift` (lines 3–17) if a non-throwing variant is wanted; research §"Token rotation reconciliation" says Phase 02 MVP scope is "re-read + re-emit" which is trivially async — keep `async throws` for symmetry with future Phase 3 needs.

---

### 4. `Features/AppSelection/ViewModel/BlockedViewModel.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` (Combine subscribe pattern) + `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Onboarding/ViewModel/OnboardingViewModel.swift` (async intent + error state + logger).

**Combine subscribe + derived state** — from `AppRootViewModel.swift` (lines 1–34):
```swift
import Observation
import Combine
import FamilyControls
import SwiftUINavigation

@MainActor
@Observable
final class AppRootViewModel: @unchecked Sendable {

    @CasePathable
    enum Destination: Equatable {
        case onboarding
        case denial
        case home
    }

    var destination: Destination?

    @ObservationIgnored
    @LazyInjected private var observeStatus: ObserveScreenTimeAuthStatusUseCase

    @ObservationIgnored
    @LazyInjected private var refreshStatusUseCase: RefreshScreenTimeAuthStatusUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    init() {
        observeStatus()
            .sink { [weak self] status in
                self?.destination = Self.map(status)
            }
            .store(in: &cancellables)
    }
```

**Async intent + error + logger** — from `OnboardingViewModel.swift` (lines 1–30):
```swift
import Observation
import os

@MainActor
@Observable
final class OnboardingViewModel: @unchecked Sendable {
    private(set) var isRequesting = false
    private(set) var error: String?

    @ObservationIgnored
    @LazyInjected private var requestAuth: RequestScreenTimeAuthUseCase

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "Onboarding")

    init() {}

    func grantAccessTapped() async {
        isRequesting = true
        error = nil
        do {
            try await requestAuth()
            logger.info("Screen Time authorization granted")
        } catch {
            logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }
        isRequesting = false
    }
}
```

**Patterns to copy for `BlockedViewModel`:**
- `@MainActor @Observable final class …ViewModel: @unchecked Sendable`.
- `@ObservationIgnored @LazyInjected private var …: …UseCase` for each UC (Observe, RemoveTokenRecord).
- `@ObservationIgnored private var cancellables: Set<AnyCancellable> = []`.
- `@ObservationIgnored private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "BlockedVM")`.
- `init()` subscribes to `observeBlocklist().sink { [weak self] blocklist in … }.store(in: &cancellables)`. Filter records into `appRecords`, `categoryRecords`, `webRecords` from research §"BlockedViewModel" (lines 849–858).
- Intent methods follow OnboardingViewModel shape: set transient state, `do { try await uc(...) } catch { self.errorMessage = "..."; logger.error(...) }`.
- No `import SwiftUI`; only `Observation`, `Combine`, `FamilyControls`, `os`.

---

### 5. `Features/AppSelection/View/BlockedView.swift`

**Analog for shell and CTA styling:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Home/View/HomeView.swift` (lines 1–63).

**Primary CTA style** (HomeView.swift lines 35–48):
```swift
Button {
    model.chooseAppsTapped()
} label: {
    Text("Choose Apps to Block")
        .font(.body)
        .bold()
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
}
.buttonStyle(.borderedProminent)
.tint(Theme.accent)
.clipShape(RoundedRectangle(cornerRadius: 12))
.padding(.horizontal, 24)
```

**Navigation title wiring** (HomeView.swift lines 54–55):
```swift
.navigationTitle("DeluluDetox")
.navigationBarTitleDisplayMode(.large)
```

**Preview with DIContainer bootstrap** (HomeView.swift lines 59–62 + OnboardingView.swift lines 74–81):
```swift
#Preview {
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)
    return OnboardingView(model: OnboardingViewModel())
}
```

**Patterns to copy for `BlockedView`:**
- `@Bindable var model: BlockedViewModel` single state dep.
- Reuse exact primary-button style block for "Zmień wybór" inside `.safeAreaInset(edge: .bottom) { … }` — research §"BlockedView with swipe-to-delete" lines 803–818.
- `.navigationTitle("Zablokowane") / .navigationBarTitleDisplayMode(.large)` per UI-SPEC.
- List + Section pattern and `.swipeActions(edge: .trailing, allowsFullSwipe: true) { Button(role: .destructive) { … } label: { Label("Usuń", systemImage: "trash") } }` (no analog in repo — research §Code Examples is the direct source, lines 787–794).
- `#Preview` mirrors OnboardingView.swift lines 74–81: `container.reset()` → register both `AppSelectionInjection` and whatever home deps are needed → return `BlockedView(model: BlockedViewModel())`.

**Delta vs analog:** `BlockedView` does NOT wrap itself in `NavigationStack` — per UI-SPEC §Screen 3 it is hosted inside `HomeView`'s existing `NavigationStack` (see `AppRootView.swift` line 23–25: `case .home: NavigationStack { HomeView(model: homeModel) }`). Do not nest another `NavigationStack`.

---

### 6. `Features/AppSelection/Injection/AppSelectionInjection.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Onboarding/Injection/OnboardingInjection.swift`

**Entire file pattern** (lines 1–21):
```swift
// Features/Onboarding/Injection/OnboardingInjection.swift
//
// Distributed DI registration for the Onboarding feature (feature-owner of ScreenTimeAuth*).
// Called from DeluluDetoxApp.init() in Wave 5 bootstrap. Not wired yet in this plan.

enum OnboardingInjection {
    static func register(in container: DIContainer) {
        container.register(ScreenTimeAuthRepository.self, scope: .application) { _ in
            ScreenTimeAuthRepositoryImpl()
        }
        container.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { c in
            RequestScreenTimeAuthUseCaseImpl(repository: c.resolve())
        }
        container.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { c in
            ObserveScreenTimeAuthStatusUseCaseImpl(repository: c.resolve())
        }
        container.register(RefreshScreenTimeAuthStatusUseCase.self, scope: .unique) { c in
            RefreshScreenTimeAuthStatusUseCaseImpl(repository: c.resolve())
        }
    }
}
```

**Patterns to copy:**
- `enum FeatureInjection` (case-less namespace).
- Repository: `scope: .application` (must be singleton because it holds the `CurrentValueSubject` — DI guide §"Reactive state" is explicit on this).
- Every UseCase: `scope: .unique` with factory `{ c in …Impl(repository: c.resolve()) }`.
- Header comment documenting that the feature is the owner and that `register(in:)` is called from `DeluluDetoxApp.init()` — update wording so AppSelection is owner of Blocklist domain.

**AppSelection registration list:**
```swift
container.register(BlocklistRepository.self, scope: .application) { _ in BlocklistRepositoryImpl() }
container.register(ObserveBlocklistUseCase.self, scope: .unique) { c in ObserveBlocklistUseCaseImpl(repository: c.resolve()) }
container.register(UpdateBlocklistUseCase.self, scope: .unique) { c in UpdateBlocklistUseCaseImpl(repository: c.resolve()) }
container.register(RemoveTokenRecordUseCase.self, scope: .unique) { c in RemoveTokenRecordUseCaseImpl(repository: c.resolve()) }
container.register(ReconcileBlocklistUseCase.self, scope: .unique) { c in ReconcileBlocklistUseCaseImpl(repository: c.resolve()) }
```

---

### 7. Modified — `Features/Home/ViewModel/HomeViewModel.swift`

**Analog primary:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` — because HomeViewModel must become @MainActor + @Observable + `@unchecked Sendable`, own a `Destination` `@CasePathable` enum, subscribe to a publisher via `.sink` + `cancellables`.

Relevant excerpt from `AppRootViewModel.swift` already quoted in section 4.

**@CasePathable Destination with payload — from research Pattern 4 (RESEARCH lines 353–365):**
```swift
@CasePathable
enum Destination {
    case picker(PickerSession)
    case errorAlert(String)
}

struct PickerSession: Identifiable, Equatable {
    let id = UUID()
    var selection: FamilyActivitySelection
}
```

**Patterns to copy:**
- Upgrade class header from current `@Observable final class HomeViewModel` (HomeViewModel.swift line 3–4) to the AppRootViewModel header (`@MainActor @Observable final class HomeViewModel: @unchecked Sendable`).
- Add `@LazyInjected` for `ObserveBlocklistUseCase` and `UpdateBlocklistUseCase` (cross-feature consumption — Denial → Onboarding precedent in `DenialViewModel.swift` lines 10–14 where Denial consumes `RequestScreenTimeAuthUseCase` registered by Onboarding).
- Add `cancellables: Set<AnyCancellable> = []` and `.sink { [weak self] in self?.snapshot = $0 }.store(in: &cancellables)` in init (AppRootViewModel.swift lines 26–34).
- Async intent `pickerDismissed(committed:)` mirrors OnboardingViewModel.swift lines 18–30 shape (`do { try await updateBlocklist(selection) } catch { destination = .errorAlert(...); logger.error(...) }`).
- Logger with category `"Home"`.

**Hard rule reminder from guide (architecture/GUIDE.md lines 46–48):** VM must not import SwiftUI — `PickerSession` stays on the VM carrying `FamilyActivitySelection` (from `FamilyControls`, non-UI). The `Binding` conversion happens only inside `HomeView`.

---

### 8. Modified — `Features/Home/View/HomeView.swift`

**Analog for child-VM-owned-by-View:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Root/View/AppRootView.swift` (lines 1–38).

**Child VM `@State` pattern** (AppRootView.swift lines 11–13):
```swift
@State private var onboardingModel = OnboardingViewModel()
@State private var denialModel = DenialViewModel()
@State private var homeModel = HomeViewModel()
```

**Branch switch on destination** (AppRootView.swift lines 16–30):
```swift
var body: some View {
    Group {
        switch model.destination {
        case .onboarding:
            OnboardingView(model: onboardingModel)
        case .denial:
            DenialView(model: denialModel)
        case .home:
            NavigationStack {
                HomeView(model: homeModel)
            }
        case .none:
            Theme.background
        }
    }
    .animation(.easeInOut(duration: 0.35), value: model.destination)
```

**Patterns to copy for `HomeView` edits:**
- Add `@State private var blockedModel = BlockedViewModel()` below the existing `@Bindable var model: HomeViewModel` (mirrors AppRootView lines 11–13).
- Replace the empty-hero `var body` with a `Group { if model.snapshot.records.isEmpty { /* existing hero VStack */ } else { BlockedView(model: blockedModel) } }` block (research Pattern 4, RESEARCH lines 410–417).
- Preserve the current hero literal content (HomeView.swift lines 7–49) as an extracted `@ViewBuilder private var emptyHero: some View { … }` so the diff is readable.
- Add `.sheet(item: $model.destination.picker) { session in PickerHostView(...) }` + `.alert(...)` using case-path bindings — research Pattern 4, RESEARCH lines 422–441.
- Add `PickerHostView` as a fileprivate struct at the bottom of HomeView.swift (RESEARCH lines 449–467). It owns `@State var session` and wraps `FamilyActivityPicker(selection: $session.selection)` in a `NavigationStack` with a "Gotowe" toolbar button.
- Preserve `.background(Theme.background)`, `.navigationTitle("DeluluDetox")`, `.navigationBarTitleDisplayMode(.large)` from current HomeView.swift lines 53–55.
- Wire `blockedModel.onChangeSelection = { [weak model] in model?.chooseAppsTapped() }` in `.onAppear { … }` (RESEARCH lines 870–874 note).

---

### 9. Modified — `Features/Home/Injection/HomeInjection.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Denial/Injection/DenialInjection.swift`

**Entire file pattern** (lines 1–11):
```swift
// Features/Denial/Injection/DenialInjection.swift
//
// No-op: Denial feature consumes RequestScreenTimeAuthUseCase registered by OnboardingInjection.
// This file exists for architectural symmetry and future registration slots.
// Per D-17: shared components live under feature-owner's directory (Onboarding).

enum DenialInjection {
    static func register(in container: DIContainer) {
        // No-op by design. Denial has no feature-owned dependencies in Phase 01.1.
    }
}
```

**Pattern to copy:** `HomeInjection` stays no-op. Home consumes `ObserveBlocklistUseCase` / `UpdateBlocklistUseCase` that are registered by `AppSelectionInjection` (feature-owner of Blocklist domain). Only update the header comment to reference AppSelection-as-owner, analogous to the Denial → Onboarding relationship. Per RESEARCH line 337 this is the sanctioned cross-feature UC consumption path.

---

### 10. Modified — `App/DeluluDetoxApp.swift`

**Analog:** self — `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/App/DeluluDetoxApp.swift` (lines 1–19).

**Current init ordering** (lines 4–12):
```swift
init() {
    let container = DIContainer.shared
    // Kolejność: Onboarding pierwszy (feature-owner ScreenTimeAuth*, D-17). Reszta no-op po nim.
    OnboardingInjection.register(in: container)
    DenialInjection.register(in: container)
    HomeInjection.register(in: container)
    RootInjection.register(in: container)
}
```

**Pattern:** Insert `AppSelectionInjection.register(in: container)` — placement between `OnboardingInjection` and `DenialInjection` is recommended so that by the time Home/Root consume `ObserveBlocklistUseCase` the Blocklist repo is registered. Update the ordering comment.

---

### 11. Test — `DeluluDetoxTests/Features/AppSelection/BlockedViewModelTests.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift`

**Full setUp + publisher-emission test pattern** (lines 1–68):
```swift
import XCTest
import Combine
import FamilyControls
@testable import DeluluDetox

@MainActor
final class AppRootViewModelTests: XCTestCase {
    var mockObserve: MockObserveScreenTimeAuthStatusUseCase!
    var mockRefresh: MockRefreshScreenTimeAuthStatusUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .notDetermined)
        mockRefresh = MockRefreshScreenTimeAuthStatusUseCase()
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        DIContainer.shared.register(RefreshScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockRefresh] _ in
            mockRefresh!
        }
    }

    func testEmissionOfApprovedRoutesToHome() async {
        let vm = AppRootViewModel()
        await Task.yield()
        XCTAssertEqual(vm.destination, .onboarding)

        mockObserve.subject.send(.approved)
        await Task.yield()

        XCTAssertEqual(vm.destination, .home)
    }
```

**Patterns to copy:**
- `@MainActor final class …Tests: XCTestCase`.
- IUO-style test doubles declared at class level; assigned in `setUp()`.
- `override func setUp() async throws { try await super.setUp(); DIContainer.shared.reset(); … }` (this exact ordering is captured by the W16 note in the comment header of `AppRootViewModelTests.swift` line 7).
- Register mocks via `DIContainer.shared.register(…self, scope: .unique) { [mockFoo] _ in mockFoo! }`.
- For publisher-driven assertions: `mockObserve.subject.send(…)` then `await Task.yield()` before assertion — the W12 pattern called out in comment lines 3–6 of `AppRootViewModelTests.swift`.
- For async intent tests: see `OnboardingViewModelTests.swift` lines 19–42 (`await vm.grantAccessTapped(); XCTAssertEqual(mock.callCount, 1); XCTAssertNil(vm.error)`).

---

### 12. Test — `DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests.swift`

**Analog:** no existing repository test in repo. Use `AppRootViewModelTests.swift` as the structural template (XCTest setup, DI reset discipline is irrelevant here since repo test is pure DI-less init-injection per DI-guide §"Testowanie niskie warstwy" lines 406–420).

**DI-less init-injection test pattern — from DI guide:**
```swift
@Test("Repository autoryzuje przez source")
func requestAuthorization() async throws {
    let mockSource = MockScreenTimeAuthSource()
    mockSource.stubAuthorize = .success(())

    let repository = ScreenTimeAuthRepositoryImpl(source: mockSource)
    try await repository.requestAuthorization()

    #expect(mockSource.authorizeCallCount == 1)
}
```

**Patterns to apply:**
- No `DIContainer` interaction — instantiate `BlocklistRepositoryImpl` directly, passing a temp-directory URL if the impl is refactored to accept an injected base URL (recommended to keep file-I/O testable without touching the real App Group container, which is unavailable to unit test runs).
- Use `FileManager.default.temporaryDirectory.appendingPathComponent("blocklists-\(UUID()).json")` as the test base URL.
- Assert round-trip: write a `Blocklist`, re-init repository, verify `blocklistPublisher.first()` yields equal content.
- Assert Combine emission on mutation: subscribe to publisher, call `update(with:)`, confirm next value via an `expectation` or `await for try await` loop.

---

### 13. Test mocks — `DeluluDetoxTests/Features/AppSelection/Mocks/`

#### 13a. `MockBlocklistRepository.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetoxTests/Features/Onboarding/Mocks/MockScreenTimeAuthRepository.swift` (lines 1–36).

**Entire file pattern:**
```swift
import Combine
import FamilyControls
@testable import DeluluDetox

final class MockScreenTimeAuthRepository: ScreenTimeAuthRepository, @unchecked Sendable {
    var stubbedStatus: AuthorizationStatus = .notDetermined {
        didSet { statusSubject.send(stubbedStatus) }
    }
    var requestAuthorizationError: Error?
    var requestAuthorizationCallCount = 0
    var refreshStatusCallCount = 0

    private let statusSubject: CurrentValueSubject<AuthorizationStatus, Never>

    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    init(initialStatus: AuthorizationStatus = .notDetermined) {
        self.stubbedStatus = initialStatus
        self.statusSubject = CurrentValueSubject(initialStatus)
    }

    func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
        if let error = requestAuthorizationError {
            throw error
        }
        stubbedStatus = .approved
    }

    func refreshStatus() {
        refreshStatusCallCount += 1
        statusSubject.send(stubbedStatus)
    }
}
```

**Patterns to copy for `MockBlocklistRepository`:**
- `@unchecked Sendable` conformance.
- Public `stubbedBlocklist: Blocklist` with `didSet { blocklistSubject.send(stubbedBlocklist) }`.
- Error stubs: `updateError: Error?`, `removeError: Error?`, `reconcileError: Error?`.
- Call counters: `updateCallCount`, `removeCallCount`, `reconcileCallCount`.
- `init(initial: Blocklist = .empty())`.

#### 13b. `MockObserveBlocklistUseCase.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetoxTests/Features/Onboarding/Mocks/MockObserveScreenTimeAuthStatusUseCase.swift` (lines 1–18).

**Entire file pattern:**
```swift
import Combine
import FamilyControls
@testable import DeluluDetox

final class MockObserveScreenTimeAuthStatusUseCase: ObserveScreenTimeAuthStatusUseCase, @unchecked Sendable {
    let subject: CurrentValueSubject<AuthorizationStatus, Never>
    var callCount = 0

    init(initialStatus: AuthorizationStatus = .notDetermined) {
        self.subject = CurrentValueSubject(initialStatus)
    }

    func callAsFunction() -> AnyPublisher<AuthorizationStatus, Never> {
        callCount += 1
        return subject.eraseToAnyPublisher()
    }
}
```

**Pattern for `MockObserveBlocklistUseCase`:** same shape with `subject: CurrentValueSubject<Blocklist, Never>`. Tests drive emissions via `mockObserveBlocklist.subject.send(stubBlocklist)` followed by `await Task.yield()` (per `AppRootViewModelTests.swift` comment lines 3–6).

#### 13c. `MockUpdateBlocklistUseCase.swift` and `MockRemoveTokenRecordUseCase.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetoxTests/Features/Onboarding/Mocks/MockRequestScreenTimeAuthUseCase.swift` (lines 1–13).

**Entire file pattern:**
```swift
@testable import DeluluDetox

final class MockRequestScreenTimeAuthUseCase: RequestScreenTimeAuthUseCase, @unchecked Sendable {
    var stubbedError: Error?
    var callCount = 0

    func callAsFunction() async throws {
        callCount += 1
        if let error = stubbedError {
            throw error
        }
    }
}
```

**Pattern for Update/Remove mocks:** identical shape, parameterize `callAsFunction` with `_ selection: FamilyActivitySelection` / `_ recordID: TokenRecord.ID` and store last argument into `capturedSelection` / `capturedRecordID` for assertions.

#### 13d. `MockReconcileBlocklistUseCase.swift`

**Analog:** `/Users/kked/Projects/KKSW---first-app/DeluluDetoxTests/Features/Onboarding/Mocks/MockRefreshScreenTimeAuthStatusUseCase.swift` (lines 1–9).

**Entire file pattern:**
```swift
@testable import DeluluDetox

final class MockRefreshScreenTimeAuthStatusUseCase: RefreshScreenTimeAuthStatusUseCase, @unchecked Sendable {
    var callCount = 0

    func callAsFunction() {
        callCount += 1
    }
}
```

Note: if planner keeps `ReconcileBlocklistUseCase.callAsFunction() async throws`, add `stubbedError: Error?` and the standard `if let error = stubbedError { throw error }` block.

---

## Shared Patterns

### DI registration ordering
**Source:** `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/App/DeluluDetoxApp.swift` lines 4–12.
**Apply to:** `DeluluDetoxApp.init()` edit.
Order: Onboarding → **AppSelection (new)** → Denial → Home → Root. Feature-owner goes first.

### `@unchecked Sendable` discipline
**Source:** `ScreenTimeAuthRepository.swift` line 14; `AppRootViewModel.swift` line 8; `OnboardingViewModel.swift` line 6.
**Apply to:** `BlocklistRepositoryImpl`, `BlockedViewModel`, edited `HomeViewModel`, all Mock classes.
Rule: protocol is `Sendable`; impl is `final class … @unchecked Sendable` when it stores `CurrentValueSubject`, `Set<AnyCancellable>`, or is `@MainActor @Observable`.

### `@ObservationIgnored @LazyInjected` on ViewModel dependencies
**Source:** `OnboardingViewModel.swift` lines 10–11; `AppRootViewModel.swift` lines 19–26.
**Apply to:** every new/edited ViewModel. Always paired — without `@ObservationIgnored` Swift Observation invalidates on every access (see DI guide line 246).

### Combine subscribe pattern in VM
**Source:** `AppRootViewModel.swift` lines 28–34 + 19–26.
**Apply to:** `BlockedViewModel.init()`, `HomeViewModel.init()`.
```swift
@ObservationIgnored private var cancellables: Set<AnyCancellable> = []

init() {
    observeFoo()
        .sink { [weak self] value in self?.state = Self.map(value) }
        .store(in: &cancellables)
}
```
Optional `.receive(on: DispatchQueue.main)` before `.sink` if publisher may emit off-main (safe default; research snippets use it).

### Async intent method shape
**Source:** `OnboardingViewModel.swift` lines 18–30.
**Apply to:** `HomeViewModel.pickerDismissed(committed:)`, `BlockedViewModel.deleteTapped(recordID:)`.
```swift
func fooTapped(...) async {
    isRequesting = true
    error = nil
    do {
        try await useCase(...)
        logger.info("…")
    } catch {
        self.error = error.localizedDescription
        logger.error("…: \(error.localizedDescription, privacy: .public)")
    }
    isRequesting = false
}
```

### Logger convention
**Source:** `OnboardingViewModel.swift` line 14; `DenialViewModel.swift` line 14.
**Apply to:** every new ViewModel + `BlocklistRepositoryImpl`.
```swift
@ObservationIgnored
private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "FeatureName")
```
Category names observed in repo: `"Onboarding"`, `"Denial"`. Planned: `"Home"`, `"BlockedVM"`, `"BlocklistRepository"`.

### Test `setUp` discipline
**Source:** `AppRootViewModelTests.swift` lines 18–29; `OnboardingViewModelTests.swift` lines 10–17.
**Apply to:** every new XCTestCase in `DeluluDetoxTests/Features/AppSelection/`.
```swift
@MainActor
final class FooTests: XCTestCase {
    var mockX: MockX!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockX = MockX()
        DIContainer.shared.register(X.self, scope: .unique) { [mockX] _ in mockX! }
    }
```
Plus: `await Task.yield()` between `subject.send(...)` and `XCTAssert...` (W12 note in `AppRootViewModelTests.swift` lines 3–6).

### Preview with DI bootstrap
**Source:** `OnboardingView.swift` lines 74–81; `AppRootView.swift` lines 40–50.
**Apply to:** `BlockedView` `#Preview` and `HomeView` updated `#Preview`.
```swift
#Preview {
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)
    AppSelectionInjection.register(in: container)
    return BlockedView(model: BlockedViewModel())
}
```

### Feature-first layout
**Source:** `feature-structure/GUIDE.md` §"Simple (1 ekran)" lines 22–51; actual Onboarding tree at `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/Onboarding/`.
**Apply to:** Directory scaffolding of `Features/AppSelection/`. Use **Simple** variant — only one new app-owned screen (`BlockedView`). Mirror Onboarding subdir names exactly: `Repository/`, `Repository/Models/`, `UseCase/`, `ViewModel/`, `View/`, `Injection/`. No `Common/`.

### XcodeGen — no edit needed
**Source:** `project.yml` lines 27–28.
**Apply to:** new files.
`sources: - path: DeluluDetox/Sources` already recursively globs new files under `Features/AppSelection/`; same for `DeluluDetoxTests/Features/AppSelection/` under test target (`project.yml` line 133). After adding files, still run `xcodegen generate` to refresh the `.xcodeproj` filelist — per CLAUDE.md "never edit `.xcodeproj` manually".

---

## No Analog Found

No file in this phase is missing a direct or strong role-match analog in the existing codebase. The two file types with no in-repo counterpart are covered by inline research code + guide rules, not left to improvisation:

| File | Gap | Substitute source |
|------|-----|-------------------|
| `BlocklistRepository` file-I/O helpers (App Group container URL, atomic write, JSON decode) | No existing repo persists to disk. | RESEARCH §"Pattern 1" lines 222–256; RESEARCH §"Don't Hand-Roll" rows on App Group path and atomic writes lines 487–488. |
| `Blocklist` / `TokenRecord` / `TokenKind` domain models | No domain models exist yet (Onboarding uses only Apple-provided `AuthorizationStatus`). | RESEARCH §"Code Examples — Blocklist domain model" lines 657–765. |
| `BlocklistRepositoryTests` (file-I/O integration) | No repository test in repo. | DI guide §"Testowanie niskie warstwy" lines 406–420 + test `@MainActor` / setUp discipline from `AppRootViewModelTests.swift`. |
| `BlockedView` List + `.swipeActions` + `.safeAreaInset(edge: .bottom)` | HomeView is a single-VStack empty hero, not a `List`. | RESEARCH §"BlockedView with swipe-to-delete" lines 772–820 + UI-SPEC §Screen 3 spacing / copy table. |

---

## Metadata

**Analog search scope:**
- `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/Features/{Onboarding,Home,Denial,Root}/**/*.swift`
- `/Users/kked/Projects/KKSW---first-app/DeluluDetox/Sources/{App,Core,DesignSystem}/**/*.swift`
- `/Users/kked/Projects/KKSW---first-app/DeluluDetoxTests/**/*.swift`
- `/Users/kked/Projects/KKSW---first-app/project.yml`

**Files scanned:** 23 Swift files + `project.yml`.

**Reference commits:** post-01.1 merge (`a0d6348`), final polish (`efd8868`).

**Pattern extraction date:** 2026-04-19.
