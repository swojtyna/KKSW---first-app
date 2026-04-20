---
phase: 04-shield-customization
plan: 06
subsystem: shield
tags: [shield, notification, deep-link, SHL-03, gap-closure]
requirements: [SHL-03]
status: complete
completed: 2026-04-20
dependency_graph:
  requires:
    - ShieldActionHandler (from 04-03) — pure decision logic producing `urlToOpen`
    - HomeViewModel.handleDeepLink (from 04-04) — scheme + path validation
    - AppRootView.onOpenURL wiring (from 04-04) — existing SHL-04 path, preserved
  provides:
    - ShieldNotificationDispatcher — pure builder + dispatcher for shield → main-app notifications
    - ShieldDeepLinkNotificationDelegate — main-app UNUserNotificationCenterDelegate
    - AppRootViewModel.deepLinkPublisher / ingestShieldDeepLink — Wzorzec B channel
    - ShieldActionExtension dispatch wiring — no more "deferred" stub
  affects:
    - project.yml — ShieldActionExtension sources: add ShieldNotificationDispatcher.swift
    - DeluluDetoxApp — owns notificationDelegate + lazy authorization request
    - AppRootView — .onReceive(deepLinkPublisher) alongside .onOpenURL
tech_stack:
  added:
    - UserNotifications (system framework, already available; new import in extension + app)
  patterns:
    - Wzorzec B (child-event → parent-publisher → sibling-sink) per navigation GUIDE.md §B
    - Fire-and-forget notification scheduling — T-04-03-02 pattern retained
key_files:
  created:
    - DeluluDetox/Sources/Features/Shield/Notification/ShieldNotificationDispatcher.swift (57 LOC)
    - DeluluDetox/Sources/Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift (80 LOC)
    - DeluluDetoxTests/Features/Shield/ShieldNotificationDispatcherTests.swift (76 LOC)
  modified:
    - Extensions/ShieldActionExtension/ShieldActionExtension.swift (+15 / -17 LOC — swap stub for real dispatch + new import)
    - DeluluDetox/Sources/App/DeluluDetoxApp.swift (+26 / -2 LOC — delegate wiring + authorization)
    - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift (+14 LOC — publisher + ingest method)
    - DeluluDetox/Sources/Features/Root/View/AppRootView.swift (+10 LOC — .onReceive modifier)
    - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift (+23 LOC — contract smoke test)
    - project.yml (+1 LOC — source-share ShieldNotificationDispatcher into ShieldActionExtension)
decisions:
  - "Local notification fallback over private-API UIApplication runtime tricks — App Store 2.5.1 safe, canonical for shield extensions per RESEARCH.md Standard Stack §Alternatives."
  - "Wzorzec B (PassthroughSubject on AppRootViewModel + .onReceive on AppRootView) chosen over promoting homeModel to AppRootViewModel ownership — minimal churn, follows navigation GUIDE.md §B."
  - "Contract smoke test (userInfoURLKey = \"url\" + identifierPrefix) added instead of duplicating existing Plan 04-04 deep-link tests A/B/C — coverage over count."
  - "completionHandler fires via `defer` in the delegate instead of inside the Task — Swift 6 strict-concurrency non-Sendable closure avoidance while keeping tap routing fire-and-forget."
  - "Dispatcher captures request.identifier as a local Sendable String before the UN add closure — avoids non-Sendable UNNotificationRequest capture warning without a @preconcurrency import."
metrics:
  duration_minutes: 12
  tasks_completed: 3
  commits: 4
  tests_added: 4
  tests_total: 153
  tests_failed: 0
  tests_skipped: 3
---

# Phase 04 Plan 06: Shield → Main-App Dispatch Fallback (SHL-03 Gap Closure)

One-liner: Ships the only App Store–compliant path from shield primary button to main-app foreground — shield extension schedules a local `UNNotificationRequest`, main app's `UNUserNotificationCenterDelegate` translates the banner tap into `HomeViewModel.handleDeepLink(_:)`.

## Objective (What We Built)

Close SHL-03 dispatch gap flagged by Phase 4 device UAT (build `e89c7c1`): "Shield primary button dismisses but DeluluDetox never foregrounds." `ShieldActionDelegate` inherits from `NSObject` (not `UIViewController`) and exposes no `extensionContext`; the UIApplication runtime workaround is App Store Guideline 2.5.1 rejection risk and was reverted in commit `3060296`.

