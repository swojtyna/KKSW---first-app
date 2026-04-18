---
summary: State-driven navigation using pointfreeco/swift-navigation
read_when: Adding navigation, sheets, alerts, confirmations, or deep links
complexity: medium
status: active
last_updated: 2026-04-18
---

# Navigation

Navigation is **state-driven** using [pointfreeco/swift-navigation](https://github.com/pointfreeco/swift-navigation). The ViewModel owns a `Destination` enum; the View reacts to it. No coordinators, no imperative `.present` calls.

---

## Why state-driven

- One source of truth on the ViewModel.
- `@CasePathable` guarantees at most one destination is active at a time.
- Testable without a running view hierarchy — set state, assert.
- Deep links collapse to "mutate state, the view follows".

---

## Setup (SPM)

Add to `Package.swift` (or `project.yml` for XcodeGen):

```swift
.package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.0.0")
```

Link the **`SwiftUINavigation`** product to the app target.

---

## Core concepts

- **`@CasePathable`** — macro that derives bindings for each enum case. Required on the `Destination` enum.
- **`@Bindable`** — SwiftUI's binding for `@Observable` models. swift-navigation composes cleanly with it.
- **Case-path bindings** — `$model.destination.addItem` yields a `Binding<AddItemViewModel?>`; when the system clears it, swift-navigation resets `destination` to `nil`.

---

## Pattern: `Destination` enum on the ViewModel

```swift
import SwiftUINavigation

@Observable
final class HomeViewModel {
    @CasePathable
    enum Destination {
        case addItem(AddItemViewModel)
        case editItem(EditItemViewModel)
        case confirmDelete(Item)
    }

    var destination: Destination?
    private(set) var items: [Item] = []

    func addTapped() { destination = .addItem(AddItemViewModel()) }
    func editTapped(_ item: Item) { destination = .editItem(EditItemViewModel(item: item)) }
    func deleteTapped(_ item: Item) { destination = .confirmDelete(item) }
}
```

**Rules:**
- All navigation state in a single `Destination?` — `nil` means "no modal open".
- One field, one source of truth. Don't mix multiple optionals (`showAdd: Bool`, `editing: Item?`, …).
- Child ViewModel lives **inside** its enum case — parent owns its lifecycle.

---

## Sheet / fullScreenCover / popover

```swift
struct HomeView: View {
    @Bindable var model: HomeViewModel

    var body: some View {
        List(model.items) { item in
            Button(item.title) { model.editTapped(item) }
        }
        .toolbar { Button("Add") { model.addTapped() } }
        .sheet(item: $model.destination.addItem) { addModel in
            AddItemView(model: addModel)
        }
        .sheet(item: $model.destination.editItem) { editModel in
            EditItemView(model: editModel)
        }
    }
}
```

When the user swipes the sheet away, swift-navigation resets `destination = nil` automatically — no manual cleanup.

Same pattern for `.fullScreenCover(item:)` and `.popover(item:)`.

---

## Alert / confirmation dialog

```swift
.confirmationDialog(
    item: $model.destination.confirmDelete,
    titleVisibility: .visible,
    title: { _ in Text("Delete item?") },
    actions: { item in
        Button("Delete", role: .destructive) { model.confirmDelete(item) }
        Button("Cancel", role: .cancel) {}
    }
)
```

---

## NavigationStack with a path

For drill-down flows, hold the path on a model:

```swift
@Observable
final class AppModel {
    var path: [Route] = []

    @CasePathable
    enum Route: Hashable {
        case itemDetail(Item.ID)
        case settings
    }
}

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack(path: $model.path) {
            HomeView(model: ...)
                .navigationDestination(for: AppModel.Route.self) { route in
                    switch route {
                    case .itemDetail(let id): ItemDetailView(id: id)
                    case .settings:           SettingsView()
                    }
                }
        }
    }
}
```

Deep linking = assigning to `model.path`:

```swift
.onOpenURL { url in
    if let id = parseItemId(from: url) {
        appModel.path = [.itemDetail(id)]
    }
}
```

---

## Decision tree: which presentation?

```
Short side-task with a "done" moment (add, edit, confirm)?
    └─ .sheet(item:)

Drill-down within the same flow?
    └─ NavigationStack + path

Blocking, must-complete flow (onboarding, paywall)?
    └─ .fullScreenCover(item:)

Tiny contextual UI tied to a specific control?
    └─ .popover(item:)

Y/N decision (destructive option)?
    └─ .confirmationDialog(item:) / .alert(item:)
```

---

## Common pitfalls

- **Multiple optional flags per screen** — collapse into one `Destination?` enum.
- **Missing `@CasePathable`** — without it you cannot derive case bindings; the macro is required.
- **Pushing navigation state into Domain or Data** — it's a Presentation concern; keep it on the ViewModel.
- **`@State var showSheet`** in the View — move it to the ViewModel so deep links and tests can drive it.
- **Mixing `NavigationLink(destination:)` with path-based stacks** — pick one style per flow.
- **Child ViewModel created inside `.sheet { … }`** — its lifecycle dies with the closure. Put it in the enum case.

---

## Integration with architecture

- `Destination` lives on the Presentation layer (ViewModel). Domain and Data know nothing about it.
- Child ViewModels are constructed by the parent ViewModel or by `DependencyContainer`. See `.claude/guides/architecture/GUIDE.md`.

---

## Related

- Architecture: `.claude/guides/architecture/GUIDE.md`
- SwiftUI patterns — invoke the `swiftui-expert:swiftui-expert-skill` skill.
- Library docs: https://github.com/pointfreeco/swift-navigation

---

**Last Updated**: 2026-04-18
