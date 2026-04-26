# String Architecture

Complete reference for where localized strings belong in this project.

---

## Single-File Architecture

This project uses one `Localizable.xcstrings` for the entire main app target (no per-feature files). All keys share a single namespace, making prefix-based naming critical to avoid collisions.

```
DeluluDetox/
└── Resources/
    └── Localizable.xcstrings    <-- ALL app translations
```

---

## Layer Rule: Where Translations Belong

**Translations belong ONLY in View and ViewModel layers.**

```
Layer           | Can Use Localized Strings?
----------------|---------------------------
View            | YES — Text("key"), Button("key"), alert titles
ViewModel       | YES — String(localized:) for display logic
Domain/UseCase  | NO — Returns domain models, not strings
Repository      | NO (see exception below)
```

### Why This Rule Exists

- **Domain layer** deals with business logic and data models — language-agnostic
- **Repository layer** maps storage/API data to domain models — no presentation concerns
- **ViewModel** transforms domain data into displayable strings
- **View** displays localized content directly

### Correct Pattern

```swift
// Domain model — no localization
struct SessionRecord {
    let durationMinutes: Int
}

// ViewModel — localizes for display
@Observable
final class SessionSuccessViewModelImpl: SessionSuccessViewModel {
    private let record: SessionRecord

    var headingText: String {
        String(format: String(localized: "sessionSuccessHeading"), record.durationMinutes)
    }
}

// View — uses ViewModel's localized strings
struct SessionSuccessView: View {
    @Bindable var model: SessionSuccessViewModel
    var body: some View {
        Text(model.headingText)
    }
}
```

### Anti-Pattern

```swift
// WRONG: Localization in Domain layer
struct SessionUseCase {
    func completionMessage() -> String {
        String(localized: "sessionSuccessHeading") // DO NOT do this
    }
}

// WRONG: Localization in Repository
final class StatsRepositoryImpl: StatsRepository {
    func streakLabel(for count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("commonDaysLabel", comment: ""), count
        ) // DO NOT do this
    }
}
```

---

## Exception: Notification Content (Repository Layer)

Push notification body strings are composed in `NotificationCaptionLibrary` (Repository layer). This is a documented exception because:

1. Notification scheduling happens in the main app process
2. The content must be ready before calling `UNUserNotificationCenter`
3. Extracting to ViewModel would require threading notification composition through too many layers

**Rule**: Use `String(localized:)` in `NotificationCaptionLibrary` with an explanatory comment:

```swift
// Documented exception: notification body is composed at schedule time
// in Repository. The main bundle locale is always available here.
let body = String(localized: "notifSessionEnd1")
```

---

## Key Ownership

Since all keys share one file, use the feature name as a key prefix to create logical ownership:

| Key prefix | Owner |
|-----------|-------|
| `splash*` | Splash feature |
| `onboarding*` | Onboarding feature |
| `denial*` | Denial feature |
| `home*`, `homeDashboard*` | Home feature |
| `blocked*` | AppSelection feature |
| `session*`, `countdown*`, `sessionSuccess*` | Session feature |
| `scheduleList*`, `scheduleEditor*` | Scheduling feature |
| `stats*` | Stats feature |
| `notif*` | Notifications feature |
| `common*` | Shared across 2+ features |

---

## Shared Keys (`common*` prefix)

When the same text appears in multiple features, use a `common*` key to avoid duplication:

```swift
// Instead of homeButtonOk, sessionButtonOk, statsButtonOk:
Text("commonButtonOk")

// Instead of homeErrorTitle, sessionErrorTitle, statsErrorTitle:
.alert(String(localized: "commonErrorTitle"), ...)
```

---

## Related

- `string-catalogs-setup.md` - File setup and XcodeGen configuration
- `native-localization-usage.md` - How to use strings in code
- `key-naming-convention.md` - Key naming rules

---

**Last Updated**: 2026-04-26