Shipped path: extension → `UNUserNotificationCenter.add(request)` with `userInfo["url"]: String` → user taps banner → `ShieldDeepLinkNotificationDelegate.userNotificationCenter(_:didReceive:)` → `AppRootViewModel.ingestShieldDeepLink(url)` → `PassthroughSubject` emits → `AppRootView.onReceive` → `homeModel.handleDeepLink(url)` → existing Plan 04-04 routing.

## Commits

| Task  | Commit    | Message                                                                      |
| ----- | --------- | ---------------------------------------------------------------------------- |
| 1 RED | `27afb31` | test(04-06): add failing ShieldNotificationDispatcher tests                  |
| 1 GREEN | `7e3b90d` | feat(04-06): add ShieldNotificationDispatcher + notification delegate      |
| 2     | `6631b0a` | feat(04-06): wire notification delegate at App launch + deep-link subject    |
| 3     | `17dcdc6` | feat(04-06): wire ShieldActionExtension dispatch to ShieldNotificationDispatcher |

## Extension Import Audit

```
$ grep "^import " Extensions/ShieldActionExtension/ShieldActionExtension.swift
import Foundation
import ManagedSettings
import UserNotifications
import os

$ grep -c "^import " Extensions/ShieldActionExtension/ShieldActionExtension.swift
4

$ grep -Ec "^import (FamilyControls|SwiftUI|Combine|UIKit)$" Extensions/ShieldActionExtension/ShieldActionExtension.swift
0
```

Import surface: exactly 4 (`Foundation + ManagedSettings + UserNotifications + os`). No UIKit, no SwiftUI, no FamilyControls, no Combine. 6 MB RAM ceiling (D-17, PROJECT.md Hard Constraint §8) preserved.

## Test-Suite Result

```
Test Suite 'All tests' passed at 2026-04-20 03:23:01.
Executed 153 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.537 seconds
** TEST SUCCEEDED **
```

- Baseline entering plan: 148 (Plan 04-04 ran 144 + Plan 04-07 added 4 SHL-02 fallback tests in commit `94bf1ae`). 3 skipped tests are inherited from baseline (unchanged).
- New tests added here: 4
  - 3 in `ShieldNotificationDispatcherTests` (Task 1 dispatcher builder + userInfo + identifier uniqueness)
  - 1 in `HomeViewModelTests.testShieldNotificationDispatcher_userInfoURLKeyContract` (Task 2 smoke test)
- Total after plan: 148 (baseline on-disk, 1 extra came from prior count drift — see Deviations §D1) + 4 = 153 executed, 3 skipped, 0 failed ≥ 148 gate.

## Acceptance Criteria Check

| Criterion                                                                   | Result                                         |
| --------------------------------------------------------------------------- | ---------------------------------------------- |
| SHL-03 dispatch path ships in production (no `#warning`/`TODO` markers)     | PASS — greps return 0                          |
| `ShieldNotificationDispatcher` source-shared into `ShieldActionExtension`   | PASS — 2 `in Sources` refs in pbxproj          |
| `ShieldDeepLinkNotificationDelegate` assigned at `DeluluDetoxApp.init()`    | PASS — `UNUserNotificationCenter.current().delegate =` present |
| Notification authorization requested lazily on `.notDetermined`             | PASS — `Task.detached` with explicit gate      |
| `AppRootViewModel.deepLinkPublisher` + `ingestShieldDeepLink(_:)` wired     | PASS                                           |
| `AppRootView.onReceive(model.deepLinkPublisher)` bridges to `homeModel.handleDeepLink` | PASS — preserves existing `.onOpenURL`  |
| Extension import surface = Foundation + ManagedSettings + UserNotifications + os | PASS — 4 imports, forbidden list = 0    |
| Full suite ≥148 tests, 0 failed                                             | PASS — 153 executed, 0 failed                  |
| `completionHandler(.close)` unconditional-fire invariant preserved          | PASS — switch block unchanged at lines 75-82   |
| No private API reintroduced (`NSClassFromString("UIApplication")` / `perform(_:)`) | PASS — grep returns 0                     |
| ≥3 new unit tests covering dispatcher + delegate contract                   | PASS — 3 dispatcher tests + 1 contract test    |

## Deviations from Plan

### D1. Test count bookkeeping

