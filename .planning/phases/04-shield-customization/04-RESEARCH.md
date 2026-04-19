# Phase 4: Shield Customization - Research

**Researched:** 2026-04-19
**Domain:** ManagedSettingsUI / ShieldConfiguration / ShieldActionDelegate / Custom URL Scheme
**Confidence:** HIGH (API surface verified against iOS 26.3 simulator binary; critical limitation verified via Apple Developer Forums + binary analysis)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Visual Identity (SHL-01)**
- D-01: Background = blur overlay. `backgroundBlurStyle` set to native UIBlurEffect.Style (exact style is Claude's Discretion), `backgroundColor` = violet `#7C3AED` with low alpha (~0.6–0.8). Exact alpha is Claude's Discretion.
- D-02: Icon = SF Symbol `hand.raised.fill` in white, rendered to `UIImage`, passed as `ShieldConfiguration.icon`. Zero custom assets in MVP.
- D-03: Title copy = sarcastic-sharp Polish. Draft direction: `"Serio?"` / `"Dopiero co sam sobie to zablokowałeś"`. Subtitle in the same tone. Exact strings drafted in execute.
- D-04: Dynamic remaining time in subtitle — PREFERRED if the extension can read `plannedEndAt` from `active_session.json` at render time. If cold-start/race — degrade to static sarcasm without minutes.

**Button Configuration (SHL-03)**
- D-05: Two buttons: primary `ShieldConfiguration.primaryButtonLabel` = "Zobacz ile zostało", background `#7C3AED`. Secondary = Apple default dismiss (`secondaryButtonLabel` nil or explicit "Zamknij"). Claude's Discretion on nil vs explicit.
- D-06: Primary triggers `ShieldActionExtension.handle(action:for:completionHandler:)` with `.primaryButtonPressed`. Extension opens app via URL scheme (see critical finding below), then `completionHandler(.close)`.
- D-07: Secondary `.close` without opening app.

**Deep Link (SHL-04)**
- D-08: Custom URL scheme `deluludetox://` with path `session/active`. Registered in `project.yml` under main app target via `CFBundleURLTypes`. No AASA/universal links in MVP.
- D-09: Handler on root `AppRootViewModel` via SwiftUI `.onOpenURL(perform:)` on `AppRootView`. Parses host/path, dispatches to `HomeViewModel` via shared publisher. For `session/active` → `Destination.countdown(CountdownViewModel(...))`.
- D-10: Fallback routing (deep link with no active session): active session exists and `plannedEndAt > now` → countdown; session just ended (completed, success screen not yet shown) → success screen; otherwise → root home with optional toast.

**Unknown-Token Fallback (SHL-02)**
- D-11: Detection: read `active_session.json` from App Group. If missing, empty, or parse fails → fallback branch. No parsing of `blocklists.json`.
- D-12: Fallback visual = SAME shield design (blur + violet + icon + two buttons). Copy only differs: title = `"Zablokowane"`, subtitle = `"Zamknij i zrób coś mądrzejszego"`.
- D-13: Fallback primary button = `"Otwórz DeluluDetox"`. Deep link URL = `deluludetox://` (root). No `session/active` path in fallback.

**Extension Integration**
- D-14: ShieldConfigurationExtension covers all four `configuration(shielding:)` overrides. Same `ShieldConfiguration` for all token types. Shared via `buildShieldConfiguration(context:)` private helper.
- D-15: ShieldActionExtension covers all four override variants, all delegating to `handleAction(_:for:completionHandler:)`.
- D-16: Both extensions read-only against App Group files. Never write to `active_session.json`, `sessions.json`, or `blocklists.json`.
- D-17: RAM: no third-party SDKs. Imports only Foundation + UIKit + ManagedSettings + ManagedSettingsUI.

### Claude's Discretion
- Exact UIBlurEffect.Style (`.systemThickMaterialDark` vs `.regular` vs other) — pick during execute after visual test.
- Alpha of violet tint (0.6 vs 0.8) — choose in execute.
- Point size / weight of `hand.raised.fill` — choose for readability.
- Exact sarcastic strings (title, subtitle, button copy) — draft multiple variants in execute.
- Mechanism for whether `plannedEndAt` is usable in subtitle (D-04) — in-memory vs try/catch per render.
- Exact form of toast/UI when deep link lands with no active session (D-10) — toast vs inline banner vs silent route.
- Secondary button color — Apple default system blue or neutral gray.
- Whether secondary button is explicit `"Zamknij"` or nil (Apple default).
- Localization strategy (hard-coded PL vs `.strings` file) — align with Phase 1–3 approach.

### Deferred Ideas (OUT OF SCOPE)
- Shield behavior at exact moment session ends while shield is visible (Phase 3 D-08 handles clear).
- Per-source shield differentiation (quick vs schedule) — same design for all sources in MVP.
- Analytics/logs from shield extension.
- Custom logo/mascot instead of SF Symbol.
- Universal Links (AASA file).
- Localization beyond PL (MVP only).
- Haptic feedback / sound on shield actions.
- Emergency pass / 1 free break per day.
- Dynamic copy based on outcome history.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHL-01 | Shield displays custom branding (colors, icon, text) | ShieldConfiguration 8-field struct; SF Symbol → UIImage; UIColor for violet; blur style selection |
| SHL-02 | Shield shows fallback design for unknown/unexpected tokens | `active_session.json` read + parse failure → fallback branch; same visual, generic copy |
| SHL-03 | Shield has action button that deep links to main app | **CRITICAL FINDING:** No first-party `openApp` API exists; workaround using `NSExtensionContext.open(_:)` from delegate is documented as unsupported but functional; confirmed approach is to call `completionHandler(.defer)` then trigger URL via `NSExtensionContext` |
| SHL-04 | Main app handles incoming deep link from shield and shows relevant session context | `CFBundleURLTypes` in project.yml; `.onOpenURL` on AppRootView; dispatch to HomeViewModel via Combine publisher; reuse `Destination.countdown` |
</phase_requirements>

---

## Summary

Phase 4 customizes the ManagedSettingsUI shield overlay for blocked apps. The core work splits into three parts: (1) the `ShieldConfigurationExtension` that builds the branded `ShieldConfiguration` struct; (2) the `ShieldActionExtension` that handles button taps and triggers app-opening; (3) the main app URL scheme registration and deep-link routing into the existing `HomeViewModel.Destination.countdown` case.

**Critical finding — SHL-03 (deep link from shield):** There is **no public Apple API** to open a URL or the parent app from `ShieldActionDelegate` as of iOS 26.3. `ShieldActionResponse` has exactly three cases: `.close`, `.defer`, `.none`. The CONTEXT.md reference to `context.openApp(URL)` does not exist in the public API. The confirmed workaround used by production apps (Opal, one-sec, AppLocker) is to call `NSExtensionContext.open(_:completionHandler:)` via the extension's context — this is not officially documented for ShieldActionExtension but is broadly used without App Store rejection. The planner must include a spike (build + test on device) to verify this works on iOS 26 before committing to it as the primary path; if it fails, the fallback is a local push notification (requires permission). The CONTEXT.md D-06 goal is achievable via this workaround; the plan should treat it as "production-grade community approach" rather than "Apple-blessed API."

**ShieldConfiguration** is frozen at 8 fields since iOS 16. All types are UIKit (UIColor, UIImage, UIBlurEffect.Style) — no SwiftUI. Extension imports must stay lean: Foundation + UIKit + ManagedSettings + ManagedSettingsUI only, to respect the 6 MB RAM ceiling.

**Primary recommendation:** Implement ShieldConfigurationExtension sharing `SessionPaths.swift` via project.yml source-share (same pattern used for DAM extension in Phase 3 Plan 04). Read `active_session.json` with a local lightweight Decodable that decodes only `plannedEndAt` (not the full SessionRecord, to avoid FamilyControls-adjacent imports). Implement URL opening via `NSExtensionContext.open(_:completionHandler:)` in ShieldActionExtension. Register URL scheme in project.yml main app target. Handle `.onOpenURL` on AppRootView, route through HomeViewModel's existing Combine publisher pattern.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 4 |
|-----------|-------------------|
| Swift 6.2, SwiftUI, iOS 26.0+ locked | All code targets Swift 6 concurrency; UIKit mandatory in extensions (no SwiftUI in shield) |
| No backend — on-device + App Group | Session state read from `group.com.kksw.DeluluDetox` App Group only |
| ShieldAPI frozen since 2022, 8-field struct, no SwiftUI/network/TextField | Can only use 8 fields; UIColor/UIImage only; no dynamic web images |
| Extension RAM: 6 MB ceiling | Zero third-party SDKs in extension targets; local Decodable envelope only (no full SessionRecord) |
| Clean Architecture MVVM + UseCase + Repository | Extensions have no ViewModel layer; thin configuration builders only; main-app deep-link handler uses existing UC patterns |
| Feature-first layout | Shield feature lives under `Extensions/` (system-imposed structure); main-app handler code lives under existing Root/Home feature trees |
| DIContainer + @LazyInjected for ViewModels | Deep-link dispatch from AppRootView re-uses existing `homeModel` @State reference; no new injection needed in extensions |
| swift-navigation for all navigation | Deep link routes through existing `HomeViewModel.Destination.countdown` enum case |
| Edit project.yml, never .xcodeproj | URL scheme registration and source-sharing done exclusively via project.yml |
| Build/test via XcodeBuildMCP | Build verification uses `build_sim`; extension behavior requires device |
| ViewModels use @Observable, never import SwiftUI | New `AppRootViewModel.handleDeepLink(_:)` stays in existing file, no SwiftUI imports |

---

## Standard Stack

### Core (Extension targets)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ManagedSettings | iOS 26 system | Shield tokens, token types (Application/WebDomain/ActivityCategory) | Required for ShieldConfigurationDataSource + ShieldActionDelegate base classes |
| ManagedSettingsUI | iOS 26 system | ShieldConfiguration struct + ShieldConfigurationDataSource | Required to produce the shield configuration |
| UIKit | iOS 26 system | UIColor, UIImage, UIBlurEffect.Style | ShieldConfiguration only accepts UIKit types, no SwiftUI |
| Foundation | iOS 26 system | Codable, FileManager, JSONDecoder, URL | App Group file reading, minimal Decodable envelope |
| os (Logger) | iOS 26 system | Diagnostic logging | Same pattern as DAM extension (scalar-only .public privacy) |

### Core (Main app additions)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUINavigation | 2.x (already installed) | Handle deep link by mutating Destination enum | Already in project; `.onOpenURL` flows into existing Wzorzec A/B pattern |
| Combine | iOS system (already used) | Propagate deep link intent from AppRootViewModel to HomeViewModel | Established Phase 1-3 pattern (Repository CurrentValueSubject) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom URL scheme | Universal Links (AASA) | Universal Links require AASA file + web server + Apple approval; custom scheme works fully on-device. Decision locked (D-08). |
| NSExtensionContext.open(_:) workaround | Local push notification for deep link | Push requires user permission, can be blocked by Focus; NSExtensionContext approach requires no permission and fires immediately. Community evidence: Opal, one-sec, AppLocker all use it. |
| Read only `plannedEndAt` from active_session.json | Import full SessionRecord | Full SessionRecord has FamilyControls-adjacent imports; violates 6 MB RAM constraint. Local envelope is established Phase 3 DAM pattern (see 03-04-SUMMARY.md). |

**Installation:** No new packages required. All frameworks are system-provided. URL scheme registration is config-only (project.yml edit).

---

## Architecture Patterns

### Recommended Project Structure

```
Extensions/
├── ShieldConfigurationExtension/
│   └── ShieldConfigurationExtension.swift   # ShieldConfigurationDataSource subclass
└── ShieldActionExtension/
    └── ShieldActionExtension.swift           # ShieldActionDelegate subclass

DeluluDetox/Sources/Features/Root/
├── ViewModel/
│   └── AppRootViewModel.swift               # Add handleDeepLink(_:) method
└── View/
    └── AppRootView.swift                    # Add .onOpenURL modifier

DeluluDetox/Sources/Features/Home/
└── ViewModel/
    └── HomeViewModel.swift                  # Add navigateToActiveSession() intent

project.yml                                  # URL scheme + source-share for SessionPaths
```

### Pattern 1: ShieldConfigurationDataSource — shared source file via project.yml

**What:** The extension reads `active_session.json` using a local Decodable envelope (only `plannedEndAt: Date`) shared via project.yml explicit path entry — same as DAM extension in Phase 3 Plan 04.

**When to use:** Whenever extension needs a subset of main-app models without pulling in FamilyControls-adjacent imports.

**Example:**
```swift
// Source: Phase 3 Plan 04 SUMMARY — established DAM extension pattern
// project.yml — add to ShieldConfigurationExtension sources:
sources:
  - path: Extensions/ShieldConfigurationExtension
  - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift

// ShieldConfigurationExtension.swift
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

// Local lightweight envelope — decode only what is needed.
// Do NOT import SessionRecord (pulls FamilyControls-adjacent types).
private struct ActiveSessionEnvelope: Decodable {
    let plannedEndAt: Date
}

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildShieldConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        buildShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        buildShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        buildShieldConfiguration()
    }

    private func buildShieldConfiguration() -> ShieldConfiguration {
        // Attempt to read remaining time from active_session.json.
        let remainingMinutes = loadRemainingMinutes()
        return makeConfig(remainingMinutes: remainingMinutes)
    }

    private func loadRemainingMinutes() -> Int? {
        guard let url = try? SessionPaths.activeSessionURL(),
              let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(ActiveSessionEnvelope.self, from: data) else {
            return nil  // Fallback path
        }
        let remaining = envelope.plannedEndAt.timeIntervalSinceNow
        guard remaining > 0 else { return nil }
        return max(1, Int(remaining / 60))
    }

    private func makeConfig(remainingMinutes: Int?) -> ShieldConfiguration {
        let violetColor = UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.75)
        let icon = UIImage(
            systemName: "hand.raised.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold)
        )?.withTintColor(.white, renderingMode: .alwaysOriginal)

        let (title, subtitle, primaryLabel, primaryURL): (String, String, String, URL)
        if let minutes = remainingMinutes {
            title = "Serio?"
            subtitle = "Jeszcze \(minutes) min zanim znowu będziesz mógł scrollować."
            primaryLabel = "Zobacz ile zostało"
            primaryURL = URL(string: "deluludetox://session/active")!
        } else {
            // Fallback: no active session context
            title = "Zablokowane"
            subtitle = "Zamknij i zrób coś mądrzejszego."
            primaryLabel = "Otwórz DeluluDetox"
            primaryURL = URL(string: "deluludetox://")!
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,   // Claude's Discretion — visual test
            backgroundColor: violetColor,
            icon: icon,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.88)),
            primaryButtonLabel: ShieldConfiguration.Label(text: primaryLabel, color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1.0),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Zamknij", color: .systemBlue)
        )
    }
}
```

**Note on URL passing:** The extension does not pass the URL through ShieldConfiguration — that struct has no URL field. The URL is hardcoded in ShieldActionExtension based on action type. ShieldConfigurationExtension and ShieldActionExtension are separate processes and cannot share state directly; both independently read `active_session.json`.

### Pattern 2: ShieldActionDelegate — NSExtensionContext URL workaround

**What:** The confirmed production workaround for opening the main app from a shield button, because `ShieldActionResponse` has no `.openApp` case. The delegate's `NSExtensionContext` is accessible via the responder chain.

**CRITICAL RISK:** This is an unofficial approach. Apple's official position (as of 2026-04-19 per Apple Developer Forums thread/719905) is "not supported." However, it is used in production by multiple App Store apps (Opal, one-sec, AppLocker) and community Feedback ID FB17261679 tracks the request. The extension's own `NSExtensionContext` (if accessible) can call `open(_:completionHandler:)`.

**When to use:** Only this approach or local push notifications are available for SHL-03.

**Example:**
```swift
// Source: community pattern — Apple Developer Forums thread/793060 + riedel.wtf/state-of-the-screen-time-api-2024
import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {

    private let sessionActiveURL = URL(string: "deluludetox://session/active")!
    private let rootURL = URL(string: "deluludetox://")!

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    // ... other three overrides delegate to handleAction(_:completionHandler:)

    private func handleAction(
        _ action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            openMainApp()
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    private func openMainApp() {
        // Determine which URL based on active session presence.
        let url = hasActiveSession() ? sessionActiveURL : rootURL

        // Workaround: NSExtensionContext.open(_:completionHandler:) from extension context.
        // Not officially documented for ShieldActionExtension, but used in production by
        // Opal, one-sec, AppLocker. Risk: potential future App Store restriction.
        // [ASSUMED] This pattern works on iOS 26 (unverified on device in this session).
        extensionContext?.open(url, completionHandler: nil)
    }

    private func hasActiveSession() -> Bool {
        guard let url = try? SessionPaths.activeSessionURL(),
              let data = try? Data(contentsOf: url),
              !data.isEmpty else { return false }
        return true
    }
}
```

**Spike required:** Plan must include a Wave 0 spike task that builds + tests this on a physical device before implementing the full flow. If `extensionContext` is nil in ShieldActionExtension (which is possible — it depends on the runtime context Apple provides), the fallback is a local push notification.

### Pattern 3: URL scheme registration in project.yml

**What:** Register a custom URL scheme for the main app target so iOS routes `deluludetox://` URLs to DeluluDetox.

**When to use:** Required for SHL-04 deep linking from shield.

**Example:**
```yaml
# project.yml — under DeluluDetox target info.properties:
targets:
  DeluluDetox:
    info:
      properties:
        CFBundleURLTypes:
          - CFBundleURLName: com.kksw.DeluluDetox
            CFBundleURLSchemes:
              - deluludetox
```

### Pattern 4: .onOpenURL deep-link handler on AppRootView

**What:** SwiftUI's `.onOpenURL(perform:)` modifier on AppRootView receives all URLs for the custom scheme. The handler calls a method on `AppRootViewModel`, which forwards via Combine to `HomeViewModel` to set `Destination.countdown`.

**When to use:** For SHL-04 main-app routing on deep link arrival.

**Example:**
```swift
// Source: navigation GUIDE.md §NavigationStack with a path — established project pattern
// AppRootView.swift (addition)
var body: some View {
    Group { ... }
    .onOpenURL { url in
        model.handleDeepLink(url)
    }
}

// AppRootViewModel.swift (addition)
func handleDeepLink(_ url: URL) {
    // Only handle deluludetox:// scheme
    guard url.scheme == "deluludetox" else { return }
    // Dispatch intent — AppRoot notifies HomeViewModel via shared repository
    // OR AppRoot holds a reference to homeModel and calls navigateToActiveSession() directly.
    // See Architecture Pattern note below.
    deepLinkSubject.send(url)
}
```

**Routing approach:** AppRootViewModel needs a channel to HomeViewModel. The cleanest approach given existing architecture:
- Add a `PassthroughSubject<URL, Never>` to `AppRootViewModel` (or expose it via a shared service registered in DI).
- `HomeViewModel` subscribes to this subject in its `init()` and maps URL path to `Destination` mutations.
- This follows the Wzorzec B event flow rule from navigation GUIDE.md: "child writes → Repository → parent's .sink".

Alternatively (simpler, lower ceremony): `AppRootView` holds `homeModel` as `@State` and the `.onOpenURL` closure can call `homeModel.handleDeepLink(url)` directly — this is acceptable since it's a View-level wiring, not architecture pollution.

### Anti-Patterns to Avoid

- **Importing SessionRecord in extensions** — it pulls in FamilyControls-adjacent types and blows the 6 MB RAM budget. Use a local Decodable envelope with only the fields needed (established DAM pattern from 03-04-SUMMARY.md).
- **Import SwiftUI or Combine in extensions** — zero reason; both add significant footprint. Shield extensions need UIKit only.
- **UIApplication.shared.open(_:) in extension** — UIApplication.shared is unavailable in extension context. Use `extensionContext?.open(_:)` or `NSExtensionContext` workaround.
- **Writing to App Group files from extensions** — D-16 locks: ShieldConfigurationExtension and ShieldActionExtension are read-only against all App Group files.
- **Using ShieldConfiguration.icon with a non-tinted UIImage** — the icon renders at whatever color the UIImage carries. Use `UIImage.withTintColor(.white, renderingMode: .alwaysOriginal)` for white color.
- **Treating ShieldConfigurationExtension and ShieldActionExtension as the same process** — they are separate extension processes. Do not attempt to pass state between them at runtime; both read `active_session.json` independently.
- **secondaryButtonLabel = nil expecting Apple default** — Apple's default for a nil secondary button is to show no secondary button at all. If you want a dismiss button, provide an explicit label. (Ref: Apple Docs note: "if secondaryButtonLabel is nil, it will not be shown".) Claude's Discretion whether to use nil vs explicit "Zamknij".

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UIBlurEffect.Style selection | Custom blur implementation | Apple's `UIBlurEffect.Style` enum values passed to `ShieldConfiguration.backgroundBlurStyle` | System handles composition; custom blur would be code with no API surface |
| SF Symbol rendering to UIImage | Custom icon drawing | `UIImage(systemName:withConfiguration:).withTintColor(.white, renderingMode:.alwaysOriginal)` | Standard pattern; SF Symbols are vector, scale correctly |
| JSON file reading in extension | Custom file manager | `Data(contentsOf:)` + `JSONDecoder` with App Group URL from `SessionPaths` (already written) | SessionPaths is already in the codebase; source-share via project.yml |
| URL scheme routing | Custom URL parser | Standard `url.scheme`, `url.host`, `url.path` properties on `URL` | Swift Foundation handles this correctly; no parsing library needed |
| Navigation to countdown | New countdown screen for deep link | Reuse `HomeViewModel.Destination.countdown(CountdownViewModel(session:))` from Phase 3 | Phase 3 already built the countdown screen; deep link is a new entry point, not a new screen |

**Key insight:** Phase 4 is deliberately thin — no new UI screens, no new data models, no new DI registrations. It wires existing pieces (SessionPaths, SessionRecord schema, AppRootViewModel, HomeViewModel.Destination.countdown) via new entry points (extensions + URL scheme).

---

## Runtime State Inventory

This phase is not a rename/refactor phase. However, there is one runtime state item to verify:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `active_session.json` in `group.com.kksw.DeluluDetox` — read by ShieldConfigurationExtension | Code edit only (extension reads existing file) |
| Live service config | App Group entitlement already registered in ShieldConfigurationExtension.entitlements and ShieldActionExtension.entitlements (verified in project.yml grep) | None — already configured |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

**ShieldConfigurationExtension.entitlements already has App Group:** Verified — `com.apple.security.application-groups: [group.com.kksw.DeluluDetox]` is present in project.yml for both extension targets.

---

## Common Pitfalls

### Pitfall 1: Assuming `context.openApp(URL)` exists

**What goes wrong:** CONTEXT.md D-06 refers to `context.openApp(URL)` — this method does NOT exist in the public `ShieldActionDelegate` or `ShieldActionExtensionContext` API. `ShieldActionResponse` has only `.close`, `.defer`, `.none`. The plan will compile-error if `context.openApp` is used verbatim.

**Why it happens:** The CONTEXT.md was authored based on research-phase assumptions about what the API might look like; the actual API was confirmed via binary analysis of ManagedSettings.framework in iOS 26.3.

**How to avoid:** Use `extensionContext?.open(url, completionHandler: nil)` via the `NSExtensionContext` workaround, or document the spike result if this is nil on device.

**Warning signs:** Compiler error "value of type 'ShieldActionExtensionContext' has no member 'openApp'". If you see this, switch to the `extensionContext` workaround.

**Confidence:** HIGH — verified by binary analysis of iOS 26.3 ManagedSettings.framework (strings output shows only `.close`, `.defer`, `.none` for ShieldActionResponse).

### Pitfall 2: ShieldConfiguration icon renders as black/invisible

**What goes wrong:** `UIImage(systemName: "hand.raised.fill")` returns a UIImage in template rendering mode. Without explicit tint, on a dark blur background it may render black (invisible) or system-blue.

**Why it happens:** SF Symbol images default to template mode; `ShieldConfiguration.icon` renders at the image's tint color.

**How to avoid:** 
```swift
UIImage(systemName: "hand.raised.fill", withConfiguration: ...)
    .withTintColor(.white, renderingMode: .alwaysOriginal)
```

**Warning signs:** Icon invisible against dark blur background during visual test.

### Pitfall 3: JSONDecoder date decoding mismatch

**What goes wrong:** `active_session.json` encodes `Date` fields using the default `JSONDecoder` date strategy (ISO 8601 via `JSONEncoder`). If the Shield extension creates a `JSONDecoder` without setting `dateDecodingStrategy`, it may fail to decode `plannedEndAt`.

**Why it happens:** Default `JSONDecoder.dateDecodingStrategy` is `.deferredToDate` (seconds since epoch), but `JSONEncoder.dateEncodingStrategy` default is also `.deferredToDate`. If Phase 3 `SessionRepository` uses a custom date strategy, the extension must match it.

**How to avoid:** Check `SessionRepositoryImpl` for its `JSONDecoder/Encoder` configuration. Mirror it in the extension's local decoder. If Phase 3 uses default strategy (both .deferredToDate), the extension decoder requires no special setup.

**Verification:** `grep -rn "dateDecodingStrategy\|dateEncodingStrategy" DeluluDetox/Sources/Features/Session/`

### Pitfall 4: `extensionContext` is nil in ShieldActionExtension

**What goes wrong:** The NSExtensionContext workaround relies on `self.extensionContext` being non-nil. `ShieldActionDelegate` inherits from NSObject, not UIViewController. The `extensionContext` property may not be populated by the runtime.

**Why it happens:** `NSExtensionContext` is designed for UI extensions (Share, Today) that have a lifecycle. ShieldActionExtension is not a UI extension in the same sense.

**How to avoid:** The spike task in Wave 0 must verify `extensionContext != nil` on device. If nil → fall back to local push notification strategy.

**Warning signs:** URL opens successfully on simulator (URLs may be handled differently) but does nothing on device.

### Pitfall 5: URL scheme conflict or omission in project.yml

**What goes wrong:** URL scheme registered but `.onOpenURL` handler on AppRootView never fires; or deep link opens a different app.

**Why it happens:** `CFBundleURLTypes` must be added under `info.properties` in the correct target (`DeluluDetox`, not extensions). The scheme must be unique.

**How to avoid:** Verify `project.yml` after `xcodegen generate` by checking `DeluluDetox.xcodeproj` target's Info tab for `URL Types`. Test with `xcrun simctl openurl booted deluludetox://session/active` from the command line.

### Pitfall 6: ShieldConfigurationExtension re-renders synchronously at high frequency

**What goes wrong:** On some iOS versions, `configuration(shielding:)` can be called repeatedly. If `Data(contentsOf:)` + `JSONDecoder` is slow (file I/O), it may cause noticeable latency in shield appearance.

**Why it happens:** Shield display is synchronous; the extension must return `ShieldConfiguration` immediately. Disk I/O on every call is fine in practice (the file is tiny, ~200B) but may cause issues if the App Group container is temporarily unavailable (cold boot, migration).

**How to avoid:** Wrap the entire `loadRemainingMinutes()` in a try/catch that returns `nil` on any error. The fallback branch displays immediately without dynamic data. Do not add async operations.

### Pitfall 7: AppRootView has no channel to HomeViewModel for deep link routing

**What goes wrong:** `.onOpenURL` fires on AppRootView, but AppRootViewModel only knows about `Destination.onboarding/denial/home` — it has no way to tell HomeViewModel to navigate to countdown.

**Why it happens:** AppRootViewModel uses Wzorzec B (no VM payload in enum cases); `homeModel` lives as `@State` on AppRootView, not on AppRootViewModel.

**How to avoid:** The cleanest solution for this project's architecture: `.onOpenURL` in AppRootView calls `homeModel.handleDeepLink(url)` directly (since `homeModel` is in scope as `@State` on AppRootView). This is View-level wiring, not a domain concern — acceptable per navigation GUIDE.md. Alternatively, add a `deepLinkPublisher: PassthroughSubject<URL, Never>` to AppRootViewModel and subscribe in HomeViewModel — cleaner testability.

---

## ShieldConfiguration API — Complete Field Reference

[VERIFIED: iOS 26.3 ManagedSettingsUI.framework binary analysis + Apple Developer Documentation init signature]

```swift
ShieldConfiguration(
    backgroundBlurStyle: UIBlurEffect.Style?,        // e.g. .systemThickMaterialDark, .dark, .regular
    backgroundColor: UIColor?,                        // Blended over blur; use alpha < 1.0 for tint effect
    icon: UIImage?,                                   // UIImage — must use .alwaysOriginal for color control
    title: ShieldConfiguration.Label?,               // Label(text: String, color: UIColor)
    subtitle: ShieldConfiguration.Label?,            // Label(text: String, color: UIColor)
    primaryButtonLabel: ShieldConfiguration.Label?,  // nil → system default label
    primaryButtonBackgroundColor: UIColor?,           // nil → system default blue
    secondaryButtonLabel: ShieldConfiguration.Label? // nil → NO secondary button shown
)
```

**ShieldConfiguration.Label:**
```swift
ShieldConfiguration.Label(text: String, color: UIColor)
```

**ShieldActionResponse cases (confirmed via binary):**
- `.close` — dismiss shield, return user to home screen
- `.defer` — keep shield active; used when waiting for external event (e.g. guardian approval)
- `.none` — update shield appearance without changing presentation state

**No `.openApp` case exists in iOS 26.3.**

---

## Code Examples

### SF Symbol to UIImage (white tinted)
```swift
// Source: Foqos ShieldConfigurationExtension.swift (MIT) + Apple UIImage docs
let icon = UIImage(
    systemName: "hand.raised.fill",
    withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold)
)?.withTintColor(.white, renderingMode: .alwaysOriginal)
```

### UIColor from hex #7C3AED
```swift
// Source: Phase 1 decision — direct RGB init (no asset catalog)
// Violet #7C3AED = R:124 G:58 B:237 → normalized: R:0.486 G:0.227 B:0.929
let violetSolid = UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1.0)
let violetTint = UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.75)  // alpha = Claude's Discretion
```

### App Group file read (extension-safe)
```swift
// Source: Phase 3 Plan 04 — DAM extension local envelope pattern
private struct ActiveSessionEnvelope: Decodable {
    let plannedEndAt: Date
}

private func loadRemainingMinutes() -> Int? {
    guard let url = try? SessionPaths.activeSessionURL(),
          let data = try? Data(contentsOf: url),
          let envelope = try? JSONDecoder().decode(ActiveSessionEnvelope.self, from: data) else {
        return nil
    }
    let remaining = envelope.plannedEndAt.timeIntervalSinceNow
    guard remaining > 0 else { return nil }
    return max(1, Int(remaining / 60))
}
```

### URL scheme registration in project.yml
```yaml
# Source: XcodeGen GUIDE.md §basics — CFBundleURLTypes under info.properties
targets:
  DeluluDetox:
    info:
      path: DeluluDetox/Info.plist
      properties:
        CFBundleURLTypes:
          - CFBundleURLName: com.kksw.DeluluDetox
            CFBundleURLSchemes:
              - deluludetox
```

### Deep link handler on AppRootView
```swift
// Source: navigation GUIDE.md §NavigationStack with a path
// AppRootView.body addition:
.onOpenURL { url in
    homeModel.handleDeepLink(url)
}

// HomeViewModel addition:
func handleDeepLink(_ url: URL) {
    guard url.scheme == "deluludetox" else { return }
    // session/active path → route to countdown if session exists
    if url.host == "session" && url.path == "/active" {
        navigateToActiveSession()
    } else {
        // Root or unknown → go home (destination = nil clears any modal)
        destination = nil
    }
}

private func navigateToActiveSession() {
    // Read active session from repository via existing UC
    // If active session exists → destination = .countdown(CountdownViewModel(session:))
    // If session just completed and success not shown → destination = .sessionSuccess(...)
    // Else → destination = nil (silent home)
}
```

### Source-sharing SessionPaths with ShieldConfigurationExtension
```yaml
# project.yml — mirrors Phase 3 Plan 04 DAM source-share pattern
ShieldConfigurationExtension:
  sources:
    - path: Extensions/ShieldConfigurationExtension
    - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
    # NOTE: Do NOT add SessionRecord.swift — imports FamilyControls-adjacent types
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Empty `ShieldConfiguration()` stub (Phase 1 scaffold) | Branded configuration with 8 fields populated | Phase 4 | Actual branded shield visible to user |
| No URL scheme | `deluludetox://` custom scheme | Phase 4 | Shield buttons can navigate to main app |
| Shield button does `completionHandler(.close)` only | Primary button triggers app-open then `.close` | Phase 4 | User can reach active session context from shield |

**Deprecated/outdated:**
- `UIApplication.shared.openURL(_:)` — deprecated iOS 10+, also unavailable in extensions. Use `extensionContext?.open(_:)` workaround or `UIApplication.shared.open(_:options:completionHandler:)` in main app.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `extensionContext?.open(url)` works in ShieldActionExtension on iOS 26 device (community pattern, not in Apple docs) | SHL-03 / ShieldActionDelegate pattern | If wrong: fallback is local push notification; UX is significantly worse. Spike required. |
| A2 | `JSONDecoder` default date strategy matches what Phase 3 `SessionRepository` uses for encoding (both default `.deferredToDate`) | Common Pitfall 3 | If wrong: `plannedEndAt` decoding fails silently, dynamic subtitle never appears (graceful fallback exists) |
| A3 | `ShieldConfigurationExtension` on iOS 26 simulator will show custom shield (not Apple default) during build verification | Environment Availability | Simulator may show Apple default shield regardless of extension; device verification required for actual visual check |
| A4 | `AppRootView.onOpenURL` fires when `deluludetox://session/active` URL is opened while the app is running (not cold-launch) | SHL-04 | If wrong: need to also handle via `Scene.openURL` or AppDelegate; both `WindowGroup.onOpenURL` and Scene-level handlers should be verified |

---

## Open Questions

1. **Does `extensionContext` exist on ShieldActionDelegate?**
   - What we know: `ShieldActionDelegate` inherits from NSObject. NSExtensionContext workaround is used by production apps but not officially documented for shield extensions.
   - What's unclear: Whether `self.extensionContext` is non-nil in the ShieldActionExtension process on iOS 26.
   - Recommendation: Wave 0 spike — add a single task that builds ShieldActionExtension with logging of `extensionContext != nil` and verifies URL open on device. Block SHL-03 tasks on spike result.

2. **What is the existing date encoding strategy in SessionRepository?**
   - What we know: `SessionRepositoryImpl` uses `JSONDecoder` and `JSONEncoder`. Phase 3 plan doesn't explicitly state the date strategy.
   - What's unclear: Whether default `.deferredToDate` is used or a custom ISO8601 strategy.
   - Recommendation: Grep `SessionRepositoryImpl.swift` for `dateDecodingStrategy` / `dateEncodingStrategy` before writing the extension decoder. If custom strategy found, mirror it. If not found, default is safe.

3. **Does `HomeViewModel.handleDeepLink` need a new UseCase for "get current active session synchronously"?**
   - What we know: `HomeViewModel` already has `ObserveActiveSessionUseCase` which emits via Combine. For deep link routing, it needs to read the current active session synchronously (or `await` the publisher's current value).
   - What's unclear: Whether `HomeViewModel` can use `repository.activeSubject.value` or needs a new `GetActiveSessionUseCase`.
   - Recommendation: Check if `ObserveActiveSessionUseCase` exposes a synchronous current-value getter or if `SessionRepository` protocol has one. If `SessionRepositoryImpl.activeSubject.value` is accessible, use it. Otherwise add a lightweight `GetActiveSessionUseCase` (one method, wraps `activeSubject.value`).

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ManagedSettings.framework | ShieldConfigurationExtension, ShieldActionExtension | ✓ | iOS 26.3 (verified in simulator runtime) | — |
| ManagedSettingsUI.framework | ShieldConfigurationExtension | ✓ | iOS 26.3 (verified in simulator runtime) | — |
| iOS 26.3 Simulator (UUID C958163F) | Build verification | ✓ | 26.3 (CLAUDE.md default) | — |
| Physical iOS 26+ device | Shield visual test + URL-open spike | Unknown — not verified in this session | — | Simulator build-only (visual unverifiable on simulator) |
| `xcodegen` CLI | project.yml edits | ✓ (assumed — used in all prior phases) | — | — |

**Missing dependencies with no fallback:**
- Physical iOS 26+ device for UA test (SHL-03 spike + SHL-01 visual verification). The plan must include a human-verification task that requires device.

**Missing dependencies with fallback:**
- If `extensionContext?.open(_:)` fails on device → local push notification fallback for SHL-03 (documented in Open Questions).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, 78+ tests passing) |
| Config file | Xcode project target `DeluluDetoxTests` |
| Quick run command | XcodeBuildMCP `test_sim` on `DeluluDetox` scheme |
| Full suite command | XcodeBuildMCP `test_sim` on `DeluluDetox` scheme (full suite) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHL-01 | ShieldConfiguration struct is built correctly with violet color, white icon, non-nil labels | unit | `test_sim` → `ShieldConfigurationBuilderTests` | ❌ Wave 0 |
| SHL-01 | SF Symbol UIImage renders non-nil with white tint | unit | `test_sim` → `ShieldConfigurationBuilderTests` | ❌ Wave 0 |
| SHL-02 | Fallback branch triggered when `active_session.json` is missing | unit | `test_sim` → `ShieldConfigurationBuilderTests` | ❌ Wave 0 |
| SHL-02 | Fallback branch triggered when JSON is malformed | unit | `test_sim` → `ShieldConfigurationBuilderTests` | ❌ Wave 0 |
| SHL-02 | Fallback uses generic copy (not session-specific text) | unit | `test_sim` → `ShieldConfigurationBuilderTests` | ❌ Wave 0 |
| SHL-03 | Primary action sends `.close` response | unit | `test_sim` → `ShieldActionHandlerTests` | ❌ Wave 0 |
| SHL-03 | Secondary action sends `.close` response | unit | `test_sim` → `ShieldActionHandlerTests` | ❌ Wave 0 |
| SHL-03 | `extensionContext?.open(_:)` called for primary action | manual-only | Device spike task | — |
| SHL-03 | URL opened is `deluludetox://session/active` when session active | unit | `test_sim` → `ShieldActionHandlerTests` (URL check via test double) | ❌ Wave 0 |
| SHL-03 | URL opened is `deluludetox://` (root) when no session | unit | `test_sim` → `ShieldActionHandlerTests` | ❌ Wave 0 |
| SHL-04 | `deluludetox://session/active` URL parsed correctly by HomeViewModel | unit | `test_sim` → `HomeViewModelTests` (new test) | ❌ Wave 0 (existing file) |
| SHL-04 | `deluludetox://session/active` routes to `Destination.countdown` when session exists | unit | `test_sim` → `HomeViewModelTests` | ❌ Wave 0 (existing file) |
| SHL-04 | `deluludetox://session/active` routes to home when no active session | unit | `test_sim` → `HomeViewModelTests` | ❌ Wave 0 (existing file) |
| SHL-04 | `deluludetox://` (root) routes to home | unit | `test_sim` → `HomeViewModelTests` | ❌ Wave 0 (existing file) |
| SHL-04 | Shield button tap → app opens → countdown screen visible | manual-only | Device human verification task | — |

### Testability Architecture Note

**What can be unit-tested:**
- `ShieldConfigurationBuilder` (extracted pure function: `(Int?) -> ShieldConfiguration` equivalent) — can be tested in `DeluluDetoxTests` target by calling the builder with mocked `remainingMinutes` values.
- URL encoder/decoder logic in HomeViewModel.
- `HomeViewModel.handleDeepLink(_:)` — driven with mock `ObserveActiveSessionUseCase` (existing `MockObserveActiveSessionUseCase` in test suite).

**What requires device (manual-only):**
- Actual shield rendering (visual branding, blur, colors) — simulator shows stub shield regardless.
- `extensionContext?.open(_:)` URL open — device only.
- `ShieldConfigurationExtension` + `ShieldActionExtension` extension processes — cannot be XCTest-unit-tested (separate process, no test harness available).

**Test file placement:**
- New `DeluluDetoxTests/Features/Shield/ShieldConfigurationBuilderTests.swift`
- New `DeluluDetoxTests/Features/Shield/ShieldActionHandlerTests.swift`
- Additions to existing `DeluluDetoxTests/Features/Home/HomeViewModelTests.swift`

### Sampling Rate
- **Per task commit:** `test_sim` full suite — maintain baseline (currently 78 tests, 0 failures)
- **Per wave merge:** Full suite green
- **Phase gate:** Full suite green + human verification on device before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `DeluluDetoxTests/Features/Shield/ShieldConfigurationBuilderTests.swift` — covers SHL-01, SHL-02
- [ ] `DeluluDetoxTests/Features/Shield/ShieldActionHandlerTests.swift` — covers SHL-03 (pure logic)
- [ ] Additions to `DeluluDetoxTests/Features/Home/HomeViewModelTests.swift` — covers SHL-04

*(No framework install needed — XCTest already in project.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Shield is display-only; no auth in extension |
| V3 Session Management | No | Extension does not manage sessions (read-only) |
| V4 Access Control | Partial | App Group sandbox enforces extension read-only access; no additional control needed |
| V5 Input Validation | Yes | URL scheme must validate `scheme`, `host`, `path` before routing; reject unknown paths to root home |
| V6 Cryptography | No | No encryption in this phase |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| URL scheme hijack (another app registers `deluludetox://`) | Spoofing | Custom schemes are first-come-first-served on iOS; no mitigation possible; accepted for MVP on-device-only usage |
| Extension reads stale `active_session.json` (race with main app write) | Tampering | Read-only + graceful fallback on any parse error (D-11). Atomic writes from main app minimize race window |
| URL parsing injection (malformed path in deep link) | Tampering | Validate `url.scheme == "deluludetox"` before acting; unknown paths → root home (safe default) |
| Extension crashes on `extensionContext?.open(_:)` | Denial of Service | Wrap in guard / optional chain; `completionHandler(.close)` always called regardless |

**App Store Guideline 5.5 compliance:** The sarcastic copy style (D-03) must avoid: emotional guilt-tripping, false urgency, claims of negative consequences. "Serio?" and "Zamknij i zrób coś mądrzejszego" are playful, not manipulative — consistent with the Phase 3 D-12 tone rule. Final copy must be reviewed against these guidelines during execute phase.

---

## Sources

### Primary (HIGH confidence)
- iOS 26.3 ManagedSettingsUI.framework binary — `strings` extraction confirming 8-field struct, `Label` type, field names, no `openApp` in ShieldActionResponse
- iOS 26.3 ManagedSettings.framework binary — `strings` extraction confirming ShieldActionResponse cases: `.close`, `.defer`, `.none` only
- Phase 3 03-04-SUMMARY.md — DAM extension source-share pattern (shared SessionPaths, local Decodable envelope)
- `.claude/guides/navigation/GUIDE.md` — Wzorzec B pattern, `.onOpenURL` example, `HomeViewModel.Destination` structure
- `DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` — existing Destination enum, `refreshStatus` pattern
- `DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift` — `Destination.countdown(CountdownViewModel)` case, existing Combine subscription pattern
- `Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.swift` — confirmed empty scaffold, 4 override stubs
- `Extensions/ShieldActionExtension/ShieldActionExtension.swift` — confirmed empty scaffold, 3 override stubs with `.close` default
- `project.yml` — confirmed App Group entitlements in both extension targets; confirmed no URL scheme registered yet

### Secondary (MEDIUM confidence)
- Foqos ShieldConfigurationExtension.swift (MIT, github.com/awaseem/foqos) — production-grade pattern for all 4 overrides, UIImage emoji rendering, `ShieldConfiguration.Label` usage
- Apple Developer Documentation init signature — `init(backgroundBlurStyle:backgroundColor:icon:title:subtitle:primaryButtonLabel:primaryButtonBackgroundColor:secondaryButtonLabel:)` confirmed
- riedel.wtf/state-of-the-screen-time-api-2024/ — confirmed ShieldActionDelegate limitation (no openApp API)

### Tertiary (LOW confidence / flagged assumptions)
- Apple Developer Forums thread/719905 — community confirmation that `NSExtensionContext.open(_:)` is used by production apps (Opal, one-sec, AppLocker) but is "not supported" per Apple DTS
- Apple Developer Forums thread/793060 — local push notification as fallback for shield-to-app navigation
- riedel.wtf Feedback ID FB17261679 — open request for `.openParentApp` ShieldActionResponse case (not addressed in iOS 26.3)

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — all frameworks are system-provided and already in the project
- Architecture: HIGH — patterns directly mirror Phase 3 DAM extension (verified working)
- SHL-01/SHL-02 (shield configuration): HIGH — 8-field API confirmed via binary analysis
- SHL-03 (deep link from shield): LOW-MEDIUM — the `extensionContext?.open(_:)` workaround is community-confirmed but not Apple-blessed; spike required
- SHL-04 (main app URL handling): HIGH — standard SwiftUI `.onOpenURL` + existing HomeViewModel.Destination.countdown

**Research date:** 2026-04-19
**Valid until:** 2026-06-01 (stable APIs; ShieldActionResponse limitation unlikely to change without WWDC announcement)
