# Native Localization Usage

Complete reference for using localized strings in Swift and SwiftUI code.

---

## Overview

This project uses Apple's native localization APIs. There is no xcstrings-tool or code generation step — strings are referenced by key name at runtime.

---

## Simple Strings in SwiftUI

SwiftUI automatically treats `String` literals as `LocalizedStringKey` in most view initializers:

```swift
// These all auto-localize:
Text("splashSubtitle")
Button("commonButtonOk") { }
.navigationTitle("homeNavigationTitle")
Section("blockedSectionApps") { }
.alert("homeErrorTitle", ...)
.confirmationDialog("countdownEndEarlyTitle", ...)
```

The literal `"splashSubtitle"` is looked up as a key in `Localizable.xcstrings`.

---

## Simple Strings as `String` Type

For custom components that take `String` (not `LocalizedStringKey`), use `String(localized:)`:

```swift
// Custom components (PrimaryButton, SecondaryButton, SectionLabel, DesignChip, etc.)
PrimaryButton(title: String(localized: "homeButtonSelectApps"), systemIcon: "plus") { }
SecondaryButton(title: String(localized: "blockedButtonClear"), systemIcon: "trash.fill") { }
SectionLabel(text: String(localized: "scheduleEditorSectionDays"))
DesignChip(text: String(localized: "scheduleEditorPresetWeekdays"), isSoft: true)
```

---

## Format Strings (with dynamic values)

Use `String(format:)` combined with `String(localized:)`:

```swift
// In .xcstrings: "homeDashboardGreeting" → "Hi, %@."
let greeting = String(format: String(localized: "homeDashboardGreeting"), userName)

// In .xcstrings: "sessionStartButtonPreset" → "Let's go — %d min"
let buttonTitle = String(format: String(localized: "sessionStartButtonPreset"), presetMinutes)

// In .xcstrings: "scheduleEditorActiveInfo" → "Blocks will automatically enable on selected days at %@."
let info = String(format: String(localized: "scheduleEditorActiveInfo"), formattedTime)
```

For SwiftUI `Text` with a format string, convert to `String` first:

```swift
Text(String(format: String(localized: "sessionSuccessHeading"), model.durationMinutes))
    .font(.dduLargeTitle)
```

---

## Pluralization

For strings with plural forms defined in `.xcstrings`, use `NSLocalizedString` + `String.localizedStringWithFormat`:

```swift
// .xcstrings has plural variations for "commonDaysLabel"
let daysText = String.localizedStringWithFormat(
    NSLocalizedString("commonDaysLabel", comment: ""),
    streakCount
)
// count=1 → "1 day" (en) / "1 dzień" (pl) / "1 día" (es)
// count=5 → "5 days" (en) / "5 dni" (pl) / "5 días" (es)
```

Combined with a summary format string:

```swift
// Step 1: get localized item count string
let itemStr = String.localizedStringWithFormat(
    NSLocalizedString("sessionStartItemCountWord", comment: ""),
    itemCount
)
// Step 2: embed in summary
let hint = String(format: String(localized: "sessionStartSummaryHint"), itemStr, unlockTime)
```

---

## Notification Content (Repository Layer Exception)

Push notification body strings are composed in the Repository layer. Use `String(localized:)` or `String(format:)` there:

```swift
// In NotificationCaptionLibrary (Repository layer — documented exception)
let captions: [String] = [
    String(localized: "notifSessionEnd1"),
    String(localized: "notifSessionEnd2"),
    String(format: String(localized: "notifSessionEnd3"), durationMinutes)
]
```

See `string-architecture.md` for the rationale.

---

## When NOT to Localize

| Code | Should localize? |
|------|----------------|
| User-visible UI strings | YES |
| Alert titles and messages | YES |
| Button and tab labels | YES |
| Notification content | YES (see exception above) |
| Error messages shown to user | YES |
| App name "DeluluDetox" | NO — brand name stays untranslated |
| Debug/log messages | NO |
| System identifiers and keys | NO |
| Placeholder mock data | NO |

---

## Common Mistakes

```swift
// WRONG: using String(localized:) in Domain/UseCase layer
struct BlockUseCase {
    func title() -> String {
        return String(localized: "homeNavigationTitle") // violates layer rule
    }
}

// CORRECT: return domain data, localize in ViewModel or View
struct BlockUseCase {
    func title() -> String { return "DeluluDetox" } // untranslated domain data
}

// In ViewModel:
var navigationTitle: String { "DeluluDetox" } // app name doesn't need localization
```

---

## Related

- `string-catalogs-setup.md` - Setting up .xcstrings files
- `string-architecture.md` - Layer rules and notification exception
- `pluralization-variations.md` - Plural form setup

---

**Last Updated**: 2026-04-26
