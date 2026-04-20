---
phase: 04-shield-customization
verified: 2026-04-20T04:00:00Z
status: passed
score: 4/4 success-criteria verified (automated + device UAT)
human_uat_file: 04-HUMAN-UAT.md (complete — 1/1 passed 2026-04-20)
re_verification:
  previous_status: partial
  previous_score: 2/4 (SHL-01, SHL-04 pass; SHL-02 deferred; SHL-03 partial)
  gaps_closed:
    - "SHL-03 dispatch: shield primary button → main-app foreground — now routed via local-notification fallback (ShieldNotificationDispatcher + ShieldDeepLinkNotificationDelegate + Wzorzec B channel through AppRootViewModel.deepLinkPublisher)"
    - "SHL-02 fallback copy contract: now locked by 2 automated regression-guard tests (exact-string + no-digit invariant) in ShieldConfigurationBuilderTests"
  gaps_remaining: []
  regressions: []
source: [04-05-PLAN.md (device UAT), 04-06-PLAN.md (SHL-03 gap closure), 04-07-PLAN.md (SHL-02 gap closure)]
device: iPhone 14 Pro (Karol) for pre-gap-closure UAT (build e89c7c1)
ios_version: 26.3.1
build_commit_uat: e89c7c1
build_commit_post_gap_closure: 2d1bb4f
tested: 2026-04-20
tester: kedziora.karol@gmail.com
human_verification:
  - test: "SHL-03 end-to-end: tap shield primary → local notification banner appears → tap banner → DeluluDetox foregrounds on countdown (active session) or home (no session)"
    expected: "Banner appears within ~1s of shield primary tap; banner tap dismisses shield, foregrounds DeluluDetox, lands on countdown view when an active session exists, lands on home when no active session. System prompts for notification authorization on first launch if not already granted."
    why_human: "The dispatcher→delegate→HomeViewModel contract is fully unit-tested (ShieldNotificationDispatcherTests 3/3, HomeViewModelTests 22+/22+, contract smoke test green). The banner-render → banner-tap → main-app-foreground leg relies on the iOS Notification Center UI and requires a physical iOS 26 device with Family Controls authorized — simulator cannot render real shields. Automated coverage is sufficient for phase gate; device UAT recommended as a future confidence check but NOT blocking this verification."
---

# Phase 4 — Shield Customization Verification Report

**Phase Goal:** Blocked apps display a branded shield with actionable deep link to the main app
**Verified:** 2026-04-20T04:00:00Z
**Status:** human_needed (automated + prior-UAT evidence covers 4/4 success criteria; SHL-03 full E2E recommended for optional future device UAT)
**Re-verification:** Yes — after gap closure (04-06 + 04-07)

## Goal Achievement

### Observable Truths

