---
summary: Adding localization, working with String Catalogs, managing translations
read_when: Adding localization, working with String Catalogs, managing translations
complexity: medium
status: active
last_updated: 2026-04-26
---

# Localization Guide

This guide is a **router** to localization specialized documentation.

---

## What is Localization?

Localization in this project uses Apple's **String Catalogs** (`.xcstrings` files) for managing translations.

A single `Localizable.xcstrings` lives in `DeluluDetox/Resources/` and covers the entire main app target. Languages are declared in `project.yml` via `options.knownRegions`.

**Important difference from the template app:** This project does not use xcstrings-tool (an SPM build plugin for type-safe code generation). Strings are accessed via native Swift APIs: `String(localized:)`, `Text("key")`, and `NSLocalizedString`.

Supported languages: **en** (base), **pl**, **es**

---

## Quick Navigation

### What are you doing?

**Setting up String Catalog / adding a new language**
-> Read `references/string-catalogs-setup.md`
- How to add/update the .xcstrings file
- XcodeGen knownRegions configuration
- Adding languages

**Using localized strings in code**
-> Read `references/native-localization-usage.md`
- `Text("key")`, `String(localized: "key")`, `NSLocalizedString`
- Format strings with `String(format:)`
- Pluralization with `String.localizedStringWithFormat`

**Understanding localization architecture (what goes where)**
-> Read `references/string-architecture.md`
- Which layers can use localized strings
- Notification content exception
- Common anti-patterns

**Naming localization keys**
-> Read `references/key-naming-convention.md`
- Convention: `featureContext` in camelCase
- Shared keys, pluralization keys
- Do's and Don'ts

**Adding pluralization or device variations**
-> Read `references/pluralization-variations.md`
- Plural categories (zero, one, two, few, many, other)
- Language-specific rules (en, pl, es)
- xcstrings JSON format for plural variations

**Exporting/importing translations for translators**
-> Read `references/export-import-workflow.md`
- XLIFF export workflow
- Sending to translators and importing back
- Verification after import

**Managing .xcstrings files programmatically**
-> Read `references/xcstrings-crud-tool.md`
- CLI commands: add, delete, list
- MCP server integration for AI agents

---

## Decision Tree

```
What do you need to do?
    |
    +-- Adding a new language?
    |   +-- Read: references/string-catalogs-setup.md (XcodeGen knownRegions)
    |
    +-- Adding strings to an existing feature?
    |   +-- Read: references/key-naming-convention.md (naming)
    |   +-- Read: references/native-localization-usage.md (how to use in code)
    |   +-- Need pluralization?
    |       +-- Yes -> Read: references/pluralization-variations.md
    |       +-- No -> Add key to .xcstrings, use String(localized:) or Text("key")
    |
    +-- Sending translations to translators?
    |   +-- Read: references/export-import-workflow.md
    |
    +-- Batch managing .xcstrings keys?
        +-- Read: references/xcstrings-crud-tool.md
```

---

## Quick Start

### Adding a localized string (minimal example)

**Step 1:** Add a key to `DeluluDetox/Resources/Localizable.xcstrings`:

| Key | English (en) | Polish (pl) | Spanish (es) |
|-----|-------------|-------------|--------------|
| `dashboardHeaderTitle` | Dashboard | Pulpit | Tablero |

**Step 2:** Use in SwiftUI View:

```swift
// In a View — SwiftUI treats string literals as LocalizedStringKey
Text("dashboardHeaderTitle")

// In a View or ViewModel — explicit String
let title = String(localized: "dashboardHeaderTitle")
```

---

## Key Rules

1. **Translations ONLY in View/ViewModel layers** — Never use localized strings in Domain, Repository, or Networking layers
2. **Exception: Notification content** — Push notification body strings may be composed in the Repository layer; document with a comment
3. **Key naming**: camelCase `featureContext` (e.g., `sessionStartNavigationTitle`)
4. **Languages**: en (base), pl, es
5. **Single .xcstrings**: All strings in `DeluluDetox/Resources/Localizable.xcstrings`
6. **Pluralization**: Use xcstrings plural variations + `NSLocalizedString` + `String.localizedStringWithFormat`

---

## References

| Reference | Description |
|-----------|-------------|
| `references/string-catalogs-setup.md` | String Catalog setup and XcodeGen configuration |
| `references/native-localization-usage.md` | Using localized strings in code (String(localized:), Text, NSLocalizedString) |
| `references/string-architecture.md` | Where strings belong (layer rules, notification exception) |
| `references/key-naming-convention.md` | Key naming convention and examples |
| `references/pluralization-variations.md` | Pluralization and device variations |
| `references/export-import-workflow.md` | XLIFF export/import for translators |
| `references/xcstrings-crud-tool.md` | CLI/MCP tool for .xcstrings management |

---

## Related

- `.claude/guides/feature-structure/GUIDE.md` - Feature directory structure
- `.claude/guides/xcodegen/GUIDE.md` - XcodeGen project generation
- `.claude/guides/xcodebuild-mcp/GUIDE.md` - Build and test with XcodeBuildMCP

---

**Last Updated**: 2026-04-26
