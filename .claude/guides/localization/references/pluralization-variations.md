# Pluralization and Variations

Complete reference for handling pluralization in String Catalogs.

---

## How String Catalogs Handle Pluralization

String Catalogs natively support plural forms through **variations** embedded in the `.xcstrings` format. No separate `.stringsdict` file is needed.

---

## Plural Categories

The Unicode CLDR defines six plural categories. Not all languages use all categories:

| Category | English Example | Polish Example |
|----------|----------------|----------------|
| `zero` | (not used) | (not used) |
| `one` | "1 item" | "1 element" |
| `two` | (not used) | (not used) |
| `few` | (not used) | "2 elementy", "3 elementy", "4 elementy" |
| `many` | (not used) | "5 elementów", "12 elementów" |
| `other` | "2 items", "5 items" | (fallback) |

### Language-Specific Rules

**English (en):**
- Uses `one` and `other`
- `one`: exactly 1
- `other`: everything else (0, 2, 3, ...)

**Polish (pl):**
- Uses `one`, `few`, `many`, `other`
- `one`: exactly 1
- `few`: 2–4, 22–24, 32–34, ... (not 12–14)
- `many`: 0, 5–21, 25–31, 35–41, ... (and 11–14)
- `other`: fallback (rarely needed — CLDR uses `many` for most remaining cases)

**Spanish (es):**
- Uses `one` and `other`
- `one`: exactly 1
- `other`: everything else

---

## Setting Up Pluralization in .xcstrings

In the Xcode String Catalog editor:

1. Add a key (e.g., `commonDaysLabel`)
2. Right-click the key and select **Vary by Plural**
3. Xcode adds plural category rows for each language
4. Fill in the value for each category, using `%lld` for the integer argument

### Example in JSON

```json
{
  "commonDaysLabel" : {
    "localizations" : {
      "en" : {
        "variations" : {
          "plural" : {
            "one" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%lld day"
              }
            },
            "other" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%lld days"
              }
            }
          }
        }
      },
      "pl" : {
        "variations" : {
          "plural" : {
            "one" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%lld dzień"
              }
            },
            "few" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%lld dni"
              }
            },
            "many" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%lld dni"
              }
            },
            "other" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%lld dni"
              }
            }
          }
        }
      },
      "es" : {
        "variations" : {
          "plural" : {
            "one" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%lld día"
              }
            },
            "other" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "%lld días"
              }
            }
          }
        }
      }
    }
  }
}
```

---

## Using Plural Strings in Code

Plural strings require `NSLocalizedString` + `String.localizedStringWithFormat`:

```swift
// count=1 → "1 day" (en) / "1 dzień" (pl) / "1 día" (es)
// count=5 → "5 days" (en) / "5 dni" (pl) / "5 días" (es)
let text = String.localizedStringWithFormat(
    NSLocalizedString("commonDaysLabel", comment: ""),
    count
)
```

Do NOT use `String(localized:)` for plural strings — it returns the raw format string (`"%lld days"`) without substitution.

---

## Pluralization in This App

The following keys use plural variations:

| Key | Languages | Notes |
|-----|-----------|-------|
| `commonDaysLabel` | en, pl, es | Streak count unit ("day/days/dzień/dni/día/días") |
| `sessionStartItemCountWord` | en, pl, es | Item count in session summary ("1 item/2 items/1 rzecz/2 rzeczy") |
| `statsTotalSessions` | en, pl, es | "Total sessions completed: X." |

---

## Common Issues

- **Missing plural category**: If a language requires `few` or `many` and you only provide `one`/`other`, the fallback to `other` may produce grammatically incorrect Polish text
- **Wrong format specifier**: Use `%lld` for integers in plural strings, not `%d` (the CLDR plural engine requires `%lld`)
- **Using String(localized:) for plurals**: Use `NSLocalizedString` + `String.localizedStringWithFormat` instead
- **Testing plurals**: Test with values 1, 2, 5, 12, 22 to cover all Polish categories

---

## Related

- `string-catalogs-setup.md` - Setting up .xcstrings files
- `native-localization-usage.md` - Code patterns for plural strings
- `key-naming-convention.md` - Naming pluralized keys

---

**Last Updated**: 2026-04-26
