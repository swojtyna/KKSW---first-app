# String Catalogs Setup

Complete reference for setting up and managing Apple String Catalogs (`.xcstrings`) in this project.

---

## What are String Catalogs?

String Catalogs (`.xcstrings`) are Apple's modern localization format introduced in Xcode 15. They replace traditional `.strings` and `.stringsdict` files with a single JSON-based file that:

- Manages all translations in one place
- Supports pluralization and device variations natively
- Provides a visual editor in Xcode
- Tracks translation state (new, needs review, translated, stale)

---

## Project Structure

This project uses a **single String Catalog** for the main app target:

```
DeluluDetox/
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.xcstrings    <-- All app translations
└── Sources/
    └── Features/
        └── ...
```

Unlike SPM-based projects with per-feature packages, all strings live in one file.

---

## XcodeGen Configuration

Language support is declared in `project.yml`. Two places need updating when adding a new language:

### 1. `options.knownRegions`

```yaml
options:
  developmentLanguage: en
  knownRegions:
    - Base
    - en
    - pl
    - es
```

### 2. Target sources — explicit path to `Localizable.xcstrings`

```yaml
targets:
  DeluluDetox:
    sources:
      - path: DeluluDetox/Sources
      - path: DeluluDetox/Resources/Assets.xcassets
      - path: DeluluDetox/Resources/Localizable.xcstrings
```

After editing `project.yml`, run `xcodegen generate` to regenerate `.xcodeproj`.

---

## Supported Languages

| Language | Code | Role |
|----------|------|------|
| English | `en` | Base (source) language |
| Polish | `pl` | Translation |
| Spanish | `es` | Translation |

### Adding a New Language

1. Add the language code to `options.knownRegions` in `project.yml`
2. Run `xcodegen generate`
3. Open `Localizable.xcstrings` in Xcode
4. Click **+** at the bottom of the language column headers
5. Select the language — Xcode adds a new column, all keys start as "New"
6. Provide translations

---

## Creating / Editing the String Catalog

### Manual JSON editing

`Localizable.xcstrings` is a JSON file. An empty catalog:

```json
{
  "sourceLanguage" : "en",
  "strings" : {},
  "version" : "1.0"
}
```

Adding a key:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "dashboardHeaderTitle" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Dashboard"
          }
        },
        "pl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Pulpit"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Tablero"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

### In the Xcode Editor

1. Open `Localizable.xcstrings` in Xcode
2. Click **+** at the bottom of the keys list
3. Enter the key name (follow naming convention: `featureContext` in camelCase)
4. Add translations for each language

---

## Common Issues

- **String not resolving at runtime**: Ensure `Localizable.xcstrings` is listed in `project.yml` sources and `xcodegen generate` was run
- **New language not showing**: Ensure the language code is in `knownRegions` AND `xcodegen generate` was re-run
- **Stale translations**: After renaming a key, Xcode marks the old translation as "Stale". Remove stale entries manually
- **Missing language column**: Click **+** in the Xcode editor to add a language

---

## Related

- `native-localization-usage.md` - How to use strings in code
- `key-naming-convention.md` - How to name keys
- `pluralization-variations.md` - Setting up plural forms

---

**Last Updated**: 2026-04-26