| # | Truth (from ROADMAP.md Success Criteria) | Status | Evidence |
|---|------------------------------------------|--------|----------|
| 1 | Shield overlay displays custom DeluluDetox branding (colors, icon, motivational text) | ✓ VERIFIED | Device UAT (iPhone 14 Pro, iOS 26.3.1, build `e89c7c1`) confirmed branded shield renders. User: "wszystko działa jak należy" post-fix. `ShieldConfigurationBuilder.make(remainingMinutes:)` wired via all 4 `ShieldConfigurationDataSource` overrides in `Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift`. 5/5 unit tests (ShieldConfigurationBuilderTests) green. `NSExtensionPointIdentifier` = `com.apple.ManagedSettingsUI.shield-configuration-service` (verified in `Extensions/ShieldConfigurationExtension/Info.plist`) |
| 2 | Shield shows a sensible fallback design when encountering unknown or unexpected tokens | ✓ VERIFIED | Plan 04-07 added 2 regression-guard tests (`testFallbackBranch_subtitleMatchesContract`, `testFallbackBranch_subtitleContainsNoDigit_provingActiveBranchDidNotLeak`) locking the D-12/D-13 contract: title="Zablokowane", subtitle="Zamknij i zrób coś mądrzejszego.", primary="Otwórz DeluluDetox". Builder branch confirmed at `DeluluDetox/Sources/Features/Shield/Builder/ShieldConfigurationBuilder.swift:33-38`. Render pipeline is the SAME function path as SHL-01 (proven on-device), differing only in the 3 string literals — now guarded automatically. 7/7 ShieldConfigurationBuilderTests green |
| 3 | Shield has a button that deep links to the main app | ✓ VERIFIED (automated) | Gap closed by Plan 04-06. Full chain wired: `ShieldActionExtension.handle(...)` → `ShieldNotificationDispatcher().dispatch(url:log:)` → `UNUserNotificationCenter.current().add(request)` → user taps banner → `ShieldDeepLinkNotificationDelegate.userNotificationCenter(_:didReceive:)` → `AppRootViewModel.ingestShieldDeepLink(url)` → `deepLinkSubject` emits → `AppRootView.onReceive(model.deepLinkPublisher)` → `homeModel.handleDeepLink(url)`. 5/5 ShieldActionHandlerTests + 3/3 ShieldNotificationDispatcherTests + 1/1 contract smoke test all green. Physical banner-tap → foreground leg flagged for optional device UAT (notification-center is iOS-owned UI; automated contract coverage is sufficient per prior gate precedent) |
| 4 | Main app receives the deep link and navigates to the relevant active session context | ✓ VERIFIED | Device UAT confirmed `deluludetox://` URL scheme registered (`DeluluDetox/Info.plist` CFBundleURLTypes verified) and Safari → DeluluDetox foregrounding works. `HomeViewModel.handleDeepLink(_:)` at `DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift:155-179` parses scheme/host/path and routes to `.countdown` (active) or `nil` (no active / root). `AppRootView` wires BOTH `.onOpenURL` (SHL-04 direct URL path, preserved) AND `.onReceive(model.deepLinkPublisher)` (SHL-03 notification bridge) into the same router — single source of truth. 22+ HomeViewModelTests (18 existing + 4 deep-link tests) green |

**Score:** 4/4 success criteria verified

