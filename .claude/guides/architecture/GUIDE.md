---
summary: Clean Architecture (MVVM + UseCase + Repository) with SOLID / KISS / DRY
read_when: Designing a new feature, adding a screen, or wiring data flow
complexity: medium
status: active
last_updated: 2026-04-18
---

# Architecture

This app follows **Clean Architecture** with **MVVM** in the presentation layer, **UseCases** in the domain layer, and **Repositories** in the data layer. Apply **SOLID, KISS, DRY** — no layer or abstraction without a concrete reason.

---

## Layers

```
┌─────────────────────────────────────────┐
│ Presentation    View + ViewModel        │  SwiftUI, @Observable
├─────────────────────────────────────────┤
│ Domain          UseCase + Entity        │  Pure Swift, no frameworks
├─────────────────────────────────────────┤
│ Data            Repository + DataSource │  Network, persistence, system APIs
└─────────────────────────────────────────┘
         ▲ dependencies point inward
```

**Rules:**
- Domain knows nothing about Presentation or Data.
- Data implements Domain protocols (dependency inversion).
- View imports SwiftUI; ViewModel does **not** (keeps it testable, reusable).
- Pass data as plain Swift types (struct, enum) — never SwiftUI types.

---

## File layout

```
App/
├── Features/
│   └── <FeatureName>/
│       ├── <FeatureName>View.swift        // SwiftUI view
│       └── <FeatureName>ViewModel.swift   // @Observable model
├── Domain/
│   ├── UseCases/
│   │   └── <Action>UseCase.swift          // Protocol + impl
│   ├── Entities/
│   │   └── <Entity>.swift                 // Plain struct
│   └── Repositories/
│       └── <Entity>Repository.swift       // Protocol only
└── Data/
    ├── Repositories/
    │   └── <Entity>RepositoryImpl.swift   // Impl of domain protocol
    └── Sources/
        ├── Remote/                        // Network clients
        └── Local/                         // Persistence, Keychain, UserDefaults
```

Domain protocols live in `Domain/`. Data implements them — never the other way around.

---

## MVVM (Presentation)

ViewModel holds state, exposes actions, calls UseCases. Use `@Observable` (Swift Observation, iOS 17+).

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

View is dumb: bind to the ViewModel, render state, forward intent.

```swift
struct HomeView: View {
    @Bindable var model: HomeViewModel

    var body: some View {
        List(model.items) { Text($0.title) }
            .task { await model.onAppear() }
    }
}
```

**Rules:**
- No business logic in views.
- ViewModels never import SwiftUI (only `Observation`).
- ViewModels never touch URLSession / Keychain / FileManager directly — always through a UseCase or Repository.

---

## UseCase (Domain)

Each UseCase represents **one business operation**. Callable as a function via `callAsFunction`.

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

**When to add a UseCase vs call the Repository directly:**

```
Plain read-through (one fetch, no rules)?
    └─ UseCase is overkill — ViewModel calls Repository.

Business rule, validation, or combining multiple sources?
    └─ Add UseCase. Rules belong in Domain, not ViewModel.
```

Start without UseCases. Extract when the ViewModel starts orchestrating.

---

## Repository (Data)

Protocol in Domain; implementation in Data. Repository hides **where** data comes from.

```swift
// Domain/Repositories/ItemRepository.swift
protocol ItemRepository {
    func allItems() async throws -> [Item]
    func save(_ item: Item) async throws
}

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

One Repository per **aggregate** — not per endpoint, not per table.

---

## Dependency Injection

**No container framework, no service locator.** Constructor injection via protocols. Compose at the app entry point.

```swift
@main
struct KKSWApp: App {
    private let container = DependencyContainer()
    var body: some Scene {
        WindowGroup { HomeView(model: container.makeHomeViewModel()) }
    }
}

struct DependencyContainer {
    let itemRepository: ItemRepository = ItemRepositoryImpl(...)

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            fetchItems: FetchItemsUseCaseImpl(repository: itemRepository)
        )
    }
}
```

Factory methods on the container, nothing global. Tests pass fakes by constructing their own container or ViewModel directly.

---

## SOLID applied

- **S**ingle Responsibility — one UseCase = one operation; one Repository = one aggregate.
- **O**pen/Closed — add new UseCases; don't modify an existing one to cover a new case.
- **L**iskov — swapping a real impl for a fake must not break callers.
- **I**nterface Segregation — ViewModels depend on narrow protocols (per UseCase), not a fat `DataManager`.
- **D**ependency Inversion — Presentation and Domain depend on abstractions; Data implements them.

---

## KISS & DRY

- **KISS.** No UseCase if the ViewModel simply returns `repository.allItems()`. No Repository if there's only one local source and no reason to abstract yet.
- **DRY.** Extract when the same logic appears 3× across features — not earlier. Two similar blocks beat a premature abstraction.
- **YAGNI.** Add layers when a concrete need appears, not "just in case".

---

## iOS design patterns used

- **Observer** — `@Observable` / `@Bindable` (Swift Observation).
- **Factory** — `DependencyContainer.makeXxx()` builds ViewModels.
- **Decorator** — wrap a Repository for caching or logging without changing callers.
- **Strategy** — swap a UseCase impl for A/B tests or feature flags.
- **State-driven navigation** — Destination enum on the ViewModel; see `.claude/guides/navigation/GUIDE.md`.
- **Avoid:** singletons outside `DependencyContainer`, God objects, service locators.

---

## Decision tree: where does new code go?

```
New screen?
    └─ Features/<Name>/<Name>View.swift + <Name>ViewModel.swift

Business rule or multi-step operation?
    └─ Domain/UseCases/<Action>UseCase.swift

New data source (API, cache, DB)?
    └─ Data/Sources/<Remote|Local>/<Thing>Source.swift
       + Domain/Repositories/<Entity>Repository.swift (protocol)
       + Data/Repositories/<Entity>RepositoryImpl.swift (impl)

Plain data shape shared across layers?
    └─ Domain/Entities/<Entity>.swift
```

---

## Common pitfalls

- **ViewModel importing SwiftUI.** Only `Observation` is OK — never `View`, `Color`, `Binding`, etc.
- **UseCase that just forwards one Repository call.** Delete it, call the Repository from the ViewModel.
- **Repository returning `Result<T, Error>`.** Use `async throws` — idiomatic Swift.
- **Shared mutable state across ViewModels.** Put it in a Repository; consume via `AsyncStream` or async reads.
- **Mocking via subclassing.** Use protocols, not class inheritance.
- **Passing Entities straight into Views.** Usually fine — but if the View needs formatted strings or UI-only fields, map to a display struct in the ViewModel.

---

## Related

- Navigation: `.claude/guides/navigation/GUIDE.md`
- Swift concurrency — invoke the `swift-concurrency:swift-concurrency` skill when touching async/await, actors, or Sendable.
- SwiftUI patterns — invoke the `swiftui-expert:swiftui-expert-skill` skill when designing views.

---

**Last Updated**: 2026-04-18
