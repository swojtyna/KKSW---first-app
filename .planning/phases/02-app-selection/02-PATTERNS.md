# Phase 2: App Selection - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 14 (new + amended)
**Analogs found:** 13 / 14 (Phase 1 Swift sources are on disk and provide strong analogs; one file has no in-repo analog and falls back to research)

## Source corpus used

- **Phase 1 Swift sources on disk** (primary) -- Phase 1 was executed and landed real files under `DeluluDetox/Sources/` and `DeluluDetoxTests/`. These are the authoritative in-repo patterns.
- **`.claude/guides/architecture/GUIDE.md`** -- canonical ViewModel / UseCase / Repository snippets.
- **`.claude/guides/navigation/GUIDE.md`** -- canonical `@CasePathable` `Destination?` snippet (NOTE: Phase 1 did *not* use swift-navigation; Phase 2 is the first phase to actually wire `@CasePathable` + case-path sheet bindings, so the binding pattern is new-to-repo).
- **`.planning/phases/02-app-selection/02-RESEARCH.md`** -- verified SDK signatures, reconcile algorithm, concrete code for Repository / UseCases.
- **`.claude/research/compass_artifact_wf-280372a6...md` §C** -- `SelectionStore` production snippet (the `BlocklistRepositoryImpl` model).
- **`.claude/research/compass_artifact_wf-9f1fb5f8...md`** -- Foqos / Pedro Esli `ApplicationProfile: Codable` pattern (origin of `TokenRecord`).

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `DeluluDetox/Sources/Features/Home/HomeView.swift` *(amended)* | View | request-response | `DeluluDetox/Sources/Features/Home/HomeView.swift` (Phase 1, in-place) | exact -- modify in-place |
| `DeluluDetox/Sources/Features/Home/HomeViewModel.swift` *(amended)* | ViewModel | request-response + foreground event | `DeluluDetox/Sources/Features/Onboarding/OnboardingViewModel.swift` | role-match (closest in-repo `@Observable` VM with UseCase deps, `@MainActor` async intents, logger) |
| `DeluluDetox/Sources/Features/Blocked/BlockedView.swift` *(new)* | View | request-response | `DeluluDetox/Sources/Features/Home/HomeView.swift` (layout + Theme usage) + `AppRootView.swift` (scenePhase observer) | role-match + guide snippet |
| `DeluluDetox/Sources/Domain/Entities/Blocklist.swift` *(new)* | Entity | N/A (value type) | RESEARCH.md §Code Examples "Blocklist entity" (lines 617-647) + Foqos `ApplicationProfile` | research-pattern (no in-repo Entity yet) |
| `DeluluDetox/Sources/Domain/Entities/BlocklistSnapshot.swift` *(new)* | Entity (UI projection) | N/A | no existing repo analog -- derived view-model-facing struct | research-pattern |
| `DeluluDetox/Sources/Domain/Repositories/BlocklistRepository.swift` *(new)* | Repository protocol | CRUD + event stream | `DeluluDetox/Sources/Domain/Repositories/ScreenTimeAuthRepository.swift` | role-match |
| `DeluluDetox/Sources/Domain/UseCases/LoadBlocklistUseCase.swift` *(new)* | UseCase | request-response | `DeluluDetox/Sources/Domain/UseCases/RequestScreenTimeAuthUseCase.swift` | exact structural analog |
| `DeluluDetox/Sources/Domain/UseCases/UpdateBlocklistFromSelectionUseCase.swift` *(new)* | UseCase | CRUD (bulk diff + write) | `RequestScreenTimeAuthUseCase.swift` (skeleton) + RESEARCH.md §Code Examples (body) | skeleton-match + research-body |
| `DeluluDetox/Sources/Domain/UseCases/RemoveTokenFromBlocklistUseCase.swift` *(new)* | UseCase | CRUD (single delete + write) | `RequestScreenTimeAuthUseCase.swift` (skeleton) | skeleton-match |
| `DeluluDetox/Sources/Domain/UseCases/ReconcileBlocklistUseCase.swift` *(new)* | UseCase | transform + write | `RequestScreenTimeAuthUseCase.swift` (skeleton) + RESEARCH.md §Code Examples (body) | skeleton-match + research-body |
| `DeluluDetox/Sources/Data/Repositories/BlocklistRepositoryImpl.swift` *(new)* | Repository impl | file I/O (App Group JSON + NSFileCoordinator) | `DeluluDetox/Sources/Data/Repositories/ScreenTimeAuthRepositoryImpl.swift` (DI + `@unchecked Sendable` shape) + `compass_artifact_wf-280372a6` §C `SelectionStore` (full I/O body) | skeleton-match + external-reference-body |
| `DeluluDetox/Sources/App/DependencyContainer.swift` *(amended)* | Config (DI factory) | N/A | `DeluluDetox/Sources/App/DependencyContainer.swift` (Phase 1, in-place) | exact -- extend in-place |
| `project.yml` *(amended)* | Config (build) | N/A | `project.yml` (Phase 1, in-place) | exact -- extend in-place |
| `DeluluDetoxTests/Blocklist/*.swift` + `DeluluDetoxTests/Fixtures/SampleFamilyActivitySelection.json` *(new)* | Test + fixture | N/A | `DeluluDetoxTests/OnboardingViewModelTests.swift` + `DeluluDetoxTests/Mocks/MockScreenTimeAuthRepository.swift` | role-match for VM/UseCase tests; **no analog** for App-Group integration test |

