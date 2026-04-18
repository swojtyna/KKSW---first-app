# Screen Time API — Known Bugs on iOS 26 (Production Mines)

**Research date:** April 18, 2026
**iOS versions anchored:** iOS/iPadOS 26.0 GA (Sept 2025) through 26.4.1 (latest public), with scattered 26.5 beta 1–2 signals. Xcode references: 26.2, 26.3, 26.4.
**Frameworks in scope:** FamilyControls, ManagedSettings, ManagedSettingsUI, DeviceActivity.
**Source weighting:** Apple Developer Forums (primary, high-confidence), Apple Developer docs/release notes, one sec / Roots / Tech Lockdown blogs. Reddit / Stack Overflow / HN / Indie Hackers returned **essentially zero iOS-26-specific developer discussion** — the entire community lives on Apple Dev Forums for this API family.

> **Caveat on FB numbers:** Every FB number below was found verbatim in a cited Apple Dev Forums thread or in Frederik Riedel's public "one sec" dev omnibus. None invented. Where a bug predates iOS 26 but is still reproducing on 26.x, that is flagged explicitly.

---

## TL;DR — The five bugs most likely to blow up an Opal-clone in production

1. **`eventDidReachThreshold` fires within seconds of scheduling** (iOS 26 regression, **FB18061981 / FB18927456 / FB13696022 / FB18351583 / FB21320644 / FB20817853**). Your shield slams on before the user has used the app at all. Apple DTS says a fix is in 26.5 beta 1 — not yet user-confirmed.
2. **`eventDidReachThreshold` fires with 0 minutes of usage on iOS 26.2** (**FB21450954**) — repros after plugging into power overnight. Apple DTS confirmed "known issue under investigation" in the parallel thread/809410 (FB21267341).
3. **Thresholds silently never fire at all** on iOS 26 (FB22304617 and a cluster of 7 older radars) — the *opposite* failure mode. Breaks daily-limit UX completely and affects Apple's own Screen Time too.
4. **FamilyControls authorization silently lost after iOS 26 upgrade** (**FB18997699**) — your shield stack evaporates and the user sees no prompt.
5. **ApplicationToken randomization** in `ShieldConfigurationDataSource` / `ShieldActionDelegate` (FB14082790, FB18764644) — tokens delivered to your extensions don't `==` anything you persisted, destroying per-app shield customization. Still reproducing on 26.2.1; the fix did **not** make 26.5 beta 1.

The common thread: **every durable Opal-clone needs a fallback path that does not trust DeviceActivity timing or ApplicationToken identity.** Treat the API as best-effort, not guaranteed.

---

## A. Authorization bugs

### Bug: FamilyControls authorization is silently lost on iOS 26
- **What happens:** An app that was previously authorized loses its Screen Time / FamilyControls permission with no user action, no prompt, and no error — shields stop applying for end users.
- **When:** Reported against iOS 26 beta 1 (June 2025) and continuing into iOS 26 GA. Affects both developer devices and App Store users after upgrading to 26.
- **FB #:** **FB18997699** (sysdiagnose attached).
- **Reported by:** Frederik Riedel ("Quappi") / one sec — https://developer.apple.com/forums/thread/794128 and summarized in omnibus post https://developer.apple.com/forums/thread/819997
- **Workaround:** None. Your app must detect `.notDetermined` / `.denied` transitions on foreground and re-prompt. Consider persisting a "last known good auth timestamp" and alerting the user when it regresses.
- **Status on iOS 26:** **Active.** No fix in 26.0–26.4; Apple has not commented publicly in 10+ months.

