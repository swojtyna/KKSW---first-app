---
phase: 03-quick-sessions
reviewed: 2026-04-19T00:00:00Z
depth: standard
files_reviewed: 31
files_reviewed_list:
  - DeluluDetox/Sources/App/DeluluDetoxApp.swift
  - DeluluDetox/Sources/DesignSystem/Theme+Session.swift
  - DeluluDetox/Sources/Features/Home/View/HomeView.swift
  - DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift
  - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
  - DeluluDetox/Sources/Features/Session/Infrastructure/SessionActivityNames.swift
  - DeluluDetox/Sources/Features/Session/Infrastructure/SessionEnforcer.swift
  - DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift
  - DeluluDetox/Sources/Features/Session/Repository/Models/SessionDuration.swift
  - DeluluDetox/Sources/Features/Session/Repository/Models/SessionFinalizeMarker.swift
  - DeluluDetox/Sources/Features/Session/Repository/Models/SessionOutcome.swift
  - DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
  - DeluluDetox/Sources/Features/Session/Repository/Models/SessionRecord.swift
  - DeluluDetox/Sources/Features/Session/Repository/SessionRepository.swift
  - DeluluDetox/Sources/Features/Session/UseCase/CheckSuccessShownUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/DetectRevocationUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/EndSessionUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/MarkSuccessShownUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/ObserveActiveSessionUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/ObserveSessionHistoryUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/SelfHealExpiredSessionUseCase.swift
  - DeluluDetox/Sources/Features/Session/UseCase/StartSessionUseCase.swift
  - DeluluDetox/Sources/Features/Session/View/CountdownView.swift
  - DeluluDetox/Sources/Features/Session/View/SessionStartView.swift
  - DeluluDetox/Sources/Features/Session/View/SessionSuccessView.swift
  - DeluluDetox/Sources/Features/Session/ViewModel/CountdownViewModel.swift
  - DeluluDetox/Sources/Features/Session/ViewModel/SessionStartViewModel.swift
  - DeluluDetox/Sources/Features/Session/ViewModel/SessionSuccessViewModel.swift
  - DeluluDetox/Sources/Features/Session/ViewModel/TickClock.swift
  - Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-19
**Depth:** standard
**Files Reviewed:** 31
**Status:** issues_found

## Summary

Phase 03 wires a complete session flow: two model files, atomic two-file persistence to App Group, a SessionEnforcer wrapping ManagedSettings + DeviceActivity, 9 UseCases, DI registration, a DAM extension `intervalDidEnd` handler, and four SwiftUI screens. The architecture is clean, the rollback logic in `StartSessionUseCase` is solid, and the defense-in-depth (self-heal + finalize-from-marker + revocation detection) is well-designed.

Two critical issues were found. The first is a midnight-crossing bug in `DeviceActivitySchedule` construction that will cause sessions spanning midnight to not fire `intervalDidEnd` at the right time. The second is that the Darwin notification posted by the DAM extension has no subscriber in the main app, meaning a foregrounded app does not react to session expiry in real time — the user sees a frozen countdown at 0 until they background/foreground.

Three warnings address: a dead `sessionInProgress` code path that will silently no-op when a concurrent session is detected, a `canStart` gate missing the `!hasActiveSession` check (allowing a double-tap to the dead path), and `requireAutomaticDateAndTime`/`denyAppRemoval` being set to `false` (not `nil`) in the DAM extension (inconsistent with the main app adapter that maps `false` → `nil`).

---

## Critical Issues

### CR-01: DeviceActivitySchedule midnight-crossing bug

**File:** `DeluluDetox/Sources/Features/Session/Infrastructure/SessionEnforcer.swift:170-183`

**Issue:** `DeviceActivitySchedule` is constructed from `DateComponents` that include only `.hour, .minute, .second` — no `.day`, `.month`, or `.year`. When a session spans midnight (e.g., starts at 23:50, ends at 00:05 the next day after a 15-minute session), `intervalEnd.hour (0) < intervalStart.hour (23)`. The `DeviceActivityCenter` interprets this as the interval ending before it starts and will either throw (error is caught and rethrown as `SessionEnforcerError.deviceActivityStartFailed`, causing the full session start to fail and roll back) or fire `intervalDidEnd` immediately. Sessions that survive the schedule call will have their DAM callback fire at the wrong time. The self-heal in `AppRootViewModel.refreshStatus` will eventually clean this up on next foreground, but the primary auto-end path is broken for midnight-crossing sessions.