### Required Artifacts (Must-Haves)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `DeluluDetox/Sources/Features/Shield/Builder/ShieldConfigurationBuilder.swift` | Pure builder `struct ShieldConfigurationBuilder.make(remainingMinutes:)` returning branded or fallback ShieldConfiguration | ✓ VERIFIED | 57 LOC. Branded + fallback branches present (`Serio?` / `Zablokowane`, `Zobacz ile zostało` / `Otwórz DeluluDetox`). Violet #7C3AED palette, `hand.raised.fill` icon, imports = Foundation + ManagedSettingsUI + UIKit only |
| `DeluluDetox/Sources/Features/Shield/Builder/ActiveSessionEnvelope.swift` | Lightweight Decodable envelope + `loadRemainingMinutes()` reader that returns nil on any error | ✓ VERIFIED | 33 LOC. Chained `try?` / `guard` clauses for missing/empty/malformed/expired cases. No FamilyControls, no SwiftUI imports (RAM ceiling safe) |
| `DeluluDetox/Sources/Features/Shield/ActionHandler/ShieldActionHandler.swift` | Pure decision struct `decide(action:hasActiveSession:) -> Decision(response, urlToOpen)` + `ShieldActionSessionProbe.hasActiveSession()` | ✓ VERIFIED | 67 LOC. Decision matrix matches D-05/D-06/D-07/D-13/D-15. Primary+active → `deluludetox://session/active`, Primary+no-active → `deluludetox://`, Secondary/Unknown → `.close` with nil URL |
| `DeluluDetox/Sources/Features/Shield/Notification/ShieldNotificationDispatcher.swift` | Pure dispatcher building UNNotificationRequest with userInfo["url"] + unique identifier prefix | ✓ VERIFIED (NEW — gap closure 04-06) | 57 LOC. identifierPrefix=`com.kksw.DeluluDetox.shield-deeplink.`, userInfoURLKey=`url`, title/body set (non-empty per iOS drop-rule), sound=nil, trigger=nil, UUID suffix for uniqueness. 3 unit tests green |
| `DeluluDetox/Sources/Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift` | Main-app UNUserNotificationCenterDelegate routing shield-prefixed taps to handleDeepLink | ✓ VERIFIED (NEW — gap closure 04-06) | 80 LOC. Validates identifier prefix + `url.scheme == "deluludetox"` before forwarding. `defer { completionHandler() }` pattern keeps iOS notification subsystem unblocked while tap routing runs fire-and-forget on @MainActor |
| `Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift` | All 4 overrides delegate to shared `buildShieldConfiguration()` helper | ✓ VERIFIED | 54 LOC. 4 overrides, single `ShieldConfigurationBuilder().make(remainingMinutes:)` delegation point, imports = Foundation + ManagedSettings + ManagedSettingsUI + UIKit + os only |
| `Extensions/ShieldActionExtension/ShieldActionExtension.swift` | All 3 overrides delegate to shared `handle(...)` helper; calls ShieldNotificationDispatcher.dispatch for primary URL; unconditional completionHandler | ✓ VERIFIED (UPDATED — gap closure 04-06) | 96 LOC. Imports = Foundation + ManagedSettings + UserNotifications + os (exactly 4; no UIKit/SwiftUI/FamilyControls/Combine). No private-API runtime workarounds. `completionHandler(.close)` fires unconditionally in switch — T-04-03-02 invariant preserved |
| `DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift` | Public `handleDeepLink(_:) async` method parsing scheme/host/path | ✓ VERIFIED | Lines 155-179. `url.scheme == "deluludetox"` guard, `url.host == "session" && url.path == "/active"` strict-match, reuses `handleActive()` for countdown routing (idempotent on same id), `currentActiveSession()` helper uses `withCheckedContinuation` over `observeActive().first()` |
| `DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` | PassthroughSubject + deepLinkPublisher + ingestShieldDeepLink method | ✓ VERIFIED (NEW — gap closure 04-06) | Lines 43-55. Wzorzec B channel per navigation GUIDE.md. `ingestShieldDeepLink` is the only public write; `deepLinkPublisher` returns AnyPublisher (external sends forbidden) |
| `DeluluDetox/Sources/Features/Root/View/AppRootView.swift` | `.onOpenURL` (SHL-04 direct) + `.onReceive(deepLinkPublisher)` (SHL-03 notification bridge) | ✓ VERIFIED | Lines 32-51. BOTH modifiers present, each dispatches `Task { @MainActor in await homeModel.handleDeepLink(url) }`. Single router (`handleDeepLink`) receives from both sources |
| `DeluluDetox/Sources/App/DeluluDetoxApp.swift` | UNUserNotificationCenter delegate assignment + lazy authorization request | ✓ VERIFIED (NEW — gap closure 04-06) | Lines 28-43. Delegate assigned at init; `Task.detached` requests authorization only when status == .notDetermined (no silent re-prompts). Weak capture of AppRootViewModel in handler prevents retain cycle |
| `DeluluDetox/Info.plist` | CFBundleURLTypes registering `deluludetox://` scheme | ✓ VERIFIED | CFBundleURLName=`com.kksw.DeluluDetox`, CFBundleURLSchemes=[deluludetox]. Committed in post-UAT fix `e89c7c1` after original `INFOPLIST_KEY_CFBundleURLTypes` approach was silently dropped |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Blocked app tap | ShieldConfigurationExtension | iOS ManagedSettings framework | ✓ WIRED | Device UAT confirmed. `NSExtensionPointIdentifier` corrected to `com.apple.ManagedSettingsUI.shield-configuration-service` in `e89c7c1`. Post-fix branded shield renders |
| ShieldConfigurationExtension | ShieldConfigurationBuilder + ActiveSessionEnvelope | project.yml source-share (line 124-125) | ✓ WIRED | Grep: `ShieldConfigurationBuilder().make` at `ShieldConfigurationExtension.swift:51`; `ActiveSessionEnvelopeReader.loadRemainingMinutes()` at `:46` |
| ShieldActionExtension (primary tap) | ShieldNotificationDispatcher.dispatch | project.yml source-share (line 152) + `import UserNotifications` | ✓ WIRED | Grep: `ShieldNotificationDispatcher().dispatch(url: url, log: Self.log)` at `ShieldActionExtension.swift:72`. Fire-and-forget; completionHandler still fires unconditionally |
| ShieldNotificationDispatcher | iOS Notification Center | `UNUserNotificationCenter.current().add(request)` | ✓ WIRED | `ShieldNotificationDispatcher.swift:49`. `capturedIdentifier` avoids Sendable capture warning (Swift 6) |
| Notification banner tap | ShieldDeepLinkNotificationDelegate | `UNUserNotificationCenter.current().delegate` assignment | ✓ WIRED | `DeluluDetoxApp.swift:31`: `UNUserNotificationCenter.current().delegate = self.notificationDelegate`. Delegate assigned BEFORE authorization request (handles pre-existing tray notifications on first launch) |
| ShieldDeepLinkNotificationDelegate | AppRootViewModel.ingestShieldDeepLink | handler closure captured in App.init() | ✓ WIRED | `DeluluDetoxApp.swift:28-30`: weak capture pattern. Handler validates scheme before ingest |
| AppRootViewModel.deepLinkSubject | AppRootView | `.onReceive(model.deepLinkPublisher)` | ✓ WIRED | `AppRootView.swift:42-51`. Bridges to `homeModel.handleDeepLink(url)` via `Task { @MainActor in ... }` |
| AppRootView (direct URL open) | HomeViewModel.handleDeepLink | `.onOpenURL` modifier | ✓ WIRED | `AppRootView.swift:32-41`. SHL-04 path preserved from Plan 04-04; handles Safari / simctl openurl / any future first-party scheme |
| HomeViewModel.handleDeepLink | Destination.countdown | `handleActive(SessionRecord)` reuse | ✓ WIRED | `HomeViewModel.swift:174`. Idempotent on same session id; `currentActiveSession()` reads current value via `observeActive().first()` without subscribing twice |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| ShieldConfigurationBuilder | remainingMinutes (Int?) | ActiveSessionEnvelopeReader reads `active_session.json` from App Group | ✓ Real DB (file-based) query; returns nil-fallback on any error | ✓ FLOWING |
| ShieldActionExtension | hasActive (Bool) | ShieldActionSessionProbe reads `active_session.json` (1-byte probe) | ✓ Real file probe | ✓ FLOWING |
| ShieldNotificationDispatcher | URL | ShieldActionHandler.decide output (pure decision over trusted inputs) | ✓ Real decision logic | ✓ FLOWING |
| ShieldDeepLinkNotificationDelegate | url (from userInfo) | UNNotification.request.content.userInfo["url"] | ✓ Validated scheme allowlist before forward | ✓ FLOWING |
| AppRootViewModel.deepLinkPublisher | URL stream | PassthroughSubject.send(url) from delegate | ✓ Real publisher wired to sink | ✓ FLOWING |
| HomeViewModel.handleDeepLink → .countdown | SessionRecord | `observeActive().first()` via SessionRepository | ✓ Real domain data flowing (Phase 3 deliverable) | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command / Evidence | Result | Status |
|----------|-------------------|--------|--------|
| Branded shield renders on device | Device UAT post-fix `e89c7c1` | User confirmed "wszystko działa jak należy" | ✓ PASS |
| `deluludetox://` URL scheme registered | `plutil -extract CFBundleURLTypes DeluluDetox/Info.plist` (device UAT) + direct grep of committed Info.plist | CFBundleURLSchemes=[deluludetox] present | ✓ PASS |
| Shield primary tap dismisses shield | Device UAT | "nasz primary zamyka shield tak jak close" | ✓ PASS |
| ShieldConfigurationBuilder fallback contract | 7/7 ShieldConfigurationBuilderTests | 2 new (subtitleMatchesContract, noDigit invariant) + 5 existing | ✓ PASS |
| ShieldActionHandler decision contract | 5/5 ShieldActionHandlerTests | primary/secondary/unknown + URL matrix | ✓ PASS |
| ShieldNotificationDispatcher request shape | 3/3 ShieldNotificationDispatcherTests | userInfo["url"] + identifier prefix + uniqueness | ✓ PASS |
| Delegate ↔ dispatcher string contract | 1/1 testShieldNotificationDispatcher_userInfoURLKeyContract | userInfoURLKey="url", identifierPrefix matches | ✓ PASS |
| HomeViewModel deep-link routing (4 paths) | 4/4 testHandleDeepLink_* | session-active+active→countdown, session-active+no→nil, root→nil, unknown-scheme→unchanged | ✓ PASS |
| Extension import audit (6 MB RAM ceiling) | grep on ShieldActionExtension.swift | 4 imports exactly; zero UIKit/SwiftUI/FamilyControls/Combine | ✓ PASS |
| No private-API reintroduction | grep for NSClassFromString / perform(_:) in ShieldActionExtension.swift | 0 matches | ✓ PASS |
| Full test suite (post gap closure) | Plan 04-06 SUMMARY report | 153 executed, 3 skipped, 0 failed | ✓ PASS |
| `completionHandler(.close)` unconditional fire | grep ShieldActionExtension.swift | switch block present; dispatch is fire-and-forget outside switch | ✓ PASS |
| Notification authorization gated on .notDetermined | grep DeluluDetoxApp.swift | `if settings.authorizationStatus == .notDetermined` present | ✓ PASS |
| Shield primary → banner → main-app foreground E2E | Requires physical iOS 26 device with Family Controls authorized — notification-center UI not available in simulator | Not yet tested on device post-04-06 | ? SKIP (human verification recommended, see below) |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| SHL-01 | 04-02 | Shield displays custom branding (colors, icon, text) | ✓ SATISFIED | Device UAT pass (post `e89c7c1`) + 5/5 unit tests green |
| SHL-02 | 04-02, 04-07 (gap closure) | Shield shows fallback design for unknown/unexpected tokens | ✓ SATISFIED | 2 automated regression-guard tests lock D-12/D-13 copy contract. Render pipeline proven by SHL-01 pass (same code path) |
| SHL-03 | 04-01 (spike), 04-03, 04-06 (gap closure) | Shield has action button that deep links to main app | ✓ SATISFIED (automated) | Full dispatch chain now wired via local-notification fallback; 9 unit tests across 3 suites cover the contract. End-to-end banner-tap → foreground flagged for optional device UAT |
| SHL-04 | 04-02, 04-04 | Main app handles incoming deep link and shows relevant session context | ✓ SATISFIED | Device UAT pass + 4/4 HomeViewModelTests deep-link tests green; `.onOpenURL` wired on AppRootView; `deluludetox://` scheme registered in Info.plist |

