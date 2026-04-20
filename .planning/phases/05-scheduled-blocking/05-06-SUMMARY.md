---
phase: 05-scheduled-blocking
plan: 06
status: complete
subsystem: scheduling
tags: [ui, viewmodel, swiftui, observable, lazyinjected, editor, design-system]

requires:
  - phase: 05-04
    provides: CreateOrUpdateScheduleUseCase + ObserveBlocklistUseCase (via AppSelection) registered in DIContainer
  - phase: 02
    provides: Blocklist + ObserveBlocklistUseCase (implicit single blocklist consumed by VM)
provides:
  - ScheduleEditorViewModel (@Observable @MainActor) — draft fields, preset intents, cross-midnight detection, save flow with Destination.errorAlert
  - ScheduleEditorView (SwiftUI Form — days chips + 3 presets, two wheel DatePickers, cross-midnight marker, enabled Toggle, save CTA, error alert)
  - ScheduleDayChip (reusable day-of-week chip subview — electric violet filled / outlined states)
  - Theme+Scheduling extension (4 named colors + cross-midnight hint)
affects: [05-07]

tech-stack:
  added: []
  patterns:
    - "Single-shot blocklistId resolve in VM init via Combine sink on ObserveBlocklistUseCase — mirrors Phase 3 SessionStartViewModel but keeps only the first id (no live rebind once editor is open)"
    - "saveTapped() returns Bool so the View can dispatch onSaved without importing Destination — navigation-agnostic editor"
    - "Two wheel DatePickers bound via computed Binding<Date> translating hour/minute Ints ↔ Date (identical pattern to Phase 3 SessionStartView custom duration picker)"
    - "SwiftUI alert driven by computed Binding<Bool> + presenting: String? extracted from VM.Destination.errorAlert — same Phase 3 idiom"

key-files:
  created:
    - DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift
    - DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift
    - DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleDayChip.swift
    - DeluluDetox/Sources/DesignSystem/Theme+Scheduling.swift
  modified:
    - DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift (8 XCTSkipIf stubs promoted to real assertions)

key-decisions:
  - "onSaved callback is a plain () -> Void closure — Plan 05-07 list parent owns dismissal, keeping the editor self-contained and previewable. Rejected alternative: Destination.dismiss case would add coupling to parent navigation."
  - "VM subscribes to ObserveBlocklistUseCase once and guards blocklistId assignment with `if self.blocklistId == nil` — prevents a later blocklist swap from clobbering the draft identity mid-edit. Initial existing Schedule blocklistId takes precedence over observer."
  - "Preset weekday constants live as private static sets on the VM (workdayWeekdays/weekendWeekdays/allWeekdays) — readable, testable, zero magic numbers in the intent functions."
  - "Save flow assembles Schedule with `Array(daysOfWeek).sorted()` so persisted daysOfWeek order is deterministic even though Set iteration is not."
  - "Error alert copy is verbatim 'iOS się zbuntował, spróbuj jeszcze raz.' per CONTEXT §D-14 — tone-matched with Phase 3/4 sarcastic Polish error voice. Separate sarcastic copy for the rare 'no blocklist' branch ('Nie mogę zapisać — brak blocklisty. Dodaj najpierw apki do blokady.') because that failure is user-actionable, not infrastructure rage."

patterns-established:
  - "Pattern 1: Navigation-agnostic feature editor — VM exposes saveTapped() -> Bool, View exposes onSaved closure. Parent (list/destination owner) decides push/pop/sheet. Scales to future Plan 05-07 schedule list and any re-use in other phases."
  - "Pattern 2: Theme extensions per feature — feature-owned colors live in Theme+{Feature}.swift (Theme+Session from Phase 3, Theme+Scheduling here). Theme.swift core stays minimal; no touching by feature work."
  - "Pattern 3: Day-chip component reusable across any multi-day selector UX — ScheduleDayChip only depends on Theme + a label/action, zero VM coupling. Plan 05-07 schedule row / future multi-schedule screens can reuse it."

requirements-completed: [SCH-01, SCH-02]

duration: ~30min
completed: 2026-04-20
---

# Phase 05 Plan 06: Editor ViewModel + View

**Schedule editor UI complete — full SCH-01 + SCH-02 (main-entry) screen ready for parent navigation in Plan 05-07.**

## Performance

- **Duration:** ~30 min (Tasks 1 + 2 landed back-to-back in a single worktree session, no checkpoints)
- **Tasks:** 2/2 complete
- **Files created:** 4 (VM + View + DayChip + Theme extension)
- **Files modified:** 1 (test file — 8 stubs → 8 real assertions)
- **Tests:** 207 / 0 failures / 7 skipped (was 207 / 0 / 15 pre-plan — 8 stubs promoted to assertions, zero delta in total count because the stubs were counted as skipped)

## Accomplishments