**Fix:** Pass the full set of calendar components including at minimum `.year, .month, .day`:

```swift
func startActivityMonitoring(for session: SessionRecord) async throws {
    let calendarComponents: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let startComponents = Calendar.current.dateComponents(calendarComponents, from: session.startedAt)
    let endComponents   = Calendar.current.dateComponents(calendarComponents, from: session.plannedEndAt)

    let schedule = DeviceActivitySchedule(
        intervalStart: startComponents,
        intervalEnd: endComponents,
        repeats: false
    )
    // ... rest unchanged
}
```

---

### CR-02: Darwin notification posted by DAM extension has no subscriber — foregrounded app does not react to session expiry

**File:** `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift:110-120`

**Issue:** `DeviceActivityMonitorExtension.intervalDidEnd` posts a Darwin notification (`com.kksw.DeluluDetox.sessionFinalized`) at step 4, with the comment "so a foregrounded main app can react fast." A grep across all main-app sources confirms there is no `CFNotificationCenter` subscriber or equivalent listener registered anywhere. The main app only reconciles via `AppRootViewModel.refreshStatus()` which fires on `scenePhase == .active`. If the app is already in the foreground when the timer fires:

1. The DAM extension clears the `ManagedSettingsStore` (shield drops — user's apps unblock).
2. The DAM extension writes the finalize marker.
3. The Darwin notification is posted — and silently dropped.
4. `SessionRepository.activeSubject` still holds the active record. `CountdownViewModel.tick()` keeps running, hitting `max(0, ...)` and freezing the display at 0 seconds remaining.
5. `HomeViewModel.handleActive` does not fire because the Combine subject was not updated.
6. The countdown UI stays stuck at "00:00" until the user backgrounds and re-foregrounds the app.

This contradicts the core value proposition: the countdown should complete cleanly when the timer expires.

**Fix:** Subscribe to the Darwin notification in `AppRootViewModel` (or `SessionRepository`) and call `refreshStatus()` / trigger finalization immediately. Example in `AppRootViewModel.init()`:

```swift
// In AppRootViewModel.init() — after the observeStatus subscription
let name = CFNotificationName("com.kksw.DeluluDetox.sessionFinalized" as CFString)
CFNotificationCenterAddObserver(
    CFNotificationCenterGetDarwinNotifyCenter(),
    Unmanaged.passUnretained(self).toOpaque(),
    { _, observer, _, _, _ in
        guard let ptr = observer else { return }
        let vm = Unmanaged<AppRootViewModel>.fromOpaque(ptr).takeUnretainedValue()
        Task { @MainActor in vm.refreshStatus() }
    },
    name.rawValue,
    nil,
    .deliverImmediately
)
```

Alternatively, expose a dedicated `handleSessionFinalized()` on `SessionRepository` that re-reads the marker synchronously and fires the subjects — this avoids the MainActor/Task complexity and fits the existing architecture better.

---

## Warnings

### WR-01: `SessionStartViewModel.Destination.sessionInProgress` is a dead code path

**File:** `DeluluDetox/Sources/Features/Session/ViewModel/SessionStartViewModel.swift:21` and `119`

**Issue:** `Destination.sessionInProgress(SessionRecord)` is declared and set in `startTapped` (line 119) when `latestActive != nil`, but `HomeView.sessionStartDestination` only observes `.countdownHandoff` in its `.onChange` block. `.sessionInProgress` is never consumed. The practical effect is tolerable — `HomeViewModel.handleActive` fires asynchronously via Combine and routes to `.countdown` anyway (overriding the `.sessionStart` destination). However, the intended fast-path (`.sessionInProgress` → parent routes straight to the existing countdown without waiting for the Combine pipeline) is silently dead. A future developer following the comment "Gate 1: already an active session → route to sessionInProgress handoff" would expect this to do something.

**Fix:** Either wire the case in `HomeView.sessionStartDestination` alongside `.countdownHandoff`:

```swift
.onChange(of: startModel.destination) { _, newValue in
    switch newValue {
    case .countdownHandoff(let record):
        model.gotoCountdown(record)
        startModel.destination = nil
    case .sessionInProgress(let record):
        model.gotoCountdown(record)
        startModel.destination = nil
    default:
        break
    }
}
```

Or remove the `.sessionInProgress` case from `SessionStartViewModel.Destination` entirely and rely on `HomeViewModel.handleActive` for the re-route (removing Gate 1 from `startTapped` or converting it to a no-op guard with a log).

---

### WR-02: `canStart` does not exclude the active-session state — Start button remains enabled during a live session

**File:** `DeluluDetox/Sources/Features/Session/ViewModel/SessionStartViewModel.swift:66`

**Issue:** `canStart` is defined as:
```swift
var canStart: Bool { blocklistHasRecords && !isStarting && resolvedDuration != nil }
```
It does not include `!hasActiveSession`. When `SessionStartView` is presented while a session is already active (`hasActiveSession == true`), the "Uruchom sesję" button is enabled. Tapping it hits the dead `.sessionInProgress` path (WR-01). This is misleading UX and risks confusion when WR-01 is fixed (the button would appear to "work" but silently reroute instead of starting a second session).

**Fix:**
```swift
var canStart: Bool { blocklistHasRecords && !isStarting && !hasActiveSession && resolvedDuration != nil }
```

Also consider disabling the Start toolbar button in `HomeView` when a session is active, to prevent navigating to `SessionStartView` at all.

---

### WR-03: DAM extension sets `requireAutomaticDateAndTime` and `denyAppRemoval` to `false` rather than `nil`

**File:** `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift:65-66`

**Issue:** `ManagedSettingsStore.dateAndTime.requireAutomaticDateAndTime` and `ManagedSettingsStore.application.denyAppRemoval` are `Bool?` in the iOS 26 SDK. `nil` semantically means "no restriction configured" while `false` is "explicitly set to false." The main-app `LiveManagedSettingsStoreWriter` correctly maps the clear path to `nil` (via `value ? true : nil`). The DAM extension directly writes:
```swift
store.dateAndTime.requireAutomaticDateAndTime = false
store.application.denyAppRemoval = false
```
This is an inconsistency: if the ManagedSettings framework treats `false` differently from `nil` in future SDK versions (or already does internally), the DAM clear path will not match the main-app clear path. In practice both paths clear the restriction for the user, but the semantic contract is violated.

**Fix:** Update `clearSharedManagedSettingsStore()` in the extension to use `nil`:
```swift
store.dateAndTime.requireAutomaticDateAndTime = nil
store.application.denyAppRemoval = nil
```

---

## Info

### IN-01: `ObserveActiveSessionUseCaseImpl` and `ObserveSessionHistoryUseCaseImpl` lack explicit `Sendable` annotation

**File:** `DeluluDetox/Sources/Features/Session/UseCase/ObserveActiveSessionUseCase.swift:7`, `DeluluDetox/Sources/Features/Session/UseCase/ObserveSessionHistoryUseCase.swift:7`

**Issue:** Both Impl classes implicitly inherit `Sendable` from their protocol but do not declare it explicitly, unlike the other Impl classes in this feature which all carry `@unchecked Sendable`. In Swift 6 strict concurrency, a `final class` with only a `SessionRepository` (`Sendable`) stored property compiles cleanly without the annotation, so this is not a bug. However, the inconsistency with the rest of the codebase is a maintenance risk — a future stored-property addition might silently pass the compiler (if the property is `Sendable`) while the intent was to be explicit.

**Fix:**
```swift
final class ObserveActiveSessionUseCaseImpl: ObserveActiveSessionUseCase, @unchecked Sendable {
```
```swift
final class ObserveSessionHistoryUseCaseImpl: ObserveSessionHistoryUseCase, @unchecked Sendable {
```

---

### IN-02: `consumeFinalizeMarker` silently ignores file-deletion failure

**File:** `DeluluDetox/Sources/Features/Session/Repository/SessionRepository.swift:168`

**Issue:** After decoding the marker, the file is removed with `try? FileManager.default.removeItem(at: url)`. A failure here (e.g., temporary file-system error) is silently dropped and not logged. On the next `refreshStatus()` call, the same marker is re-read and re-processed. `EndSessionUseCase` is idempotent (it swallows `noActiveSession`), so this does not cause a double-finalization bug. However, the silent drop makes debugging harder if a deletion race is encountered.

**Fix:** Log the error at warning level:
```swift
do {
    try FileManager.default.removeItem(at: url)
} catch {
    Self.log.warning("consumeFinalizeMarker: delete failed (will retry on next foreground): \(String(describing: error), privacy: .public)")
}
```

---

_Reviewed: 2026-04-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