### Bug: `AuthorizationCenter.shared.$authorizationStatus` publisher does not fire on revocation
- **What happens:** When the user revokes FamilyControls individual authorization from Settings, ManagedSettings restrictions drop immediately, but the Combine publisher `$authorizationStatus` emits **nothing** on a non-debug build — app never learns it lost power.
- **When:** iOS 26.2, Xcode 26.3, Swift 6.2.4. Publisher only fires when a debugger is attached.
- **FB #:** Not publicly known (no FB cited in thread).
- **Reported by:** anonymous OP — https://developer.apple.com/forums/thread/820796
- **Workaround:** Poll `AuthorizationCenter.shared.authorizationStatus` on every foreground transition and when your `DeviceActivityMonitor` extension wakes. Do not rely on Combine.
- **Status on iOS 26:** **Active, single-reporter.** Security-sensitive for MDM / parental-control use cases because restrictions drop without the app being notified.

### Bug: iOS 26.4 new "App & Website Usage" capability removes the "approved-without-data-access" tier
- **What happens:** After adopting the new iOS 26.4 `com.apple.developer.family-controls-app-and-website-usage` capability (paired with the new `AuthorizationStatus.approvedWithDataAccess`), end users can choose only *full access with usage data* or *nothing* — the prior intermediate `.approved` state becomes unobtainable.
- **When:** iOS 26.4 + Xcode 26.4 beta 3+.
- **FB #:** Not publicly known.
- **Reported by:** forum user `nemecek_f` — https://developer.apple.com/forums/thread/820283
- **Workaround:** Do not adopt the new capability unless you genuinely need usage-data access. If you do, your onboarding flow must accept that users who decline will now be *fully* unauthorized.
- **Status on iOS 26:** **Open — possibly intended behavior.** Apple has not responded. Treat as a design change you must plan around, not a guaranteed bug fix.

### Bug: Screen Time passcode bypass via Face ID when revoking app's Screen Time access (iOS 26.4)
- **What happens:** Settings → Apps → [your app] → Screen Time Access toggle prompts for Face ID instead of the Screen Time passcode, letting a tampering user revoke your app's Screen Time access without the parental passcode. Undermines the iOS 26.4 "Lock Screen Time" promise.
- **When:** iOS 26.4.
- **FB #:** Not publicly known.
- **Reported by:** forum thread — https://developer.apple.com/forums/thread/821959
- **Workaround:** None available to a third-party app. Surface this risk to parents in your copy.
- **Status on iOS 26:** **Active on 26.4.** Security-sensitive; watch for 26.4.x / 26.5.

---

## B. Token bugs (ApplicationToken / WebDomainToken / ActivityCategoryToken)

### Bug: ApplicationTokens delivered to extensions do not match persisted tokens
- **What happens:** The `ApplicationToken` passed into `ShieldConfigurationDataSource.configuration(shielding:in:)` and `ShieldActionDelegate.handle(action:for:completionHandler:)` does not equate (`==`) any token previously selected via `FamilyActivityPicker` and written to your App Group. You cannot map the shielded app back to the user's block/profile, so custom shield UI and shield actions fail.
- **When:** Explicitly reported on **iOS 26.2.1**. The same failure mode existed historically (iOS 17.5.1, threads 756440 / 758325), so this is partly an iOS-26 *continuation* of a longstanding bug — flagged. Frederik Riedel reports it worsened on iOS 26 and that the slated fix did not ship in 26.5 beta 1.
- **FB #:** **FB14082790**, **FB18764644** (per Frederik's omnibus — FB18764644 was reportedly tagged for 26.5 beta 1 but did not land).
- **Reported by:** Frederik Riedel — https://developer.apple.com/forums/thread/819997 ; also a 26.2.1 repro in https://developer.apple.com/forums/thread/814571
- **Workaround:** Two-layer defense. (1) Ask users to unselect + reselect apps in the picker to regenerate tokens — temporary (regresses within days). (2) Do **not** rely on token equality; instead key your shield configuration off the `FamilyActivitySelection` set and fall back to a generic shield if lookup fails. Never crash or return empty on unknown tokens.
- **Status on iOS 26:** **Active.** Fix deferred past 26.5 beta 1.

