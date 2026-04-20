---
phase: 04-shield-customization
plan: 02
subsystem: ui
tags: [managed-settings-ui, shield-configuration, url-scheme, app-group, xcodegen, uikit, sf-symbols]

# Dependency graph
requires:
  - phase: 01-foundation-onboarding
    provides: electric violet #7C3AED brand color, empty ShieldConfigurationExtension + ShieldActionExtension scaffolds
  - phase: 03-quick-sessions
    provides: active_session.json schema (plannedEndAt Date), SessionPaths.activeSessionURL(), DAM extension source-share precedent
  - phase: 04-shield-customization / plan 01
    provides: validation strategy + 5 XCTSkip stubs in ShieldConfigurationBuilderTests to turn green
provides:
  - Pure XCTest-driveable ShieldConfigurationBuilder (violet-branded 8-field ShieldConfiguration with Polish sarcastic copy)
  - ActiveSessionEnvelope + ActiveSessionEnvelopeReader (lean Decodable reading only plannedEndAt, never throws, collapses to nil on any error)
  - ShieldConfigurationExtension with all 4 configuration(shielding:) overrides delegating to shared buildShieldConfiguration() helper
  - deluludetox:// custom URL scheme registered on DeluluDetox app target (SHL-04 entry point for Plan 04)
  - Source-share of SessionPaths + ActiveSessionEnvelope into both shield extensions; ShieldConfigurationBuilder shared into ShieldConfigurationExtension only
affects: [04-03, 04-04, 04-05]

# Tech tracking
tech-stack:
  added: []  # All frameworks system-provided (ManagedSettings, ManagedSettingsUI, UIKit, os, Foundation)
  patterns:
    - "Pure builder struct extracted from extension class for XCTest drivability"
    - "Lightweight local Decodable envelope in extension target (avoids pulling full SessionRecord + FamilyControls-adjacent types — DAM pattern from Phase 3 Plan 04)"
    - "project.yml source-share of main-app Swift files into extension targets"
    - "URL scheme registration via INFOPLIST_KEY_CFBundleURLTypes build setting (compatible with GENERATE_INFOPLIST_FILE: true)"
    - "Scalar-only .public os.Logger (Int + Bool) — no PII in extension logs"

key-files:
  created:
    - DeluluDetox/Sources/Features/Shield/Builder/ActiveSessionEnvelope.swift (33 LOC)
    - DeluluDetox/Sources/Features/Shield/Builder/ShieldConfigurationBuilder.swift (56 LOC)
  modified:
    - project.yml (URL scheme + 2 source-share blocks)
    - Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift (rewrite, 53 LOC)
    - DeluluDetoxTests/Features/Shield/ShieldConfigurationBuilderTests.swift (replace 5 XCTSkip stubs with real assertions, 38 LOC)

key-decisions:
  - "URL scheme registration used INFOPLIST_KEY_CFBundleURLTypes build setting (JSON array literal) — preserves GENERATE_INFOPLIST_FILE: true and avoids switching to explicit info.path. Verified via successful build validation on iPhone 17 simulator."
  - "Explicit secondary button label \"Zamknij\" in UIColor.systemBlue (Apple default would hide the button entirely when nil) — aligns with CONTEXT §D-05 Claude's Discretion default."
  - "Round-up to >=1 minute in ActiveSessionEnvelopeReader so a 45s remainder shows \"1 min\" rather than \"0 min\"."
  - "Log line emits only scalar .public fields (Int + Bool) — no App token content, no session IDs — matching DAM extension privacy posture."

patterns-established:
  - "Builder-in-main-app + source-share into extension target: lets XCTest exercise pure logic without extension process, keeps RAM ceiling intact"
  - "Shared buildShieldConfiguration() helper across all 4 ShieldConfigurationDataSource overrides (D-14)"

requirements-completed: [SHL-01, SHL-02]  # SHL-04 URL scheme is *registered* here but handler logic lives in Plan 04

# Metrics
duration: ~8min
completed: 2026-04-20
---

# Phase 04 Plan 02: Shield Extension Build-Out Summary

**Branded violet ShieldConfiguration (SHL-01) + generic fallback branch (SHL-02) live in ShieldConfigurationExtension via pure testable builder; `deluludetox://` URL scheme registered for SHL-04.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-20T00:16:00Z (approx)
- **Completed:** 2026-04-20T00:24:00Z (approx)
- **Tasks:** 2
- **Files modified:** 4 (2 created, 2 modified) + project.yml

## Accomplishments

