---
phase: 1
slug: foundation-onboarding
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | project.yml (XcodeGen) |
| **Quick run command** | `xcodebuild test -scheme DeluluDetox -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Full suite command** | `xcodebuild test -scheme DeluluDetox -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | ONB-01 | — | N/A | manual | Simulator launch + visual check | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | ONB-02 | — | N/A | manual | Device-only (AuthorizationCenter) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | ONB-03 | — | N/A | manual | Device-only (deny + retry) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extension targets compile and link correctly
- [ ] App Group entitlement present in all targets
- [ ] Build succeeds on simulator (UI tests deferred — Screen Time API requires device)

*Note: Screen Time authorization (`AuthorizationCenter.requestAuthorization(for: .individual)`) always fails on simulator (Code=2). ONB-02 and ONB-03 require physical device verification.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Explanation screen visible on launch | ONB-01 | UI visual check | Launch app → verify explanation screen appears with SF Symbol, headline, and "Grant Access" button |
| System Screen Time prompt appears | ONB-02 | Requires device + system dialog | Tap "Grant Access" → verify system authorization prompt appears (device only) |
| Denial screen with retry | ONB-03 | Requires device + deny flow | Deny permission → verify non-dismissible denial screen with retry button appears |
| App Group accessible from extensions | SC-5 | Requires multi-target build verification | Build all 4 targets → verify shared container accessible |

*Note: All Screen Time behaviors require physical device testing.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