- `ScheduleEditorViewModel` shipped with the full draft model — 5 scalar fields + Set<Int> daysOfWeek + enabled toggle + isSaving + derived isCrossMidnight + canSave. All preset + toggle intents wired, cross-midnight detection pure (no Calendar calls), save flow assembles Schedule per D-02 and delegates to `CreateOrUpdateScheduleUseCase` which chains Sync UC from Plan 05-04.
- `ScheduleEditorView` renders a 3-section Form (days + presets, time pickers + cross-midnight marker, enabled toggle), safeAreaInset primary CTA (Zapisz / Zapisywanie…), and an error alert driven by VM.Destination. Two `.wheel` `DatePicker(.hourAndMinute)` bindings translate hour/minute Ints ↔ Date on the fly.
- `ScheduleDayChip` is a 40×40 reusable subview — filled electric violet on select, outlined violet on deselect, RoundedRectangle corners 12, plain button style for tap handling. Accessibility label + `.isSelected` trait wired.
- `Theme+Scheduling` adds 4 day-chip colors + `crossMidnightHintColor` without touching `Theme.swift` — same extension pattern as Phase 3's `Theme+Session.swift`.
- 8 `XCTSkipIf` stubs in `ScheduleEditorViewModelTests` promoted to real assertions covering init (default + from-existing), 3 presets, cross-midnight detection, save success (VM populates Schedule correctly, returns true, destination stays nil) and save failure (destination becomes errorAlert with exact CONTEXT §D-14 copy, returns false, UC still called once).
- ViewModel discipline preserved: no `import SwiftUI`. Only `Observation` + `SwiftUINavigation` (swift-navigation, for `@CasePathable`) + `Combine` + `Foundation` + `os`. Comment in-file documents the invariant for future readers.

## Task Commits

1. **Task 1: ScheduleEditorViewModel + 8 tests** — `aef8b53` (feat)
2. **Task 2: ScheduleEditorView + ScheduleDayChip + Theme+Scheduling** — `6a52565` (feat)

## Deviations

- **D1 (Rule 2 — CONTEXT completeness):** Added a second sarcastic error path for the "no blocklist resolved" branch (`"Nie mogę zapisać — brak blocklisty. Dodaj najpierw apki do blokady."`). Plan interfaces included this in the VM skeleton but not in the test matrix. Kept the branch because it's the only user-actionable failure and deserves distinct copy; the single-phrase test asserts only the CONTEXT §D-14 infrastructure error ("iOS się zbuntował").
- **D2 (Rule 3 — environment):** The `CLAUDE.md` repo scaffolded simulator UUID `C958163F-49E1-4B46-8A6D-C2056CD25A37` is stale — local Xcode 26.3.1 maps iPhone 17 to `6D73311F-3541-4B74-92E8-8014FABC3329` (matches the UUID supplied in the execute prompt's `<mcp_tools>` block). Ran tests against the live UUID. Not a repo change — just noted here so a future orchestrator updates CLAUDE.md when refreshing the simulator pin.
- **D3 (Rule 2 — test realism):** Plan test plan referenced `mockObserveBlocklist.blocklistSubject` and `mockCreateOrUpdate.lastSchedule` / `stubbedError`, but the actual Phase 01 mocks expose `subject` / `lastInputSchedule` / `createOrUpdateError`. Rewired the tests to the real mock surface — no mock changes, no spec change.

## Threat Register Verification (from PLAN)

- **T-05-06-01 (DoS — double-tap Save):** mitigated via `isSaving` guard + `canSave` driving `.disabled`. VM returns false immediately on re-entry.
- **T-05-06-02 (Tampering — out-of-range hour/minute):** mitigated by `DatePicker(.wheel, .hourAndMinute)` restricting input; `Calendar.dateComponents` extraction in the bindings normalises to Ints.
- **T-05-06-03 (InfoDisclosure — logger UUID):** accepted. Matches Phase 3 pattern.
- **T-05-06-04 (EoP — missing blocklistId):** mitigated by `guard let blocklistId` in saveTapped with explicit error message.
- **T-05-06-05 (Repudiation — silent save failure):** mitigated by `logger.error("save failed: …")` in the catch branch.
- **T-05-06-06 (Spoofing — preset button input):** N/A per plan.

## Known Stubs

None. No placeholder data, no hardcoded empty collections flowing to UI. `daysOfWeek` defaulting to `[]` is the intended empty state (save-disabled until user picks days) — documented by `canSave` gate.

## Threat Flags

None. No new network endpoints, auth paths, or schema changes introduced. All data flows through existing Plan 02 (Blocklist) + Plan 05-02 (Schedule persistence) boundaries already in the register.

## Test Delta

Pre-plan (post-05-05): 207 / 200 passed / 7 failed/skipped breakdown — 8 of the 15 pre-plan skips belonged to Phase 05 scheduling stubs; 8 ScheduleEditorViewModelTests stubs promoted here.

Post-plan: 207 tests / 200 passed / 7 skipped / 0 failures. Net +0 total but +8 passed / −8 skipped. Remaining 7 skips are unrelated to this plan (covered by Plan 05-07 + future plans).

## What's Next

- **Plan 05-07 (List VM + Navigation)** — will add `ScheduleListViewModel` + `ScheduleListView`, wire `HomeViewModel.Destination.scheduleList` (per CONTEXT D-22 amendment), and push `ScheduleEditorView(model: ScheduleEditorViewModel(existing:))` as a `navigationDestination`. The `onSaved` callback in this editor is ready to be wired to a parent pop.
- **Plan 05-08 (Device UAT)** — will exercise the full editor → save → DAS registration chain on hardware, including the SCH-03 day-N+1 window verification deferred from the Wave 0 spike.

## Self-Check: PASSED

- `DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleDayChip.swift` — FOUND
- `DeluluDetox/Sources/DesignSystem/Theme+Scheduling.swift` — FOUND
- `DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift` — FOUND (8 stubs promoted, 0 XCTSkipIf remaining)
- Commit `aef8b53` (Task 1) — FOUND
- Commit `6a52565` (Task 2) — FOUND
- Test run: 207 / 0 failures — PASSED