- Pure `ShieldConfigurationBuilder` renders violet (#7C3AED) ShieldConfiguration with white-tinted `hand.raised.fill` SF Symbol and Polish sarcastic copy (`"Serio?"` / `"Jeszcze X min zanim znowu będziesz mógł scrollować"` / `"Zobacz ile zostało"`).
- Fallback branch (`remainingMinutes == nil`) keeps the brand and swaps copy (`"Zablokowane"` / `"Zamknij i zrób coś mądrzejszego"` / `"Otwórz DeluluDetox"`) — SHL-02 addressed without visual drift.
- `ActiveSessionEnvelopeReader.loadRemainingMinutes()` reads `active_session.json` through a chain of four `try?`/`guard` clauses — any malformed / missing / expired file collapses silently to `nil` (T-04-02-01 mitigation).
- `ShieldConfigurationExtension` now implements all four `configuration(shielding:)` overrides (application, application-in-category, webDomain, webDomain-in-category), each delegating to a single `buildShieldConfiguration()` helper (D-14).
- `deluludetox://` URL scheme registered on the DeluluDetox app target via `INFOPLIST_KEY_CFBundleURLTypes` build setting — verified by successful build-time Info.plist generation and app validation.
- Extension imports verified lean: `Foundation`, `ManagedSettings`, `ManagedSettingsUI`, `UIKit`, `os` only — no `FamilyControls`, no `SwiftUI`, no `Combine` (D-17, 6 MB RAM ceiling).

## Task Commits

Each task was committed atomically:

1. **Task 1: project.yml + ShieldConfigurationBuilder + ActiveSessionEnvelope + turn 5 tests green** — `d816c2e` (feat)
2. **Task 2: Wire ShieldConfigurationExtension's four overrides** — `6b2b766` (feat)

## Files Created/Modified

- `DeluluDetox/Sources/Features/Shield/Builder/ActiveSessionEnvelope.swift` (NEW, 33 LOC) — `ActiveSessionEnvelope: Decodable` + `ActiveSessionEnvelopeReader.loadRemainingMinutes(now:)` lean reader.
- `DeluluDetox/Sources/Features/Shield/Builder/ShieldConfigurationBuilder.swift` (NEW, 56 LOC) — `struct ShieldConfigurationBuilder { func make(remainingMinutes: Int?) -> ShieldConfiguration }` — pure, no I/O.
- `Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift` (REWRITE, 53 LOC) — 4 overrides → shared `buildShieldConfiguration()` → `ActiveSessionEnvelopeReader.loadRemainingMinutes()` → `ShieldConfigurationBuilder().make(remainingMinutes:)`.
- `DeluluDetoxTests/Features/Shield/ShieldConfigurationBuilderTests.swift` (UPDATED, 38 LOC) — replaced 5 XCTSkip stubs with real assertions.
- `project.yml` (UPDATED) — three changes:
  1. `INFOPLIST_KEY_CFBundleURLTypes` JSON literal on `DeluluDetox.settings.base` (registers `deluludetox://`).
  2. `ShieldConfigurationExtension.sources` now includes `SessionPaths.swift`, `ActiveSessionEnvelope.swift`, `ShieldConfigurationBuilder.swift`.
  3. `ShieldActionExtension.sources` now includes `SessionPaths.swift`, `ActiveSessionEnvelope.swift` (Plan 03 will consume).

## project.yml Diff Summary

```yaml
# DeluluDetox target settings.base — added one line after accent-color, before bundle identifier:
        INFOPLIST_KEY_CFBundleURLTypes: '[{"CFBundleURLName":"com.kksw.DeluluDetox","CFBundleURLSchemes":["deluludetox"]}]'

# ShieldConfigurationExtension.sources — replaced single-entry array with:
      - path: Extensions/ShieldConfigurationExtension
      - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
      - path: DeluluDetox/Sources/Features/Shield/Builder/ActiveSessionEnvelope.swift
      - path: DeluluDetox/Sources/Features/Shield/Builder/ShieldConfigurationBuilder.swift

# ShieldActionExtension.sources — replaced single-entry array with:
      - path: Extensions/ShieldActionExtension
      - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
      - path: DeluluDetox/Sources/Features/Shield/Builder/ActiveSessionEnvelope.swift
```

## URL Scheme Registration Variant

The **build-setting variant** landed (not the explicit `info.path` variant). XcodeGen correctly interpreted the JSON array literal starting with `[` and emitted it into the generated Info.plist; build validation succeeded (`ValidateEmbeddedBinary` and `builtin-validationUtility` both passed). No fallback to explicit `info.path` needed.

## Test Result

- Scoped run (`-only-testing:DeluluDetoxTests/ShieldConfigurationBuilderTests`): **5 passed, 0 failed, 0 skipped**.
- Full suite on iPhone 17 simulator (UUID `6D73311F-3541-4B74-92E8-8014FABC3329`): **147 passed, 12 skipped, 0 failed**.
- Skipped count dropped from 17 (Plan 01 post-baseline) to 12 — exactly the 5 Shield tests that Plan 02 was assigned to turn green.

## Extension Import Audit (grep)

```
$ grep -c "^import FamilyControls$" Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift → 0
$ grep -c "^import SwiftUI$"        Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift → 0
$ grep -c "^import Combine$"        Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift → 0
$ grep -c "import FamilyControls"   DeluluDetox/Sources/Features/Shield/Builder/ActiveSessionEnvelope.swift → 0
$ grep -c "import SwiftUI"          DeluluDetox/Sources/Features/Shield/Builder/ActiveSessionEnvelope.swift → 0
```

Imports limited to the approved 5 modules in the extension; the shared envelope file imports only `Foundation`.

## Decisions Made

- **URL scheme via build setting, not explicit `info.path`.** Preserved `GENERATE_INFOPLIST_FILE: true` for the main target rather than creating a standalone `Info.plist` — lower config footprint and validated successfully. The plan's fallback branch was not needed.
- **Explicit secondary button label `"Zamknij"`** in `UIColor.systemBlue` rather than `nil`. Per CONTEXT §D-05 last bullet, `nil` hides the button entirely; explicit label keeps the dismiss affordance branded-but-distinct from the violet primary.
- **Round-up to ≥1 minute** in `loadRemainingMinutes()` (`Int((remaining + 59) / 60)`) — prevents the shield from showing "0 min" in the final minute of a session.
- **Scalar-only `.public` Logger** — log line emits only `Int` (`remainingMinutes ?? -1`) and `Bool` (`remainingMinutes == nil`). No Application tokens, no selection content, no session identifiers. Matches T-04-02-05 mitigation.

## Deviations from Plan

None — plan executed exactly as written. Two minor operational notes:

1. **Simulator UUID in CLAUDE.md is stale** (`C958163F-49E1-4B46-8A6D-C2056CD25A37` not found); the active iPhone 17 simulator on this machine is `6D73311F-3541-4B74-92E8-8014FABC3329` (iOS 26.3.1). Not a code deviation — this is a workstation-drift issue worth flagging for a future CLAUDE.md refresh but out of scope for this plan (would not auto-fix under Rules 1–3).
2. **Full-suite test re-run hit a transient simulator "Busy / preflight checks" error** between the scoped run and the full run. Resolved by a single simulator boot + uninstall of the prior bundle + retry; subsequent run was clean (147/12/0). Flake, not a bug.

## Issues Encountered

Same as deviation note 2 — transient simulator launcher flake, resolved by retry.

## Next Phase Readiness

- **Plan 04-03** (SHL-03 shield action delegate + `NSExtensionContext.open(_:)` URL workaround): Ready. `ActiveSessionEnvelope` + `SessionPaths` are already source-shared into `ShieldActionExtension`; Plan 03 only needs to edit `Extensions/ShieldActionExtension/ShieldActionExtension.swift`.
- **Plan 04-04** (SHL-04 main-app URL deep-link handler): Ready. The `deluludetox://` scheme is registered; Plan 04 wires `.onOpenURL` on `AppRootView` and `HomeViewModel.handleDeepLink(_:)`.
- **Plan 04-05** (device visual verification): Shield rendering will be visually verified on physical device.

**Known limitation carried forward:** Actual shield visual rendering cannot be verified on simulator (iOS shows Apple default shield regardless of custom extension) — device verification deferred to Plan 05 per RESEARCH.md Environment Availability.

## Self-Check: PASSED

- `DeluluDetox/Sources/Features/Shield/Builder/ActiveSessionEnvelope.swift`: FOUND
- `DeluluDetox/Sources/Features/Shield/Builder/ShieldConfigurationBuilder.swift`: FOUND
- `Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift`: FOUND (modified in place)
- Commit `d816c2e`: FOUND (Task 1 — `feat(04-02): add ShieldConfigurationBuilder + ActiveSessionEnvelope`)
- Commit `6b2b766`: FOUND (Task 2 — `feat(04-02): wire ShieldConfigurationExtension to builder + envelope`)
- 5 ShieldConfigurationBuilderTests: PASSED
- Full suite: 147 passed, 12 skipped, 0 failed

---
*Phase: 04-shield-customization*
*Completed: 2026-04-20*