---

## Pattern Assignments

### `HomeView.swift` (View, amended)

**Analog:** `DeluluDetox/Sources/Features/Home/HomeView.swift` (current Phase 1 file, lines 1-64). The empty-hero layout stays verbatim; Phase 2 adds a branch + sheet wiring around it.

**Preserve verbatim** (Phase 1 lines 9-49) -- empty-state hero (SF Symbol + headline + body + primary button). Only **copy is re-localized to Polish** per UI-SPEC §Copywriting:

```swift
// Existing layout skeleton to keep (HomeView.swift:9-49)
Image(systemName: "apps.iphone")
    .font(.system(size: 56))
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(Theme.tertiaryText)

Text("Jeszcze żadnych wrogów")               // was: "No Apps Blocked Yet"
    .font(.title2).bold()
    .foregroundStyle(Theme.primaryText)

Text("Wybierz aplikacje, które kradną Ci czas. Resztą zajmie się DeluluDetox.")
    .font(.body).foregroundStyle(Theme.secondaryText)

Button { model.chooseAppsTapped() } label: {
    Text("Wybierz aplikacje do blokady")     // was: "Choose Apps to Block"
}
.buttonStyle(.borderedProminent).tint(Theme.accent)
.clipShape(RoundedRectangle(cornerRadius: 12))
```

**Pattern to add -- branching + scenePhase + sheet** (source: RESEARCH.md §View wiring lines 528-551; scenePhase observer source: `AppRootView.swift:5-25`):

```swift
import SwiftUI
import SwiftUINavigation       // NEW import -- first use of swift-navigation in this repo
import FamilyControls

struct HomeView: View {
    @Bindable var model: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.snapshot.isEmpty {
                // ... existing empty-hero VStack unchanged ...
            } else {
                BlockedView(
                    snapshot: model.snapshot,
                    onRemove: { id in Task { await model.removeTapped(recordId: id) } },
                    onChangeSelection: { model.chooseAppsTapped() }
                )
            }
        }
        .task { await model.onAppear() }
        .onChange(of: scenePhase) { _, new in
            if new == .active { Task { await model.onForeground() } }
        }
        .sheet(item: $model.destination.picker) { $selection in
            FamilyActivityPicker(selection: $selection)
        }
    }
}
```

**scenePhase observer copy-paste source:** `AppRootView.swift:5-25` -- exact same `.onChange(of: scenePhase)` shape as Phase 1's auth re-check, just a different callback.

---

### `HomeViewModel.swift` (ViewModel, amended)

**Analog:** `DeluluDetox/Sources/Features/Onboarding/OnboardingViewModel.swift` (lines 1-33). This is the only non-trivial `@Observable` VM in-repo; it already demonstrates: `@Observable`, `Observation` + `os` imports (no SwiftUI), private-let UseCase injection, `@MainActor` async intent method, `private(set)` state, logger subsystem `com.kksw.DeluluDetox`.

**Imports pattern** (from `OnboardingViewModel.swift:1-2`, extended for Phase 2 per RESEARCH.md Gap 5):

```swift
import Observation
import os
import FamilyControls          // value types only (FamilyActivitySelection); safe per Gap 5
import SwiftUINavigation       // for @CasePathable
// NEVER import SwiftUI  -- CLAUDE.md rule, enforced in Phase 1
```

**State + DI shape** (structural copy from `OnboardingViewModel.swift:4-17`):

```swift
@Observable
final class HomeViewModel {
    private(set) var snapshot: BlocklistSnapshot = .empty
    var destination: Destination?                    // replaces Phase 1's empty VM

    private let loadBlocklist:    LoadBlocklistUseCase
    private let updateBlocklist:  UpdateBlocklistFromSelectionUseCase
    private let removeToken:      RemoveTokenFromBlocklistUseCase
    private let reconcile:        ReconcileBlocklistUseCase
    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "Home")

    init(
        loadBlocklist: LoadBlocklistUseCase,
        updateBlocklist: UpdateBlocklistFromSelectionUseCase,
        removeToken: RemoveTokenFromBlocklistUseCase,
        reconcile: ReconcileBlocklistUseCase
    ) { /* assign */ }
}
```

**Destination enum** (source: Navigation GUIDE §Pattern `Destination` enum lines 44-65 + RESEARCH.md §HomeViewModel Destination shape lines 457-463):

