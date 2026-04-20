---
phase: 06-engagement-layer
reviewed: 2026-04-21T00:00:00Z
depth: standard
files_reviewed: 51
files_reviewed_list:
  - DeluluDetox/Sources/App/DeluluDetoxApp.swift
  - DeluluDetox/Sources/Features/Home/View/HomeDashboardView.swift
  - DeluluDetox/Sources/Features/Home/View/HomeView.swift
  - DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift
  - DeluluDetox/Sources/Features/Notifications/Injection/NotificationsInjection.swift
  - DeluluDetox/Sources/Features/Notifications/Notification/AppNotificationDelegate.swift
  - DeluluDetox/Sources/Features/Notifications/Repository/LocalNotificationRepository.swift
  - DeluluDetox/Sources/Features/Notifications/Repository/NotificationCaptionLibrary.swift
  - DeluluDetox/Sources/Features/Notifications/UseCase/CancelSessionEndNotificationUseCase.swift
  - DeluluDetox/Sources/Features/Notifications/UseCase/GetBrokenStreakCopyUseCase.swift
  - DeluluDetox/Sources/Features/Notifications/UseCase/ReconcileScheduleNotificationsUseCase.swift
  - DeluluDetox/Sources/Features/Notifications/UseCase/SchedulePermissionPromptUseCase.swift
  - DeluluDetox/Sources/Features/Notifications/UseCase/ScheduleSessionEndNotificationUseCase.swift
  - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift
  - DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift
  - DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift
  - DeluluDetox/Sources/Features/Session/UseCase/EndSessionUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/StartSessionUseCase.swift
  - DeluluDetox/Sources/Features/Stats/Injection/StatsInjection.swift
  - DeluluDetox/Sources/Features/Stats/Repository/Models/Stats.swift
  - DeluluDetox/Sources/Features/Stats/UseCase/ComputeStatsUseCase.swift
  - DeluluDetox/Sources/Features/Stats/UseCase/ObserveStatsUseCase.swift
  - DeluluDetox/Sources/Features/Stats/View/StatsView.swift
  - DeluluDetox/Sources/Features/Stats/ViewModel/HomeStatsCardViewModel.swift
  - DeluluDetox/Sources/Features/Stats/ViewModel/StatsViewModel.swift
  - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift
  - DeluluDetoxTests/Features/Notifications/AppNotificationDelegateTests.swift
  - DeluluDetoxTests/Features/Notifications/CancelSessionEndNotificationUseCaseTests.swift
  - DeluluDetoxTests/Features/Notifications/GetBrokenStreakCopyUseCaseTests.swift
  - DeluluDetoxTests/Features/Notifications/LocalNotificationRepositoryTests.swift
  - DeluluDetoxTests/Features/Notifications/Mocks/MockCancelSessionEndNotificationUseCase.swift
  - DeluluDetoxTests/Features/Notifications/Mocks/MockGetBrokenStreakCopyUseCase.swift
  - DeluluDetoxTests/Features/Notifications/Mocks/MockLocalNotificationRepository.swift
  - DeluluDetoxTests/Features/Notifications/Mocks/MockReconcileScheduleNotificationsUseCase.swift
  - DeluluDetoxTests/Features/Notifications/Mocks/MockSchedulePermissionPromptUseCase.swift
  - DeluluDetoxTests/Features/Notifications/Mocks/MockScheduleSessionEndNotificationUseCase.swift
  - DeluluDetoxTests/Features/Notifications/ReconcileScheduleNotificationsUseCaseTests.swift
  - DeluluDetoxTests/Features/Notifications/SchedulePermissionPromptUseCaseTests.swift
  - DeluluDetoxTests/Features/Notifications/ScheduleSessionEndNotificationUseCaseTests.swift
  - DeluluDetoxTests/Features/Root/AppRootViewModelTests.swift
  - DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift
  - DeluluDetoxTests/Features/Session/EndSessionUseCaseTests.swift
  - DeluluDetoxTests/Features/Session/FinalizeSessionFromMarkerUseCaseTests.swift
  - DeluluDetoxTests/Features/Session/StartSessionUseCaseTests.swift
  - DeluluDetoxTests/Features/Stats/ComputeStatsUseCaseTests.swift
  - DeluluDetoxTests/Features/Stats/Fixtures/SessionRecordFixtures.swift
  - DeluluDetoxTests/Features/Stats/HomeStatsCardViewModelTests.swift
  - DeluluDetoxTests/Features/Stats/Mocks/MockComputeStatsUseCase.swift
  - DeluluDetoxTests/Features/Stats/Mocks/MockObserveStatsUseCase.swift
  - DeluluDetoxTests/Features/Stats/ObserveStatsUseCaseTests.swift
  - DeluluDetoxTests/Features/Stats/StatsViewModelTests.swift
