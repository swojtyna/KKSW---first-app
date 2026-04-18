---
phase: 2
slug: app-selection
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Fill during/after planning; planner may refine this alongside plan creation.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift) — Apple native, no external deps |
| **Config file** | `DeluluDetox.xctestplan` (created by Phase 1 XcodeGen setup) |
| **Quick run command** | `XcodeBuildMCP test_project_device_ws` targeting the `DeluluDetoxTests` target with a tag filter for Phase 2 unit tests (e.g. `--only-testing:DeluluDetoxTests/BlocklistSuite`) |
| **Full suite command** | `XcodeBuildMCP test_project_device_ws` with all Phase 2 test classes |
| **Estimated runtime** | ~15–30 seconds (Repository + UseCase units are pure-Swift, no simulator UI) |

> Shell fallback (only if MCP unavailable): `xcodebuild test -workspace DeluluDetox.xcworkspace -scheme DeluluDetox -destination 'platform=iOS Simulator,name=iPhone 15'` — prefer MCP per CLAUDE.md.

---

## Sampling Rate

- **After every task commit:** Run quick suite for the affected UseCase/Repository test class
- **After every plan wave:** Run full Phase 2 test suite
- **Before `/gsd-verify-work`:** Full suite green + manual device pass for picker/App-Group behaviors
- **Max feedback latency:** 30 seconds for unit layer; device tests are manual, documented below

---

## Per-Task Verification Map

> Planner populates this table as plans are written. Each row maps one plan task to a concrete test (automated where possible, manual with steps otherwise). Placeholder rows below show the required shape — planner rewrites these.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 2-??-01 | 01 | 0 | (scaffolding) | — | — | setup | `XcodeBuildMCP build_project_ws` | ❌ W0 | ⬜ pending |
| 2-??-02 | 01 | 1 | SEL-04 | — | Blocklist round-trips Codable JSON via atomic write | unit | `test BlocklistRepositorySuite/test_saveThenLoadRoundTrips` | ❌ W0 | ⬜ pending |
| 2-??-03 | 01 | 1 | SEL-05 | — | `UpdateFromSelectionUseCase` reuses existing UUIDs for tokens still present, assigns fresh UUIDs for new tokens, drops removed | unit | `test BlocklistUseCaseSuite/test_updateFromSelectionPreservesUUIDs` | ❌ W0 | ⬜ pending |
| 2-??-04 | 01 | 1 | SEL-05 | — | `ReconcileBlocklistUseCase` rewrites stale token binaries under the same UUIDs | unit | `test BlocklistUseCaseSuite/test_reconcileReplacesStaleTokens` | ❌ W0 | ⬜ pending |
| 2-??-05 | 02 | 2 | SEL-01 / SEL-02 / SEL-03 | — | `HomeViewModel.chooseAppsTapped()` transitions Destination to `.picker(selection)` seeded from current blocklist | unit | `test HomeViewModelSuite/test_chooseAppsTappedOpensPicker` | ❌ W0 | ⬜ pending |
| 2-??-06 | 02 | 2 | SEL-01 / SEL-02 / SEL-03 | — | `pickerDismissed(selection:)` calls `UpdateFromSelectionUseCase` and clears Destination | unit | `test HomeViewModelSuite/test_pickerDismissedCommitsAndClosesDestination` | ❌ W0 | ⬜ pending |
| 2-??-07 | 02 | 2 | SEL-04 | — | `BlockedView` renders sections for apps / categories / web domains; empty sections are hidden | snapshot OR manual | see Manual-Only table | N/A | ⬜ pending |
| 2-??-08 | 03 | 3 | SEL-01 / SEL-02 / SEL-03 / SEL-04 / SEL-05 | — | End-to-end on a physical device with `com.apple.developer.family-controls` entitlement | manual | see Manual-Only table | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Planner note:** Keep sampling continuity — never more than 3 consecutive tasks without an automated verify step. SwiftUI `BlockedView` rendering can use `ViewInspector` or XCTest snapshot tests for smoke coverage of the empty-state → populated-state branch; deeper visual QA stays manual per UI-SPEC policy.