- **Type:** Informational (not a rule-driven fix).
- **Found during:** Task 3 verification.
- **Observation:** The plan predicted `≥148` tests (baseline 144 + 3 dispatcher + ≥1 contract). Actual count: 153 executed. The extra 2 tests come from the Plan 04-07 commit `94bf1ae` already in the base (SHL-02 fallback tests) plus one additional baseline drift from prior plans.
- **Action:** None — well above the `≥148` gate. Documented here for traceability.

### D2. Swift 6 strict-concurrency fix in delegate

- **Type:** Rule 1 — bug (blocker on build).
- **Found during:** Task 1 GREEN build.
- **Issue:** Swift 6 flagged `sending 'completionHandler' risks causing data races` when the plan's literal snippet placed `completionHandler()` inside the `Task { @MainActor [handler, log] in ... }` block. The system-framework closure is `@Sendable` but carrying it across isolation boundaries trips the strict check.
- **Fix:** `defer { completionHandler() }` at the top of the delegate method; all branches (guard, invalid-URL, happy path) fall through to the deferred call. The tap routing (log + `handler(url)`) still runs fire-and-forget on `@MainActor`, so the UX contract is identical.
- **Files modified:** `DeluluDetox/Sources/Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift`
- **Commit:** `7e3b90d`

### D3. Dispatcher identifier capture

- **Type:** Rule 1 — bug (warning → error under strict concurrency).
- **Found during:** Task 1 GREEN build.
- **Issue:** `UNNotificationRequest` is not `Sendable` in iOS 26 SDK; capturing `request` into the `UNUserNotificationCenter.add(_:)` completion closure emitted a warning that escalates under strict concurrency.
- **Fix:** Capture `request.identifier` into a local `let capturedIdentifier = request.identifier` (pure `String`, `Sendable`) before the closure. Log uses the local instead of `request.identifier`.
- **Files modified:** `DeluluDetox/Sources/Features/Shield/Notification/ShieldNotificationDispatcher.swift`
- **Commit:** `7e3b90d`

### D4. HomeViewModel test contract-only (per plan guidance)

- **Type:** Informational — explicit plan option B taken.
- **Observation:** Plan 04-04 already shipped 4 `testHandleDeepLink_*` tests covering Cases A/B/C identically. Plan explicitly authorized skipping duplicates: *"If existing 4 tests already cover Cases A/B/C identically, add ONLY the smoke check … ensures the string contract between extension and delegate never drifts."*
- **Action:** Added only `testShieldNotificationDispatcher_userInfoURLKeyContract` asserting `userInfoURLKey == "url"` and `identifierPrefix == "com.kksw.DeluluDetox.shield-deeplink."`.

## Authentication Gates

None encountered — this plan is automation-only.

## Threat Flags

No new security surface outside the plan's `<threat_model>`. Local `UNNotificationRequest` scheduling is inside the same bundle ID, validated on receive (scheme allowlist), and downstream routing reuses the hardened `HomeViewModel.handleDeepLink` path from Plan 04-04.

## Next Phase Readiness

**Phase 4.1 UAT on device** (manual, deferred gate):

1. Install build on iPhone 14 Pro (iOS 26.3.1) via `build_run_dev`.
2. On first launch: system prompts for notification authorization.
3. Start a quick session blocking Safari.
4. Tap Safari → shield appears.
5. Tap shield primary button → shield dismisses → local notification banner appears within ~1s.
6. Tap banner → DeluluDetox foregrounds on countdown (active session) or home (no session).

SHL-03 moves from **Partial** (shield dismisses but no foreground) → **Pass** if device test confirms the banner → foreground path.

## Known Stubs

None. All code paths wire real behaviour; no placeholder data, no empty props flowing into UI.

## Self-Check: PASSED

Files verified on disk:
- FOUND: `DeluluDetox/Sources/Features/Shield/Notification/ShieldNotificationDispatcher.swift`
- FOUND: `DeluluDetox/Sources/Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift`
- FOUND: `DeluluDetoxTests/Features/Shield/ShieldNotificationDispatcherTests.swift`

Commits verified in `git log`:
- FOUND: `27afb31` (RED)
- FOUND: `7e3b90d` (GREEN dispatcher + delegate)
- FOUND: `6631b0a` (App wiring)
- FOUND: `17dcdc6` (Extension dispatch)
