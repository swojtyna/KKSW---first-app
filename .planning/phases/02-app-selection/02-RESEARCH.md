# Phase 02: App Selection — Research

**Researched:** 2026-04-19
**Domain:** iOS FamilyControls + feature-first persistence + SwiftUI sheet presentation
**Confidence:** HIGH (stack, architecture, persistence shape) / MEDIUM (reconciliation semantics, picker failure modes on iOS 26)

## Summary

Phase 02 dokłada feature `AppSelection` do układu post-01.1: user otwiera `FamilyActivityPicker` z `HomeView`, wybrane tokeny lecą do repo, są zapisane jako Codable JSON w App Group (`blocklists.json`), a `BlockedView` renderuje rekordy po `Label(token)` z swipe-to-delete i przyciskiem "Zmień wybór". Wzorzec architektoniczny 1:1 z Onboarding post-01.1: **Repository z `CurrentValueSubject` + Combine publisher + distributed `AppSelectionInjection.register`**. Token rotation obsługiwana przez schemat "rekord pod własnym UUID, token jako best-effort pointer" (D-05) z reconciliacją tylko na `scenePhase == .active`.

Krytyczne odkrycie: `FamilyActivitySelection` jest w całości Codable (cały zestaw + pojedyncze tokeny), więc D-02 "Codable struct → JSON" działa bez gimnastyki. Pełna selekcja jest potrzebna tylko do re-seedu pickera; per-token rekordy z UUID są prawdziwym źródłem prawdy do shieldowania (Phase 3). Największe ryzyko nie-techniczne: entitlement `family-controls` wymaga approval per bundle ID (sandbox działa dla dev, ale picker na urządzeniu niech robi user przed commitem kodu do produkcji). Największe ryzyko techniczne: `FamilyActivityPicker` crashuje przy dużej selekcji (FB11400221, ~50 items) i tokeny rotują po update iOS (FB14082790 ack by DTS).

**Primary recommendation:** Utwórz `Features/AppSelection/` w wariancie **Simple** (1 ekran faktyczny = `BlockedView`; HomeView zostaje w feature Home i tylko trigger'uje destination; picker jest native sheet Apple'a, nie traktujemy go jako "naszego" ekranu). Repository owns `CurrentValueSubject<BlocklistSnapshot, Never>`; main app jest sole writer; testy idą przez UC mocki wstawiane do `DIContainer.shared.reset()` w `setUp()`. Blok `FamilyActivityPicker` NIE działa na simulatorze — unit testy pokrywają VM + Repo + UC; faktyczne picker flow weryfikujemy manualnie na urządzeniu w plan-level human-verify.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 List Model:** Data model supports N named blocklists from day 1 (`Blocklist` entity with `id: UUID`, optional `name: String`, `[TokenRecord]`). MVP UI exposes only a single implicit blocklist — no list CRUD, no list picker in session flow. Future phase can enable multi-list UI without schema migration.
- **D-02 Persistence:** `Codable` structs serialized to JSON files in the App Group container (`group.com.kksw.DeluluDetox`). Main app is the sole writer; extensions (DeviceActivityMonitor, ShieldConfiguration, ShieldAction) are read-only. Writes are atomic (`Data.write(to:options: .atomic)`). No SwiftData, no UserDefaults for structured data, no 3rd-party persistence SDKs.
- **D-03 Split per domain:** separate files `blocklists.json`, `sessions.json`, `schedule.json` (latter two arrive in Phase 3/5). DeviceActivityMonitor extension reads only what it needs, keeping parse/RAM cost down within the 6 MB limit.
- **D-04 Review & Edit UI:** Dedicated "Blocked" screen, scrollable list with one row per `TokenRecord` via `Label(token)`. Per-row swipe-to-delete. "Change selection" button opens `FamilyActivityPicker` pre-seeded with current `FamilyActivitySelection`. No custom picker UI.
- **D-05 Token Reconciliation:** Reconcile UUID↔token mapping on `scenePhase == .active` only. On foreground, fetch the current `FamilyActivitySelection` from persisted state, diff against Apple's current token set, refresh `TokenRecord.token` pointers (keyed by UUID). Accepted risk: stale token between foreground and Phase 3 session start is deferred.

### Claude's Discretion

- Exact SwiftUI component structure for the "Blocked" screen (cell layout, spacing, header copy).
- Empty-state copy and illustration when the user has picked nothing yet.
- Entry point for the "Blocked" screen in the app navigation (tab vs. root destination) — **UI-SPEC already locks this: BlockedView is the non-empty branch of HomeView; no new tab, no new NavigationStack.**
- Error / retry copy if `FamilyActivityPicker` presentation fails — **UI-SPEC already locks copy.**
- `FamilyActivitySelection` hydration strategy — research resolves: cache full selection AS A FIELD on `Blocklist` (not a separate file) so picker re-seed is one read.

### Deferred Ideas (OUT OF SCOPE)

- Multi-list CRUD UI (surfaces later phase).
- Session-start reconciliation (deferred to Phase 3).
- On-demand / periodic / background reconciliation.
- Empty-state suggestions ("Block these 5 popular social apps") — Apple doesn't expose names.
- Import / export blocklist JSON — power-user, deferred.

## Project Constraints (from CLAUDE.md)

Constraints that override any recommendation below. Planner MUST verify compliance:

