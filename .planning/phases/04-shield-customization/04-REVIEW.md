---
phase: 04-shield-customization
reviewed: 2026-04-20T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - DeluluDetox/Sources/App/DeluluDetoxApp.swift
  - DeluluDetox/Sources/Features/Root/View/AppRootView.swift
  - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
  - DeluluDetox/Sources/Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift
  - DeluluDetox/Sources/Features/Shield/Notification/ShieldNotificationDispatcher.swift
  - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift
  - DeluluDetoxTests/Features/Shield/ShieldConfigurationBuilderTests.swift
  - DeluluDetoxTests/Features/Shield/ShieldNotificationDispatcherTests.swift
  - Extensions/ShieldActionExtension/ShieldActionExtension.swift
  - project.yml
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-20
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed gap-closure work for plans 04-06 (SHL-03 local-notification fallback) and 04-07 (SHL-02 fallback-copy contract tests). The implementation is sound overall:

- **Security posture is good.** The notification delegate enforces a two-layer allowlist (identifier prefix via `ShieldNotificationDispatcher.identifierPrefix` + scheme check `url.scheme == "deluludetox"`), so tampered `userInfo` from other notification sources gets rejected. No private API usage (`NSClassFromString("UIApplication")`, `perform(_:)`, etc.) — the App Store Guideline 2.5.1 risk has been correctly eliminated.
- **T-04-03-02 invariant preserved.** `ShieldActionExtension.handle(...)` calls `ShieldNotificationDispatcher().dispatch(url:log:)` without awaiting, then fires `completionHandler(.close/.defer/.none)` unconditionally. The shield process is always released on time regardless of UN scheduling outcome.
- **6 MB RAM ceiling respected.** `ShieldActionExtension.swift` and the source-shared `ShieldNotificationDispatcher.swift` import only `Foundation + ManagedSettings + UserNotifications + os`. No SwiftUI/Combine/FamilyControls leakage into the extension binary.
- **Fire-and-forget dispatch is correctly Sendable-safe.** `dispatch` captures the identifier as a local `String` (`let capturedIdentifier = request.identifier`) before entering the `add(_:)` completion closure, sidestepping the non-Sendable `UNNotificationRequest` capture that Swift 6 strict concurrency would flag.

Two warnings and four info items — none blocking. The warnings concern a suspicious `@unchecked Sendable` on a `@MainActor` class (defensive-typing smell that could mask future data races) and a subtle `PassthroughSubject` lifecycle coupling between `DeluluDetoxApp.init()` and `AppRootViewModel`.

## Warnings

### WR-01: Redundant and risky `@unchecked Sendable` on `@MainActor` class

**File:** `DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift:10`

**Issue:** `AppRootViewModel` is declared as `@MainActor @Observable final class AppRootViewModel: @unchecked Sendable`. Types annotated with `@MainActor` are *already* implicitly `Sendable` in Swift 6 — adding `@unchecked Sendable` disables the compiler's actor-isolation safety check and serves no purpose while the `@MainActor` stays. If `@MainActor` is ever removed during a refactor, the `@unchecked Sendable` will silently continue to claim thread-safety that no longer holds, hiding real data-race bugs (notably the `cancellables: Set<AnyCancellable>` mutable stored property and `deepLinkSubject` subject).

**Fix:** Drop `@unchecked Sendable` entirely. `@MainActor` already gives you Sendable conformance, and if `@MainActor` ever disappears, the compiler will correctly refuse to synthesize conformance until the mutable state is protected.

```swift
@MainActor
@Observable
final class AppRootViewModel {
    // @unchecked Sendable removed — @MainActor already implies Sendable.
    ...
}
```

### WR-02: `AppRootViewModel` lifecycle coupling between `DeluluDetoxApp.init()` and the notification delegate

**File:** `DeluluDetox/Sources/App/DeluluDetoxApp.swift:26-31`

**Issue:** The init sequence is:

```swift
let model = AppRootViewModel()
self._rootModel = State(wrappedValue: model)
self.notificationDelegate = ShieldDeepLinkNotificationDelegate { [weak model] url in
    await MainActor.run { model?.ingestShieldDeepLink(url) }
}
UNUserNotificationCenter.current().delegate = self.notificationDelegate
```

Two concerns:

1. **`@State(wrappedValue:)` copies, it does not reference.** `State` stores `model` via its own storage location that SwiftUI manages; the property-wrapper initializer does not magically give you the stable reference SwiftUI will use at runtime. The `[weak model]` closes over the `let model` in init scope, not over the `State`-managed instance SwiftUI binds to `AppRootView`. In practice SwiftUI re-emits the same reference because `AppRootViewModel` is a reference type and `@State` stores it as-is, but this is brittle — a future migration to `@StateObject`-style semantics or to `@Bindable` with ownership held elsewhere would break the coupling silently.
2. **`UNUserNotificationCenter.current().delegate` is a strong reference set at launch.** `self.notificationDelegate` keeps the delegate alive; the delegate closes `[weak model]` weakly; but `_rootModel` on the `DeluluDetoxApp` struct keeps `model` alive for the process lifetime. The weak capture is unnecessary defensive code — the VM can never be released before the app terminates because the App struct owns it.

