# DeluluDetox

## What This Is

A native iOS self-control app that blocks distracting apps, categories, and websites on-demand or on schedule. A functional clone of Opal, built for adults who want to reclaim focus — not parental control, not Family Sharing. Everything on-device, no backend.

## Core Value

**User can block chosen apps immediately and the block holds until the timer ends.** If nothing else works, this must. A focus blocker that can be trivially bypassed is worthless.

## Requirements

### Validated

- [x] Onboarding + Screen Time authorization (individual) — Phase 01 / 01.1
- [x] App/category/website selection via FamilyActivityPicker — Phase 02
- [x] Quick session — instant block for chosen duration (15/30/60/90 min, custom 15 min – 8 h) — Phase 03

### Active

- [ ] Schedules — recurring blocks (e.g. weekdays 9–17)
- [ ] Custom shield with branding and basic buttons
- [ ] Minimal gamification — completed sessions count + streak (consecutive days)
- [ ] Local notifications on session end
- [ ] Shield deep link to main app for richer UX

### Out of Scope

- Backend / cloud sync — MVP is fully on-device
- Deep Focus anti-bypass (delay, passphrase typing) — post-MVP per R6
- DeviceActivityReport statistics — post-MVP per R4
- Live Activity timer — post-MVP per R9
- Subscription / monetization — post-MVP per R10
- Accountability partner — requires backend, far future
- Parental control / Family Sharing — explicitly not this product
- Android / cross-platform — iOS only

## Context

### Technical Environment

- **Platform:** iOS 26.0+, Swift 6.2, SwiftUI, Xcode 26+
- **Frameworks:** FamilyControls, ManagedSettings, DeviceActivity, ManagedSettingsUI
- **Architecture:** Clean Architecture (MVVM + UseCase + Repository), `@Observable` ViewModels (no SwiftUI import), state-driven navigation via `swift-navigation` (Destination enum, `@CasePathable`)
- **Project tooling:** XcodeGen (`project.yml` → `.xcodeproj`), XcodeBuildMCP for builds
- **Third-party committed:** `pointfreeco/swift-navigation` — others decided ad-hoc via ADR

### Multi-Target Structure

1. **Main App** — onboarding, picker, sessions, stats, settings
2. **DeviceActivityMonitor extension** — schedule start/end, event thresholds
3. **ShieldConfigurationExtension** — shield appearance
4. **ShieldActionExtension** — shield button handling, deep link to main app
5. **DeviceActivityReport extension** — (post-MVP, decision after R4)

All targets share `group.com.kksw.DeluluDetox` App Group.

### Hard Constraints

1. **Opaque tokens** — `ApplicationToken`, `WebDomainToken`, `ActivityCategoryToken` are opaque. Apple does NOT expose app names/icons. Display via SwiftUI `Label(token)`. Never deserialize or map to strings.
2. **Entitlement required** — `com.apple.developer.family-controls` must be requested per bundle ID and approved by Apple. Frame as `.individual`, not `.child`. All logic on-device or rejection.
3. **Extensions are separate processes** — main app and extensions communicate through App Group only. Without App Group, token persistence fails.
4. **Unknown token problem** — iOS sometimes gives extensions tokens they haven't seen before. Shield extensions MUST have fallback (default shield, error log).
5. **No raw stats access** — DeviceActivityReport renders in sandboxed extension; data CANNOT leave it. "Save usage minutes to UserDefaults" does NOT work directly.
6. **Shield limitations** — ShieldConfiguration does NOT support custom SwiftUI views, animations, text fields, network images. Rich UX (typing, countdown) goes through deep link to main app.
7. **Token instability** — Token rotation bug acknowledged by DTS from iOS 17.5 to 26.3.1. Store records under own UUID, token alongside as best-effort pointer.
8. **DeviceActivityMonitor RAM limit** — 6 MB, zero third-party SDKs allowed.
9. **Max 20 activities** — total across app + extensions for DeviceActivityMonitor schedules.

## Constraints

- **Tech stack**: Swift 6.2, SwiftUI, iOS 26.0+ — locked
- **No backend**: Everything on-device + App Group in MVP
- **Entitlement**: Requires Apple approval per bundle ID (2–3 week median)
- **Extension RAM**: DeviceActivityMonitor limited to 6 MB
- **Shield API**: Frozen since 2022, 8-field struct, no SwiftUI/network/TextField

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| iOS 26.0 deployment target | User choice despite R1 recommending iOS 18 for stability/reach | — Pending |
| Clean Architecture MVVM | Testability, separation of concerns, scalable for extensions | Shipped in Phase 01.1 (feature-first layout + DIContainer + hard dep rules) |
| swift-navigation for routing | State-driven navigation, Destination enum pattern, composable | Shipped in Phase 01.1 (Wzorzec A modal + Wzorzec B root-switch documented; AppRoot uses B) |
| XcodeGen for project management | Eliminates .xcodeproj merge conflicts, human-readable YAML | — Pending |
| Minimal gamification in MVP | Streak + session count only; deeper gamification post-MVP | — Pending |
| No backend in MVP | Simplicity, faster shipping, on-device = privacy story | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-19 after Phase 03 (quick-sessions) completion*