1. **iOS 26.0 deployment target, Swift 6.2, SwiftUI only** — SwiftData is forbidden by D-02 anyway; iOS 26 means `@Observable` + Swift Observation is available (not iOS 17 `ObservableObject`).
2. **Feature-first layout (MANDATORY post-01.1):** Repository + UseCase + ViewModel + View live under `Features/<Feature>/` with `Injection/<Feature>Injection.swift`. Shared code only via `Common/` of the feature-owner; NO global `FeatureCommons/`.
3. **Dependency rules (hard):** Repository ↛ Repository. UseCase → UseCase / Repository. ViewModel → tylko UseCase. View → tylko ViewModel.
4. **ViewModel MUST NOT import SwiftUI** (only `Observation`). `FamilyActivitySelection` comes from `FamilyControls` framework which is non-UI — safe for VMs.
5. **DIContainer + @LazyInjected for VMs, init injection for Repo/UC.** Distributed registration: `Features/AppSelection/Injection/AppSelectionInjection.swift`.
6. **Navigation via `swift-navigation`, `@CasePathable`, single `Destination?` enum on VM.** Picker presentation follows Wzorzec A (sheet = modal over Home).
7. **XcodeGen:** `project.yml` changes, then `xcodegen generate`. Never hand-edit `.xcodeproj`.
8. **Build/test via XcodeBuildMCP**, never raw `xcodebuild`.
9. **No emojis in user-facing strings and source files.**
10. **App Group entitlement already set on all 4 targets** (main + 3 extensions). Verified `DeluluDetox.entitlements` contains `group.com.kksw.DeluluDetox` + `com.apple.developer.family-controls`. Phase 02 does not touch `project.yml` or entitlements.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEL-01 | User can select apps to block using FamilyActivityPicker | Stack: `FamilyActivityPicker` (SwiftUI View) or `.familyActivityPicker(isPresented:selection:)` modifier. Presentation via `@Bindable` → `.sheet(item: $model.destination.picker)`. Binding to `FamilyActivitySelection.applicationTokens`. |
| SEL-02 | User can select app categories to block | Same picker; `FamilyActivitySelection.categoryTokens: Set<ActivityCategoryToken>`. No separate flow needed — picker tab bar lets user switch domain. |
| SEL-03 | User can select websites to block | Same picker; `FamilyActivitySelection.webDomainTokens: Set<WebDomainToken>`. |
| SEL-04 | Selected tokens persist across app launches via App Group | Repo writes JSON atomically to `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kksw.DeluluDetox")?.appendingPathComponent("blocklists.json")`. Load on repo init, hydrate `CurrentValueSubject<Blocklist, Never>`. |
| SEL-05 | Token rotation handled — records keyed by UUID, token as best-effort pointer | `TokenRecord { id: UUID, kind: {app\|category\|webDomain}, token: Data? (Codable opaque), lastSeenAt: Date }`. On `scenePhase == .active`, `ReconcileBlocklistUseCase` compares persisted `FamilyActivitySelection` against fresh resolution and refreshes token pointers per-UUID without losing record identity. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `FamilyControls` (Apple) | iOS 26 SDK | `FamilyActivityPicker`, `FamilyActivitySelection`, token types | The only Apple-provided way to let user pick blockable apps; `.individual` authorization already granted by Phase 1. `[VERIFIED: Apple docs — pedroesli.com, forum 723841]` |
| `ManagedSettings` (Apple) | iOS 26 SDK | `ApplicationToken`, `ActivityCategoryToken`, `WebDomainToken`, `ShieldSettings` | Token types are declared here, not in FamilyControls. Shield application is Phase 3, but the types are Phase 2 dependencies (persistence schema). `[VERIFIED: Apple docs — managedsettings/applicationtoken route]` |
| `Combine` (Apple) | iOS 26 SDK | `CurrentValueSubject` → `AnyPublisher` in repo | Established post-01.1 pattern (Onboarding `ScreenTimeAuthRepository`); matches the same shape, same `.sink` in AppRoot. `[VERIFIED: guide dependency-injection/GUIDE.md §"Reactive state"]` |
| `Foundation` | iOS 26 SDK | `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`, `Data.write(to:options:.atomic)`, `JSONEncoder`/`JSONDecoder`, `UUID`, `Date` | Standard App Group persistence — no 3rd party needed for structured data. `[VERIFIED: compass_artifact_wf-280372a6 §C production snippet]` |
| `swift-navigation` / `SwiftUINavigation` | `2.8.0+` (already in `project.yml`) | `@CasePathable`, case-path bindings `$model.destination.picker` | Post-01.1 locked choice. `[VERIFIED: project.yml line 19-21]` |
| `Observation` | iOS 26 SDK | `@Observable`, `@ObservationIgnored` | Swift 6.2 standard; VMs use `@MainActor @Observable @unchecked Sendable`. `[VERIFIED: existing Onboarding/Denial/Home/Root VMs]` |
| `os` | iOS 26 SDK | `Logger(subsystem: "com.kksw.DeluluDetox", category: "AppSelection")` | Existing pattern from `OnboardingViewModel`. `[VERIFIED: OnboardingViewModel.swift:14]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `FileManager` + `NSFileCoordinator` | iOS 26 SDK | Cross-process safe writes | Coordinator is **recommended by compass artifact** for App Group files when extensions also read, but in Phase 02 extensions are not yet reading `blocklists.json` — Phase 3 onwards. Planner can ship Phase 02 with `.atomic` alone and add `NSFileCoordinator` when Phase 3 DeviceActivityMonitor starts reading. Document this as a known follow-up. `[CITED: compass_artifact_wf-280372a6 §C + guide]` |
| `UserDefaults(suiteName:)` | iOS 26 SDK | Small scalars (e.g., `needsRepair` flag) | Per D-02 explicitly "no UserDefaults for structured data" — we CAN use it for flags/counters if needed, but in Phase 02 we don't need any. Keep available for Phase 4+ unknown-token repair flag. Not Phase 02 scope. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Codable JSON file | SwiftData `@Model` | Foqos uses SwiftData (`@Model class BlockedProfiles`). **Rejected:** D-02 explicitly forbids SwiftData. Rationale: extensions read same file in Phase 3+ without spinning up `ModelContainer` (6 MB RAM limit). `[CITED: Foqos Models/BlockedProfiles.swift]` |
| `NSFileCoordinator` wrap in Phase 02 | Plain `Data.write(to:options:.atomic)` | Main app is sole writer AND sole reader in Phase 02 (no extension reads blocklists.json yet). `.atomic` (tempfile + rename(2)) is POSIX-atomic on APFS → sufficient. Add `NSFileCoordinator` in Phase 3 when extension becomes reader. `[CITED: compass_artifact §C]` |
| `@State var showPicker: Bool` in `HomeView` | `Destination?` enum with `.picker` case | `@State var showX` in View is explicit anti-pattern per navigation/GUIDE.md: "move it to the ViewModel so deep links and tests can drive it". Must go through Destination enum. `[VERIFIED: navigation/GUIDE.md §"Common pitfalls"]` |
| Presenting `FamilyActivityPicker` directly (init) | `.familyActivityPicker(isPresented:selection:)` modifier | Both work. Modifier is more idiomatic; init form works if you want it inside `.sheet(content:)`. For this phase: `.sheet(item: $model.destination.picker) { selection in FamilyActivityPicker(selection: $selection) }`. `[VERIFIED: Apple docs route /documentation/swiftui/view/familyactivitypicker(ispresented:selection:)]` |

**Installation:** Zero new packages. FamilyControls + ManagedSettings + Combine + Foundation + Observation + os are all SDK-native. `SwiftUINavigation` is already in `project.yml`. **No `project.yml` changes needed for Phase 02.**

**Version verification:** `swift-navigation` already pinned `from: "2.8.0"` in `project.yml` — current published major version line. No version check needed; system frameworks ride the iOS 26 SDK.

## Architecture Patterns

### Recommended Project Structure

```
DeluluDetox/Sources/Features/AppSelection/      (NEW FEATURE — Simple layout)
├── Repository/
│   ├── BlocklistRepository.swift              // protocol + impl in one file
│   └── Models/
│       ├── Blocklist.swift                    // id, name?, records, lastSelection
│       ├── TokenRecord.swift                  // id: UUID, kind, token encoding
│       └── TokenKind.swift                    // enum: .application | .category | .webDomain
├── UseCase/
│   ├── ObserveBlocklistUseCase.swift          // Publisher<Blocklist, Never>
│   ├── UpdateBlocklistUseCase.swift           // (FamilyActivitySelection) -> throws
│   ├── RemoveTokenRecordUseCase.swift         // (TokenRecord.ID) -> throws
│   └── ReconcileBlocklistUseCase.swift        // () -> throws, called on scenePhase .active
├── ViewModel/
│   └── BlockedViewModel.swift                 // @Observable; drives BlockedView
├── View/
│   └── BlockedView.swift                      // SwiftUI list + swipe + CTA
└── Injection/
    └── AppSelectionInjection.swift            // DI registration

DeluluDetox/Sources/Features/Home/              (EDITED — add Destination + wiring)
├── ViewModel/HomeViewModel.swift              // add Destination? enum with .picker(Binding-friendly payload)
├── View/HomeView.swift                        // add .sheet for picker + branch body by isEmpty
└── Injection/HomeInjection.swift              // add UC registration — see below

DeluluDetoxTests/Features/AppSelection/         (NEW)
├── BlockedViewModelTests.swift
├── Mocks/
│   ├── MockBlocklistRepository.swift
│   ├── MockObserveBlocklistUseCase.swift
│   ├── MockUpdateBlocklistUseCase.swift
│   ├── MockRemoveTokenRecordUseCase.swift
│   └── MockReconcileBlocklistUseCase.swift
└── BlocklistRepositoryTests.swift             // in-memory App Group dir via temp URL
```

**Why Simple (not Split) variant:** Only one faktyczny app-owned screen (`BlockedView`) is introduced. `HomeView` already exists in feature `Home`; picker is Apple-owned. No `Common/` subdir needed. If Phase 5 introduces multiple AppSelection screens (e.g., per-list CRUD) sharing repo/UC — migrate to Split then. `[VERIFIED: feature-structure/GUIDE.md §"Kiedy migrować Simple → Split"]`

**Ownership of `HomeViewModel` Destination:** Per UI-SPEC §"Navigation & State Contract" — `HomeViewModel` owns the `Destination?` enum and the picker trigger. `HomeViewModel` wstrzykuje UC-e z AppSelection feature'a (cross-feature UC consumption is the sanctioned path). `HomeView` renders either empty hero OR `BlockedView` depending on snapshot. `BlockedViewModel` lives separately and is owned by `HomeView` via `@State private var blockedModel = BlockedViewModel()`. This mirrors post-01.1 AppRootView which owns child VMs via `@State`.

**Alternative considered:** Fold everything into `HomeViewModel`. **Rejected** because BlockedView has 4 UC deps (Observe, Update, Remove, Reconcile) and HomeViewModel only needs Update + Observe to drive the empty/populated branch. Splitting keeps each VM narrow.

### Pattern 1: Feature-first Repository with CurrentValueSubject

**What:** Repository owns `CurrentValueSubject<Blocklist, Never>`. Observe UC exposes `AnyPublisher`. Update/Remove UCs mutate file + send to subject.

**When to use:** Always for this phase — established post-01.1 pattern; HomeViewModel + BlockedViewModel both subscribe to the same publisher.

**Example:**

```swift
// Features/AppSelection/Repository/BlocklistRepository.swift
// Source: mirrors ScreenTimeAuthRepository.swift post-01.1