**Fix:** Either (a) accept that the VM lives for the process lifetime and drop the `[weak model]` indirection for clarity, or (b) make the ownership explicit by moving `notificationDelegate` wiring into a dedicated function on `AppRootViewModel.init()` that registers itself. Option (b) also collocates the delegate with the publisher it feeds.

```swift
// Option A — acknowledge process-lifetime ownership.
let model = AppRootViewModel()
self._rootModel = State(wrappedValue: model)
self.notificationDelegate = ShieldDeepLinkNotificationDelegate { url in
    await MainActor.run { model.ingestShieldDeepLink(url) }
}
```

Either way, add a comment explaining *why* the weak capture is there (or why it isn't) so the next reader doesn't have to reverse-engineer SwiftUI's `@State` semantics.

## Info

### IN-01: Case-sensitive URL scheme comparison

**File:** `DeluluDetox/Sources/Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift:68`

**Issue:** The guard `url.scheme == "deluludetox"` is case-sensitive. RFC 3986 §3.1 specifies that URL schemes are case-insensitive ("Although schemes are case-insensitive, the canonical form is lowercase"). If a future code path — or a misconfigured test fixture — writes `"DeluluDetox://session/active"` into `userInfo["url"]`, `URL(string:)` will preserve the case and the delegate will silently drop the tap.

Since `userInfo` is written exclusively by `ShieldNotificationDispatcher.makeRequest(url:)` (which uses `url.absoluteString` verbatim) and the app's registered `CFBundleURLSchemes` entry is lowercase `deluludetox`, the bug is not reachable today. Future-proofing costs one method call.

**Fix:**

```swift
guard let urlString = userInfo[ShieldNotificationDispatcher.userInfoURLKey] as? String,
      let url = URL(string: urlString),
      url.scheme?.lowercased() == "deluludetox" else {
    ...
}
```

### IN-02: Contract smoke test placed in the wrong test class

**File:** `DeluluDetoxTests/Features/Home/HomeViewModelTests.swift:336-347`

**Issue:** `testShieldNotificationDispatcher_userInfoURLKeyContract` asserts the static constants `ShieldNotificationDispatcher.userInfoURLKey` and `.identifierPrefix`. It touches nothing on `HomeViewModel`, uses none of the mocks from `setUp()`, and its name starts with `testShieldNotificationDispatcher_`. Logically it belongs in `ShieldNotificationDispatcherTests.swift`, next to `testDispatcher_buildRequest_*`. As-is, it inflates `HomeViewModelTests` and makes CI failure reports harder to triage (a dispatcher-contract failure shows up under a Home-feature heading).

**Fix:** Move the test into `ShieldNotificationDispatcherTests.swift`. The existing "smoke test asserting the string keys the dispatcher and delegate agree on" rationale in the comment applies better there.

### IN-03: Silenced `.list` presentation option may harm discoverability

**File:** `DeluluDetox/Sources/Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift:42`

**Issue:** `willPresent` returns `[.banner]` only — no `.list`. Consequence: if the user misses the banner (e.g., phone face-down, notification center already open), the entry does not land in Notification Center, so they have no second chance to tap back into the app. This is a deliberate UX trade-off (silent-ish pivot, no notification clutter) documented in the dispatcher tests as "Silent — shield is a UX pivot, not a ping (D-17 threat model T-04-06-03)".

Flagging for awareness: during UAT (plan 04-05), verify that dismissed banners are not silently lost on device. If the P0 "user can always return to the app from a shield" core-value promise requires Notification Center fallback, this becomes `.banner, .list`.

**Fix (deferred / product decision):**

```swift
completionHandler([.banner, .list])  // only if UAT shows banner-miss is a real-world issue
```

### IN-04: `Task.detached` for notification authorization leaks from `@MainActor` unnecessarily

**File:** `DeluluDetox/Sources/App/DeluluDetoxApp.swift:37-43`

**Issue:** `Task.detached` is used to request notification authorization at launch. Detached tasks drop their parent's actor isolation and task-local values; here neither is needed (the calls are `async` on `UNUserNotificationCenter`, which is thread-safe and has no actor requirement). Plain `Task { ... }` suffices, runs on the default actor, and keeps the init's structured-concurrency story clean. The detached flavor also costs extra in priority propagation.

**Fix:**

```swift
Task {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    if settings.authorizationStatus == .notDetermined {
        _ = try? await center.requestAuthorization(options: [.alert, .badge])
    }
}
```

---

_Reviewed: 2026-04-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