```swift
@CasePathable
enum Destination {
    case picker(FamilyActivitySelection)
    case errorAlert(ErrorAlertState)      // simple wrapper value type for the alert copy
}
```

**Async intent + error logging pattern** (structural copy from `OnboardingViewModel.swift:19-32`):

```swift
@MainActor
func removeTapped(recordId: UUID) async {
    do {
        try await removeToken(recordId: recordId)
        await refresh()
    } catch {
        logger.error("Remove failed: \(error.localizedDescription, privacy: .public)")
    }
}
```

**Dismissal-commit didSet** (source: RESEARCH.md §Binding the dismissal-commit lines 515-524) -- this pattern is new-to-repo:

```swift
var destination: Destination? {
    didSet {
        if case .picker(let finalSelection) = oldValue, destination == nil {
            Task { await pickerDismissed(finalSelection) }
        }
    }
}
```

**Shared rules from `OnboardingViewModel.swift`:**
- `private(set)` on state, `var` only on `destination` (bindable).
- Logger subsystem MUST be `"com.kksw.DeluluDetox"`; category is per-feature (`"Home"`).
- Intents are `@MainActor` and `async`; catch errors and log them, don't re-throw into the UI layer.

---

### `BlockedView.swift` (View, new)

**Analog:** `HomeView.swift` (for layout grammar: `VStack`-based, `Theme.*` colors, `RoundedRectangle(cornerRadius: 12)` primary button) + UI-SPEC §Screen 3 (for the `List(.insetGrouped)` + swipe + `safeAreaInset` structure, which is new-to-repo).

**Imports pattern** (copy from `HomeView.swift:1` + add FamilyControls for `Label(token)`):

```swift
import SwiftUI
import FamilyControls          // for Label(token) — View-layer only
```

**Primary button styling -- reuse verbatim from `HomeView.swift:35-48`:**

```swift
Button { onChangeSelection() } label: {
    Text("Zmień wybór")
        .font(.body).bold()
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).frame(height: 50)
}
.buttonStyle(.borderedProminent)
.tint(Theme.accent)
.clipShape(RoundedRectangle(cornerRadius: 12))
.padding(.horizontal, 24)
```

**Token row -- new-to-repo pattern** (source: UI-SPEC §Screen 3 + RESEARCH.md Gap 4 verified SDK signature lines 218-227):

```swift
// Inside List { Section(...) { ForEach(records) { r in ... } } }
Label(record.applicationToken)        // Apple-rendered; NEVER .font(...)/.foregroundStyle(...)
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) { onRemove(record.id) } label: {
            Label("Usuń", systemImage: "trash")
        }
    }
```

**safeAreaInset footer -- new-to-repo pattern** (source: UI-SPEC §Screen 3 point 5):

```swift
.safeAreaInset(edge: .bottom) {
    // primary button block from HomeView:35-48 (see above)
}
```

**Loading + error states -- structural copy from `OnboardingView.swift:38-51`:** the `Group { if isLoading { ProgressView().tint(.white) } else { Text(...) } }` grammar already exists in-repo; reuse the `ProgressView().tint(Theme.accent)` shape per UI-SPEC §Screen 3 point 6.

---

### `Blocklist.swift` (Entity, new)

**Analog:** no Domain Entity file exists in-repo yet. Use RESEARCH.md §Code Examples lines 617-647 verbatim. Origin: Foqos / Pedro Esli `ApplicationProfile: Codable, Hashable` pattern cited in `compass_artifact_wf-9f1fb5f8`.

**Imports + core shape** (RESEARCH.md lines 620-632):

```swift
import Foundation
import FamilyControls
import ManagedSettings

struct Blocklist: Codable, Equatable {
    var id: UUID
    var name: String?
    var records: [TokenRecord]
    var selection: FamilyActivitySelection

    static let empty = Blocklist(id: UUID(), name: nil, records: [],
                                 selection: FamilyActivitySelection())
}
```

**TokenRecord sum-type shape** (RESEARCH.md lines 634-646):

```swift
struct TokenRecord: Codable, Equatable, Identifiable {
    let id: UUID                              // own UUID -- not derived from token (SEL-05)
    let kind: Kind
    var token: TokenPayload

    enum Kind: String, Codable { case application, category, webDomain }

    enum TokenPayload: Codable, Equatable, Hashable {
        case application(ApplicationToken)
        case category(ActivityCategoryToken)
        case webDomain(WebDomainToken)
    }
}
```