findings:
  critical: 0
  warning: 3
  info: 6
  total: 9
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-21
**Depth:** standard
**Files Reviewed:** 51
**Status:** issues_found

## Summary

Phase 6 (Engagement Layer) implementation — notifications UCs (NTF-01/NTF-02 + permission prompt + broken-streak copy), Stats feature (ComputeStats/ObserveStats/VMs/View), and the cross-feature wiring (Session→Notifications, Scheduling→Notifications, AppRoot foreground reconcile) — is consistently well-structured and adheres closely to the Clean Architecture rules in `CLAUDE.md`. Protocols, distributed DI registration, testing seams (pure `presentationOptions(forIdentifier:)`, `dispatchResponse(identifier:userInfo:)`), and feature-owner ordering are all clean. Test coverage for the new UCs is thorough (rotation determinism, auth gating, full-replace semantics, rollback paths).

Issues found are mostly quality/robustness concerns rather than correctness bugs. The most actionable finding is **WR-01**: `HomeView.tabContent` instantiates a fresh `StatsViewModel()` on every body re-evaluation while tab 3 is active, which rebuilds the Combine subscription on every SwiftUI diff and undermines the intended VM-owned state lifecycle. The other warnings concern a Sendable hole in the notification delegate's `_SendableUserInfo` box and a Destination Equatable footgun in `HomeViewModel.Destination.stats`.

No security issues, no hardcoded secrets, no crashes on reviewed paths.

## Warnings

### WR-01: `HomeView` recreates `StatsViewModel` on every render for tab 3

**File:** `DeluluDetox/Sources/Features/Home/View/HomeView.swift:78`

**Issue:** Inside the `tabContent` switch, the Stats tab branch is:

```swift
case 3:
    StatsView(model: StatsViewModel())
```

Unlike `blockedModel` and `scheduleListModel` (held via `@State` at lines 7-8), this creates a **new** `StatsViewModel` every time SwiftUI evaluates the body. Each construction calls `observeStats().sink { ... }.store(in:)` inside `init()` (StatsViewModel.swift:41-44), so the Combine pipeline is rebuilt on every diff. The displayed month picker state (`prevMonthTapped()` / `nextMonthTapped()`) and the reactive `stats` projection are reset whenever SwiftUI invalidates the view — user scroll / month-nav progress gets clobbered the next time `selectedTab` triggers a body recompute.

This is inconsistent with the pattern used for the other tab VMs on the same screen, and inconsistent with the comment on the `tabContent` property (lines 64-68) that explicitly promises "Each tab owns its state via @State in HomeView so switching back preserves scroll position / edited fields."

**Fix:**
```swift
struct HomeView: View {
    @Bindable var model: HomeViewModel
    @State private var blockedModel = BlockedViewModel()
    @State private var scheduleListModel = ScheduleListViewModel()
    @State private var statsTabModel = StatsViewModel()   // <— add
    @State private var selectedTab: Int = 0

    // ...

    case 3:
        StatsView(model: statsTabModel)
```

Note: `HomeViewModel.statsCardTapped()` (HomeViewModel.swift:169-171) correctly creates a fresh `StatsViewModel()` for the **pushed** Stats destination — that's an event-driven intent, not a per-render side-effect, so it's fine to leave as-is.

---

### WR-02: `_SendableUserInfo` `@unchecked Sendable` box hides arbitrary non-Sendable values

**File:** `DeluluDetox/Sources/Features/Notifications/Notification/AppNotificationDelegate.swift:92-106`

**Issue:** `didReceive` receives `[AnyHashable: Any]` userInfo from iOS and boxes it in `_SendableUserInfo`, which is declared `@unchecked Sendable` purely to satisfy the cross-actor hop into the `Task { @MainActor ... }`:

```swift
private struct _SendableUserInfo: @unchecked Sendable {
    let value: [AnyHashable: Any]
    init(_ value: [AnyHashable: Any]) { self.value = value }
}
```

Comment acknowledges "tests only use String values so this box is safe in practice for MVP. Future: validate the dictionary shape before boxing." In production, iOS can place non-Sendable reference types (NSNumber, NSDate, arbitrary CFType bridges) inside `userInfo` depending on what was set on the original `UNMutableNotificationContent`. The current app only writes `[String: String]` userInfo (`ReconcileScheduleNotificationsUseCase.swift:71-74`, `ScheduleSessionEndNotificationUseCase.swift:44-47`, shield repo key `"url"` → String), so the real runtime payload is Sendable — but the `@unchecked` promise here is strictly too broad and will silently mask future regressions if anyone adds a non-String userInfo value.