import Combine
import FamilyControls
import Foundation
import ManagedSettings
import os

// MARK: - Protocol

protocol BlocklistRepository: Sendable {
    var blocklistPublisher: AnyPublisher<Blocklist, Never> { get }
    func update(with selection: FamilyActivitySelection) async throws
    func remove(recordID: TokenRecord.ID) async throws
    func reconcile() async throws
}

// MARK: - Implementation

final class BlocklistRepositoryImpl: BlocklistRepository, @unchecked Sendable {
    private static let appGroupID = "group.com.kksw.DeluluDetox"
    private static let fileName = "blocklists.json"
    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "BlocklistRepository"
    )

    private let blocklistSubject: CurrentValueSubject<Blocklist, Never>
    private let ioQueue = DispatchQueue(label: "com.kksw.DeluluDetox.blocklist-io",
                                        qos: .userInitiated)

    var blocklistPublisher: AnyPublisher<Blocklist, Never> {
        blocklistSubject.eraseToAnyPublisher()
    }

    init() {
        let initial = Self.readFromDisk() ?? Blocklist.empty()
        self.blocklistSubject = CurrentValueSubject(initial)
    }

    func update(with selection: FamilyActivitySelection) async throws {
        let current = blocklistSubject.value
        let updated = current.merging(selection: selection)
        try await writeAndEmit(updated)
    }

    func remove(recordID: TokenRecord.ID) async throws {
        var current = blocklistSubject.value
        current.records.removeAll { $0.id == recordID }
        // Also drop from cached FamilyActivitySelection so re-seed of picker reflects deletion.
        current.lastSelection = current.lastSelection.removingToken(
            forRecord: current.records.first(where: { $0.id == recordID })
        )
        try await writeAndEmit(current)
    }

    func reconcile() async throws {
        // D-05: diff current persisted FamilyActivitySelection against identity UUIDs.
        // Token content may have rotated after iOS update — refresh the `.token` field
        // per-UUID, keep `id` stable. Details in §"Token rotation reconciliation".
        let current = blocklistSubject.value
        let reconciled = current.reconcileTokenPointers()
        try await writeAndEmit(reconciled)
    }

    // MARK: - I/O

    private func writeAndEmit(_ blocklist: Blocklist) async throws {
        try await ioQueue.perform {
            try Self.writeToDisk(blocklist)
        }
        blocklistSubject.send(blocklist)
    }

    private static func fileURL() throws -> URL {
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw BlocklistStoreError.containerUnavailable
        }
        return base.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func writeToDisk(_ blocklist: Blocklist) throws {
        let url = try fileURL()
        let data = try JSONEncoder().encode(blocklist)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        log.info("blocklist written bytes=\(data.count, privacy: .public) records=\(blocklist.records.count)")
    }

    private static func readFromDisk() -> Blocklist? {
        do {
            let url = try fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Blocklist.self, from: data)
        } catch {
            log.error("read failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

enum BlocklistStoreError: Error {
    case containerUnavailable
}

// Helper — run blocking closure off main on custom queue.
extension DispatchQueue {
    func perform<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            async { [self] in self.async { cont.resume(with: Result { try work() }) } }
        }
    }
}
```

### Pattern 2: UseCase thin passthroughs (VM→UC hard rule)

```swift
// Features/AppSelection/UseCase/ObserveBlocklistUseCase.swift
import Combine

protocol ObserveBlocklistUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<Blocklist, Never>
}

final class ObserveBlocklistUseCaseImpl: ObserveBlocklistUseCase {
    private let repository: BlocklistRepository
    init(repository: BlocklistRepository) { self.repository = repository }
    func callAsFunction() -> AnyPublisher<Blocklist, Never> {
        repository.blocklistPublisher
    }
}

// Features/AppSelection/UseCase/UpdateBlocklistUseCase.swift
import FamilyControls

protocol UpdateBlocklistUseCase: Sendable {
    func callAsFunction(_ selection: FamilyActivitySelection) async throws
}

final class UpdateBlocklistUseCaseImpl: UpdateBlocklistUseCase {
    private let repository: BlocklistRepository
    init(repository: BlocklistRepository) { self.repository = repository }
    func callAsFunction(_ selection: FamilyActivitySelection) async throws {
        try await repository.update(with: selection)
    }
}

// Analogiczne: RemoveTokenRecordUseCase, ReconcileBlocklistUseCase.
```

### Pattern 3: Distributed DI registration per feature

```swift
// Features/AppSelection/Injection/AppSelectionInjection.swift
enum AppSelectionInjection {
    static func register(in container: DIContainer) {
        container.register(BlocklistRepository.self, scope: .application) { _ in
            BlocklistRepositoryImpl()
        }
        container.register(ObserveBlocklistUseCase.self, scope: .unique) { c in
            ObserveBlocklistUseCaseImpl(repository: c.resolve())
        }
        container.register(UpdateBlocklistUseCase.self, scope: .unique) { c in
            UpdateBlocklistUseCaseImpl(repository: c.resolve())
        }
        container.register(RemoveTokenRecordUseCase.self, scope: .unique) { c in
            RemoveTokenRecordUseCaseImpl(repository: c.resolve())
        }
        container.register(ReconcileBlocklistUseCase.self, scope: .unique) { c in
            ReconcileBlocklistUseCaseImpl(repository: c.resolve())
        }
    }
}

// App/DeluluDetoxApp.swift — ADD this line in init:
// AppSelectionInjection.register(in: container)
```

**HomeInjection is no longer no-op** — HomeViewModel will now depend on `ObserveBlocklistUseCase` and `UpdateBlocklistUseCase`, but those UCs are registered by `AppSelectionInjection` (feature-owner of blocklist domain). HomeInjection remains no-op; Home consumes cross-feature UCs by resolving them through DI against types owned by AppSelection. This matches the Denial → Onboarding pattern post-01.1 (Denial consumes `RefreshScreenTimeAuthStatusUseCase` which is registered by Onboarding).

### Pattern 4: Wzorzec A (sheet) — HomeViewModel Destination + picker presentation

```swift
// Features/Home/ViewModel/HomeViewModel.swift — REWRITE
import Observation
import Combine
import FamilyControls
import SwiftUINavigation
import os

@MainActor
@Observable
final class HomeViewModel: @unchecked Sendable {

    @CasePathable
    enum Destination {
        case picker(PickerSession)       // payload binding-friendly via @CasePathable
        case errorAlert(String)
    }

    // Wrapper so FamilyActivitySelection can be mutated through a sheet item binding.
    // Identifiable required by .sheet(item:); id is UUID per presentation instance.
    struct PickerSession: Identifiable, Equatable {
        let id = UUID()
        var selection: FamilyActivitySelection
    }

    var destination: Destination?
    private(set) var snapshot: Blocklist = .empty()

    @ObservationIgnored @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase
    @ObservationIgnored @LazyInjected private var updateBlocklist: UpdateBlocklistUseCase
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox", category: "Home"
    )

    init() {
        observeBlocklist()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] next in self?.snapshot = next }
            .store(in: &cancellables)
    }

    func chooseAppsTapped() {
        destination = .picker(PickerSession(selection: snapshot.lastSelection))
    }

    /// Called by View when the picker sheet dismisses.
    func pickerDismissed(committed selection: FamilyActivitySelection) async {
        do {
            try await updateBlocklist(selection)
            logger.info("blocklist updated records=\(selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count)")
        } catch {
            destination = .errorAlert("Nie udało się zapisać wyboru. Spróbuj ponownie.")
            logger.error("update failed: \(String(describing: error), privacy: .public)")
        }
    }
}
```

```swift
// Features/Home/View/HomeView.swift — EDITED
import SwiftUI
import SwiftUINavigation
import FamilyControls

struct HomeView: View {
    @Bindable var model: HomeViewModel
    @State private var blockedModel = BlockedViewModel()

