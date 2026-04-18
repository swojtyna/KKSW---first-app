# Phase 1: Foundation & Onboarding - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Scaffold multi-target Xcode project (main app + DeviceActivityMonitor, ShieldConfiguration, ShieldAction extensions) with App Group, and deliver Screen Time authorization flow. User completes onboarding and grants Screen Time permission on a working build.

</domain>

<decisions>
## Implementation Decisions

### Onboarding tone & content
- **D-01:** Playful / irreverent tone — self-aware humor matching the "DeluluDetox" brand name. Think "Your phone is winning. Let's fix that." energy.
- **D-02:** Single screen before permission request — one explanation screen with WHY + "Grant Access" button. Minimal friction, fastest path to value.
- **D-03:** SF Symbol + bold text for visual — large SF Symbol with punchy headline and brief explanation. No custom illustrations. Ships fast, looks clean.

### Permission denial handling
- **D-04:** Hard gate — app is completely unusable without Screen Time permission. No soft access, no browsing the app shell.
- **D-05:** Non-dismissible denial screen — the denial screen IS the app until permission is granted. Shows a witty fallback message (matching playful tone) with a Retry button. Cannot be bypassed.

### Post-permission destination
- **D-06:** Land on home screen with empty state — "No apps blocked yet" with prominent call-to-action. Sets up the hub users return to every session.
- **D-07:** Subtle transition after granting permission — quick fade/slide to home screen. No celebration screen, no confetti. The permission grant itself is the reward.

### App personality & brand feel
- **D-08:** Clean white + bold accent color palette. Light/white background with one strong brand color. Premium and minimal feel.
- **D-09:** Colors must be centralized from the start (e.g., a Theme or Colors enum) so a design system / theming can be introduced in a future phase without refactoring scattered color literals.
- **D-10:** Minimal UI + punchy copy — clean iOS-native layouts using standard SwiftUI components and SF Symbols. Personality comes from the words, not the widgets.

### Claude's Discretion
- Specific accent color choice (should be bold, work on white, match playful tone)
- SF Symbol selection for onboarding screen
- Exact onboarding copy / microcopy
- Home screen empty state layout and copy
- Architecture folder structure details
- Extension target naming conventions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Screen Time API & onboarding
- `.claude/research/README.md` — Full research index (R1–R10), start here
- `.claude/research/compass_artifact_wf-14f18c53-0c15-46ba-90f6-4e8befe1261a_text_markdown.md` — iOS 26 vs iOS 18 deployment target analysis, Screen Time API status
- `.claude/research/compass_artifact_wf-dee368a6-dad8-4281-9c56-dceec8896003_text_markdown.md` — Entitlement `family-controls` process, `.individual` framing, per-bundle-ID requirement
- `.claude/research/compass_artifact_wf-280372a6-1bd9-4044-95d9-1d65f1d292dc_text_markdown.md` — Main app ↔ extensions communication, App Group architecture, token instability

### Architecture & navigation
- `.claude/guides/architecture/GUIDE.md` — Clean Architecture MVVM + UseCase + Repository pattern
- `.claude/guides/navigation/GUIDE.md` — swift-navigation, Destination enum, @CasePathable
- `.claude/guides/xcodegen/GUIDE.md` — XcodeGen project.yml conventions

### Reference implementations
- `.claude/research/compass_artifact_wf-9f1fb5f8-b639-4ece-808e-76cc0b222990_text_markdown.md` — Best public repos for Opal clone (Foqos as primary reference)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DeluluDetoxApp.swift`: Bare @main entry point — will need to host the navigation root and permission check
- `ContentView.swift`: Placeholder — will be replaced by the onboarding/home routing logic
- `project.yml`: XcodeGen config with main app target only — needs extension targets, App Group, and dependencies added

### Established Patterns
- XcodeGen is already set up — all project changes go through `project.yml`
- iOS 26.0 deployment target and Swift 6.2 are locked in project.yml
- Bundle ID prefix `com.kksw` established

### Integration Points
- `project.yml` is the single source for adding extension targets, App Group entitlements, and SPM dependencies
- `DeluluDetoxApp.swift` is where the root navigation (onboarding vs home) will be wired

</code_context>

<specifics>
## Specific Ideas

- Brand name "DeluluDetox" sets a playful/irreverent expectation — all copy should match this energy
- User explicitly wants future theming flexibility: centralize colors now so a design system can slot in without refactoring
- Denial screen should have personality, not just be a boring "permission required" wall

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-onboarding*
*Context gathered: 2026-04-18*