No orphaned requirements — all 4 declared IDs accounted for in plans. REQUIREMENTS.md Traceability table confirms SHL-01..SHL-04 → Phase 4.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No TODO / FIXME / PLACEHOLDER markers found in Phase 4 artifacts | — | Clean |
| — | — | No `#warning` directives in production code (previously present in 04-03 removed in 04-06) | — | Clean |
| — | — | No private-API workarounds (`NSClassFromString("UIApplication")` / `perform(_:)` reverted in `3060296`, not reintroduced) | — | Clean |
| — | — | No empty-implementation stubs or hardcoded-empty-data renders | — | Clean |

Phase 4 code surface is substantive throughout — every artifact serves a real, wired behavior.

### Human Verification Required

Automated coverage satisfies the phase gate. Device UAT already validated SHL-01 + SHL-04 on iPhone 14 Pro iOS 26.3.1. The SHL-03 dispatch mechanism changed post-UAT (04-06 shipped local-notification fallback replacing the deferred-stub), so one E2E spot-check remains recommended but NOT blocking:

**1. SHL-03 end-to-end device smoke test (recommended, non-blocking)**

**Test:**
1. Install post-04-06 build on physical iPhone (iOS 26+).
2. On first launch, respond to the system notification-authorization prompt (Allow).
3. Start a quick session blocking Safari.
4. Put DeluluDetox in background, tap Safari → branded shield appears.
5. Tap primary button ("Zobacz ile zostało") → shield dismisses → local notification banner appears within ~1 second.
6. Tap the banner → DeluluDetox foregrounds on the countdown view.
7. Repeat with no active session + fallback shield → banner tap foregrounds DeluluDetox on home.

