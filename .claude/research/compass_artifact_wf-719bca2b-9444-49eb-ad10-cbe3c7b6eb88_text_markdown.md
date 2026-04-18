# Building an Opal clone on iOS 26: Live Activities, Dynamic Island & Screen Time

Live Activities are the right primitive for an Opal-style focus timer, but the hardest constraint is structural: **ActivityKit cannot be called from any Screen Time extension**, so your architecture must funnel all state changes through the main app or a backend APNs pipe. This report assembles the full picture across ActivityKit, the Dynamic Island, WidgetKit, push notifications, and Screen Time integration — with explicit call-outs for what iOS 26 changes (Liquid Glass, CarPlay, macOS menu-bar Live Activities, AlarmKit, Relevance Widgets) versus what has been stable since iOS 16.1.

The good news: a focus timer is a near-ideal fit for the Live Activity model. Its countdown can be driven entirely by the system via `Text(timerInterval:)` with zero update budget consumed, and iOS 18's interactive buttons plus iOS 26's CarPlay/Watch/Mac inheritance give you rich presence across surfaces with minimal extra code. The bad news: iOS 26 has introduced meaningful regressions in `DeviceActivity` callback reliability and token stability (one sec's developer and others have publicly flagged several Feedback reports). Defensive reconciliation on app foreground is mandatory, not optional.

This report is organized to match the user's ten numbered topics, with iOS 26-specific material flagged in-line and consolidated in §9.

---

## 1. ActivityKit framework state on iOS 26

### Version-by-version evolution

**iOS 16.1 (Oct 2022)** introduced ActivityKit with `ActivityAttributes`, `Activity.request(attributes:contentState:)`, the Lock Screen presentation, and the Dynamic Island on iPhone 14 Pro. The 8-hour active cap plus 4-hour Lock Screen grace (12 hours total) and the 4 KB payload limit date to this release and have not changed.

**iOS 16.2 (Dec 2022)** reshaped the API into the modern form: `Activity.request(attributes:content:pushType:)` where `content` is `ActivityContent<ContentState>` (wrapping state, `staleDate`, and `relevanceScore`). `activity.update(_:)` and `activity.end(_:dismissalPolicy:)` were updated to take `ActivityContent`. The APNs push type `liveactivity` was introduced.

**iOS 17.0 (Sept 2023)** added StandBy, iPad Lock-Screen support, interactive Live Activities via `Button(intent:)` and `Toggle(isOn:intent:)` (requiring the `LiveActivityIntent` protocol), and most importantly the self-animating `Text(timerInterval:)` and `ProgressView(timerInterval:)` views that render countdowns without consuming updates.

**iOS 17.2 (Dec 2023)** added **push-to-start**: `Activity<Attrs>.pushToStartTokenUpdates` exposes a per-app token that lets a server remotely *create* a Live Activity via an APNs payload with `"event": "start"`. It also introduced the `NSSupportsLiveActivitiesFrequentUpdates` Info.plist key, which increases the high-priority push budget (user-visible in Settings as a "more frequent updates" toggle; detectable via `ActivityAuthorizationInfo().frequentPushesEnabled` and `frequentPushEnablementUpdates`).

**iOS 18.0 (Sept 2024)** tightened local update throttling to roughly **5–15 seconds between updates** (down from iOS 17's ~1 Hz ceiling); Apple has publicly stated Live Activities were never intended for real-time streams. `Text(timerInterval:)` is exempt and still animates every second. watchOS 11 added automatic **Smart Stack mirroring** of iOS Live Activities, with opt-in customization via `.supplementalActivityFamilies([.small, .medium])` and `@Environment(\.activityFamily)`. Broadcast Live Activities (a single push delivered to many subscribers via a Channel ID) were added for sports/fan use cases.

**iOS 26.0 (Sept 2025)** is the user's deployment target. The ActivityKit API surface is essentially stable; the changes are environmental and ecosystem-spanning. See §9 for a consolidated iOS 26 treatment.

### Anatomy recap

An `ActivityAttributes` struct declares **static** attributes (set once at `Activity.request` time) plus a nested `ContentState` struct carrying **dynamic** properties. Every update transmits a new `ContentState`; the combined serialized payload (attributes + state) must fit the 4 KB APNs ceiling. The `ActivityConfiguration(for:)` DSL then takes two closures: the Lock Screen / banner view and a `DynamicIsland { ... }` builder with four regions — `compactLeading`, `compactTrailing`, `minimal`, and an `expanded` builder containing up to four sub-regions (`leading`, `trailing`, `center`, `bottom`). The same configuration object drives the Apple Watch Smart Stack, CarPlay Dashboard, and macOS Tahoe menu bar if you opt into the supplemental families.

Activity lifecycle states are `.active`, `.ended`, `.dismissed`, and `.stale`, observable via `activity.activityStateUpdates`. The `staleDate` in `ActivityContent` drives the `.stale` transition; `relevanceScore` (iOS 16.2+) orders multiple concurrent activities when the system has to pick which one the Dynamic Island shows.

### Limits as of iOS 26

| Limit | Value | Changed? |
|---|---|---|
| Active Dynamic Island duration | 8 hours | No |
| Lock Screen grace after end | +4 hours (12 h total) | No |
| Payload size (attributes + state) | 4 KB | No |
| Local update throttle | ~5–15 s between updates | No (since iOS 18) |
| Concurrent activities per app | Up to 5 (community-reported) | No |
| Dynamic Island concurrent visible | 2 (1 attached + 1 detached minimal) | No |
| Widget-extension memory | ~30 MB working set (undocumented) | No |

WidgetKit restrictions apply to all Live Activity views: **no ScrollView, no Lists, no video, no network calls, no location, limited animations** (numericText, symbolEffect, implicit animations, and the `timerInterval` views). Images larger than the minimal region (≤45×36.67 pt) can be dropped.

---

## 2. Live Activity integration with the Screen Time API

### The critical constraint: ActivityKit is not usable from any Screen Time extension

Apple's documentation states plainly that **"your app can only start Live Activities while it's in the foreground."** There is no entitlement, header, or documented path to call `Activity.request`, `activity.update`, or `activity.end` from inside `DeviceActivityMonitor`, `ShieldConfigurationExtension`, `ShieldActionExtension`, or `DeviceActivityReportExtension`. Developers who have tried report silent failures, `unsupportedTarget` errors, or crashes; Apple's DTS engineer Quinn has also publicly stated that the rumored `com.apple.developer.activitykit.allow-third-party-activity` entitlement "isn't a real entitlement." Additionally, the 6 MB high-watermark memory cap on `DeviceActivityMonitor` would blow up anyway once you loaded WidgetKit + ActivityKit symbols.

**Design implication:** you need a foreground-initiated Live Activity whose updates arrive from (a) the main app whenever it runs, (b) an APNs push from your backend, or (c) the system itself via `Text(timerInterval:)` without any updates at all.

### The recommended hybrid architecture

```
[Main App (foreground)] ──Activity.request(pushType: .token)──▶ [Live Activity]
        │                                                              ▲
        │ push token to backend                                         │
        ├─▶ [Your server / APNs] ───apns-push-type: liveactivity────────┤
        │                                                               │
[DeviceActivityMonitor / ShieldAction Ext] ─App Group + Darwin + HTTPS ─┘
```

Start the Live Activity only in the foreground main app. For the countdown UI, use `Text(timerInterval: startDate...endDate, countsDown: true)` so the system animates locally with zero updates. When an extension fires (shield shown, shield button tapped, schedule interval rolled over), it writes a counter increment to an App Group `UserDefaults` suite, posts a **Darwin notification** via `CFNotificationCenterGetDarwinNotifyCenter()`, and — if you run a backend — hits your server with a small `URLSession` call. The backend then sends an `apns-push-type: liveactivity` update so the Dynamic Island's "blocked attempts" counter increments in real time even when the app is suspended. When the main app next foregrounds, a Darwin observer reads the shared state and calls `activity.update(...)` to reconcile.

### Which extension fires for a blocked-app tap

Two observable hooks produce the "blocked attempt" signal. `ShieldConfigurationExtension.configuration(shielding:)` is called every time iOS renders the shield, which is effectively every attempt to open a blocked app — this is the counter most focus apps (one sec, likely Opal) use. `ShieldActionExtension.handle(action:for:completionHandler:)` fires only when the user taps a button on the shield, so it counts "interactions" rather than "glances." Both are permitted to read/write App Group storage and post Darwin notifications; `ShieldActionExtension` is also the best place to make a small `URLSession` call since it has permissive networking (confirmed by multiple Apple Developer Forums threads, e.g. 772282).

### App Groups, Darwin, and shared state

Every target — main app, widget extension, `DeviceActivityMonitor`, `ShieldConfigurationExtension`, `ShieldActionExtension` — needs the same App Group (e.g., `group.com.yourco.opalclone`) in its entitlements. Store the `FamilyActivitySelection` (it conforms to `Codable`), session metadata, and the attempt counter in either `UserDefaults(suiteName:)` or a file in the shared container. Darwin notifications carry no payload — they are a pure "wake up and re-read" doorbell. Critically, **Darwin only wakes running processes**, so if the main app is suspended, the update is deferred until it foregrounds. This is precisely why a backend push is needed if you want real-time counter updates on a closed app.

### iOS 26 regressions to plan around

As of iOS 26.2–26.3.1, multiple independent developers (including the one sec team on the Apple Developer Forums) report: `intervalDidEnd` firing inconsistently or not at all, `eventDidReachThreshold` firing prematurely, `deviceactivityd` emitting zero logs on 26.3.1, Screen Time permission being silently revoked after the iOS 26 upgrade (FB18997699), and `ApplicationToken` values rotating post-upgrade such that stored tokens no longer match those arriving in shield extensions. Build defensively: always re-read `AuthorizationCenter.shared.authorizationStatus` on foreground, reconcile shield state against persisted session data whenever the main app runs, and accept that `intervalDidStart` is markedly more reliable than `intervalDidEnd` (letvar's "Time After (Screen) Time" series documents this explicitly).

---

## 3. Push-based updates via ActivityKit

### Token types and payload anatomy

There are two distinct token streams. **Per-activity update tokens** are delivered via `activity.pushTokenUpdates` once you request the activity with `pushType: .token`; send each rotation to your backend, keyed by user + activity ID. **Push-to-start tokens** (iOS 17.2+) arrive via the static `Activity<Attrs>.pushToStartTokenUpdates` sequence — there's one per app (not per attributes type, a confusing API detail Apple has confirmed in forum threads) and it should be registered in `didFinishLaunching`. Push-to-start is famously finicky; developers commonly have to delete the app, reboot the device, and reinstall before the token is issued on a given device.

A complete APNs payload looks like this:

```
apns-push-type: liveactivity
apns-topic: com.yourco.opalclone.push-type.liveactivity
apns-priority: 10          // or 5 for routine
apns-expiration: 0
authorization: bearer <JWT ES256 signed from .p8>

{
  "aps": {
    "timestamp": 1700000000,
    "event": "update",                      // or "start" (17.2+) or "end"
    "content-state": { "blockedAttempts": 3, "isPaused": false },
    "stale-date": 1700003600,
    "relevance-score": 75,
    "attributes-type": "FocusSessionAttributes",  // only for "start"
    "attributes": { ... },                        // only for "start"
    "alert": { "title": "…", "body": "…", "sound": "default" }
  }
}
```

### Priority, budget, and when to use each

Use `apns-priority: 5` (low) for routine updates — **there is no budget limit on priority-5 pushes**. Reserve `apns-priority: 10` (high) for user-critical moments like session completion. High-priority pushes consume a dynamic, undocumented hourly budget; once exhausted (replenishment can take up to 24 hours), the system silently drops them. Debug via `Console.app` filtering on `liveactivitiesd`, `apsd`, `chronod`, and `springboardd`; look for `priority(0), budget(0)` or `running-not-visible` entries.

`NSSupportsLiveActivitiesFrequentUpdates = YES` raises the high-priority budget but is user-controllable in Settings. **A focus timer does not need this** — a countdown's visual ticking is handled by `Text(timerInterval:)`, and the only semantic events (pause, resume, blocked-attempt, end) are sparse enough to fit in either the low-priority bucket or a handful of high-priority bursts.

### Local vs push update decision rule

Use **local** updates (`activity.update(...)` called from the foreground app) whenever the app is active — they're immediate and don't touch APNs budget. Use **push** updates only when the app is backgrounded or terminated and you still need the Live Activity to reflect state changes (the blocked-attempt counter being the canonical example). For a countdown, use neither: `Text(timerInterval:)` makes both unnecessary.

### Timestamp and encoding gotchas

Every push must have a strictly **monotonically increasing `timestamp`**; out-of-order updates are dropped silently. The `content-state` JSON must **exactly match** your Swift `ContentState` using default Codable encoding — no custom date strategies, no snake_case keys unless you've overridden `CodingKeys`. JWT signatures must use **ES256** and the `iat` claim must be within the last hour or APNs returns `ExpiredProviderToken` (403). A stubbornly common bug is base64 (not base64url) encoding of the JWT, which produces requests that simply hang.

---

## 4. UserNotifications framework for focus apps

### Interruption levels and the focus-timer fit

The four levels — `.passive`, `.active`, `.timeSensitive`, `.critical` — determine how a notification interacts with Focus modes and the ringer switch. Only `.timeSensitive` and `.critical` break through Focus. A focus timer's start notification should typically be `.active` (default); the end notification is the interesting case: use `.timeSensitive` so it surfaces even during a Do Not Disturb or Work focus, since the user explicitly asked to be told when the session ends. This requires the `com.apple.developer.usernotifications.time-sensitive` entitlement (usually granted without issue) and setting `content.interruptionLevel = .timeSensitive` or the payload key `"interruption-level": "time-sensitive"`. `.critical` requires a narrow Apple-approved entitlement and should not be used for focus timers.

### Live Activity alerts (iOS 16.2+)

`activity.update(_:alertConfiguration:)` accepts an `AlertConfiguration(title:body:sound:)`. On iPhone/iPad this plays the sound and surfaces the Live Activity as a banner/expanded Dynamic Island rather than a traditional notification; on Apple Watch it presents as a proper alert with title and body. This is the right mechanism for "session complete" without scheduling a separate `UNNotificationRequest`.

### Categories and actions

Declare a `UNNotificationCategory` with one or two `UNNotificationAction`s — "End session early" and "Extend 15 minutes" are the natural pair for a focus timer. Register on launch via `UNUserNotificationCenter.current().setNotificationCategories(...)` and set the outgoing `content.categoryIdentifier` to match. Handle taps in `userNotificationCenter(_:didReceive:withCompletionHandler:)`, distinguishing your custom action IDs from `UNNotificationDefaultActionIdentifier` and `UNNotificationDismissActionIdentifier`. For actions that should not open the app (e.g. "Extend"), omit `.foreground` from the action options and pair it with an `AppIntent` to handle the work.

### Focus Filters

`SetFocusFilterIntent` (App Intents) lets your app receive the user's current Focus configuration and adapt — e.g., auto-select a different block list for "Work" versus "Personal" focuses. The app doesn't learn the Focus's name; it receives filter parameters the user bound in Settings. Changes while the app is foreground trigger `perform()` immediately; otherwise, check `MyFilterIntent.current.perform()` in `sceneDidBecomeActive`. For an Opal clone, this is a genuinely nice integration point — users can tie their Work Focus to a specific focus-app block list without manual toggling.

### Apple Intelligence notification summaries (iOS 18.1+, iOS 26)

iOS 18.1 introduced AI-generated one-line summaries across grouped notifications; iOS 26 adds "Prioritize Notifications" which reorders which notifications surface first. **There is no developer API to opt your app's notifications out of summarization or prioritization** — only the user controls this per-app in Settings. Given your focus app's notifications are short and infrequent, summarization is unlikely to hurt; but be aware that an AI paraphrase may subtly distort "Focus session complete!" into something generic.

---

## 5. Dynamic Island specifics

### The region model

The `DynamicIsland { ... }` builder takes four closures: `compactLeading`, `compactTrailing`, `minimal`, and an `expanded` builder whose result contains `DynamicIslandExpandedRegion(.leading | .trailing | .center | .bottom)`. The compact state (attached, ~52 pt wide per side on 14 Pro, ~62 pt on 14 Pro Max) is shown when your app is the only/primary active activity; `minimal` (~37 pt circular) appears when another app also has an activity attached and yours is the detached secondary; `expanded` is shown on long-press or during significant state transitions. Apple has not published exact pixel dimensions — the figures above come from Infinum's and UX Planet's community-measured references and are consistent with the HIG's qualitative guidance.

**Design rules:** compact should fit a symbol + ≤4 characters of text ("88:88" timer); minimal is a single symbol; expanded should target ≤144 pt height (the system may truncate past ~160 pt on Lock Screen). Use `.monospacedDigit()` on all timer Text so the width doesn't jitter.

### Device availability and graceful degradation

Dynamic Island exists only on iPhone 14 Pro and later Pro models plus the iPhone 15, 16, 17 non-Pro lineups (which adopted the pill cutout). On all other iPhones and iPads the Lock Screen/banner view is rendered instead — the `dynamicIsland:` closure is simply ignored. Apple Watch (watchOS 11+) auto-mirrors via Smart Stack, using your compact leading/trailing by default unless you implement `.supplementalActivityFamilies([.small, .medium])` and switch on `@Environment(\.activityFamily)`. **iOS 26** extends this to CarPlay Dashboard (uses `.small`) and macOS Tahoe menu bar (uses compact regions, clicking opens the Lock Screen presentation, clicking that launches the app via iPhone Mirroring).

### Tap handling and deep links

Attach `.widgetURL(URL)` to the Dynamic Island DSL or the Lock Screen view to set the default tap target. Inside expanded regions, use `Link(destination:)` for sub-region deep links — e.g., leading opens stats, bottom opens the session controls. `Button(intent:)` is reserved for `LiveActivityIntent`-conforming intents that execute without opening the app (since iOS 17, with Lock Screen expanded support added in iOS 18).

### Multiple concurrent activities

Per app, up to 5 activities can be active; the Dynamic Island shows at most 2 (one attached + one detached minimal) at any time. Ordering is (1) highest `relevanceScore` wins the attached slot, (2) ties break by earliest-started, (3) recent user interaction can nudge priority. The Lock Screen lists all active activities ordered by relevance.

### iOS 26 specifics

No new regions, sizes, or API additions for Dynamic Island itself. Visual changes: the **Liquid Glass** material is applied automatically to the DI shell and Live Activity surfaces; the Lock Screen clock adaptively resizes to accommodate your activity. A new Live Activity **scheduling API** (used by Wallet boarding passes and Fitness in 26.x) lets you create activities for future start times. CarPlay support is non-interactive and uses `.small` — see §9.

### HIG essentials

A Live Activity must represent an **ongoing, user-initiated, real-time** activity with a defined beginning and end. Don't use it as a permanent status bar, don't display ads or marketing, don't draw attention to the Dynamic Island with blinking or movement, don't show PII or sensitive health/financial data. End the activity promptly when the task completes; use `.dismissalPolicy: .after(Date() + 60)` to linger briefly on a "Session Complete 🎉" state, or `.immediate` for user-initiated end.

---

## 6. WidgetKit and Lock Screen widgets

### Live Activity Lock Screen presentation vs Lock Screen accessory widget

These are **different systems** that happen to share a real-estate area. The ActivityKit Lock Screen view is banner-style, appears only while an activity is active, updates reactively via `activity.update(_:)` or APNs pushes, and expires after 12 hours max. A WidgetKit accessory widget is user-pinned in Lock Screen customization, always visible, updated via pre-computed `Timeline` entries or `WidgetCenter.shared.reloadTimelines(ofKind:)`, and persists until the user removes it.

For a focus app, **use both**: an `accessoryCircular` or `accessoryRectangular` widget provides a "Start focus" tap target and today's streak when no session is running; the Live Activity takes over during a session. To avoid two identical countdowns on the same Lock Screen, have the widget show *complementary* content while a session is active (e.g., today's total minutes focused) rather than duplicating the timer.

### Widget families for focus apps

The relevant families are `accessoryCircular` (~58×58 pt on iPhone Lock Screen) for a progress ring of today's goal; `accessoryRectangular` (~172×76 pt) for session name plus progress bar; `accessoryInline` for a single-line "🎯 Deep work · 22 min left" above the clock; and `systemSmall`/`systemMedium` on Home Screen for preset buttons and weekly summary. Accessory widgets render in one of three modes via `@Environment(\.widgetRenderingMode)` — `fullColor` (StandBy), `accented` (Lock Screen, tinted Home Screen), or `vibrant` (Lock Screen blending with wallpaper). Split accented content via `.widgetAccentable()`; use `AccessoryWidgetBackground()` for the standard translucent pill on circular/rectangular.

### Timeline model vs Live Activity model

Widgets are **pre-computed**: you hand back a `Timeline<Entry>` of future entries, and WidgetKit rotates through them at the entries' dates. Reload policies are `.atEnd` (most common), `.after(Date)`, or `.never`. The daily reload budget is community-reported at **40–72 entries** depending on how often the user views the widget. Live Activities are **reactive** — each update is a fresh `ContentState`; there is no timeline. Crucially, a widget's countdown should use `Text(endDate, style: .timer)` so the system re-draws each second without consuming reload budget.

After state changes in your app, call `WidgetCenter.shared.reloadTimelines(ofKind:)` (or `reloadAllTimelines()`) and `ControlCenter.shared.reloadAllControls()` to sync all surfaces.

### Smart Stack relevance

`TimelineEntryRelevance(score:duration:)` ranks entries within *your own* widget. `RelevantContext` signals (iOS 17+) let widgets surface based on time-of-day, location, headphones-detected, or workout state. iOS 18+ adds **Suggested Widgets** via `INRelevantShortcut` donation. **iOS 26** adds **Relevance Widgets** (`RelevanceEntriesProvider` / `WidgetRelevance<Configuration>`) — a widget can appear in the Smart Stack *only* when relevant and disappear afterward, with support for multiple concurrent instances. For a focus app, donate a "Start focus" shortcut tied to recurring weekday mornings at 9 AM, and score entries highest during typical focus hours.

### ControlWidget (iOS 18+)

A **ControlWidget** appears in Control Center, on the Lock Screen customizable button, and as an Action Button binding. Use `ControlWidgetButton(action: StartFocusIntent())` for a one-tap session start, or `ControlWidgetToggle` for pause/resume. iOS 26 extends Controls to the macOS Tahoe menu bar and watchOS Control Center automatically — no code changes needed. Remember to call both `WidgetCenter.shared.reloadAllTimelines()` and `ControlCenter.shared.reloadAllControls()` after state changes; the two systems have separate reload buses.

---

## 7. Focus timer best practices and competitor analysis

### How major focus apps use Live Activities

| App | Live Activity | What it shows | Source signal |
|---|---|---|---|
| **Opal** | Yes — Timer Live Activity, redesigned in 2025/26 | Active session countdown, tappable to Waiting Room / add time | App Store release notes |
| **Jomo** | Yes | Break-mode countdown in Dynamic Island | App Store release notes |
| **one sec** | Yes (iPhone 15 Pro+ only) | Intention + live usage timer of the target app | tutorials.one-sec.app |
| **Forest** | Yes | Pomodoro countdown in LA + DI (incompatible with "Deep Focus" mode) | MacRumors; App Store notes |
| **ScreenZen** | Yes, with interactive Relock button | Unlock countdown after "Skip" | App Store release notes |
| **Freedom** | No LA as of 2026 | Relies on notifications, VPN, Screen Time API | support.freedom.to |
| **Roots** | No LA confirmed; ships Home Screen widgets | "Monitor active blocks", "Breathe to Unblock" | App Store release notes |
| **Clearspace** | No LA found | App-open interception + mindfulness exercises | App Store listing |

The adopters — Opal, Jomo, one sec, Forest, ScreenZen — all share a common pattern: a short-to-medium session (≤1 hr typical) with a countdown timer and an interactive "end/extend" affordance in the expanded Dynamic Island. The abstainers (Freedom, Clearspace) tend to focus on multi-hour or indefinite blocks where the 8-hour active cap is a poor fit, and lean on notifications plus widgets instead.

### UX patterns that consistently work

**Drive the countdown with `Text(timerInterval:)` and `ProgressView(timerInterval:)`** using a `ClosedRange<Date>` stored in `ContentState`. Zero updates consumed, perfect animation, and it survives app termination since the system renders the widget. For pause state, store `pausedAt: Date?` and conditionally render either the dynamic `Text(timerInterval:)` or a static `Text(formattedElapsed)` — there's no way to actually "pause" the timer view itself. On resume, shift `startedAt` forward by the pause duration and push a single update.

**End ceremonies:** when a session completes, push a final update swapping the countdown for a "Session Complete 🎉" message, then call `activity.end(_:dismissalPolicy: .after(Date().addingTimeInterval(60)))` so the user sees the celebration for ~60 seconds before the activity disappears. Use `.immediate` only when the user explicitly taps "End session."

**Blocked-attempt counter** should increment in the `ShieldConfigurationExtension` (counts every shield render) or `ShieldActionExtension` (counts only button taps). Most apps appear to use the former for a more impactful number. Write to App Group `UserDefaults`, post a Darwin notification, and optionally hit your backend for a real-time APNs push to update the Live Activity.

### Edge case playbook

- **Device reboot mid-session:** Live Activities **do not survive reboot** (confirmed behavior; `liveactivitiesd` state is in-memory). On launch, check persisted session state; if `endDate > now`, recreate the activity via `Activity.request(...)` with adjusted fields. The app must be foregrounded to do this — schedule a local notification at session end as a safety net.
- **App force-quit:** The activity continues; it's managed by `liveactivitiesd`, not your process. `Text(timerInterval:)` keeps ticking. But `willTerminateNotification` does **not** fire on background termination (Apple Dev Forum 732418), so don't rely on it to end the activity gracefully — instead, always set a `staleDate` slightly past `endDate` as a safety net.
- **User disables Live Activities in Settings mid-session:** existing tokens become invalid; push updates silently fail. Observe `ActivityAuthorizationInfo().activityEnablementUpdates` and fall back to scheduled notifications for end alerts.
- **Session > 8 hours:** the system auto-ends at 8 hours. This is the real reason Freedom and Opal's "Fortress/Deep Focus" modes don't use Live Activities for the full session duration. Either chunk into multi-session blocks or accept the auto-end with a notification follow-up.
- **Background audio apps:** iOS forbids Live Activity updates from apps in audio-only background mode ("Process is only playing background media so is forbidden to update activity" — Apple Dev Forum 748569). Use APNs pushes instead.

### Common pitfalls with fixes

The most reported bug is **`LiveActivityIntent.perform()` not being called** — almost always because the intent struct isn't a member of *both* the app target and the widget extension target. Ben Frearson's blog documents the canonical pattern: put the intent declaration in a shared Swift file included in both targets, conform to `LiveActivityIntent`, and let the system choose the execution process.

**Push updates silently dropped** almost always means budget exhaustion (use priority 5), stale token, or disabled Live Activities. Monitor Console.app with the `Budget` filter for `priority(0), budget(0)` lines. **Widget extension crashes** often trace to sharing an AppIntent class name across two widgets (Apple Dev Forum 807831), oversized images in the minimal region, or missing `NSSupportsLiveActivities = YES` in the extension's Info.plist. **Timer stuck at "00:00"** is a known `Text(timerInterval:)` limitation — push one final update to swap in a "Complete" view.

### Accessibility

Respect Dynamic Type by using `.font(.headline.monospacedDigit())` rather than fixed sizes. Add `.accessibilityLabel("Focus session, 14 minutes remaining")` on the timer view since VoiceOver reads `Text(timerInterval:)` as raw digits. Honor `@Environment(\.accessibilityReduceMotion)` by using `.transition(.identity)` for region changes. Test Always-On Display rendering; Apple HIG explicitly requires LAs look correct on dimmed Always-On.

---

## 8. Swift/SwiftUI code patterns

### ActivityAttributes for a focus timer

```swift
import ActivityKit

struct FocusSessionAttributes: ActivityAttributes {
    // Static — set once at request time
    var sessionName: String
    var sessionGoal: String
    var startDate: Date
    var plannedEndDate: Date
    var blockedAppBundleIDs: [String]

    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var pausedAt: Date?
        var blockedAppOpenCount: Int
        var effectiveRange: ClosedRange<Date>   // drives Text(timerInterval:)
        var progress: Double
    }
}
```

### ActivityConfiguration with Dynamic Island + Lock Screen + Watch/CarPlay

```swift
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            FocusLockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.sessionName, systemImage: "brain.head.profile")
                        .foregroundStyle(.indigo)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.effectiveRange, countsDown: true)
                        .monospacedDigit().frame(maxWidth: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        ProgressView(timerInterval: context.state.effectiveRange,
                                     countsDown: false).tint(.indigo)
                        Button(intent: EndFocusIntent()) {
                            Label("End", systemImage: "stop.fill")
                        }.tint(.red)
                    }
                }
            } compactLeading: {
                Image(systemName: "brain.head.profile").foregroundStyle(.indigo)
            } compactTrailing: {
                Text(timerInterval: context.state.effectiveRange, countsDown: true)
                    .monospacedDigit().frame(maxWidth: 50)
            } minimal: {
                Image(systemName: "brain.head.profile").foregroundStyle(.indigo)
            }
            .widgetURL(URL(string: "opalclone://focus/current"))
            .keylineTint(.indigo)
        }
        // iOS 18+ Apple Watch Smart Stack; iOS 26 CarPlay Dashboard & Mac menu bar
        .supplementalActivityFamilies([.small, .medium])
    }
}
```

### Starting, updating, and ending an activity

```swift
@MainActor
final class FocusActivityManager {
    static let shared = FocusActivityManager()
    private var activity: Activity<FocusSessionAttributes>?

    var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(name: String, goal: String, duration: TimeInterval,
               blocked: [String]) throws {
        guard isSupported else {
            throw NSError(domain: "Focus", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Live Activities disabled"])
        }
        let start = Date()
        let end = start.addingTimeInterval(duration)
        let attributes = FocusSessionAttributes(
            sessionName: name, sessionGoal: goal,
            startDate: start, plannedEndDate: end,
            blockedAppBundleIDs: blocked)
        let state = FocusSessionAttributes.ContentState(
            isPaused: false, pausedAt: nil, blockedAppOpenCount: 0,
            effectiveRange: start...end, progress: 0)
        let content = ActivityContent(state: state,
            staleDate: end.addingTimeInterval(60), relevanceScore: 100)
        activity = try Activity.request(
            attributes: attributes, content: content, pushType: .token)
        observeState()
    }

    func updateBlockedCount(_ count: Int) async {
        guard let activity else { return }
        var latest = activity.content.state
        latest.blockedAppOpenCount = count
        await activity.update(ActivityContent(state: latest, staleDate: nil))
    }

    func end(immediately: Bool = false) async {
        guard let activity else { return }
        await activity.end(
            ActivityContent(state: activity.content.state, staleDate: nil),
            dismissalPolicy: immediately ? .immediate
                : .after(Date().addingTimeInterval(60)))
        self.activity = nil
    }

    private func observeState() {
        guard let activity else { return }
        Task {
            for await state in activity.activityStateUpdates {
                if state == .ended || state == .dismissed { self.activity = nil }
            }
        }
    }
}
```

### Authorization monitoring and token observation

```swift
Task {
    for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
        // Update UI; if disabled, suggest notifications-only mode
    }
}

Task {
    for await activity in Activity<FocusSessionAttributes>.activityUpdates {
        Task {
            for await token in activity.pushTokenUpdates {
                let hex = token.map { String(format: "%02x", $0) }.joined()
                await Backend.register(updateToken: hex, activityID: activity.id)
            }
        }
    }
}

// iOS 17.2+ push-to-start (register in didFinishLaunching)
Task {
    for await token in Activity<FocusSessionAttributes>.pushToStartTokenUpdates {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        await Backend.register(pushToStartToken: hex)
    }
}
```

### LiveActivityIntent for interactive buttons

```swift
import AppIntents

// Put this struct in a file added to BOTH the app and the widget extension targets.
struct EndFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Focus Session"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await FocusActivityManager.shared.end(immediately: false)
        return .result()
    }
}
```

---

## 9. iOS 26 specifically

iOS 26 is primarily an **environmental expansion** of Live Activities rather than an API rewrite — the ActivityKit surface is backward compatible with iOS 16.2 code — but the net result is significantly more surfaces for free if you opt in.

**Liquid Glass design system.** The system chrome around Live Activities is now the Liquid Glass material — translucent, refractive, adapting to wallpaper. The Lock Screen clock adaptively resizes to accommodate your activity. Don't apply `.glassEffect()` to your own primary content — let system chrome do the work and keep text on solid legible tints (Donny Wals has written extensively on this). Widgets gain a formal accented rendering mode on Home Screen and macOS desktop with new modifiers `.widgetAccentedRenderingMode(.desaturated | .accentedDesaturated | .fullColor)`.

**CarPlay Live Activities.** Every Live Activity automatically appears on the CarPlay Dashboard, non-interactive (no button taps while driving). The system prefers the `.small` activity family; if you haven't adopted `.supplementalActivityFamilies([.small])`, CarPlay falls back to your compact leading/trailing views. For a focus timer, driving is itself a focus context — showing session name + remaining time is a legitimate win. You can opt out per-activity if inappropriate.

**macOS Tahoe (macOS 26) menu-bar Live Activities.** Zero code required. iPhone Live Activities surface in the macOS menu bar via iPhone Mirroring; clicking shows the Lock Screen view, clicking that launches the app on the iPhone. Works with any paired iPhone on iOS 18+.

**AlarmKit (new in iOS 26).** A new framework that builds on top of ActivityKit. Every alarm automatically creates a system-managed Live Activity using `AlarmAttributes` + `AlarmPresentation`. Crucially, AlarmKit alarms **break through Silent mode and Focus modes** without the Critical Alerts entitlement — previously only Apple's Clock app could do this. Supports fixed-schedule, weekly, and countdown-based alarms; requires `NSAlarmKitUsageDescription` in Info.plist and explicit user authorization. For a focus timer, AlarmKit is the right tool for the **session-end alert** (since you want it to cut through whatever Focus mode the user has active), while raw ActivityKit remains the right tool for the **in-progress UI**. Caveats (per Michael Tsai's coverage): in AlarmKit 1.0, the stop intent is not called when the user swipes away the alarm, so accidental dismissals aren't reliably detectable.

**Relevance Widgets (iOS 26 / watchOS 26).** A new `RelevanceEntriesProvider` / `WidgetRelevance<Configuration>` API lets a widget appear in the Smart Stack *only* when relevant and disappear afterward — with support for multiple concurrent instances. For a focus app, surface the "Start focus" widget during the user's typical focus hours rather than permanently rotating it in.

**Live Activity scheduling API.** New in iOS 26.x (used by Wallet boarding passes and Fitness): schedule future Live Activities for events that haven't started yet. Relevant if you let users plan sessions in advance.

**Screen Time API on iOS 26.** No substantial API additions at WWDC 2025 — Xcode 26.4 beta exposes a new "Family Controls App & Website Usage" identifier capability with unclear semantics. The **regressions** are the story: unreliable `DeviceActivity` callbacks, premature threshold firing, `deviceactivityd` log silence on 26.3.1, silent permission revocation after upgrade, and occasional `ApplicationToken` rotation. Build defensively: reconcile state on foreground, persist `FamilyActivitySelection` rather than individual tokens, and prompt re-picking if tokens no longer match.

**Apple Intelligence.** No direct ActivityKit integration. App Intents gained interactive snippets at WWDC 25 — potentially useful for post-session quick actions, but separate from Live Activities. Users can disable per-app notification summarization and prioritization; there is no developer opt-out API.

**No new Dynamic Island regions or sizes.** The region model (`compactLeading`, `compactTrailing`, `minimal`, expanded with `.leading/.trailing/.center/.bottom`) is identical to iOS 16.1.

**WWDC 2026** is scheduled June 8–12, 2026 — it has not yet occurred as of this report (April 18, 2026). No iOS 27 material exists.

---

## 10. Real-world constraints: entitlements, Info.plist, and App Review

### Info.plist requirements

```xml
<!-- Main app target -->
<key>NSSupportsLiveActivities</key><true/>

<!-- Optional; use only if you really need sub-minute high-priority pushes -->
<key>NSSupportsLiveActivitiesFrequentUpdates</key><true/>

<!-- iOS 26: if you adopt AlarmKit for session-end alerts -->
<key>NSAlarmKitUsageDescription</key>
<string>FocusApp uses alarms to notify you when a focus session ends, so the alert breaks through Focus modes.</string>

<!-- Widget extension target also needs this -->
<key>NSSupportsLiveActivities</key><true/>
```

### Target layout and capabilities

You will need five targets: main app, widget extension (contains Live Activity + accessory widgets + ControlWidgets), `DeviceActivityMonitor` extension, `ShieldConfigurationExtension`, and `ShieldActionExtension`. All five share a single App Group (`group.com.yourco.opalclone`) added in Signing & Capabilities. All five require `com.apple.developer.family-controls` — **for both Development and Distribution**, requested separately per bundle ID via developer.apple.com/contact/request/family-controls-distribution.

Capabilities on the main app: Push Notifications (for `.token` pushType), Family Controls (Distribution), App Groups, Time-Sensitive Notifications. The `ActivityAttributes` struct must be in a Swift file with Target Membership on both the main app and the widget extension so both sides agree on the type.

### FamilyControls entitlement approval reality

The `.distribution` entitlement cannot be obtained by Personal Teams; the Account Holder (not an Admin) must submit the request. Historical turnaround is 1–5 weeks but has been creeping up — 2025–2026 forum threads cite 3–4 weeks with some requests stuck indefinitely. **Request all of them on day one**, including per-extension bundle IDs, or you will be blocked from TestFlight. Each submission needs a clear justification: describe the self-control use case, what shields are applied, and what data flows. Apple rejects submissions where FamilyControls is used for general automation or data harvesting rather than genuine screen-time/parental control purposes.

Once approved, enable Family Controls (Distribution) under each App ID's Additional Capabilities, and regenerate provisioning profiles. Mismatched Development vs Distribution profiles produce the common archive error *"Provisioning profile failed qualification. Profile doesn't support Family Controls (Development)."*

### App Store review notes

The most-cited **Live Activity rejection patterns** are: using the activity for promotional content or upsells rather than a real ongoing task; not providing a clear start/end (HIG requires ≤8 hours and prompt termination); drawing attention to the Dynamic Island; displaying sensitive information. Guideline 2.5.18 bans advertising in extensions — your Live Activity view must not contain ads. Guideline 4.5.4 governs push notifications broadly and is invoked against Live Activities that feel promotional.

For **FamilyControls apps**, common rejections include using `.child` authorization for an adult self-control app (must be `.individual`), missing demo credentials/mode for reviewers (they need to see shields in action without doing a full onboarding flow), lacking a functional privacy policy link in both the app and App Store Connect, attempting to serialize or transmit `ApplicationToken` values off-device, and apps that expose only the system `FamilyActivityPicker` without meaningful additional logic (4.2 Minimum Functionality). Provide detailed review notes walking through the full user flow: grant Screen Time → pick apps → start session → observe shield → Live Activity appears with countdown and attempt counter.

Privacy considerations for tokens: `ApplicationToken`, `WebDomainToken`, and `ActivityCategoryToken` are deliberately opaque — you cannot resolve them to bundle IDs or URLs. Display via `Label(token)` which asks the system to render the icon and name. Never log tokens; encode with `PropertyListEncoder()` or `JSONEncoder()` for persistence within an authorization session and accept that they may rotate on iOS upgrade.

---

## Conclusion: the recommended architecture, at a glance

For an Opal clone on iOS 26, the right design is a **single `Activity<FocusSessionAttributes>` started foreground-only from the main app**, with its countdown driven entirely by `Text(timerInterval:)` + `ProgressView(timerInterval:)` so no updates are consumed while the session runs normally. Interactive Pause/End buttons in the expanded Dynamic Island use `LiveActivityIntent` — declared in a file that's a member of both the app and widget targets.

The blocked-app-attempt counter increments inside `ShieldConfigurationExtension`, writing to an App Group `UserDefaults` and posting a Darwin notification. For **v1 without a backend**, the Live Activity's counter only updates when the main app next runs and issues `activity.update(...)`; for **v1.1 with a backend**, the extension hits your server over HTTPS (permitted in Shield extensions), which sends an `apns-push-type: liveactivity` low-priority push to update the counter in real time.

The session-end alert should use **AlarmKit (iOS 26)** rather than a plain `UNUserNotification` — it breaks through Focus modes without requiring the Critical Alerts entitlement. Use `.supplementalActivityFamilies([.small, .medium])` to get Apple Watch Smart Stack, CarPlay Dashboard, and macOS Tahoe menu bar mirroring for free. End with `.dismissalPolicy: .after(Date() + 60)` to show a "Session Complete 🎉" state briefly before disappearing.

The three biggest things to plan for are (1) the 8-hour active Dynamic Island cap, which forces multi-hour "Fortress" modes to chunk sessions, (2) iOS 26's real Screen Time regressions, which require defensive reconciliation on every foreground, and (3) the 1–5 week FamilyControls entitlement approval window per bundle ID, which should start on day one of the project. Get the architecture right and ActivityKit rewards you with a polished, glanceable presence across every Apple surface the user touches.