### Bug: Moving a token between `ManagedSettingsStore`s reuses the old shield configuration
- **What happens:** If you move an `ApplicationToken` from store A to store B, `ShieldConfigurationDataSource` is not re-queried; the token continues to render with store A's shield.
- **When:** Reproduced on iOS 26 beta 7 per the reporter. Bug predates iOS 26 (per Frederik, "since 2020"), so **not an iOS 26 regression** — flagged — but still active on 26.x.
- **FB #:** **FB14237883**, **FB17902392**.
- **Reported by:** Frederik Riedel — https://developer.apple.com/forums/thread/819997
- **Workaround:** Force re-evaluation by removing the token from all stores, waiting a tick on the main queue, then inserting into the new store. Some teams maintain a single store and vary shield content rather than moving tokens.
- **Status on iOS 26:** **Active, longstanding.**

### Bug: No API to open the parent app from a shield action or from an ApplicationToken
- **What happens:** From a custom shield, you cannot programmatically open your containing app (useful for "let me explain why this is blocked" flows), and you cannot open the blocked target app from an `ApplicationToken` either. Limits custom UX severely.
- **When:** iOS 26 continues the prior limitation; treated as a framework gap rather than a regression.
- **FB #:** **FB15079668** (open parent app), **FB15500695** (open target from token), and related FB22347946 / FB18846650 / FB15500681 / FB10393561 in Frederik's follow-up.
- **Reported by:** Frederik Riedel — https://developer.apple.com/forums/thread/820790
- **Workaround:** Some teams embed a universal link / custom URL scheme in shield UI text and instruct users to tap it manually via the system sheet. No automatic open.
- **Status on iOS 26:** **Feature request, not yet filled.**

---

## C. ManagedSettings bugs

### Bug: Shields remain applied after morning downtime / rest-period ends on iOS 26.2
- **What happens:** Apps that are supposed to unblock when downtime ends (e.g., at 7 AM) remain shielded; device logs usage against the user before they have touched the phone. Often the only remedy is a reboot.
- **When:** Started with iOS 26.2 upgrade. Widely reproduced by end users and likely rooted in the same DeviceActivity timing regressions described in section D.
- **FB #:** Not publicly known; correlates with FB21450954 / FB21267341.
- **Reported by:** multiple end-user threads including https://discussions.apple.com/thread/256216039 and Roots app support docs https://intercom.help/roots/en/articles/13440805-ios-26-2-known-issue-time-limits-triggering-early
- **Workaround (end-user):** Toggle Settings → Screen Time → Apps With Screen Time Access **off then on** for the affected app. Not durable.
- **Status on iOS 26:** **Active on 26.2+.** No confirmed fix in 26.3 / 26.4.

### Bug: Shields cannot block Compact Live Activities in the Dynamic Island
- **What happens:** ManagedSettings correctly blocks the app surface, notifications, and Lock Screen Live Activities, but **Compact Live Activities in the Dynamic Island continue to render** for a shielded app.
- **When:** Reproduced on iOS 26, but the bug predates iOS 26 (flagged — not an iOS 26 regression). No framework API exists to suppress Dynamic Island compact presentations from ManagedSettings.
- **FB #:** Not publicly known.
- **Reported by:** anonymous forum post under https://developer.apple.com/forums/tags/managed-settings
- **Workaround:** None at the framework level.
- **Status on iOS 26:** **Active, longstanding.**

### Bug: Shielding an app also suppresses its notifications (no way to separate)
- **What happens:** Applying an `ApplicationToken` to `ManagedSettingsStore.shield` unconditionally suppresses notifications for that app. There is no public way on iOS 26 to shield UI while still allowing notifications to arrive.
- **When:** iOS 26 (confirmed framework behavior, not a new regression — flagged).
- **FB #:** Not publicly known.
- **Reported by:** multiple Apple Developer Forums answers under tags/managed-settings.
- **Workaround:** None via public API. Some teams emulate "notification-only" awareness by scheduling their own user-visible notifications in the parent app based on DeviceActivity events, but only for apps the user explicitly opts into notification proxying.
- **Status on iOS 26:** **By design on 26.x.**