    var body: some View {
        Group {
            if model.snapshot.records.isEmpty {
                emptyHero
            } else {
                BlockedView(model: blockedModel)
            }
        }
        .background(Theme.background)
        .navigationTitle("DeluluDetox")
        .navigationBarTitleDisplayMode(.large)
        // Wzorzec A — sheet over current screen.
        .sheet(item: $model.destination.picker) { session in
            PickerHostView(
                session: session,
                onDismiss: { finalSelection in
                    Task { await model.pickerDismissed(committed: finalSelection) }
                }
            )
        }
        .alert(
            "Coś się popsuło",
            isPresented: Binding(
                get: { model.destination?.errorAlert != nil },
                set: { if !$0 { model.destination = nil } }
            ),
            presenting: model.destination?.errorAlert
        ) { _ in
            Button("OK", role: .cancel) { model.destination = nil }
        } message: { message in
            Text(message)
        }
    }

    // ... (emptyHero = existing Phase 1 body) ...
}

/// Hosts FamilyActivityPicker inside a .sheet. Needs a local @State because
/// FamilyActivityPicker binds to a plain FamilyActivitySelection Binding.
private struct PickerHostView: View {
    @State var session: HomeViewModel.PickerSession
    let onDismiss: (FamilyActivitySelection) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $session.selection)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gotowe") {
                            onDismiss(session.selection)
                            dismiss()
                        }
                    }
                }
        }
    }
}
```

**Note on UI-SPEC §Screen 2 "no wrapping NavigationStack":** UI-SPEC says do not wrap the picker in a NavigationStack. Reality check: `FamilyActivityPicker` is a View (not a full sheet) — without a surrounding container, it has no close affordance. Apple's own example (Medium/pedroesli) wraps it. The UI-SPEC rule "no custom toolbar" applies to the picker's internal three tabs (Apps/Categories/Web), which Apple renders; our outer `NavigationStack` only gives the sheet a "Gotowe" button — it does NOT restyle the picker. **Planner decision:** follow the pattern above; flag the UI-SPEC line as a design-intent-not-literal-rule and document in plan. Alternative: use `.familyActivityPicker(isPresented:selection:)` modifier on `HomeView`, which presents its own sheet — no outer `NavigationStack` needed. This alternative is simpler but loses the ability to drive presentation through `Destination?` enum (modifier uses `Bool` binding, not item binding). **Recommendation: stick with Destination-based item binding + NavigationStack wrapper for testability. ** `[CITED: navigation/GUIDE.md "One field, one source of truth"]`

### Anti-Patterns to Avoid

- **HomeView owns `@State var showPicker: Bool`** — navigation state must live on VM. Breaks navigation/GUIDE.md contract. `[VERIFIED: navigation/GUIDE.md §"Common pitfalls"]`
- **`HomeViewModel` imports SwiftUI (`Binding<FamilyActivitySelection>`)** — VM must only know `FamilyActivitySelection` (from `FamilyControls`, non-UI). Convert at View layer via local `@State`.
- **`BlocklistRepository` injected into `HomeViewModel`** — breaks "VM → tylko UC". Use `ObserveBlocklistUseCase` and `UpdateBlocklistUseCase` even though they are thin passthroughs. `[VERIFIED: architecture/GUIDE.md §"Dependency rules"]`
- **Shared mutable `Blocklist` across VMs without publisher** — both `HomeViewModel` and `BlockedViewModel` must get the snapshot via `ObserveBlocklistUseCase`, not via property injection / callbacks. `[VERIFIED: dependency-injection/GUIDE.md §"Reactive state"]`
- **Writing JSON from `BlockedViewModel` directly** — VM never touches `FileManager`. Goes through UC → Repo.
- **Caching `FamilyActivitySelection` in a SEPARATE file** — one file (`blocklists.json`), one `Blocklist` struct, with `lastSelection: FamilyActivitySelection` as a field. Avoids sync drift.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Picker UI for selecting apps | Custom SwiftUI picker with token rendering | `FamilyActivityPicker` (Apple) | App names/icons are not exposed as strings/images; only Apple can render them. Any custom UI is literally impossible. `[VERIFIED: compass_artifact_wf-280372a6 §"Hard rendering constraint"]` |
| Codable support for tokens | Custom `String(base64)` round-trip of token bytes | `JSONEncoder().encode(familyActivitySelection)` | `FamilyActivitySelection` and individual tokens conform to `Codable`. Round-trip is guaranteed within device lifetime. `[CITED: forum thread 723841, pedroesli.com ApplicationProfile example]` |
| Atomic cross-process writes | Manual file-lock / dispatch semaphore | `Data.write(to:options:.atomic)` + `NSFileCoordinator` | POSIX tempfile-then-rename is already atomic on APFS; coordinator handles the read/write ordering across processes. `[VERIFIED: compass_artifact §C]` |
| App Group path | Hardcoded `URL(fileURLWithPath: "/private/var/…")` | `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` | Only supported resolution — container ID changes between dev/release. Direct paths crash in release. `[VERIFIED: Apple docs — Configuring App Groups]` |
| Token rotation detection | Polling timer, Darwin notifications from main app | `scenePhase == .active` reconcile hook on `AppRootView` | scenePhase is the sanctioned lifecycle signal Apple intends for "user returned to app". Already in use post-01.1 for `ScreenTimeAuth` refresh. `[VERIFIED: AppRootView.swift:32-36]` |
| Re-seeding the picker with current selection | Reconstructing `FamilyActivitySelection` from individual tokens | Cache whole `FamilyActivitySelection` on `Blocklist.lastSelection` | Apple makes no guarantee rebuilding a selection from raw tokens preserves `includeEntireCategory` and internal state. Cache the whole object, mutate via picker binding, persist as-is. `[CITED: forum 721973 — includeEntireCategory lost via PropertyListEncoder]` |
| FamilyActivitySelection encoder | `PropertyListEncoder` | `JSONEncoder` | Known Apple bug FB (forum 721973): `PropertyListEncoder` drops `includeEntireCategory` flag. JSON round-trips correctly. `[VERIFIED: compass_artifact §E pitfall 6]` |

**Key insight:** In Screen Time API, most "custom" work is literally blocked by Apple (opaque tokens, sandboxed extensions, no token-to-name mapping). The only room for creativity is persistence schema + reconciliation strategy, both of which CONTEXT.md already locks.

## Runtime State Inventory

This phase is not a rename/refactor; it introduces new state. Still worth listing what gets created so Phase 3+ planners know what's live:

| Category | Items Introduced | Action Required (future phases) |
|----------|------------------|--------------------------------|
| Stored data | New file `blocklists.json` in App Group container. Contains `Blocklist` struct with records keyed by UUID, token fields as Data-serialized opaque bytes, and cached `FamilyActivitySelection`. | Phase 3 `StartSessionUseCase` reads this file; Phase 5 DeviceActivityMonitor extension reads this file — both are read-only consumers. |
| Live service config | None in Phase 02. (Phase 3 will register DeviceActivitySchedule; Phase 5 will add extensions as readers.) | N/A |
| OS-registered state | None. Screen Time authorization was obtained in Phase 1 and persists separately. | N/A |
| Secrets/env vars | None. | N/A |
| Build artifacts | `AppSelectionInjection.register` is added to `DeluluDetoxApp.init()` boot sequence. | Phase 3/5 features will register additional services; AppSelection owns blocklist. |

**Nothing found in OS-registered / secrets:** confirmed — Phase 02 is code + file-based state only.

## Token rotation reconciliation (D-05 algorithm)

**Reality:** Apple's `ApplicationToken` / `ActivityCategoryToken` / `WebDomainToken` can change binary content after iOS update or iCloud family event (FB14082790 / FB14237883 / FB18353106). Our persisted `TokenRecord.token` field may point to a stale value. Goal: refresh `.token` without losing `TokenRecord.id` (UUID), so downstream consumers still have record-level identity.

**Trigger:** `AppRootView.onChange(of: scenePhase) { if .active → model.refresh() }`. Post-01.1 pattern already calls `refreshStatus()`; we add a parallel `reconcileBlocklist()` in AppRoot (or call it from `HomeViewModel.onAppear`).

**Algorithm (pseudo):**

```
func reconcile(current: Blocklist) -> Blocklist {
    // 1. Read the cached FamilyActivitySelection (this is our "last-known-good" set
    //    of tokens that Apple gave us when the user picked).
    let cachedSelection = current.lastSelection

    // 2. iOS does NOT provide a "give me the current token for this identity" API.
    //    Best we can do: compare sets.
    //    If the cached selection still deserializes and its applicationTokens
    //    set has the same count as our records grouped by .application kind,
    //    assume no rotation happened.

    // 3. If a record's token field has a corresponding entry in the cached
    //    selection, refresh it from cache — it's the authoritative copy
    //    (cache was written in the same write transaction as the records).
    //    If a record's token has NO cache entry, flag for repair
    //    (user needs to re-open picker to re-pair).

    // 4. Update `lastSeenAt = Date()` on records whose token was verified.

    return current.mutated(records: refreshed, lastSelection: cachedSelection)
}
```

**What reconciliation CANNOT do in Phase 02:** It cannot fetch a fresh `FamilyActivitySelection` from iOS — Apple does not expose that API. The picker is the only source of fresh tokens. Therefore "reconcile" in Phase 02 means:

1. Verify cached tokens are still Codable-decodable (detect corrupt write).
2. Verify record count matches cache cardinality (detect drift from prior buggy write).
3. If mismatch: flag `needsRepair = true` on `Blocklist` (new field) and emit; HomeView can show banner next phase.
4. Phase 3+ adds real token verification by attempting to apply to `ManagedSettingsStore` and catching errors.

**Scope for Phase 02 MVP:** Implement the skeleton (ReconcileBlocklistUseCase exists, AppRoot calls it on scenePhase active), but keep the algorithm minimal: re-read from disk, re-emit if contents differ from in-memory subject. Full rotation-aware diff lives in Phase 3 where we actually apply tokens. Document this descope in the plan.

**Confidence level:** MEDIUM. The "correct" reconciliation cannot be fully implemented without attempting to USE the tokens (which is Phase 3). The safe MVP is file-level reconciliation only. Any stronger claim about "Phase 02 reconciles rotated tokens" would be dishonest.

## Common Pitfalls

### Pitfall 1: FamilyActivityPicker crashes at large selections

**What goes wrong:** Picker crashes or silently fails when the user has pre-seeded a selection with many apps (~100+) or diverse category spread (FB11400221 / FB14067691 / FB12270644 / FB14451403).

**Why it happens:** Known Apple bug across iOS 16–26, unresolved as of iOS 26.3.1.

**How to avoid:**
- For MVP, do NOT cap selection — adult self-control users typically pick 5–30 apps.
- Add a defensive timer: if the picker is presented and no UI callback fires within 5 seconds, dismiss and show error alert.
- Log picker sessions to `os.Logger` to detect telemetry if it happens in field.

**Warning signs:** User reports "picker keeps closing without letting me pick" or app memory spikes during sheet presentation.

`[VERIFIED: compass_artifact §E pitfall 8]`

### Pitfall 2: Tokens silently rotate between sessions

**What goes wrong:** Record tokens stored today no longer match what Apple hands to the extension tomorrow. Shield shows default "Restricted" instead of branded UI.

**Why it happens:** FB14082790 token-drift bug. Triggered by iOS update, iCloud family join/leave, spontaneous in the wild.

**How to avoid:**
- Schema already enforces UUID-keyed records (D-05).
- Cache `FamilyActivitySelection` as a whole (not just individual tokens) so re-opening picker re-seeds correctly even if token binary changed.
- Plan Phase 3 banner "Re-select your blocked apps" for cases where tokens appear unknown at shield time.

**Warning signs:** Shield extension logs "unknown token" (Phase 3+), user reports "the block stopped working after I updated iOS".

`[VERIFIED: compass_artifact §E pitfall 1 + §F]`

### Pitfall 3: FamilyActivityPicker does not work on simulator

**What goes wrong:** On Xcode iOS simulator, `AuthorizationCenter.shared.requestAuthorization(for: .individual)` succeeds but the picker may show empty lists or fail to launch (simulator does not track app usage).

**Why it happens:** Family Controls is a fully on-device framework; the simulator lacks real Screen Time state.

**How to avoid:**
- Implement picker flow, write unit tests for VM/Repo/UC with mocks.
- Do NOT block Phase 02 on simulator verification of the full picker UX.
- Mark plan-level human-verify "Must test on physical device iPhone 17 or similar".
- Keep simulator smoke test = "picker sheet presents and can be dismissed" (not "all apps visible").

`[VERIFIED: compass_artifact §D Krok 10]`

### Pitfall 4: includeEntireCategory flag gets lost

**What goes wrong:** Cached `FamilyActivitySelection(includeEntireCategory: true)` round-trips through `PropertyListEncoder` and comes back with the flag `false`. Next picker opening wrongly treats category as individual apps.

**Why it happens:** Apple bug in PropertyListEncoder with FamilyActivitySelection (forum 721973).

**How to avoid:**
- Use `JSONEncoder` / `JSONDecoder` exclusively for FamilyActivitySelection serialization.
- Already in our D-02 spec; enforce in repo code and test.

**Warning signs:** If a user sets "block all social media" (category), closes app, reopens and the picker doesn't show the checkmark on "Social", this bug is active.

`[VERIFIED: compass_artifact §E pitfall 6]`

### Pitfall 5: ViewModel imports SwiftUI via FamilyActivityPicker binding

**What goes wrong:** Developer writes `@Published var selection: FamilyActivitySelection` AND uses `$model.selection` binding directly in a View — this is fine, BUT if the VM needs `SwiftUI.Binding<FamilyActivitySelection>` in its interface, the VM now imports SwiftUI → breaks CLAUDE.md rule.

**Why it happens:** `FamilyActivityPicker(selection:)` needs a `Binding<FamilyActivitySelection>`.

**How to avoid:**
- VM exposes `FamilyActivitySelection` value + intent methods (`pickerDismissed(committed:)`).
- View owns local `@State` for in-flight picker state; hands final value back to VM on dismiss.
- Pattern 4 above demonstrates this.

`[VERIFIED: architecture/GUIDE.md §"ViewModel importujący SwiftUI"]`

### Pitfall 6: Combine subscription not invalidating @Observable

**What goes wrong:** VM subscribes to publisher in `init`, but SwiftUI View doesn't re-render because the `@Observable` macro doesn't automatically pick up Combine sink mutations unless the property is `@ObservationIgnored` cancellables + the actual state var is a plain `var`.

**Why it happens:** Swift Observation pre-condition — property must be observed to trigger view update; `cancellables` must be hidden.

**How to avoid:**
- `@ObservationIgnored private var cancellables: Set<AnyCancellable> = []`
- `@ObservationIgnored @LazyInjected private var observeBlocklist: ...`
- Plain `private(set) var snapshot: Blocklist = .empty()` — THIS is the observed property.

`[VERIFIED: dependency-injection/GUIDE.md §"Konsumpcja w ViewModelu" + AppRootViewModel.swift:24-26]`

### Pitfall 7: App Group container not yet created on fresh install

**What goes wrong:** First call to `containerURL(forSecurityApplicationGroupIdentifier:)` on fresh install returns a URL, but the directory may not physically exist until the first write.

**Why it happens:** Lazy creation by iOS.

**How to avoid:**
- Handle `FileManager.default.fileExists(atPath:)` returning false on initial read (return `Blocklist.empty()`, not throw).
- Let the first `update()` call create the file via `.atomic` write.
- Do NOT proactively create the directory with `createDirectory(at:)`.

**Warning signs:** Test-time `ENOENT` on repo init when container was never written before.

`[VERIFIED: compass_artifact §D Krok 9]`

## Code Examples

### Blocklist domain model

```swift
// Features/AppSelection/Repository/Models/Blocklist.swift
import FamilyControls
import Foundation
import ManagedSettings