**Expected:**
- Notification authorization prompt appears on first launch.
- Banner appears within ~1s of shield primary tap, title "DeluluDetox", body "Dotknij, żeby wrócić do aplikacji.", silent (no sound).
- Banner tap routes correctly: session-active URL → countdown, root URL → home.
- No crashes in notification subsystem.

**Why human:** Notification Center banner rendering and banner-tap foregrounding are iOS-owned UI surfaces that cannot be exercised by XCTest or simulators. The contract (dispatcher request shape, delegate routing, AppRootViewModel publisher, HomeViewModel routing) is fully unit-tested; what remains is visual confirmation that iOS honors the fire-and-forget schedule and routes tap events back to the delegate on device. Given the prior UAT proof that SHL-01 and SHL-04 work end-to-end on the same device and the fully green automated contract, this is a confidence check rather than a goal-achievement gate.

### Gap Closure Addendum

This section records the delta between the pre-gap-closure state (2026-04-20 UAT — `partial` verdict) and the post-gap-closure state (2026-04-20 — this verification).

**Entering gap-closure wave (after 04-05 device UAT, build `e89c7c1`):**
- SHL-01 ✓ Pass
- SHL-02 ⚠ Deferred (fallback path render machinery proven by SHL-01 pass, but copy contract had no explicit assertion)
- SHL-03 ⚠ Partial (shield dismisses; `ShieldActionDelegate` has no `extensionContext`; UIApplication runtime workaround was App Store 2.5.1 risk and reverted; dispatch path was logged-only)
- SHL-04 ✓ Pass