**Fix:** Narrow the box to the exact shape you need before hopping actors. The dispatcher only reads `userInfo[ShieldNotificationConstants.userInfoURLKey] as? String`, so extract that one string synchronously on the nonisolated queue and hop only the strings:

```swift
nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let id = response.notification.request.identifier
    let urlString = response.notification.request.content.userInfo[ShieldNotificationConstants.userInfoURLKey] as? String
    defer { completionHandler() }

    Task { @MainActor [self] in
        await dispatchResponse(identifier: id, urlString: urlString)
    }
}
```

Then update the `dispatchResponse` seam accordingly (and its tests — `AppNotificationDelegateTests.swift` already keys userInfo by `"url"` → String, so the mock shape stays the same).

---

### WR-03: `HomeViewModel.Destination.stats` identity equality breaks re-navigation semantics

**File:** `DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift:26-37`

**Issue:** `Destination` uses `===` reference-identity for `.stats` (and sibling `.sessionStart`, `.countdown`, `.sessionSuccess`, `.scheduleList`). This matches the pre-existing cases, but combined with `statsCardTapped()` (line 169-171) which allocates a new `StatsViewModel()` on every tap, two sequential taps on the home stats card produce two destinations that **are not equal**:

```swift
HomeViewModel.Destination.stats(a) != HomeViewModel.Destination.stats(b)   // a !== b
```

SwiftUI's `.navigationDestination(item: $model.destination.stats)` (HomeView.swift:39-41) uses the case-path binding which will call `setter(.stats(newVM))` when routing changes. Because the equality test is identity-based, SwiftUI may tear down and reinstate the destination on each tap, losing in-flight calendar state. The existing test `testStatsCardDestination_isIdentityEquatable` (HomeViewModelTests.swift:403-408) actually pins this "two distinct VMs are not equal" behavior as a contract.

This is likely the intended pre-existing pattern (to force fresh screens), but it's inconsistent with WR-01's concern about state churn. If fresh state is desired on every push this is a feature; if preserving prev/next month state across the push cycle is desired, the VM should be hoisted to a `@State` property on HomeView (the same fix as WR-01 but for the pushed path rather than the tab path).

**Fix:** Decide intent and document it explicitly on the Destination declaration. If fresh is desired:
```swift
// .stats VM is identity-equated by design: every tap produces a new
// StatsViewModel so the screen's month picker resets. If you want
// persistent state across taps, hoist the VM to @State on HomeView
// and pass it through handleStatsCardTapped(_:) instead of allocating here.
case (.stats(let a), .stats(let b)): return a === b
```

If persistent is desired, change `statsCardTapped()` to accept the VM from the caller (HomeView keeps it in `@State`), and switch `.stats` to structural `==` on the VM's Equatable projection. Pick one and align the test.

---

## Info

### IN-01: Preview in `HomeView.swift` mutates `DIContainer.shared` global state

**File:** `DeluluDetox/Sources/Features/Home/View/HomeView.swift:216-228`

**Issue:** The `#Preview` block calls `container.reset()` then re-registers six feature injections. Previews run in a separate process under normal Xcode usage, so the global mutation is contained, but if someone ever exercises the Preview inside the test bundle (e.g., via `XCUIApplication` snapshot tools) it will stomp other tests' DI state. Low risk in MVP; worth a short comment noting the Preview assumes process isolation.

**Fix:** Add a one-line note at the top of the preview block: `// SAFE: Previews run in a dedicated process; DIContainer.shared.reset() does not leak to the XCTest bundle.`

---

### IN-02: `ReconcileScheduleNotificationsUseCase` hash entropy is effectively 4 bits

**File:** `DeluluDetox/Sources/Features/Notifications/UseCase/ReconcileScheduleNotificationsUseCase.swift:64`

**Issue:** `let hashBase = Int(schedule.id.uuidString.unicodeScalars.first?.value ?? 0)` pulls only the first hex character of the UUID string (`0x30…0x66`, ~6 bits across 16 hex digits + 6 possible ASCII letters). Modulo-3 over the 3 caption templates keeps distribution reasonable but highly skewed. Same comment applies to `ScheduleSessionEndNotificationUseCase.swift:37`. Documented intent per RESEARCH OQ#2 (`Int.hashValue` is process-randomized, avoid it) so this is a deliberate trade-off, not a bug. Noted here only so future copy additions understand the rotation is barely randomized.