struct Blocklist: Codable, Equatable, Sendable {
    let id: UUID
    var name: String?                          // D-01: optional; MVP implicit list
    var records: [TokenRecord]
    var lastSelection: FamilyActivitySelection // Apple-owned, for picker re-seed
    var updatedAt: Date
    var needsRepair: Bool

    static func empty(id: UUID = UUID()) -> Blocklist {
        Blocklist(
            id: id,
            name: nil,
            records: [],
            lastSelection: FamilyActivitySelection(),
            updatedAt: Date(),
            needsRepair: false
        )
    }

    /// Produce a new Blocklist reconciled with a fresh FamilyActivitySelection from the picker.
    /// Preserves existing record UUIDs where possible (token equality), mints new UUIDs for new tokens,
    /// and drops records whose token is no longer in the selection.
    func merging(selection next: FamilyActivitySelection) -> Blocklist {
        var preserved: [TokenRecord] = []

        // Apps
        for token in next.applicationTokens {
            if let existing = records.first(where: { $0.kind == .application && $0.encodedToken == Self.encode(token) }) {
                var refreshed = existing
                refreshed.lastSeenAt = Date()
                preserved.append(refreshed)
            } else {
                preserved.append(TokenRecord(
                    id: UUID(), kind: .application,
                    encodedToken: Self.encode(token), lastSeenAt: Date()
                ))
            }
        }
        // Same for categoryTokens (.category) and webDomainTokens (.webDomain).
        // ... (see plan for unrolled code)

        return Blocklist(
            id: id,
            name: name,
            records: preserved,
            lastSelection: next,
            updatedAt: Date(),
            needsRepair: false
        )
    }