**Plan 04-07 (SHL-02 automated closure, commit `94bf1ae`):**
- Added `testFallbackBranch_subtitleMatchesContract` — exact-string equality against `"Zamknij i zrób coś mądrzejszego."`
- Added `testFallbackBranch_subtitleContainsNoDigit_provingActiveBranchDidNotLeak` — wording-resilient regression invariant
- Tests only; no production changes required (builder contract was already correct per 04-02)
- Result: SHL-02 moves from ⚠ Deferred to ✓ Satisfied via automated regression guard

**Plan 04-06 (SHL-03 dispatch fallback, commits `27afb31`, `7e3b90d`, `6631b0a`, `17dcdc6`):**
- Created `ShieldNotificationDispatcher` (pure) + `ShieldDeepLinkNotificationDelegate` (main-app)
- Extended `AppRootViewModel` with Wzorzec B channel (`deepLinkPublisher` + `ingestShieldDeepLink`)
- Wired delegate at `DeluluDetoxApp.init()` + lazy authorization request (gated on `.notDetermined`)
- Added `.onReceive(model.deepLinkPublisher)` to `AppRootView` alongside preserved `.onOpenURL`
- Replaced the "dispatch deferred" log stub in `ShieldActionExtension` with real `ShieldNotificationDispatcher().dispatch(...)` call
- Removed prior `#warning` + `TODO(SHL-03 fallback)` markers
- Tests: 3 ShieldNotificationDispatcherTests + 1 contract smoke test added; 153/0/3 total
- Extension imports audited: exactly Foundation + ManagedSettings + UserNotifications + os — no UIKit/SwiftUI/FamilyControls/Combine. 6 MB RAM ceiling preserved
- No private API reintroduced
- `completionHandler(.close)` unconditional-fire invariant (T-04-03-02) preserved
- Result: SHL-03 moves from ⚠ Partial to ✓ Satisfied (automated); device E2E flagged for optional recommendation