---

## Wave 0 Requirements

- [ ] `DeluluDetoxTests/Blocklist/BlocklistRepositorySuite.swift` — round-trip + atomic-write tests, scoped to a temp-directory container URL injected into the repository (NOT the real App Group)
- [ ] `DeluluDetoxTests/Blocklist/BlocklistUseCaseSuite.swift` — `Load`, `UpdateFromSelection`, `Remove`, `Reconcile` unit tests
- [ ] `DeluluDetoxTests/Blocklist/HomeViewModelSuite.swift` — Destination + intent tests for picker wiring
- [ ] `DeluluDetoxTests/Fixtures/family_activity_selection.sample.json` — on-device-captured sample `FamilyActivitySelection` serialized to JSON, committed as a stable Codable fixture (tokens are opaque blobs that cannot be synthesized in code)
- [ ] `DeluluDetoxTests/Fixtures/README.md` — short note explaining the fixture origin device + iOS version + refresh procedure

> Rationale for the JSON fixture: `ApplicationToken` / `WebDomainToken` / `ActivityCategoryToken` are opaque and cannot be constructed in unit tests. Capture a real selection once on a device with the entitlement (via a small debug path that writes `try JSONEncoder().encode(selection)` to disk), commit the bytes, and decode them in tests.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `FamilyActivityPicker` opens as a sheet and renders Apple's three tabs | SEL-01 / SEL-02 / SEL-03 | System UI requires real `family-controls` entitlement; simulator/sandbox token works for dev but picker rendering is Apple-controlled and not introspectable | On a device (or dev-entitled simulator), tap "Wybierz aplikacje do blokady" on empty `HomeView`, confirm Apple sheet appears with Apps / Categories / Web tabs, select 1 of each, dismiss |
| Selections persist across cold launches via App Group | SEL-04 | Real App Group container URL only resolves on a signed/provisioned build | After the previous step, force-quit the app, relaunch, confirm `BlockedView` shows all 3 rows (one per kind) |
| Token rotation reconcile runs on `scenePhase == .active` and records keep their UUIDs | SEL-05 | Token rotation is a system behavior that can't be provoked reliably; we verify the reconciliation hook runs + produces no crash + `Label(token)` still renders | Add log points in `ReconcileBlocklistUseCase` (remove before ship), background the app for >60s, foreground it, confirm log fires and no UI regressions; confirm `blocklists.json` UUIDs are unchanged across the cycle |
| `BlockedView` swipe-to-delete removes a row and re-persists | SEL-04 | Swipe gesture can be UI-tested but value/cost is low for MVP; manual is faster | In `BlockedView`, swipe a row left → full swipe → row disappears; force-quit, relaunch, confirm row is still gone |
| "Zmień wybór" reopens picker pre-seeded with current selection | SEL-01 / SEL-02 / SEL-03 | Picker rendering is Apple-controlled | With a populated blocklist, tap "Zmień wybór", confirm picker opens with the existing items pre-checked |
| Entitlement-missing fallback surfaces the alert and does not crash | (robustness) | Requires a build without the entitlement (expected during early dev / TestFlight rollout) | Build without `com.apple.developer.family-controls`, tap the primary CTA, confirm alert `Coś się popsuło / Nie udało się otworzyć wyboru aplikacji…` appears and app returns to `HomeView` cleanly |

---

## Validation Sign-Off

- [ ] All tasks have automated verify OR a row in Manual-Only (no orphan tasks)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (XCTest suites, fixture JSON)
- [ ] No watch-mode flags in commands
- [ ] Feedback latency < 30s for unit layer
- [ ] `nyquist_compliant: true` set in frontmatter (flip when audit passes)

**Approval:** pending
