---
phase: 06-engagement-layer
fixed_at: 2026-04-21T01:30:30Z
review_path: .planning/phases/06-engagement-layer/06-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-04-21T01:30:30Z
**Source review:** `.planning/phases/06-engagement-layer/06-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (Critical + Warning)
- Fixed: 3
- Skipped: 0

All three Warning findings (WR-01/02/03) were fixed. Zero Critical findings in this review. Info findings (IN-01 through IN-06) are out of scope per `fix_scope: critical_warning`.

Build verification: `** BUILD SUCCEEDED **` on iPhone 17 simulator (iOS 26.3.1). Test verification: `** TEST SUCCEEDED **` running `AppNotificationDelegateTests` + `HomeViewModelTests` (all 24 test cases pass, including `testStatsCardDestination_isIdentityEquatable` which pins the WR-03 contract).

## Fixed Issues

### WR-01: `HomeView` recreates `StatsViewModel` on every render for tab 3

**Files modified:** `DeluluDetox/Sources/Features/Home/View/HomeView.swift`
**Commit:** `2b2de89`
**Applied fix:** Added `@State private var statsTabModel = StatsViewModel()` at line 9 of `HomeView` (alongside existing `blockedModel` and `scheduleListModel` `@State`s), and changed the `tabContent` switch's `case 3:` branch from `StatsView(model: StatsViewModel())` to `StatsView(model: statsTabModel)`. The Stats tab now owns its VM via `@State` like siblings `blockedModel` / `scheduleListModel`, so the Combine pipeline in `StatsViewModel.init()` is built exactly once per view identity. Month picker state and `stats` projection now survive SwiftUI body re-evaluations. Matches the `tabContent` property's documented promise ("Each tab owns its state via @State in HomeView so switching back preserves scroll position / edited fields"). `HomeViewModel.statsCardTapped()` (line 169) is left unchanged — allocating a fresh `StatsViewModel` for the pushed (navigation-destination) Stats screen is intentional and out of scope for WR-01 (see WR-03 for the intent doc there).

### WR-02: `_SendableUserInfo` `@unchecked Sendable` box hides arbitrary non-Sendable values

**Files modified:** `DeluluDetox/Sources/Features/Notifications/Notification/AppNotificationDelegate.swift`, `DeluluDetoxTests/Features/Notifications/AppNotificationDelegateTests.swift`
**Commit:** `870e8ec`
**Applied fix:** Narrowed the cross-actor payload from the raw `[AnyHashable: Any]` dictionary to the single `String?` value the dispatcher actually needs. Changes:

1. Removed the `_SendableUserInfo: @unchecked Sendable` private struct at the bottom of `AppNotificationDelegate.swift`.
2. Refactored `nonisolated func userNotificationCenter(_:didReceive:withCompletionHandler:)` to extract `urlString: String?` from `userInfo[ShieldNotificationConstants.userInfoURLKey]` synchronously on the nonisolated queue before hopping to `@MainActor` via `Task`. Only the Sendable `String?` crosses the actor boundary.
3. Renamed the `dispatchResponse(identifier:userInfo:)` test seam to `dispatchResponse(identifier:urlString:)` — the shield-deeplink branch now takes the pre-extracted optional string and retains the same URL/scheme validation (`URL(string:)` + `scheme == "deluludetox"`).
4. Updated all 5 call-sites in `AppNotificationDelegateTests.swift` to pass `urlString: "deluludetox://shield"` (or `"https://example.com"` / `nil`) instead of `userInfo: ["url": ...]` / `[:]`.
5. Updated the doc comment on `dispatchResponse(_:_:)` to explain why the signature takes `String?` instead of the raw dictionary.

No `@unchecked Sendable` promise remains in this file. Future call-sites that need richer payloads must extract the exact Sendable subset they need at the nonisolated-to-MainActor boundary, rather than boxing the whole dictionary.

Note: This is a signature change on an `internal` test seam. No production callers other than the nonisolated `didReceive` forwarder above exist (verified via Grep across the whole repo — only `06-REVIEW.md` and historical planning docs reference the old signature, neither is build-relevant).

### WR-03: `HomeViewModel.Destination.stats` identity equality breaks re-navigation semantics

**Files modified:** `DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift`
**Commit:** `ead5dac`
**Applied fix:** Documented the intent of `.stats` identity equality as BY DESIGN on the `Destination.==` implementation. Per the reviewer's guidance — "Decide intent and document it explicitly" — and given the existing test `testStatsCardDestination_isIdentityEquatable` (HomeViewModelTests.swift:403-408) already pins "two distinct VMs are != by identity" as the contract, the fresh-VM-per-tap behavior is the intentional GAM-01/02 UX (month picker resets on each push). Added an 11-line comment block above `static func ==` that:

1. States explicitly that `.stats` identity equality is intentional.
2. Links the test `testStatsCardDestination_isIdentityEquatable` as the pinned contract.
3. Explains that `statsCardTapped()` allocates a fresh `StatsViewModel()` per tap, producing the `a !== b` behavior.
4. Documents the alternative path (if persistent state is desired later): hoist the VM to `@State` on HomeView — note this is the same pattern WR-01 introduced for `statsTabModel` in the tab path — pass it into a modified `statsCardTapped(_:)`, and switch `.stats` to structural `==` on the VM's Equatable projection.
5. Keeps the behavioral code unchanged (no VM lifecycle churn introduced).

This resolves the footgun flagged by the reviewer (implicit intent → explicit intent) without making a behavior change that would contradict the existing test contract.

---

_Fixed: 2026-04-21T01:30:30Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