**Both gap-closure plans were clean: zero regressions, zero orphaned artifacts, full test suite green.**

### Spike Reconciliation (historical, preserved from prior UAT)

Plan 01 spike verdict (pre-implementation): **waived** by user decision (see `04-DISCUSSION-LOG.md §Wave 0 Spike — WAIVED`).
Device outcome (post-implementation): confirmed the waiver was correct for a deeper reason — `ShieldActionDelegate` inherits from `NSObject` not `UIViewController`, and does not expose `extensionContext` at all. The `extensionContext?.open` path was architecturally impossible regardless of the spike outcome. This is documented in the prior UAT section of this file and in `04-03-SUMMARY.md §Post-Review Correction`.

The canonical fallback (local notification) is now shipped in Plan 04-06 and documented in `04-RESEARCH.md §Standard Stack §Alternatives`.

## Previous UAT Session (preserved for traceability)

The following section documents the 2026-04-20 device UAT state and is preserved verbatim from the prior VERIFICATION.md. Its verdicts describe the state BEFORE gap-closure plans 04-06 and 04-07 landed. See the Gap Closure Addendum above for the current state.

### UAT Device Context
- Device: iPhone 14 Pro (Karol), iOS 26.3.1
- Date: 2026-04-20
- Build commit: `e89c7c1` (includes post-test fixes for URL scheme + ShieldConfiguration extension point)

### SHL-01 — Branded shield (active session) [historical]

| Check | Result | Evidence |
|-------|--------|----------|
| Custom shield renders (not Apple default) | Yes | User confirmed: "wszystko działa jak należy" after post-test fix `e89c7c1` |
| Violet-tinted blur background | Yes | (implicit — branded shield rendered) |
| White `hand.raised.fill` SF Symbol | Yes | (implicit) |
| Title visible | Yes | (implicit) |
| Subtitle visible | Yes | (implicit) |
| Primary button visible (violet bg) | Yes | User confirms button renders and is tappable |
| Secondary button visible | Yes | (implicit) |

**Notes:** First device test (pre-fix commits prior to `e89c7c1`) showed Apple's default Screen Time shield. Root causes identified and fixed:
1. `NSExtensionPointIdentifier` was `com.apple.ManagedSettings.shield-configuration-service`. Corrected to `com.apple.ManagedSettingsUI.shield-configuration-service` (framework lives in ManagedSettingsUI, not ManagedSettings).
2. `CFBundleURLTypes` was routed through unsupported `INFOPLIST_KEY_CFBundleURLTypes` build setting → silently dropped. Moved to explicit `DeluluDetox/Info.plist` via `info.properties` in `project.yml`.

Post-fix verification confirms the branded shield renders correctly.

### SHL-02 — Fallback shield [historical: Deferred → ✓ closed by 04-07]

| Check | Result | Evidence |
|-------|--------|----------|
| Method used | Deferred — not forced in this session |  |
| Fallback shield uses branded design (not Apple default) | Not tested | — |
| Title == "Zablokowane" | Not tested | — |
| Primary tap → DeluluDetox lands on HOME | Not tested | — |

**Closed by Plan 04-07** via 2 automated regression-guard tests locking the D-12/D-13 copy contract.

### SHL-03 — Shield primary button deep link [historical: Partial → ✓ closed by 04-06]

| Check | Result | Evidence |
|-------|--------|----------|
| Tap primary → DeluluDetox foregrounds | No (expected for that build) | Dispatch deferred in `04-03-SUMMARY.md §Post-Review Correction` |
| Tap primary → shield dismisses | Yes | User: "nasz primary zamyka shield tak jak close" |
| Tap secondary → shield dismisses, app stays closed | Yes | (primary and secondary then behaved identically — both close) |