### Bug: `webContent.blockedByFilter = .specific(domains)` does not filter Safari but does filter Chrome/Firefox
- **What happens:** The `.specific(domains)` variant of `ManagedSettingsStore.webContent.blockedByFilter` fails to block listed domains in Safari, yet correctly blocks them in Chrome and Firefox. `.all(except: domains)` does work in Safari.
- **When:** Reproduced on iOS 26 by the Foqos developer and corroborated on Apple Dev Forums. Historical behavior — flagged as **not purely an iOS 26 regression** but definitely still present.
- **FB #:** Not publicly known.
- **Reported by:** Foqos developer (https://github.com/awaseem/foqos) and tags/managed-settings forum posts.
- **Workaround:** If you need Safari blocking, use `.all(except:)` with an allow-list instead of a block-list, or rely on content-blocker extensions for domain-level control.
- **Status on iOS 26:** **Active, longstanding.**

---

## D. DeviceActivity bugs — the category with the most production mines

### Bug: `eventDidReachThreshold` fires within seconds of scheduling (iOS 26 regression)
- **What happens:** Immediately after you register a `DeviceActivityEvent` with a threshold (e.g., 30 minutes), `DeviceActivityMonitor.eventDidReachThreshold()` is invoked within seconds, with `includesPastActivity = false` and zero actual usage. Your shield applies instantly.
- **When:** First reproduced on iOS 26.0 beta 1 (June 2025). Persists through 26.0, 26.1, 26.2 beta. "Quite reliably reproduces after each new beta seed."
- **FB #:** **FB18061981, FB18927456, FB13696022, FB18351583, FB21320644** (Frederik Riedel / Quappi); user-filed **FB20817853**.
- **Reported by:** Frederik Riedel ("Quappi"), one sec — https://developer.apple.com/forums/thread/808470 and https://developer.apple.com/forums/thread/819997 ; one sec help center article https://tutorials.one-sec.app/en/articles/5709826 cites FB18061981 verbatim.
- **Workaround:** Ask users to revoke and re-grant Screen Time permission in Settings — holds about two weeks or until the next beta seed. Delete + reboot is another transient fix. Not durable.
- **Status on iOS 26:** **Active on 26.0–26.4.** Apple DTS engineer Albert Pascual stated in thread/808470 that a fix targets **iOS 26.5 beta 1**; Frederik reports cautious optimism as of early April 2026 but the bug is non-deterministic and not yet confirmed fixed by the original reporter.

### Bug: `eventDidReachThreshold` fires with 0 minutes of real usage at interval boundaries (iOS 26.2)
- **What happens:** For a `DeviceActivitySchedule` that runs 00:00–23:59 daily, `eventDidReachThreshold` fires on roughly 50% of days even when Settings → Screen Time shows **0 minutes** of usage on the selected apps. Sysdiagnose reveals `UsageTrackingAgent` telling the extension that "unproductive from activity daily reached its threshold."
- **When:** iOS 26.2 (build 23C55), iPhone 13 Pro Max, 30-min threshold, 2-app selection. Not observed prior to 26.2. Repro correlation identified: device idle/locked for hours → plug into charger while locked → threshold fires within minutes.
- **FB #:** **FB21450954**.
- **Reported by:** `SaulD18` — https://developer.apple.com/forums/thread/811305 ; corroborated by `mdiazmen` ("hundreds of users affected") in https://developer.apple.com/forums/thread/812472 and by Quappi in thread/808470.
- **Workaround:** None from Apple. Roots app tells users to toggle Settings → Screen Time → Apps With Screen Time Access off/on. From your side, gate shield application on "minutes ≥ some sanity floor" by cross-checking `DeviceActivityReport` data before trusting the callback.
- **Status on iOS 26:** **Active.** No fix in 26.3 / 26.4.

### Bug: `eventDidReachThreshold` fires on first device unlock of the day / after charger connection (iOS 26.2 RC → 26.3)
- **What happens:** Every registered `eventDidReachThreshold` callback fires immediately when the user first picks up the device after overnight idle, or when the device is plugged into a charger. On iOS 26.3 beta 3 the pattern shifted to "fires on each app's first open of the day" instead of a single burst.
- **When:** iOS 26.2 RC first, then 26.3 beta, 26.3 beta 3 (variant), and 26.3 RC. Also reportedly affects Apple's own App Limits.
- **FB #:** **FB21267341**.
- **Reported by:** forum user `kgaidis` — https://developer.apple.com/forums/thread/809410 (3.1k views, most-read thread in this cluster). Apple DTS engineer marked this "known issue under investigation" as the accepted answer.
- **Workaround:** None reported.
- **Status on iOS 26:** **Apple-acknowledged, still open on 26.3 RC.** No confirmed fix through 26.4.

### Bug: Thresholds silently never fire at all
- **What happens:** The opposite failure mode — `eventDidReachThreshold` never fires even after the real threshold is exceeded. Affects both third-party shield apps and Apple's own Screen Time App Limits.
- **When:** iOS 26.x. Exact sub-version not pinned in the omnibus, but consistent across multiple user reports since 26.0.
- **FB #:** **FB22304617, FB20526837, FB15491936, FB12195437, FB15663329, FB18198691, FB18289475, FB19827144.** Several of these FB#s predate iOS 26 (FB12195437, FB15491936, FB15663329), so this is partly a continuation of longstanding issues that Frederik reports **worsened** on iOS 26 — flagged.
- **Reported by:** Frederik Riedel — https://developer.apple.com/forums/thread/819997
- **Workaround:** Belt-and-braces: run a secondary timer in your main app and, on foreground, compute elapsed usage from `DeviceActivityReport` aggregates and apply the shield yourself via `ManagedSettingsStore` if needed. Do not rely solely on the callback.
- **Status on iOS 26:** **Active, "no response from Apple" after 10 months** per Frederik.

### Bug: Screen Time usage data itself is corrupted (hundreds of hours/week on a single domain)
- **What happens:** Raw Screen Time usage data returned by the system is wildly inflated — e.g., ~20 hours/day against one website, hundreds of hours/week against a single domain. This data feeds both Apple's own UI and your `DeviceActivityReport`, so it also likely drives the false-threshold fires in Bug D-2.
- **When:** iOS 26.x.
- **FB #:** **FB22304617, FB17777429, FB18464235.** (Some predate iOS 26 — flagged.)
- **Reported by:** Frederik Riedel — https://developer.apple.com/forums/thread/819997
- **Workaround:** None at the framework level. Sanity-check any aggregate numbers you display to users (clip to 24h/day). Apple Community users anecdotally report turning off "Share across devices" helps with display corruption in some cases, but this does not address API data integrity.
- **Status on iOS 26:** **Active.**

### Bug: `deviceactivityd` silent — DeviceActivityMonitor extension never wakes on iOS 26.3.1
- **What happens:** After registering a valid, non-repeating `DeviceActivitySchedule`, the `DeviceActivityMonitor` extension is never invoked — `init()`, `intervalDidStart(for:)`, `intervalDidEnd(for:)`, and `eventDidReachThreshold(_:activity:)` logs all stay empty. `DeviceActivityCenter().activities` correctly lists the registered activity. Other third-party Screen Time apps on the same device do wake, so it is not device-wide. Shields never re-apply.
- **When:** iOS 26.3.1, iPhone 17 Pro, Xcode 26.4, development-signed build with the `com.apple.developer.family-controls` entitlement.
- **FB #:** None yet; reporter references similarity to older **FB13556935** — flag that this may be a recurrence rather than pure new regression.
- **Reported by:** anonymous OPs — https://developer.apple.com/forums/thread/820956 and https://developer.apple.com/forums/thread/819242
- **Workaround:** Fall back to `UNCalendarNotificationTrigger` from the main app to apply shields when the extension fails to wake; only works while the main app is alive. Some teams additionally run a short `BGAppRefreshTask` loop as a third layer.
- **Status on iOS 26:** **Open, single-to-few reporters.** May be entitlement / code-signing sensitive — test both dev and TestFlight builds.

### Bug: DeviceActivityMonitor extension IPA upload rejected by App Store Connect validator (IrisAPI -19241)
- **What happens:** Archive uploads fail with "The value of the `NSExtensionPointIdentifier` key, `com.apple.deviceactivity.monitor`, in the `Info.plist` … is invalid" even though the extension's plist, entitlements, and provisioning profile are correct. Affects both Xcode 26.2 (iOS 26 SDK) and Xcode 16.4 (iOS 18 SDK), strongly suggesting a server-side validator bug rather than a local build problem.
- **When:** Observed across Q1 2026.
- **FB #:** Not publicly known.
- **Reported by:** forum thread — https://developer.apple.com/forums/thread/819904
- **Workaround:** Retry uploads at different times; some reports of eventual success without any code change. File a DTS incident if blocked.
- **Status on iOS 26:** **Open.**

---

## E. ManagedSettingsUI bugs

### Bug: `ShieldConfigurationDataSource` not re-invoked when a token moves stores
Covered in section B ("Moving a token between ManagedSettingsStores reuses the old shield configuration"). This is the single most-cited ManagedSettingsUI failure and it reproduces on iOS 26 beta 7.

### Bug: iOS 26 re-triggers one sec's intervention after a screenshot
- **What happens:** Taking a screenshot while shielded and returning to the target app causes the shield flow (intervention) to re-trigger unexpectedly on iOS 26.
- **When:** iOS 26+, any sub-version.
- **FB #:** Not publicly known.
- **Reported by:** one sec tutorials — https://tutorials.one-sec.app/en/categories/683266
- **Workaround:** Published in the linked tutorial article.
- **Status on iOS 26:** **Active, iOS-side root cause suspected.**

### Bug: `FamilyActivityPicker` parent sheet dismissed when tapping Done / Cancel
- **What happens:** When `familyActivityPicker(isPresented:selection:)` is attached inside another presented sheet, tapping Done or Cancel dismisses the **outer** sheet as well, collapsing the whole picker flow.
- **When:** iOS 18.4, 18.5, iOS 26 beta 1, iOS 26 beta 2. Worked on iOS 18.0–18.3. **Flag: not an iOS 26-exclusive regression** — continues from iOS 18.4.
- **FB #:** **FB18369821**.
- **Reported by:** forum user "Axel" under https://developer.apple.com/forums/tags/managed-settings
- **Workaround:** Present the picker directly from a navigation context rather than nested sheets.
- **Status on iOS 26:** **Active, inherited from 18.x.**

### Bug: `FamilyActivityPicker` never opens on iOS 26
- **What happens:** After updating to iOS 26 the picker sheet silently fails to present; no console errors. One developer reports this caused App Store review rejections.
- **When:** iOS 26 (sub-version not pinned).
- **FB #:** Not publicly known.
- **Reported by:** anonymous OP under https://developer.apple.com/forums/tags/family-controls — **flag: single reporter, may be environmental**.
- **Workaround:** None stated.
- **Status on iOS 26:** **Unverified, low corroboration.** Watch for it but do not assume widespread.

---

## F. Cross-cutting iOS 26 changes and regressions

### New in iOS 26.4: `AuthorizationStatus.approvedWithDataAccess` and the "Family Controls App & Website Usage" capability
Apple introduced a new authorization tier that includes usage-data access in addition to restriction powers, exposed as `AuthorizationStatus.approvedWithDataAccess` (https://developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess). It requires a new, distinct entitlement/capability separate from `com.apple.developer.family-controls`. See Bug A-3 for the design consequence: adopting it eliminates the intermediate approval tier for users on 26.4+.

### New in iOS 26.4: "Lock Screen Time Settings" covers third-party apps
Settings → Screen Time → Lock Screen Time Settings now extends to third-party apps built on FamilyControls, closing the classic bypass where users just revoked Screen Time access to disable a shield. Confirmed by one sec's "Making one sec truly bullet-proof with iOS 26.4" blog post (https://one-sec.app/blog/lock-screen-time-permission/, March 24, 2026) and by Tech Lockdown (https://techlockdown.com/articles/ios-26-screen-time-changes). Uninstall of a shielded app now requires the parent's Apple Account email+password rather than device passcode/FaceID. **But** see Bug A-4 — the FaceID-vs-passcode bypass on the per-app Screen Time Access toggle undermines this on 26.4.

### New in iOS 26: PermissionKit and Declared Age Range API
`PermissionKit` lets third-party messaging/social apps plug into Apple's parental-approval flow. A **known issue acknowledged in iOS 26.2 beta release notes** (per Releasebot mirror): "PermissionKit Significant App Update API is not testable in sandbox" (issue 163601229). Declared Age Range API lets apps read a child's age range without exact birthdate. Neither is strictly part of FamilyControls / ManagedSettings / DeviceActivity but they ship alongside and may interact with your onboarding flow for kid accounts.

### Consumer regression: iOS 26.0 "Limit Adult Websites" no longer disables Safari Private tabs
Tech Lockdown flagged this as a **regression** from prior iOS. Not a developer-API bug per se, but relevant if your app markets itself as a parental-controls complement — the OS guardrail you may have relied on as a backstop is weaker on 26.0+.

### Consumer regression: "One Minute extension" on App Limits unblocks all apps
Widely reported end-user bug on iOS 26.x (https://discussions.apple.com/thread/256137598, MacObserver explainer). Not your API, but if your app uses Apple's native App Limits as a fallback shielding mechanism, be aware this is broken on 26.0+.

### No Apple Resolved Issues for the API family in 26.0 / 26.1 / 26.2 / 26.3 release notes
The public iOS & iPadOS release notes for 26.0 through 26.3 contain **no explicit entries** for FamilyControls, ManagedSettings, or DeviceActivity under New Features, Resolved Issues, or Known Issues. All acknowledgments to date are via Apple Dev Forums DTS replies (FB21267341) or appear only in Feedback Assistant. Plan on zero observability of fix status unless you are in direct contact with DTS or monitor Frederik Riedel's omnibus thread.

---

## Conclusion — the shape of the problem

The iOS 26 Screen Time API isn't broken in a single, diagnosable way. It's broken in a **pair of opposite ways at the same time**: thresholds either fire far too eagerly (D-1, D-2, D-3) or never fire at all (D-4), with data corruption (D-5) and extension-silence episodes (D-6) layered on top. Authorization silently evaporates (A-1) and tokens silently drift (B-1). Apple has publicly confirmed exactly one of these as a known issue (FB21267341), targeted a fix for exactly one more at 26.5 beta 1 (the D-1 cluster), and has otherwise been quiet for 10 months.

What this means for an Opal-clone shipping on iOS 26 today: **the API cannot be the single source of truth for whether a shield should be on.** Build a secondary enforcement layer that runs from the main app — periodic `DeviceActivityReport` aggregate checks on foreground, `BGAppRefreshTask` touch-ups, and `UNCalendarNotificationTrigger` fallback scheduling — and treat every `DeviceActivityMonitor` callback as a *hint*, not a command. Assume any `ApplicationToken` you receive may not match what you persisted, and design shield configuration to degrade gracefully to a generic shield rather than fail. Monitor **thread 819997** (Frederik Riedel's omnibus) and **thread 808470** (DTS-engaged) as your bellwethers; when those move, the ecosystem moves with them.

The good news is that all of the failure modes above are **known within a small, identifiable community** (Frederik Riedel, the Roots team, kgaidis, SaulD18, a handful of DTS engineers). If you trigger one in production, the fingerprint is recognizable and the workaround paths are already mapped.

---

## Sources

**Apple Developer Forums threads (primary):**
- https://developer.apple.com/forums/thread/808470 — Quappi, `eventDidReachThreshold` immediate (iOS 26 regression, DTS engaged)
- https://developer.apple.com/forums/thread/809410 — kgaidis, iOS 26.2 RC first-pickup regression, FB21267341 (Apple "known issue under investigation")
- https://developer.apple.com/forums/thread/811305 — SaulD18, iOS 26.2 0-minute threshold fire, FB21450954
- https://developer.apple.com/forums/thread/811743 — iOS 26.2 early-fire consumer bug
- https://developer.apple.com/forums/thread/812472 — mdiazmen, corroborating 26.2 threshold fire
- https://developer.apple.com/forums/thread/814559 — iOS 26.2 immediate threshold with reboot workaround
- https://developer.apple.com/forums/thread/814571 — ApplicationToken mismatch on iOS 26.2.1
- https://developer.apple.com/forums/thread/819242 — `deviceactivityd` silent on iOS 26.3.1
- https://developer.apple.com/forums/thread/819904 — App Store Connect IrisAPI -19241 validator failure
- https://developer.apple.com/forums/thread/819997 — Frederik Riedel omnibus iOS 26 regression summary
- https://developer.apple.com/forums/thread/820283 — nemecek_f, iOS 26.4 approvedWithoutDataAccess unreachable
- https://developer.apple.com/forums/thread/820790 — Frederik Riedel, `openParentApp` enhancement request
- https://developer.apple.com/forums/thread/820796 — `$authorizationStatus` publisher silent on revocation, iOS 26.2
- https://developer.apple.com/forums/thread/820956 — `intervalDidEnd` not firing on iOS 26.3.1
- https://developer.apple.com/forums/thread/821959 — Face ID bypass of Screen Time passcode on iOS 26.4
- https://developer.apple.com/forums/thread/794128 — FB18997699 Screen Time permission lost on iOS 26

**Apple Developer Forums tag pages:**
- https://developer.apple.com/forums/tags/familycontrols
- https://developer.apple.com/forums/tags/managedsettings
- https://developer.apple.com/forums/tags/deviceactivity
- https://developer.apple.com/forums/tags/screen-time

**Apple official documentation:**
- https://developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess — new in iOS 26.4
- https://developer.apple.com/documentation/familycontrols
- https://developer.apple.com/documentation/managedsettings
- https://developer.apple.com/documentation/deviceactivity
- Apple Newsroom (June 11, 2025): https://www.apple.com/newsroom/2025/06/apple-expands-tools-to-help-parents-protect-kids-and-teens-online/
- Apple Support "About iOS 26 Updates": https://support.apple.com/en-us/123075

**Screen-time app vendor blogs / help centers:**
- https://tutorials.one-sec.app/en/articles/5709826 — one sec, "Re-Intervention not working on iOS 26," cites FB18061981
- https://tutorials.one-sec.app/en/categories/683266 — one sec, screenshot re-intervention issue on iOS 26
- https://one-sec.app/blog/lock-screen-time-permission/ — Frederik Riedel, "Making one sec truly bullet-proof with iOS 26.4" (Mar 24, 2026)
- https://intercom.help/roots/en/articles/13440805-ios-26-2-known-issue-time-limits-triggering-early — Roots app, user workaround

**Third-party coverage:**
- https://techlockdown.com/articles/ios-26-screen-time-changes — Tech Lockdown, iOS 26 Screen Time changes summary (updated Apr 2, 2026)

**Related end-user threads (Apple Discussions — consumer side, cross-reference only):**
- https://discussions.apple.com/thread/256137598 — iOS 26 one-minute extension unblocks all apps
- https://discussions.apple.com/thread/256216039 — iOS 26.2 apps stay blocked after morning rest time
- https://discussions.apple.com/thread/256138930 — iOS 26 native Screen Time inconsistencies

**GitHub:**
- https://github.com/awaseem/foqos — Foqos repo (issue #198 tangentially related; `.specific(domains)` Safari behavior corroborated in commentary)

**Reddit / Stack Overflow / Hacker News / Indie Hackers:** Exhaustive searches with the queries specified returned **no iOS-26-specific Screen Time API developer discussion** on any of these platforms. End-user complaints exist on r/ios but do not add bug content beyond what the Apple Dev Forums / Apple Discussions already cover. This is explicitly a negative result, not a gap in the search.