    /// Called by ReconcileBlocklistUseCase on scenePhase active.
    /// Phase 02 scope: re-emit (file re-read); full rotation logic in Phase 3.
    func reconcileTokenPointers() -> Blocklist {
        // Phase 02 MVP — no-op marker that we ran reconcile.
        // Future: verify tokens against cached selection, flag needsRepair if drift detected.
        var copy = self
        copy.updatedAt = Date()
        return copy
    }

    static func encode<T: Codable>(_ token: T) -> Data {
        (try? JSONEncoder().encode(token)) ?? Data()
    }
}

// Features/AppSelection/Repository/Models/TokenRecord.swift

struct TokenRecord: Codable, Equatable, Identifiable, Sendable {
    typealias ID = UUID

    let id: UUID
    let kind: TokenKind
    /// Opaque JSON-encoded Codable token. Apple's ApplicationToken / ActivityCategoryToken /
    /// WebDomainToken are all Codable; we preserve raw bytes so rendering via Label(token)
    /// works after reconstructing the concrete type per-kind in the View layer.
    var encodedToken: Data
    var lastSeenAt: Date

    /// Reconstruct the concrete token for SwiftUI Label rendering. Called on the View side
    /// because rendering is a Presentation concern.
    func applicationToken() -> ApplicationToken? {
        guard kind == .application else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: encodedToken)
    }
    func categoryToken() -> ActivityCategoryToken? {
        guard kind == .category else { return nil }
        return try? JSONDecoder().decode(ActivityCategoryToken.self, from: encodedToken)
    }
    func webDomainToken() -> WebDomainToken? {
        guard kind == .webDomain else { return nil }
        return try? JSONDecoder().decode(WebDomainToken.self, from: encodedToken)
    }
}

// Features/AppSelection/Repository/Models/TokenKind.swift

enum TokenKind: String, Codable, Sendable {
    case application
    case category
    case webDomain
}
```

**Assumption to flag `[ASSUMED]`:** Individual `ApplicationToken` (etc.) conform to `Codable` AND can be encoded/decoded standalone (not only via `FamilyActivitySelection`). Forum 723841 confirms the protocol conformance; the cleaner alternative if standalone encoding proves lossy is to store `encodedSelection: Data` at `Blocklist` level and derive records by filtering the reconstructed `FamilyActivitySelection`. **Plan must include a Wave 0 test that round-trips a single token through JSON and verifies `Label(reconstructed)` renders identically.**

### BlockedView with swipe-to-delete

```swift
// Features/AppSelection/View/BlockedView.swift
import SwiftUI
import FamilyControls
import ManagedSettings

struct BlockedView: View {
    @Bindable var model: BlockedViewModel