**Fix:** If the library ever grows past ~5 captions, consider using multiple leading scalars or a `djb2`-style deterministic hash:
```swift
let hashBase = schedule.id.uuidString.unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) }
```

---

### IN-03: `NotificationCaptionLibrary.sessionEndCaptions[1]` has no `%d` — rotation produces duration-free copy

**File:** `DeluluDetox/Sources/Features/Notifications/Repository/NotificationCaptionLibrary.swift:12`

**Issue:** Template 1 is `"Sesja ukończona. Możesz wrócić do chaosu."` — no `%d`. `sessionEndCopy(for:durationMinutes:)` correctly branches on `contains("%d")` so the missing specifier won't crash `String(format:)`, but it does mean 1/3 of scheduled NTF-01 banners omit the minutes count. This is likely intentional (copy variety) — flagging so the product/copy author is aware.

**Fix:** No code change needed. If uniform minutes-inclusion is desired, add `%d` to the template. If intentional variance, add a comment:
```swift
let sessionEndCaptions: [String] = [
    "Przetrwałeś %d min bez scrollowania. Świat się nie zawalił.",
    "Sesja ukończona. Możesz wrócić do chaosu.",   // intentionally no %d — copy variety
    "Gratuluję, %d min w realnym świecie. Teraz możesz pojeździć palcem."
]
```

---

### IN-04: `PickerHostView.@State session` initialized from init parameter — documented SwiftUI footgun

**File:** `DeluluDetox/Sources/Features/Home/View/HomeView.swift:188-199`

**Issue:** `PickerHostView` uses `@State private var session` seeded from `initialSession` via `self._session = State(initialValue: ...)`. SwiftUI only honors the initial value once per view identity — if the parent re-presents the sheet with a different `initialSession`, the inner state will NOT re-seed. Because the sheet uses `.sheet(item:)` with an Identifiable `PickerSession.id = UUID()`, each presentation gets fresh view identity, so this is safe. Worth a one-line comment noting the dependency on the `Identifiable.id` changing per presentation.

**Fix:**
```swift
init(
    initialSession: HomeViewModel.PickerSession,
    onDismiss: @escaping (FamilyActivitySelection) -> Void
) {
    // NOTE: @State only honors initialValue on first appearance. Safe here
    // because PickerSession.id = UUID() ensures .sheet(item:) hands a new
    // view identity each presentation.
    self._session = State(initialValue: initialSession)
    self.onDismiss = onDismiss
}
```

---

### IN-05: `SyncScheduleWithSystemUseCase` swallows rollback-upsert errors with `try?`

**File:** `DeluluDetox/Sources/Features/Scheduling/Common/UseCase/SyncScheduleWithSystemUseCase.swift:77`

**Issue:** On the catch branch, `try? await repository.upsert(prior)` silently drops any error from the rollback persist. Comment on the class (lines 21-22) documents this intent ("If the prior snapshot upsert itself throws, we swallow that error — the user's original failure is what matters"). Documented trade-off — not a bug. Flagging because silent `try?` sites tend to hide diagnostics during incident debugging.

**Fix:** Add a log line on failure so diagnostic rails have breadcrumbs:
```swift
if let prior = priorSnapshot {
    do {
        try await repository.upsert(prior)
        Self.log.info("rolled back schedule.json to prior snapshot id=\(schedule.id.uuidString, privacy: .public)")
    } catch {
        Self.log.error(
            "rollback upsert failed id=\(schedule.id.uuidString, privacy: .public) error=\(String(describing: error), privacy: .public) — original failure takes precedence"
        )
    }
}
```

---

### IN-06: `StatsViewModel.setDisplayedMonthForTesting(_:)` is `internal` — typical test seam, but not guarded

**File:** `DeluluDetox/Sources/Features/Stats/ViewModel/StatsViewModel.swift:100-102`

**Issue:** The test seam is marked `internal` (Swift default) and relies on a documentation comment for the "production MUST NOT call" contract. Production code in the app target could accidentally call it. Because the project uses `@testable import DeluluDetox` in tests, there's no way to make this `@testable-only`. This is the idiomatic Swift approach — just noting that the contract is enforced by convention, not by the compiler.

**Fix:** Optional. If stricter enforcement is desired, rename to include a warning substring so IDE autocomplete surfaces it:
```swift
/// Test-only seam. DO NOT CALL FROM PRODUCTION CODE.
internal func __test_setDisplayedMonth(_ date: Date) {
    displayedMonth = calendar.startOfDay(for: date)
}
```
(and update `StatsViewModelTests.swift:150` + `:161` accordingly).

---

_Reviewed: 2026-04-21_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
