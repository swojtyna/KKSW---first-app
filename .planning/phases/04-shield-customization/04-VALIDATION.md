---
phase: 04
slug: shield-customization
status: draft
nyquist_compliant: false
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
| TBD | TBD | TBD | SHL-01..04 | — | TBD | unit / manual | TBD | ❌ W0 | ⬜ pending |

*Planner fills this in based on RESEARCH.md `## Validation Architecture`.*

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Wave 0 spike task: verify `extensionContext?.open(_:)` works from `ShieldActionDelegate` on a physical device (per RESEARCH.md, `context.openApp(URL)` does not exist; this workaround is unofficial)
- [ ] XCTest stubs for shield-config builder, deep-link URL encoder/decoder, fallback selection logic
- [ ] App-Group read helpers stubbed in extension target sources

*Planner refines based on RESEARCH.md `## Validation Architecture`.*

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
