---
phase: 04
slug: shield-customization
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-19
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

> Detailed validation architecture, test list, and manual QA steps live in
> `04-RESEARCH.md` (`## Validation Architecture`). This file is the
> orchestrator-facing contract — the planner fills it in during planning.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (DeluluDetoxTests target) |
| **Config file** | `project.yml` (XcodeGen) — DeluluDetoxTests target |
| **Quick run command** | `XcodeBuildMCP test_sim` (scoped to changed test class via `-only-testing:`) |
| **Full suite command** | `XcodeBuildMCP test_sim` (DeluluDetox scheme) |
| **Estimated runtime** | ~30–60 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run scoped `test_sim` for the touched test file
- **After every plan wave:** Run full `test_sim` on DeluluDetox scheme
- **Before `/gsd-verify-work`:** Full suite must be green AND device manual QA recorded
- **Max feedback latency:** ~60 seconds (sim-only); device manual QA is out-of-band

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-T1 | 01 | 0 | SHL-03 | T-04-01-01..04 | Spike documents extensionContext.open(_:) verdict on iOS 26 device; spike artifacts not committed | manual + grep | `grep -c "## Wave 0 Spike Result" .planning/phases/04-shield-customization/04-DISCUSSION-LOG.md` | ✅ Plan 01 | ⬜ pending |
| 04-01-T2 | 01 | 0 | SHL-01..04 | T-04-01-04 | XCTest scaffolds for ShieldConfigurationBuilder/Handler + HomeViewModel deep-link compile and skip cleanly | unit (skipped) | `XcodeBuildMCP test_sim --scheme DeluluDetox` (full suite green, +14 skipped) | ✅ Plan 01 | ⬜ pending |
| 04-02-T1 | 02 | 1 | SHL-01, SHL-02, SHL-04 | T-04-02-01,02,06 | URL scheme registered; ShieldConfigurationBuilder + ActiveSessionEnvelope cover active + fallback branches | unit | `XcodeBuildMCP test_sim --scheme DeluluDetox -only-testing:DeluluDetoxTests/ShieldConfigurationBuilderTests` (5 passed) | ✅ Plan 02 | ⬜ pending |
| 04-02-T2 | 02 | 1 | SHL-01, SHL-02 | T-04-02-03,05 | Extension's 4 overrides delegate to shared helper; imports limited to Foundation+UIKit+ManagedSettings+ManagedSettingsUI+os | build + grep | `XcodeBuildMCP build_sim --scheme DeluluDetox && grep -c "^import FamilyControls$" Extensions/ShieldConfigurationExtension/*.swift` (returns 0) | ✅ Plan 02 | ⬜ pending |
| 04-03-T1 | 03 | 2 | SHL-03 | T-04-03-04 | ShieldActionHandler pure decision struct turns 5 unit tests green | unit | `XcodeBuildMCP test_sim --scheme DeluluDetox -only-testing:DeluluDetoxTests/ShieldActionHandlerTests` (5 passed) | ✅ Plan 03 | ⬜ pending |
| 04-03-T2 | 03 | 2 | SHL-03 | T-04-03-02,06 | Extension wires extensionContext.open inside if-let; completionHandler always fires; imports limited to Foundation+ManagedSettings+os | build + grep | `XcodeBuildMCP build_sim --scheme DeluluDetox && grep -c "extensionContext?.open" Extensions/ShieldActionExtension/*.swift` (returns 1) | ✅ Plan 03 | ⬜ pending |
| 04-04-T1 | 04 | 1 | SHL-04 | T-04-04-01,02,06 | HomeViewModel.handleDeepLink validates scheme/host/path strictly; reads currentActiveSession via withCheckedContinuation; never mutates session state | unit | `XcodeBuildMCP test_sim --scheme DeluluDetox -only-testing:DeluluDetoxTests/HomeViewModelTests` (4 new + existing pass) | ✅ Plan 04 | ⬜ pending |
| 04-04-T2 | 04 | 1 | SHL-04 | T-04-04-03 | AppRootView.onOpenURL → homeModel.handleDeepLink wiring | build + grep | `XcodeBuildMCP build_sim --scheme DeluluDetox && grep -c ".onOpenURL { url in" DeluluDetox/Sources/Features/Root/View/AppRootView.swift` (returns 1) | ✅ Plan 04 | ⬜ pending |
| 04-05-T1 | 05 | 3 | SHL-01..04 | T-04-05-01 | Device verification of all 4 SHL requirements; VERIFICATION.md populated | manual | `grep -c "^## SHL-" .planning/phases/04-shield-customization/04-VERIFICATION.md` (returns 4) | ✅ Plan 05 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Wave 0 spike task — assigned to Plan 01 Task 1 (extensionContext.open device check); marked `autonomous: false`
- [x] XCTest stubs for ShieldConfigurationBuilder, ShieldActionHandler, HomeViewModel deep-link — assigned to Plan 01 Task 2 (3 files, all initially XCTSkip)
- [x] App-Group read helpers — `ActiveSessionEnvelope` (Plan 02) + `ShieldActionSessionProbe` (Plan 03) source-shared into both extension targets via project.yml

Plans 02–04 turn the XCTSkip stubs into real assertions as their respective implementations land.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Shield overlay actually renders for blocked app | SHL-01, SHL-02 | ManagedSettings shield runs only on a real device with FamilyControls authorization; simulator does not render | Install on device, start a session blocking a known app (e.g. Safari), tap the blocked app icon, verify branded shield appears with correct title/icon/colors |
| Shield "Open DeluluDetox" button opens main app to active session | SHL-03, SHL-04 | `extensionContext?.open(_:)` is device-only and unsupported by Apple DTS — must be verified on hardware | Tap the primary button on the shield, confirm DeluluDetox opens and lands on the countdown view for the active session |
| Fallback shield renders for unresolved tokens | SHL-02 | Requires injecting an unknown token, only reproducible on device with Screen Time | Manually trigger fallback path, verify generic branded shield appears (no crash, no Apple default) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (manual-only tasks must be flanked by automated ones where possible)
- [ ] Wave 0 covers all MISSING references (extensionContext spike + XCTest stubs)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s on simulator
- [ ] `nyquist_compliant: true` set in frontmatter once planner fills the verification map

**Approval:** pending