**Hard rules:**
- `id: UUID` is the primary key, NEVER the token bytes (RESEARCH.md §Don't Hand-Roll line 564; Pitfall in compass_artifact_wf-280372a6 §E.1).
- Encode with `JSONEncoder`, never `PropertyListEncoder` (forum 721973).
- `TokenPayload` must be `Hashable` so `UpdateBlocklistFromSelectionUseCase` can key an `existingByToken` dictionary (RESEARCH.md §Code Examples line 757).

---

### `BlocklistSnapshot.swift` (Entity, new, UI projection)

**Analog:** no in-repo analog; pure helper struct. Purpose per RESEARCH.md §Gap 8 line 390: "UI-facing projection (grouped sections, stable sort) -- the VM reads `Blocklist` from the UseCase and maps to `BlocklistSnapshot` for the View."

**Sketch:**

```swift
import Foundation
import FamilyControls

struct BlocklistSnapshot: Equatable {
    var apps: [TokenRecord]
    var categories: [TokenRecord]
    var webDomains: [TokenRecord]
    var selection: FamilyActivitySelection      // used to pre-seed the picker

    var isEmpty: Bool { apps.isEmpty && categories.isEmpty && webDomains.isEmpty }
    static let empty = BlocklistSnapshot(apps: [], categories: [], webDomains: [],
                                         selection: FamilyActivitySelection())

    init(from blocklist: Blocklist) {
        self.apps       = blocklist.records.filter { $0.kind == .application }.sorted { $0.id.uuidString < $1.id.uuidString }
        self.categories = blocklist.records.filter { $0.kind == .category }.sorted    { $0.id.uuidString < $1.id.uuidString }
        self.webDomains = blocklist.records.filter { $0.kind == .webDomain }.sorted   { $0.id.uuidString < $1.id.uuidString }
        self.selection  = blocklist.selection
    }
}
```

Sort key is the record UUID: opaque, stable, does not leak privacy, independent of token rotation.

---

### `BlocklistRepository.swift` (Repository protocol, new)

**Analog:** `DeluluDetox/Sources/Domain/Repositories/ScreenTimeAuthRepository.swift` (lines 1-6).

**Existing shape to mirror** (`ScreenTimeAuthRepository.swift:1-6`):

```swift
import FamilyControls

protocol ScreenTimeAuthRepository: Sendable {
    var authorizationStatus: AuthorizationStatus { get }
    func requestAuthorization() async throws
}
```

**Target pattern** (same grammar -- `Sendable` protocol, `async throws` methods, imports only what's necessary):

```swift
import Foundation
import FamilyControls

protocol BlocklistRepository: Sendable {
    func load() async throws -> Blocklist
    func save(_ blocklist: Blocklist) async throws
    /// Cross-process change stream. Phase 2 publishes; Phase 3+ extensions subscribe.
    func changes() -> AsyncStream<Void>
}
```

**Rules from Phase 1 analog:**
- Protocol is `Sendable`.
- Imports are minimal -- `Foundation` + `FamilyControls`; never SwiftUI, never Observation.
- No `Result<T, Error>` -- `async throws` per architecture GUIDE line 251.

---

### `LoadBlocklistUseCase.swift` (UseCase, new)

**Analog:** `DeluluDetox/Sources/Domain/UseCases/RequestScreenTimeAuthUseCase.swift` (lines 1-18) -- **exact structural analog**.

**Phase 1 reference file verbatim:**

```swift
// RequestScreenTimeAuthUseCase.swift:1-18
import FamilyControls

protocol RequestScreenTimeAuthUseCase: Sendable {
    func callAsFunction() async throws
}

final class RequestScreenTimeAuthUseCaseImpl: RequestScreenTimeAuthUseCase {
    private let repository: ScreenTimeAuthRepository
    init(repository: ScreenTimeAuthRepository) { self.repository = repository }
    func callAsFunction() async throws {
        try await repository.requestAuthorization()
    }
}
```

**Target shape (copy-paste with renames):**

```swift
import Foundation

protocol LoadBlocklistUseCase: Sendable {
    func callAsFunction() async throws -> Blocklist
}

final class LoadBlocklistUseCaseImpl: LoadBlocklistUseCase {
    private let repo: BlocklistRepository
    init(repo: BlocklistRepository) { self.repo = repo }
    func callAsFunction() async throws -> Blocklist {
        do { return try await repo.load() }
        catch { return .empty }      // missing file == empty; first launch
    }
}
```

Keeps the Phase 1 convention: protocol `Sendable`, `callAsFunction`, one-line body, constructor-injected dependency.

---

### `UpdateBlocklistFromSelectionUseCase.swift` (UseCase, new)

**Skeleton analog:** `RequestScreenTimeAuthUseCase.swift` (same protocol/impl split + `callAsFunction`).

**Body analog:** RESEARCH.md §Code Examples lines 740-778 (verified against SDK signatures in Gap 1). Copy verbatim; this is the diff that preserves UUIDs across picker commits:

```swift
// body highlights -- see RESEARCH.md lines 753-776 for full source
var existingByToken: [TokenRecord.TokenPayload: TokenRecord] = [:]
for r in blocklist.records { existingByToken[r.token] = r }

var next: [TokenRecord] = []
for t in newSelection.applicationTokens {
    let key: TokenRecord.TokenPayload = .application(t)
    next.append(existingByToken[key] ?? TokenRecord(id: UUID(), kind: .application, token: key))
}
// ... repeat for categoryTokens / webDomainTokens ...

blocklist.records = next
blocklist.selection = newSelection
try await repo.save(blocklist)
```

**Critical:** the same atomic write MUST update both `records` and `selection` -- splitting them causes Pitfall 1 (picker "remembers" deleted items on re-open, RESEARCH.md line 572).

---

### `RemoveTokenFromBlocklistUseCase.swift` (UseCase, new)

**Skeleton analog:** `RequestScreenTimeAuthUseCase.swift`.

**Body -- derive from RESEARCH.md §Gap 6 row 3 + Pitfall 1:**

```swift
protocol RemoveTokenFromBlocklistUseCase: Sendable {
    func callAsFunction(recordId: UUID) async throws
}

final class RemoveTokenFromBlocklistUseCaseImpl: RemoveTokenFromBlocklistUseCase {
    private let repo: BlocklistRepository
    init(repo: BlocklistRepository) { self.repo = repo }

    func callAsFunction(recordId: UUID) async throws {
        var blocklist = try await repo.load()
        guard let removed = blocklist.records.first(where: { $0.id == recordId }) else { return }
        blocklist.records.removeAll { $0.id == recordId }

        // KEEP selection IN SYNC (Pitfall 1)
        switch removed.token {
        case .application(let t): blocklist.selection.applicationTokens.remove(t)
        case .category(let t):    blocklist.selection.categoryTokens.remove(t)
        case .webDomain(let t):   blocklist.selection.webDomainTokens.remove(t)
        }
        try await repo.save(blocklist)
    }
}
```

---

### `ReconcileBlocklistUseCase.swift` (UseCase, new)

**Skeleton analog:** `RequestScreenTimeAuthUseCase.swift`.

**Body analog:** RESEARCH.md §Code Examples lines 783-828 (verbatim). Algorithm spec: RESEARCH.md §Gap 3 lines 180-201. Copy the two-phase (forward rewrite + reverse pickup) loop exactly. Called from `HomeViewModel.onForeground()` with a hard `await` (Pitfall 5).

---

### `BlocklistRepositoryImpl.swift` (Repository impl, new)

**Skeleton analog:** `DeluluDetox/Sources/Data/Repositories/ScreenTimeAuthRepositoryImpl.swift` (lines 1-11) -- class declaration, `@unchecked Sendable` conformance, no stored state except lazy system access:

```swift
// ScreenTimeAuthRepositoryImpl.swift:1-11 (reference shape)
import FamilyControls

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository, @unchecked Sendable {
    var authorizationStatus: AuthorizationStatus {
        AuthorizationCenter.shared.authorizationStatus
    }
    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}
```

**Body analog:** `compass_artifact_wf-280372a6...md` §C `SelectionStore` (lines 99-217 of that artifact) -- the production-grade JSON + NSFileCoordinator + Darwin recipe. RESEARCH.md §Code Examples lines 651-736 already adapts it to `Blocklist`; copy that near-verbatim.

**Imports + constants pattern** (RESEARCH.md lines 653-665):

```swift
import Foundation
import FamilyControls
import os

final class BlocklistRepositoryImpl: BlocklistRepository, @unchecked Sendable {
    private static let log = Logger(subsystem: "com.kksw.DeluluDetox",
                                    category: "BlocklistRepository")
    private static let appGroupID     = "group.com.kksw.DeluluDetox"
    private static let fileName       = "blocklists.v1.json"
    private static let darwinChangeName = "com.kksw.DeluluDetox.blocklists.changed" as CFString
    // ... fileURL computed property (RESEARCH.md lines 664-672)
}
```

**Write recipe -- MUST copy this exactly** (RESEARCH.md lines 698-718 / compass_artifact_wf-280372a6 lines 133-155):

```swift
func save(_ blocklist: Blocklist) async throws {
    let url = try fileURL
    let data = try JSONEncoder().encode(blocklist)        // NEVER PropertyListEncoder -- forum 721973
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordErr: NSError?
    var writeErr: Error?

    coordinator.coordinate(writingItemAt: url,
                           options: .forReplacing,
                           error: &coordErr) { coordURL in
        do {
            try data.write(to: coordURL,
                           options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { writeErr = error }
    }
    if let e = coordErr { throw BlocklistRepositoryError.coordination(e) }
    if let e = writeErr { throw BlocklistRepositoryError.writeFailed(e) }

    Self.log.info("Blocklist saved, records=\(blocklist.records.count)")
    postChangeNotification()
}
```

**Read recipe mirrors it** -- see RESEARCH.md lines 674-696 for the `coordinate(readingItemAt:)` variant with fall-through to `.empty` and corrupted-file logging.

**Darwin post** (RESEARCH.md lines 722-727 / compass artifact lines 203-208):

```swift
private func postChangeNotification() {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(Self.darwinChangeName),
        nil, nil, true)
}
```

**`changes()` AsyncStream**: RESEARCH.md §Code Examples line 720 leaves this as `/* Phase 3 wires consumers */`. Phase 2 can ship a minimal observer using `CFNotificationCenterAddObserver` wrapped in `AsyncStream.makeStream(of: Void.self)` -- pattern is the `DarwinObserver` helper at compass_artifact_wf-280372a6 lines 220+ (cited in research but not copied into RESEARCH.md; read that artifact's §C tail if you need the full helper).

**Hard rules (from research + Phase 1 precedent):**
- Single writer = main app; extensions only read (D-02).
- Always wrap writes in `NSFileCoordinator` (Pitfall 3).
- File name is `blocklists.v1.json` -- the `v1` allows future schema migration without breaking extensions.
- App Group ID `group.com.kksw.DeluluDetox` already exists in all four `.entitlements` files (verified in `project.yml:55-58, 79-81, 101-104, 124-127`).

---

### `DependencyContainer.swift` (config, amended in-place)

**Analog:** `DeluluDetox/Sources/App/DependencyContainer.swift` (current, lines 1-35).

**Existing shape to preserve** (lines 3-10):

```swift
struct DependencyContainer {
    let screenTimeAuthRepository: ScreenTimeAuthRepository

    init(screenTimeAuthRepository: ScreenTimeAuthRepository = ScreenTimeAuthRepositoryImpl()) {
        self.screenTimeAuthRepository = screenTimeAuthRepository
    }
    // ... factory methods
}
```

**Add, following the same grammar:**

```swift
struct DependencyContainer {
    let screenTimeAuthRepository: ScreenTimeAuthRepository
    let blocklistRepository: BlocklistRepository           // NEW

    init(
        screenTimeAuthRepository: ScreenTimeAuthRepository = ScreenTimeAuthRepositoryImpl(),
        blocklistRepository: BlocklistRepository = BlocklistRepositoryImpl()        // NEW
    ) {
        self.screenTimeAuthRepository = screenTimeAuthRepository
        self.blocklistRepository = blocklistRepository
    }

    // NEW factory methods (mirror makeRequestScreenTimeAuthUseCase shape)
    func makeLoadBlocklistUseCase() -> LoadBlocklistUseCase {
        LoadBlocklistUseCaseImpl(repo: blocklistRepository)
    }
    // ... makeUpdateBlocklistFromSelectionUseCase, makeRemoveTokenFromBlocklistUseCase,
    //     makeReconcileBlocklistUseCase

    // AMENDED -- HomeViewModel now takes four UseCases
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            loadBlocklist:   makeLoadBlocklistUseCase(),
            updateBlocklist: makeUpdateBlocklistFromSelectionUseCase(),
            removeToken:     makeRemoveTokenFromBlocklistUseCase(),
            reconcile:       makeReconcileBlocklistUseCase()
        )
    }
}
```

Follow Phase 1's pattern: default-arg concrete in `init`, tests substitute a fake by calling `init(blocklistRepository: FakeRepo())`. No singletons, no globals (architecture GUIDE lines 170-195).

---

### `project.yml` (config, amended in-place)

**Analog:** existing `project.yml` (current, lines 1-141).

**Existing `packages` block to preserve** (lines 18-21):

```yaml
packages:
  swift-navigation:
    url: https://github.com/pointfreeco/swift-navigation
    from: "2.8.0"
```

Already declared in Phase 1; Phase 2 only needs to **link** it to the main target. Existing `dependencies:` block at lines 44-52 already does this:

```yaml
    dependencies:
      # ... extension embeds ...
      - package: swift-navigation
        product: SwiftUINavigation
```

**No net-new project.yml changes required for Phase 2** unless the test target needs `SwiftUINavigation` for `@CasePathable` tests -- if so, add to `DeluluDetoxTests.dependencies`:

```yaml
  DeluluDetoxTests:
    # ... existing ...
    dependencies:
      - target: DeluluDetox
      - package: swift-navigation              # only if tests use CasePathable directly
        product: SwiftUINavigation
```

**App Group entitlement on the main target** (lines 53-58) is already correct; the four `.entitlements` files on disk (main + 3 extensions) all declare `group.com.kksw.DeluluDetox` -- verified by scanning `project.yml:56,80,103,126`.

**Regen rule:** always edit `project.yml` then run `xcodegen generate` (CLAUDE.md §XcodeGen). Never touch `.xcodeproj`.

---

### `DeluluDetoxTests/Blocklist/*.swift` (tests, new)

**Analog for VM / UseCase tests:** `DeluluDetoxTests/OnboardingViewModelTests.swift` (lines 1-50) + `DeluluDetoxTests/Mocks/MockScreenTimeAuthRepository.swift` (lines 1-20).

**Imports + test class pattern** (`OnboardingViewModelTests.swift:1-4`):

```swift
import XCTest
@testable import DeluluDetox

@MainActor
final class HomeViewModelTests: XCTestCase { /* ... */ }
```

**Mock shape -- copy-paste from `MockScreenTimeAuthRepository.swift:1-20`:**

```swift
import FamilyControls
@testable import DeluluDetox

final class MockBlocklistRepository: BlocklistRepository, @unchecked Sendable {
    var stubbedBlocklist: Blocklist = .empty
    var saveCallCount = 0
    var saveError: Error?
    var loadError: Error?

    func load() async throws -> Blocklist {
        if let e = loadError { throw e }
        return stubbedBlocklist
    }
    func save(_ blocklist: Blocklist) async throws {
        saveCallCount += 1
        if let e = saveError { throw e }
        stubbedBlocklist = blocklist
    }
    func changes() -> AsyncStream<Void> { AsyncStream { _ in } }
}
```

**Test shape -- async VM test** (`OnboardingViewModelTests.swift:6-20`):

```swift
func testRemoveTokenUpdatesSnapshot() async {
    let mockRepo = MockBlocklistRepository()
    mockRepo.stubbedBlocklist = /* pre-seeded blocklist */
    let vm = HomeViewModel(
        loadBlocklist:   LoadBlocklistUseCaseImpl(repo: mockRepo),
        updateBlocklist: UpdateBlocklistFromSelectionUseCaseImpl(repo: mockRepo),
        removeToken:     RemoveTokenFromBlocklistUseCaseImpl(repo: mockRepo),
        reconcile:       ReconcileBlocklistUseCaseImpl(repo: mockRepo)
    )
    await vm.onAppear()
    await vm.removeTapped(recordId: someId)
    XCTAssertEqual(mockRepo.saveCallCount, 1)
    XCTAssertFalse(vm.snapshot.apps.contains { $0.id == someId })
}
```

**BlocklistRepositoryImpl integration test -- no in-repo analog.** Strategy from RESEARCH.md Gap 7 lines 332-333: inject a temp directory (parameterise the container URL) or use `FileManager.default.temporaryDirectory`. Write → read → assert round-trip. No existing test in the repo does file I/O.

**Fixture:** `DeluluDetoxTests/Fixtures/SampleFamilyActivitySelection.json` is captured **on-device** (simulator cannot produce real tokens -- RESEARCH.md Gap 7 line 344). Phase 1 VALIDATION.md should indicate whether an on-device capture ran; if not, the fixture must be generated during Phase 2 human-verification before UseCase tests that exercise real token Sets can run. Alternative: seed `FamilyActivitySelection()` (empty) and test only the empty-branch logic on CI.

---

## Shared Patterns

### ViewModel grammar
**Source:** `OnboardingViewModel.swift` (all 33 lines) -- the in-repo gold standard.
**Apply to:** `HomeViewModel` (amended in Phase 2). Any future Phase 2 VM split (e.g. a dedicated `BlockedViewModel`) follows the same shape.

- `import Observation` + `import os`; add `FamilyControls` only for value types; **never** `import SwiftUI`.
- `@Observable final class ...ViewModel`
- `private(set) var` for read-only state; plain `var` only for bindable fields (`destination`).
- Constructor injection of protocol-typed UseCases.
- `@MainActor` on async intent methods.
- `private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "<Feature>")`.
- Catch errors inside the intent, log via `logger.error("... \(error.localizedDescription, privacy: .public)")`, surface to the view via `private(set) var error: String?` or a `Destination.errorAlert` case.

### View grammar
**Source:** `HomeView.swift`, `OnboardingView.swift`, `DenialView.swift` (all Phase 1 views share the same skeleton).
**Apply to:** `BlockedView.swift` (new), `HomeView.swift` (amended).

- `import SwiftUI` only; `import FamilyControls` additionally for `Label(token)` constructors.
- `@Bindable var model: <Feature>ViewModel` (or pass the concrete data + closure handlers as `BlockedView` does to stay reusable).
- All colors via `Theme.*`; no raw `Color(...)` literals (`Theme.swift` currently exposes `accent`, `background`, `primaryText`, `secondaryText`, `tertiaryText` -- extend it in Phase 2 only if UI-SPEC's suggested `Theme.groupedBackground` / `Theme.warning` are actually needed).
- Primary buttons: 50pt height, `.buttonStyle(.borderedProminent)`, `.tint(Theme.accent)`, `.clipShape(RoundedRectangle(cornerRadius: 12))` -- verbatim from `HomeView.swift:42-47`, `OnboardingView.swift:48-54`, `DenialView.swift:48-54`.
- Include a `#Preview` block -- all three Phase 1 views do.

### UseCase grammar
**Source:** `RequestScreenTimeAuthUseCase.swift` (all 18 lines).
**Apply to:** all four new Phase 2 UseCases.

```swift
protocol <Action>UseCase: Sendable {
    func callAsFunction(<args>) async throws [-> <Return>]
}

final class <Action>UseCaseImpl: <Action>UseCase {
    private let repo: BlocklistRepository
    init(repo: BlocklistRepository) { self.repo = repo }
    func callAsFunction(<args>) async throws [-> <Return>] { /* body */ }
}
```

### Repository grammar
**Source:** `ScreenTimeAuthRepository.swift` (protocol, 6 lines) + `ScreenTimeAuthRepositoryImpl.swift` (impl, 11 lines).
**Apply to:** `BlocklistRepository` / `BlocklistRepositoryImpl`.

- Protocol is `: Sendable`; methods are `async throws`.
- Impl is `final class ... : Protocol, @unchecked Sendable` (Phase 1 chose `@unchecked Sendable` explicitly -- follow that; Swift 6.2 strict concurrency otherwise trips on system-API properties).
- Impl hides persistence primitives (`NSFileCoordinator`, `FileManager`, `JSONEncoder`, `CFNotificationCenter`) entirely behind the protocol.

### Logging
**Source:** `OnboardingViewModel.swift:12`, `DenialViewModel.swift:11`.
**Apply to:** every new VM, UseCase-with-side-effects, and Repository impl.

```swift
private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "<Feature>")
logger.info("...")
logger.error("... \(error.localizedDescription, privacy: .public)")
```

Subsystem is invariant across the main-app module; only `category` varies.

### Testing grammar
**Source:** `OnboardingViewModelTests.swift` + `MockScreenTimeAuthRepository.swift`.
**Apply to:** all Phase 2 VM and UseCase tests.

- Class: `@MainActor final class ...Tests: XCTestCase`.
- `@testable import DeluluDetox`.
- Mocks conform `@unchecked Sendable` to the Domain protocol, expose `stubbedX` / `xError` / `xCallCount` knobs.
- Tests build the real VM with the real UseCase impls, injecting only the mock Repository -- this matches Phase 1's approach (`OnboardingViewModelTests.swift:7-14`) and gives deep coverage.

### App Group + file I/O
**Source:** `compass_artifact_wf-280372a6-...` §C (`SelectionStore`) -- external production snippet.
**Apply to:** `BlocklistRepositoryImpl.swift` only. Do not hand-roll `Data.write` without `NSFileCoordinator` (Pitfall 3). Copy the §C recipe, swap the filename + Darwin name, keep the protection flags (`.atomic`, `.completeFileProtectionUntilFirstUserAuthentication`).

---

## No Analog Found

| File | Role | Data Flow | Fallback |
|---|---|---|---|
| `DeluluDetoxTests/Blocklist/BlocklistRepositoryImplTests.swift` | Integration test | file I/O | No Phase 1 test touches `FileManager` / `NSFileCoordinator`. Use RESEARCH.md Gap 7 guidance (temp-dir injection, round-trip assertion). The planner should either parameterise `BlocklistRepositoryImpl` to accept an injected base URL, or wrap `containerURL(for:)` behind a `FileSystemSource` protocol for testability. |

Also flagged for planner attention (not a missing analog, but a first-in-repo idiom):
- **`@CasePathable` case-path sheet binding** (`$model.destination.picker` → `Binding<FamilyActivitySelection>`). Phase 1 declared `swift-navigation` as an SPM dep but did **not** use it -- `AppRootViewModel.Screen` is a plain enum. Phase 2 is the first live consumer. Follow `.claude/guides/navigation/GUIDE.md` lines 76-97 verbatim.
- **`didSet` on `destination`** to detect the dismissal-commit transition (RESEARCH.md lines 515-524). No Phase 1 code uses a `didSet` observer on an `@Observable` property; the planner should call this out in the plan so the executor does not attempt a SwiftUI `.onChange(of:)` on the view side instead.

---

## Metadata

**Analog search scope:**
- `DeluluDetox/Sources/**/*.swift` (14 files)
- `DeluluDetoxTests/**/*.swift` (4 files)
- `Extensions/**/*.swift` (3 files, not directly relevant to Phase 2 but inspected for shared logging / entitlements conventions)
- `.claude/guides/{architecture,navigation}/GUIDE.md`
- `.planning/phases/01-foundation-onboarding/01-PATTERNS.md`
- `.planning/phases/02-app-selection/{02-CONTEXT,02-RESEARCH,02-UI-SPEC}.md`
- `.claude/research/compass_artifact_wf-280372a6-...md` §C (SelectionStore snippet)
- `project.yml`

**Files scanned:** 21 Swift files + 1 YAML + 3 markdown guides + 2 research artifacts.

**Pattern extraction date:** 2026-04-18.

**Phase 1 status:** executed -- real Swift sources on disk at the paths cited above. Pattern map is **not thin**; every Phase 2 file except the App-Group integration test has a solid in-repo skeleton analog, with bodies sourced from verified research snippets.