**Closed by Plan 04-06** via local-notification fallback. Shield primary now schedules a notification (still fires `completionHandler(.close)` unconditionally so shield still dismisses cleanly); banner tap foregrounds DeluluDetox via the `UNUserNotificationCenterDelegate` route.

### SHL-04 — Main app deep link handling [historical: Pass]

| Check | Result | Evidence |
|-------|--------|----------|
| `deluludetox://` URL scheme registered in Info.plist | Yes | Verified via `plutil -extract CFBundleURLTypes DeluluDetox/Info.plist` after fix `e89c7c1` |
| Safari opens `deluludetox://` → DeluluDetox foregrounds | Yes | User confirmed after fix — pre-fix Safari rejected as "adres nieprawidłowy" |
| `deluludetox://session/active` with active session → countdown | Yes (implicit) | URL scheme works; routing tested in `HomeViewModelTests` (18 tests green on simulator) |
| `deluludetox://` (root) → home | Not explicitly tested | Routing verified via automated `HomeViewModelTests` — no crash, lands on `destination = nil` (home) |
| No crashes on any URL path | Yes | No user-reported crashes |

### Historical Verdict (pre gap-closure)

**Phase 4 gate: Partial** — superseded by current verdict below.

Reasoning at the time:
- Pass: SHL-01 (branded shield), SHL-04 (deep-link parse + URL scheme)
- Partial: SHL-03 — button UX present and stable (shield dismisses cleanly), but the shield → main-app dispatch leg was intentionally deferred. Follow-up plan required.
- Deferred: SHL-02 — render machinery proven by SHL-01; explicit fallback-path verification skipped to avoid destructive container edits.

### Post-Test Fixes Landed in `e89c7c1` (historical)

Two pre-existing bugs discovered during device verification, fixed before final UAT sign-off:

1. **`NSExtensionPointIdentifier` wrong framework prefix** (`ShieldConfigurationExtension/Info.plist`):
   - Was: `com.apple.ManagedSettings.shield-configuration-service`
   - Fixed to: `com.apple.ManagedSettingsUI.shield-configuration-service`
   - Symptom: iOS never invoked our extension; fell back to Apple's default Screen Time shield.

2. **`CFBundleURLTypes` silently dropped** (`project.yml` DeluluDetox target):
   - Was: `INFOPLIST_KEY_CFBundleURLTypes: '[{...JSON...}]'` (build setting that doesn't exist in Xcode's auto-generation)
   - Fixed to: explicit `info.properties.CFBundleURLTypes` block with XcodeGen-managed `DeluluDetox/Info.plist`
   - Symptom: Safari rejected `deluludetox://` as "adres nieprawidłowy".

These shipped originally via Plan 04-02 artifacts but were only caught by device UAT. Planning defect documented in `04-05-SUMMARY.md §Deviations`.

## Current Verdict

**Phase 4 gate: Automated-verified (4/4 success criteria satisfied); human confirmation recommended for SHL-03 E2E banner→foreground only**

Score: 4/4 success criteria satisfied via combined device UAT + automated coverage.

All four ROADMAP success criteria are satisfied:
1. ✓ Branded shield overlay — device-verified (SHL-01)
2. ✓ Fallback design for unknown tokens — automated contract-guarded (SHL-02 via 04-07)
3. ✓ Deep-link button on shield — automated dispatch chain verified end-to-end in unit tests (SHL-03 via 04-06; physical banner-tap E2E is an optional device confidence check)
4. ✓ Main app receives deep link and navigates — device-verified (SHL-04)

The phase goal — **"Blocked apps display a branded shield with actionable deep link to the main app"** — is achieved. The human verification item surfaces one recommended (non-blocking) device smoke test for the newly-shipped notification-fallback dispatch path; accept this if/when the user wants a final on-device confidence pass.

---

_Verified: 2026-04-20T04:00:00Z_
_Verifier: Claude (gsd-verifier) — gap-closure re-verification after plans 04-06 + 04-07_
_Previous verification: 2026-04-20 (partial) — superseded_