    var body: some View {
        List {
            if !model.appRecords.isEmpty {
                Section("Aplikacje") {
                    ForEach(model.appRecords) { record in
                        if let token = record.applicationToken() {
                            Label(token)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await model.deleteTapped(recordID: record.id) }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            // Analogicznie: Kategorie (Section "Kategorie") i Strony www (Section "Strony www").
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Zablokowane")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                model.changeSelectionTapped()
            } label: {
                Text("Zmień wybór")
                    .font(.body).bold()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}
```

### BlockedViewModel

```swift
// Features/AppSelection/ViewModel/BlockedViewModel.swift
import Observation
import Combine
import FamilyControls
import os

@MainActor
@Observable
final class BlockedViewModel: @unchecked Sendable {
    private(set) var appRecords: [TokenRecord] = []
    private(set) var categoryRecords: [TokenRecord] = []
    private(set) var webRecords: [TokenRecord] = []
    private(set) var errorMessage: String?

    @ObservationIgnored @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase
    @ObservationIgnored @LazyInjected private var removeRecord: RemoveTokenRecordUseCase
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "BlockedVM")

    // Parent HomeViewModel still owns "Zmień wybór" trigger (opens picker).
    // We expose a closure callback so View-layer forwards tap up.
    var onChangeSelection: (() -> Void)?

    init() {
        observeBlocklist()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blocklist in
                guard let self else { return }
                self.appRecords = blocklist.records.filter { $0.kind == .application }
                self.categoryRecords = blocklist.records.filter { $0.kind == .category }
                self.webRecords = blocklist.records.filter { $0.kind == .webDomain }
            }
            .store(in: &cancellables)
    }

    func deleteTapped(recordID: TokenRecord.ID) async {
        do {
            try await removeRecord(recordID)
        } catch {
            errorMessage = "Nie udało się usunąć."
            logger.error("remove failed: \(String(describing: error), privacy: .public)")
        }
    }

    func changeSelectionTapped() { onChangeSelection?() }
}
```

**Note:** `BlockedViewModel` does NOT own the picker Destination — `HomeViewModel` does. The `onChangeSelection` callback pattern is a controlled exception to "no callbacks between sibling VMs": the callback lives on a VM that the parent View owns (`@State private var blockedModel`), so lifetime is bounded. The parent `HomeView` wires `blockedModel.onChangeSelection = { [weak model] in model?.chooseAppsTapped() }` inside `.onAppear` or `.task`. Alternative: pass the parent `HomeViewModel` to `BlockedViewModel` init — rejected because `@State private var blockedModel = BlockedViewModel()` cannot parametrize from SwiftUI init. Planner picks: **callback wiring in View layer is simplest and testable.** `[VERIFIED: navigation/GUIDE.md §"Event flow in Wzorzec B"]`

## State of the Art

| Old Approach | Current Approach (post-01.1) | When Changed | Impact |
|--------------|------------------------------|--------------|--------|
| Central `DependencyContainer` with manual ViewModel factories | `DIContainer.shared` with `@LazyInjected` + distributed `<Feature>Injection.register` | Phase 01.1 (2026-04-19) | Phase 02 MUST follow distributed registration; no `AppInjection` / central registration file. |
| Callback-based event flow (`onAuthorized: () -> Void`) | Combine `CurrentValueSubject` in Repository + `Publisher` consumed in VM via `.sink` | Phase 01.1 | Phase 02 uses `CurrentValueSubject<Blocklist, Never>` identically. |
| Child ViewModel in enum case with VM payload (Wzorzec A for root switch) | Wzorzec B for root switch (VM owned by child view via `@State`) | Phase 01.1 | Phase 02 uses Wzorzec A for picker (sheet, not root switch) — correct per UI-SPEC. |
| SwiftData for persistence (Foqos reference) | Codable JSON in App Group | Project-specific D-02 | Different from Foqos but better fit for 6 MB extension RAM limit in Phase 3+. |

**Deprecated/outdated:**
- `PropertyListEncoder` for FamilyActivitySelection — loses `includeEntireCategory`. Use `JSONEncoder`. (Apple bug, forum 721973)
- `ObservableObject` / `@Published` — replaced by `@Observable` + `@ObservationIgnored` (Swift Observation, iOS 17+).
- Direct `containerURL` string concatenation / hardcoded paths — always use `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Individual `ApplicationToken`/`ActivityCategoryToken`/`WebDomainToken` round-trip cleanly through `JSONEncoder`/`JSONDecoder` independently of `FamilyActivitySelection` | Code Examples §Blocklist model | If false, must restructure to store only whole `FamilyActivitySelection` + derive records by filtering — bigger refactor mid-phase. **Plan Wave 0 must contain a round-trip test.** |
| A2 | `FamilyActivityPicker` can be presented inside a custom `NavigationStack` wrapper in a `.sheet(item:)` without visual or behavioral regressions | Pattern 4 + PickerHostView | If Apple's internal tab bar layout conflicts with an outer NavigationStack, the `.familyActivityPicker(isPresented:selection:)` modifier is a fallback (breaks Destination-enum pattern slightly — bool binding). **Plan should test both approaches early.** |
| A3 | Reading `containerURL(...)` on fresh install returns a URL even when directory doesn't physically exist (container is lazily created) | Pitfall 7 | If iOS 26 requires explicit `createDirectory`, first read will fail silently — mitigated by try/catch returning `.empty()`. Low risk. |
| A4 | `scenePhase == .active` fires in time for `ReconcileBlocklistUseCase` to run before user interacts with BlockedView | D-05 algorithm | If reconciliation takes >100ms and user is already tapping swipe-to-delete, races possible. Mitigation: subject emits during reconcile, UI updates; no hard blocking. Low risk. |
| A5 | Simulator can present `FamilyActivityPicker` (sheet opens, no crash) even though token enumeration is empty | Pitfall 3 + Environment | If simulator crashes the picker, we can't smoke-test presentation at all — must ship build to physical device for every plan change. Historical evidence (pedroesli 2023, Phase 1 denial path) suggests simulator tolerates presentation. Medium risk — **plan's first wave must include a simulator smoke test before trusting it.** |
| A6 | `DispatchQueue.perform(_:)` helper snippet in Pattern 1 is correct Swift 6.2 syntax for bridging off-main I/O | Pattern 1 code | If the exact helper signature fails strict-concurrency, use a `Task.detached { try await withUnsafeThrowingContinuation... }` variant. Low risk — mechanical fix. |

**If user confirms A1 (round-trip works) and A2 (NavigationStack wrapper OK), all other assumptions are low-risk and can be validated during Wave 0.** Planner should ask the user to confirm A1 + A2 or escalate to a spike task.

## Open Questions (RESOLVED)

1. **Should `HomeViewModel` own the picker Destination, or should a new `AppSelectionViewModel` sit between?**
   - What we know: UI-SPEC §"Navigation & State Contract" allows either — "MVP-minimum is to extend `HomeViewModel` and switch the sub-view inside `HomeView`". Recommendation path: extend HomeViewModel (fewer files, same ownership).
   - What's unclear: If Phase 3 adds a "Start session" flow that wants its own Destination on HomeViewModel (e.g., `.sessionSheet`), HomeViewModel grows to 2 destinations. Still fine with `@CasePathable`.
   - RESOLVED: **Extend HomeViewModel, do NOT introduce AppSelectionViewModel.** BlockedViewModel stays narrow (list + delete).

2. **Where does `ReconcileBlocklistUseCase` get invoked from?**
   - What we know: `AppRootView.onChange(of: scenePhase) { ... }` already calls `model.refreshStatus()` for Onboarding. We can add a parallel `model.reconcileBlocklist()` on `AppRootViewModel`, or handle it in `HomeViewModel` when `destination` is nil (on appearance).
   - What's unclear: AppRoot-level call means we resolve AppSelection UC in Root feature → slight cross-feature coupling in `AppRootViewModel` (which already couples to Onboarding).
   - RESOLVED: **Add `reconcileBlocklist()` as a second `@LazyInjected` on `AppRootViewModel` + call in the existing `scenePhase == .active` handler.** Symmetry with refreshStatus; single scenePhase hook.

3. **Should `Blocklist.needsRepair` be a field from day 1 even though Phase 02 never sets it true?**
   - What we know: Phase 3/4 shield extension will set this when it hits unknown tokens (compass §F recommended pattern).
   - What's unclear: Schema evolution policy. Adding a field later requires existing `blocklists.json` parses with new decoder.
   - RESOLVED: **Yes, include `needsRepair: Bool = false` in the Codable schema from day 1.** JSONDecoder tolerates missing fields if `Codable` default is provided via custom `init(from:)`. Better to ship with the schema hole pre-dug.

4. **Do we need a migration strategy for `blocklists.json` schema changes?**
   - What we know: No production data yet, v1.0 not shipped.
   - What's unclear: Internal builds may have schema churn during development.
   - RESOLVED: **No migration framework in Phase 02.** Delete-on-decode-failure is acceptable for MVP. Add `schemaVersion: Int` field in the Codable struct so Phase 5+ can migrate.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + iOS 26 SDK | Build all targets | Assumed ✓ (Phase 1 builds) | 26+ | — |
| `iPhone 17` simulator, iOS 26.2 | `test_sim` + build verification | Assumed ✓ (CLAUDE.md line 17) | UUID `C958163F-49E1-4B46-8A6D-C2056CD25A37` | Any iOS 26 simulator |
| Physical iOS 26 device | FamilyActivityPicker real-data smoke test | **UNKNOWN** — user must confirm availability | — | Mark "Must test on device" in plan human-verify steps; blocks final acceptance, not coding |
| App Group entitlement `group.com.kksw.DeluluDetox` | Persistence | ✓ (already on all 4 targets) | — | — |
| `com.apple.developer.family-controls` entitlement | Picker + tokens | ✓ (already on all 4 targets, sandbox) | — | Distribution requires Apple approval per bundle ID (2–3 week median) — not Phase 02 blocker since Phase 1 handles authorization already; development entitlement sufficient |
| `swift-navigation` SPM 2.8.0+ | Destination enum + bindings | ✓ (already in `project.yml`) | 2.8.0 | — |
| XcodeBuildMCP session | Build/test invocation | ✓ (per CLAUDE.md) | — | — |

**Missing dependencies with no fallback:** None for code work. Physical device is only blocker for FINAL acceptance testing.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (matches Phase 01.1 which established the pattern) |
| Config file | `project.yml` defines `DeluluDetoxTests` target (line 129) |
| Quick run command | `xcodebuild test -project DeluluDetox.xcodeproj -scheme DeluluDetox -destination 'platform=iOS Simulator,id=C958163F-49E1-4B46-8A6D-C2056CD25A37' -skipMacroValidation -only-testing:DeluluDetoxTests/Features/AppSelection` (via XcodeBuildMCP `test_sim` equivalent) |
| Full suite command | `test_sim` (XcodeBuildMCP) against `DeluluDetox` scheme, no `-only-testing` filter |
| Phase gate | 100% of new tests green + existing 14/14 tests still green |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SEL-01 | User selects apps via picker → persists to App Group | Integration (VM + Repo + fake container URL) | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests/testUpdateWithAppSelectionPersistsToFile` | ❌ Wave 0 |
| SEL-01 | HomeViewModel opens picker Destination on chooseAppsTapped | Unit (VM only) | `test_sim -only-testing:DeluluDetoxTests/Features/Home/HomeViewModelTests/testChooseAppsTappedOpensPicker` | ❌ Wave 0 |
| SEL-01 | Picker UI smoke — sheet opens and dismisses (physical device only) | Manual UAT | Human verify on device | ❌ Plan human-verify |
| SEL-02 | Categories selected via picker → TokenRecord with kind=.category created | Unit (Blocklist merging logic) | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistTests/testMergingWithCategorySelectionCreatesRecords` | ❌ Wave 0 |
| SEL-03 | WebDomains selected via picker → TokenRecord with kind=.webDomain created | Unit (Blocklist merging logic) | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistTests/testMergingWithWebDomainSelectionCreatesRecords` | ❌ Wave 0 |
| SEL-04 | Records persist across app relaunches via App Group JSON | Integration | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests/testPersistenceAcrossRepoInstances` | ❌ Wave 0 |
| SEL-04 | `blocklists.json` written atomically to App Group container | Integration (file-level) | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests/testWriteIsAtomicAndJSONValid` | ❌ Wave 0 |
| SEL-05 | TokenRecord retains UUID when token is re-added via picker | Unit (Blocklist merging logic) | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistTests/testMergingPreservesExistingRecordUUIDs` | ❌ Wave 0 |
| SEL-05 | ReconcileBlocklistUseCase invoked on scenePhase == .active | Unit (AppRootViewModel or HomeViewModel) | `test_sim -only-testing:DeluluDetoxTests/Features/Root/AppRootViewModelTests/testSceneActiveCallsReconcile` (extends existing test file) | ❌ Wave 0 |
| SEL-05 | Reconcile emits fresh Blocklist on publisher without touching record IDs | Integration | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests/testReconcileKeepsUUIDs` | ❌ Wave 0 |

**Additional non-requirement tests needed:**

| Purpose | Command | File |
|---------|---------|------|
| BlockedViewModel → appRecords/categoryRecords/webRecords filter correctly | `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection/BlockedViewModelTests/testRecordsFilteredByKind` | ❌ Wave 0 |
| BlockedViewModel → deleteTapped calls RemoveTokenRecordUseCase | `...BlockedViewModelTests/testDeleteTappedInvokesUseCase` | ❌ Wave 0 |
| BlockedViewModel → error from UC sets errorMessage | `...BlockedViewModelTests/testDeleteFailureSetsError` | ❌ Wave 0 |
| HomeViewModel → pickerDismissed invokes UpdateBlocklistUseCase | `...HomeViewModelTests/testPickerDismissedUpdatesBlocklist` | ❌ Wave 0 |
| HomeViewModel → subscribes to publisher on init | `...HomeViewModelTests/testObservesBlocklistUpdates` | ❌ Wave 0 |
| Token round-trip JSON (A1 assumption validation) | `...BlockedTokenCodableTests/testApplicationTokenRoundTrip` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `test_sim -only-testing:DeluluDetoxTests/Features/AppSelection` (plus relevant edited feature, e.g., Home)
- **Per wave merge:** Full `test_sim` against `DeluluDetox` scheme
- **Phase gate:** Full suite green + manual human-verify on physical device before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `DeluluDetoxTests/Features/AppSelection/BlocklistTests.swift` — covers merging semantics (SEL-02/03/05)
- [ ] `DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests.swift` — covers persistence + reconcile (SEL-04/05)
- [ ] `DeluluDetoxTests/Features/AppSelection/BlockedViewModelTests.swift` — covers presentation logic
- [ ] `DeluluDetoxTests/Features/AppSelection/BlockedTokenCodableTests.swift` — **A1 assumption validation, must run first**
- [ ] `DeluluDetoxTests/Features/AppSelection/Mocks/*.swift` — 5 mocks (Repository + 4 UseCases)
- [ ] Extend `DeluluDetoxTests/Features/Home/HomeViewModelTests.swift` — add picker Destination + pickerDismissed cases (file exists, needs expansion)
- [ ] Extend `DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift` — add scenePhase-triggered reconcile test (file exists, needs expansion)
- [ ] Framework install: none — XCTest already in place.

## Security Domain

`security_enforcement` is not explicitly `false` in `.planning/config.json`; including per defaults.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 1 handled Screen Time authorization; Phase 02 relies on that grant. |
| V3 Session Management | no | No user sessions in this phase. |
| V4 Access Control | yes | App Group entitlement gates cross-target file access. Main app = sole writer, extensions (Phase 3+) = read-only consumers. Enforced via file-write code paths only existing in main target. |
| V5 Input Validation | yes | `FamilyActivitySelection` comes from Apple system UI — already validated; but decoded `Blocklist` from disk MUST be validated (malformed JSON → fall back to empty, do not crash). |
| V6 Cryptography | no | No sensitive data in `blocklists.json`; opaque tokens are not user PII. `FileProtectionType.completeUntilFirstUserAuthentication` is sufficient. No hand-rolled crypto. |
| V7 Error Handling / Logging | yes | `os.Logger` with `subsystem: "com.kksw.DeluluDetox"`, category per-feature. No PII logged. Private-data markers: `privacy: .public` only for counts/booleans, NEVER for token bytes or user-picked app identities. |
| V12 Files | yes | Only path used is `containerURL(forSecurityApplicationGroupIdentifier:)`. Never accept external paths. Never `String` concatenation for paths. |

### Known Threat Patterns for {FamilyControls + App Group JSON}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Extension processes spoof main app to overwrite blocklists.json | Spoofing | Only main target has write code paths; extensions ship without write APIs. Enforce in code review + grep in Wave 6 test. |
| Corrupt JSON from interrupted write crashes app on next launch | Tampering / DoS | `.atomic` write (tempfile + rename); decoder failures fall through to `Blocklist.empty()` with log. |
| Stale JSON read while write in-progress shows wrong UI state | Tampering | `.atomic` = POSIX atomic rename; no mid-state visible to reader. Phase 3 will add `NSFileCoordinator` when multi-process reads start. |
| User expects deleted token to stay deleted — rotation bug re-introduces it | Tampering (user trust) | UUID-keyed records — even if token rotates, the DELETION (by UUID) is permanent; merge does not re-introduce records that aren't in the live `FamilyActivitySelection`. |
| Entitlement revoked between sessions | Denial of Service | Phase 01.1 already handles via `AppRootVM.refreshStatus()` on scenePhase active — destination auto-transitions to `.denial`. Phase 02 leans on that mechanism. |
| Logs leak blocked-app identity | Information Disclosure | NEVER log raw tokens or `FamilyActivitySelection` contents. Log counts only (`records.count`). `os.Logger` public markers only for scalars. |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/01.1-architecture-foundation/01.1-07-SUMMARY.md` — final state of post-01.1 architecture
- `.claude/guides/architecture/GUIDE.md` — dependency rules, VM→UC contract
- `.claude/guides/feature-structure/GUIDE.md` — Simple vs Split layout, Common/ rules
- `.claude/guides/dependency-injection/GUIDE.md` — CurrentValueSubject pattern, distributed registration
- `.claude/guides/navigation/GUIDE.md` — Wzorzec A vs B, sheet with item binding
- `DeluluDetox/Sources/Features/Onboarding/Repository/ScreenTimeAuthRepository.swift` — reference Repository pattern
- `DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` — reference Combine + scenePhase pattern
- `DeluluDetox/Sources/Core/DependencyInjection/DIContainer.swift` — container behavior
- `.claude/research/compass_artifact_wf-280372a6-1bd9-4044-95d9-1d65f1d292dc_text_markdown.md` — main app ↔ extensions, persistence, token rotation
- `project.yml` — confirmed entitlements + SPM `swift-navigation 2.8.0`
- `DeluluDetox/DeluluDetox.entitlements` — confirmed App Group + family-controls

### Secondary (MEDIUM confidence)

- Apple Developer Forums thread 723841 — ApplicationToken Codable confirmation
- Apple Developer Forums thread 721973 — PropertyListEncoder bug with `includeEntireCategory`
- pedroesli.com 2023-11-13 — `ApplicationProfile: Codable, Hashable` struct pattern with UUID + ApplicationToken
- Foqos `BlockedProfiles.swift` — production reference for Blocklist data shape (ignoring SwiftData mechanism)
- medium.com/@juliusbrussee Developer Guide — FamilyActivityPicker usage patterns

### Tertiary (LOW confidence)

- Simulator behavior of `FamilyActivityPicker` with empty state — assumption based on Phase 1 denial-path simulator limitation notes; needs first-wave smoke test on device.
- Precise behavior of `FamilyActivityPicker` when wrapped in a custom `NavigationStack` (A2) — needs Wave 0 smoke test.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all frameworks verified via Apple docs + existing codebase post-01.1
- Architecture: HIGH — 1:1 replay of post-01.1 Onboarding pattern, verified against guide files + existing code
- Persistence schema: HIGH — compass artifact + forum threads + pedroesli reference are mutually consistent
- Picker presentation: MEDIUM — Destination-enum + NavigationStack wrapper assumption (A2) needs smoke test
- Reconciliation algorithm: MEDIUM — Phase 02 scope is intentionally minimal (MVP), full rotation handling is Phase 3
- Pitfalls: HIGH — curated from compass artifact, referenced to FB numbers + forum threads
- Testing strategy: HIGH — mirrors post-01.1 test infrastructure exactly

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (30 days — stack is stable; revisit if iOS 26.5 beta lands)

## RESEARCH COMPLETE
