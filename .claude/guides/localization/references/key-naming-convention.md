# Key Naming Convention

Complete reference for naming localization keys consistently across the project.

---

## Convention

All localization keys use **camelCase** following the pattern:

```
featureContext
```

| Part | Description | Example |
|------|-------------|---------|
| `feature` | Feature module name (or `common` for shared) | `session`, `home`, `stats` |
| `Context` | Screen area, component, or element | `NavigationTitle`, `ButtonSave`, `EmptyHeading` |

---

## Examples

### Feature-Specific Keys

| Key | English Value | Usage |
|-----|--------------|-------|
| `sessionStartNavigationTitle` | "New session" | Session start screen title |
| `sessionStartHeader` | "How long will you last this time?" | Header text |
| `sessionStartEmptyHeading` | "Select apps to block first" | Empty state heading |
| `homeEmptySubheading` | "Choose apps that steal your time." | Empty state body |
| `blockedClearConfirmTitle` | "Clear the entire list?" | Confirmation dialog title |
| `scheduleEditorSectionDays` | "Days" | Section header |
| `countdownEndEarlyTitle` | "End early?" | Confirmation dialog title |
| `statsNavigationTitle` | "Statistics" | Stats screen navigation title |

### Shared Keys (`common` prefix)

| Key | English Value | Usage |
|-----|--------------|-------|
| `commonButtonOk` | "OK" | Generic OK button |
| `commonButtonDone` | "Done" | Generic Done button |
| `commonErrorTitle` | "Something went wrong" | Generic error alert title |
| `commonDaysLabel` | "days" (pluralized) | Unit label next to streak count |

### Pluralization Keys

Keys with plural variations use descriptive names:

| Key | Notes |
|-----|-------|
| `commonDaysLabel` | Plural: en one="day" other="days", pl one/few/many/other |
| `sessionStartItemCountWord` | Plural: count + item word for blocklist summary |

See `pluralization-variations.md` for full pluralization setup.

### Format String Keys

Keys with `%@`, `%d`, `%lld` placeholders use the same naming convention:

| Key | English Value | Parameters |
|-----|--------------|------------|
| `homeDashboardGreeting` | "Hi, %@." | name: String |
| `sessionStartButtonPreset` | "Let's go — %d min" | minutes: Int |
| `sessionStartSummaryHint` | "Will block %@ · unlocks at %@" | itemStr, time |
| `scheduleEditorActiveInfo` | "Blocks will automatically enable on selected days at %@." | time |
| `countdownEndEarlyMessage` | "Timer has %@ left. Are you sure?" | remaining |
| `sessionSuccessHeading` | "You lasted %lld minutes" | minutes: Int |
| `statsTotalSessions` | "Total sessions completed: %lld." | count: Int |

---

## Element Suffix Reference

Use consistent suffixes to indicate the UI role:

| Suffix | Usage |
|--------|-------|
| `NavigationTitle` | `.navigationTitle(...)` |
| `Heading` | Primary text, large title |
| `Subheading` | Secondary body text |
| `Label` | Short label (section headers, stat card labels) |
| `Button*` | Button titles (`ButtonSave`, `ButtonCancel`, `ButtonAdd`) |
| `EmptyHeading` | Empty state primary text |
| `EmptySubheading` | Empty state secondary text |
| `ErrorTitle` | Error alert title |
| `ConfirmTitle` | Confirmation dialog title |
| `ConfirmMessage` | Confirmation dialog body |
| `ConfirmButton` | Confirmation destructive action |
| `CancelButton` | Confirmation cancel action |
| `Note` | Informational inline text |
| `Suffix` | Short appended text (e.g., "(night shift)") |

---

## Do's and Don'ts

### Do

- **Use camelCase**: `scheduleEditorNavigationTitle`
- **Be descriptive**: `blockedClearConfirmTitle` over `blockedTitle`
- **Include feature prefix**: Always start with feature name or `common`
- **Use consistent element suffixes** (see table above)

### Don't

- **Don't use underscores**: `schedule_editor_title` — use camelCase
- **Don't use generic keys**: `title`, `buttonText`, `message`
- **Don't nest with dots**: `schedule.editor.title` — use camelCase
- **Don't abbreviate**: `sesStartNavTitle` is unclear
- **Don't duplicate across features**: If used in 2+ features, move to `common*`

---

## Common Issues

- **Key conflicts**: There's one shared `.xcstrings` file — use the feature prefix to avoid collisions (`scheduleEditorSectionDays` vs `statsCurrentLabel`)
- **Renaming keys**: After renaming a key, Xcode marks the old entry as "Stale". Remove stale entries and rebuild
- **Long keys**: If a key feels too long, consider whether two parts (`featureContext`) suffice over three

---

## Related

- `string-catalogs-setup.md` - Adding keys to .xcstrings files
- `string-architecture.md` - Which layer owns which keys
- `pluralization-variations.md` - Pluralization key setup

---

**Last Updated**: 2026-04-26
