---
status: partial
phase: 04-shield-customization
source: [04-05-PLAN.md]
device: iPhone 14 Pro (Karol)
ios_version: 26.3.1
build_commit: e89c7c18c66fd020cc54cece727065e50bc401fa
tested: 2026-04-20
tester: kedziora.karol@gmail.com
---

# Phase 4 — Device Verification

**Device:** iPhone 14 Pro (Karol), iOS 26.3.1
**Date:** 2026-04-20
**Build commit:** `e89c7c1` (includes post-test fixes for URL scheme + ShieldConfiguration extension point)

## SHL-01 — Branded shield (active session)

| Check | Result | Evidence |
|-------|--------|----------|
| Custom shield renders (not Apple default) | Yes | User confirmed: "wszystko działa jak należy" after post-test fix `e89c7c1` |
| Violet-tinted blur background | Yes | (implicit — branded shield rendered) |
| White `hand.raised.fill` SF Symbol | Yes | (implicit) |
| Title visible | Yes | (implicit) |
| Subtitle visible | Yes | (implicit) |
| Primary button visible (violet bg) | Yes | User confirms button renders and is tappable |
| Secondary button visible | Yes | (implicit) |

**Notes:** First device test (pre-fix commits `e89c7c1`) showed Apple's default Screen Time shield ("Z ograniczeniem" / hourglass / single OK button). Root causes identified and fixed:
1. `NSExtensionPointIdentifier` was `com.apple.ManagedSettings.shield-configuration-service`. Corrected to `com.apple.ManagedSettingsUI.shield-configuration-service` (framework lives in ManagedSettingsUI, not ManagedSettings).
2. `CFBundleURLTypes` was routed through unsupported `INFOPLIST_KEY_CFBundleURLTypes` build setting → silently dropped. Moved to explicit `DeluluDetox/Info.plist` via `info.properties` in `project.yml`.

Post-fix verification confirms the branded shield renders correctly.

## SHL-02 — Fallback shield

| Check | Result | Evidence |
|-------|--------|----------|
| Method used | Deferred — not forced in this session |  |
| Fallback shield uses branded design (not Apple default) | Not tested | — |
| Title == "Zablokowane" | Not tested | — |
| Primary tap → DeluluDetox lands on HOME | Not tested | — |

**Notes:** SHL-02 requires a container-edit via Xcode Devices inspector to force the "unknown token" code path (Option B in plan). Deferred — render machinery proven by SHL-01 pass; the fallback branch in `ShieldConfigurationBuilder.make(remainingMinutes:)` has the same render pipeline. Flagged as a gap for `/gsd-verify-work` follow-up.

## SHL-03 — Shield primary button deep link

| Check | Result | Evidence |
|-------|--------|----------|
| Tap primary → DeluluDetox foregrounds | No (expected) | Dispatch deferred — see `04-03-SUMMARY.md §Post-Review Correction` |
| Tap primary → shield dismisses | Yes | User: "nasz primary zamyka shield tak jak close" |
| Tap secondary → shield dismisses, app stays closed | Yes | (primary and secondary now behave identically — both close) |

**Notes:** **Dispatch intentionally deferred.** `ShieldActionDelegate` does not expose `extensionContext`, and the private-API runtime workaround (`NSClassFromString("UIApplication")` → `sharedApplication` → `openURL:`) is an App Store rejection pattern (Guideline 2.5.1) that was reverted during plan 04-03 post-review. Current behavior: decision logic runs, URL is logged, `completionHandler(.close)` fires unconditionally.

Follow-up gap-closure plan required: local-push-notification fallback (UNNotificationRequest from extension → UNUserNotificationCenterDelegate in main app → HomeViewModel.handleDeepLink). Scheduled as Phase 4.1 or Phase 5 addition.

## SHL-04 — Main app deep link handling

| Check | Result | Evidence |
|-------|--------|----------|
| `deluludetox://` URL scheme registered in Info.plist | Yes | Verified via `plutil -extract CFBundleURLTypes DeluluDetox/Info.plist` after fix `e89c7c1` |
| Safari opens `deluludetox://` → DeluluDetox foregrounds | Yes | User confirmed after fix — pre-fix Safari rejected as "adres nieprawidłowy" |
| `deluludetox://session/active` with active session → countdown | Yes (implicit) | URL scheme works; routing tested in `HomeViewModelTests` (18 tests green on simulator) |
| `deluludetox://` (root) → home | Not explicitly tested | Routing verified via automated `HomeViewModelTests` — no crash, lands on `destination = nil` (home) |
| No crashes on any URL path | Yes | No user-reported crashes |

## Verdict

**Phase 4 gate: Partial**

Reasoning:
- **Pass:** SHL-01 (branded shield), SHL-04 (deep-link parse + URL scheme)
- **Partial:** SHL-03 — button UX present and stable (shield dismisses cleanly), but the shield → main-app dispatch leg is intentionally deferred. Follow-up plan required.
- **Deferred:** SHL-02 — render machinery proven by SHL-01; explicit fallback-path verification skipped to avoid destructive container edits.

### Failing / Deferred Requirements

| Requirement | Status | Disposition |
|-------------|--------|-------------|
| SHL-02 | Deferred | Document gap — flag for `/gsd-verify-work`. Not a code bug; verification step skipped. |
| SHL-03 | Partial (dispatch deferred) | **Code follow-up needed** — schedule Phase 4.1 or Phase 5 plan for local-push-notification fallback. |

## Spike reconciliation

Plan 01 Verdict (pre-implementation): **waived** (user decided a priori — see `04-DISCUSSION-LOG.md §Wave 0 Spike — WAIVED`)
Device outcome (post-implementation): **confirms the waiver was correct for a different reason**

Key insight: The spike was intended to verify whether `extensionContext?.open(_:)` works from `ShieldActionDelegate`. Plan 04-03 execution discovered the more fundamental truth: `ShieldActionDelegate` inherits from `NSObject` (not `UIViewController`) and **does not expose `extensionContext` at all**. The spike's entire premise was therefore moot; no version of the `extensionContext.open` approach could have worked from this class hierarchy.

This confirms the broader research conclusion: shield → main-app routing from a `ShieldActionDelegate` requires a non-UIApplication mechanism. Local push notification is the canonical fallback, documented in `04-RESEARCH.md` and now deferred to a follow-up plan.

## Post-Test Fixes Landed in `e89c7c1`

Two pre-existing bugs discovered during device verification, fixed before final UAT sign-off:

1. **`NSExtensionPointIdentifier` wrong framework prefix** (`ShieldConfigurationExtension/Info.plist`):
   - Was: `com.apple.ManagedSettings.shield-configuration-service`
   - Fixed to: `com.apple.ManagedSettingsUI.shield-configuration-service`
   - Symptom: iOS never invoked our extension; fell back to Apple's default Screen Time shield.

2. **`CFBundleURLTypes` silently dropped** (`project.yml` DeluluDetox target):
   - Was: `INFOPLIST_KEY_CFBundleURLTypes: '[{...JSON...}]'` (build setting that doesn't exist in Xcode's auto-generation)
   - Fixed to: explicit `info.properties.CFBundleURLTypes` block with XcodeGen-managed `DeluluDetox/Info.plist`
   - Symptom: Safari rejected `deluludetox://` as "adres nieprawidłowy".

These were shipped as Plan 04-02 artifacts originally; Plan 04-02's SUMMARY incorrectly claimed the `INFOPLIST_KEY_CFBundleURLTypes` variant "landed". Real verification came through device testing and should have been caught earlier by a device smoke-test in Plan 04-02's acceptance criteria.
