# Phase 2: App Selection - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

User picks apps, categories, and websites to block via `FamilyActivityPicker`. Selections persist across app launches in the App Group, keyed by app-generated UUIDs with tokens stored as best-effort pointers. User can view and edit selections from within the main app.

**In scope:** FamilyActivityPicker integration, persistence schema, review/edit UI, token rotation reconciliation on app foreground.

**Out of scope (other phases):** Starting block sessions (Phase 3), scheduled blocking (Phase 5), shield customization (Phase 4), gamification (Phase 6), multi-list CRUD UI (deferred — MVP shows one list).

</domain>

<decisions>
## Implementation Decisions

### List Model
- **D-01:** Data model supports N named blocklists from day 1 (e.g., `Blocklist` entity with `id: UUID`, optional `name: String`, `[TokenRecord]`). MVP UI exposes only a single implicit blocklist — no list CRUD, no list picker in session flow. Future phase can enable multi-list UI without schema migration.

### Persistence
- **D-02:** `Codable` structs serialized to JSON files in the App Group container (`group.com.kksw.DeluluDetox`). Main app is the sole writer; extensions (DeviceActivityMonitor, ShieldConfiguration, ShieldAction) are read-only. Writes are atomic (`Data.write(to:options: .atomic)`). No SwiftData, no UserDefaults for structured data, no 3rd-party persistence SDKs.
- **D-03:** Split per domain — separate files `blocklists.json`, `sessions.json`, `schedule.json` (latter two arrive in Phase 3/5). DeviceActivityMonitor extension reads only what it needs, keeping parse/RAM cost down within the 6 MB limit.

### Review & Edit UI
- **D-04:** Dedicated "Blocked" screen in main app shows a scrollable list with one row per `TokenRecord`, rendered via `Label(token)`. Per-row swipe-to-delete removes a single record. A "Change selection" button opens `FamilyActivityPicker` pre-seeded with the current `FamilyActivitySelection` so the user can add/remove in bulk via Apple's picker. No custom picker UI.

### Token Reconciliation
- **D-05:** Reconcile UUID↔token mapping on `scenePhase == .active` only. On foreground, fetch the current `FamilyActivitySelection` from persisted state, diff against Apple's current token set, and refresh `TokenRecord.token` pointers (keyed by UUID). Accepted risk: if a token rotates between foreground and a Phase 3 session start, the session may apply a stale token — revisit in Phase 3 if this becomes a reliability issue.

### Claude's Discretion
- Exact SwiftUI component structure for the "Blocked" screen (cell layout, spacing, header copy).
- Empty-state copy and illustration when the user has picked nothing yet.
- Entry point for the "Blocked" screen in the app navigation (tab vs. root destination) — to be aligned with the navigation graph defined in Phase 1.
- Error / retry copy if `FamilyActivityPicker` presentation fails.
- `FamilyActivitySelection` hydration strategy (whether to cache the full selection alongside individual `TokenRecord`s for picker pre-seeding).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project constraints
- `.planning/PROJECT.md` §Hard Constraints from Research — opaque tokens, App Group requirement, token instability, extension RAM, entitlement
- `.planning/PROJECT.md` §Multi-Target Structure — which targets share the App Group
- `.planning/REQUIREMENTS.md` §App Selection — SEL-01 through SEL-05 acceptance criteria
- `.planning/ROADMAP.md` §Phase 2 — goal + success criteria

### Screen Time API / persistence
- `.claude/research/compass_artifact_wf-280372a6-1bd9-4044-95d9-1d65f1d292dc_text_markdown.md` — Main app ↔ extensions communication: App Group as source of truth, writer/reader split, token rotation bug (FB14082790/FB14237883/FB18353106), DeviceActivityMonitor 6 MB RAM limit
- `.claude/research/compass_artifact_wf-dee368a6-dad8-4281-9c56-dceec8896003_text_markdown.md` — `family-controls` entitlement: per-bundle-ID approval, `.individual` framing, no cloud
- `.claude/research/compass_artifact_wf-26aecd00-d219-4bf6-9a30-c4499255cad5_text_markdown.md` — Known bugs on iOS 26 (deployment target context — ties into `scenePhase` reconciliation robustness)

### Reference implementations
- `.claude/research/compass_artifact_wf-9f1fb5f8-b639-4ece-808e-76cc0b222990_text_markdown.md` — Foqos (`awaseem/foqos`) as the only production-grade public reference; Kingstinct RN wrapper as a fallback source for Shield/Action code (less relevant for Phase 2)

### Architecture guides (project)
- `.claude/guides/architecture/GUIDE.md` — MVVM + UseCase + Repository layering; `@Observable` ViewModels; SOLID/KISS/DRY rules
- `.claude/guides/navigation/GUIDE.md` — `swift-navigation`, single `Destination?` enum per ViewModel, `@CasePathable`
- `.claude/guides/xcodegen/GUIDE.md` — adding targets / App Group entitlements via `project.yml`
- `.claude/guides/xcodebuild-mcp/GUIDE.md` — build/run/test tooling

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **None yet** — greenfield repository. Phase 1 has not been executed: no `project.yml`, no Xcode project, no Swift sources. Phase 2 execution depends on Phase 1 being run first.

### Established Patterns
- Clean Architecture is the committed pattern (PROJECT.md): `Presentation (SwiftUI + @Observable VM) → Domain (UseCase) → Data (Repository)`.
- `swift-navigation` with a single `Destination?` enum on each ViewModel is the routing pattern (PROJECT.md, CLAUDE.md).
- Phase 2 should establish the first concrete `Repository` (blocklist persistence) and the first non-trivial `UseCase`s (e.g., `AddTokensToBlocklistUseCase`, `RemoveTokenFromBlocklistUseCase`, `ReconcileBlocklistUseCase`).
- ViewModels never import SwiftUI — `FamilyActivityPicker` presentation state lives in the VM as `FamilyActivitySelection?` or similar value, and the SwiftUI layer wires the sheet.

### Integration Points
- **App Group container** (`group.com.kksw.DeluluDetox`) — must exist as an entitlement on all targets (set up in Phase 1 via XcodeGen). Phase 2 Repository reads/writes through it.
- **Main app navigation graph** — "Blocked" screen needs an entry point; exact position (root tab, settings child, onboarding continuation) aligns with the navigation structure Phase 1 introduces.
- **Entitlement gate** — `FamilyActivityPicker` requires `com.apple.developer.family-controls`. App Store distribution requires Apple approval per bundle ID; development with the sandbox token works in the simulator/device in the meantime.
- **Downstream consumers** — Phase 3 `StartSessionUseCase` reads the blocklist file and applies tokens to `ManagedSettings.shield.applications`. Phase 5 DeviceActivityMonitor extension reads the same file. File format is the contract.

</code_context>

<specifics>
## Specific Ideas

- Opal / Foqos are the reference UX: user sees what they've blocked at a glance, swipe-to-delete on iOS feels native.
- MVP stays single-list to ship the core value (block holds for N minutes) without investing in list CRUD UI yet.
- Token rotation is treated as a known hazard but not a central MVP concern — one reconciliation point (foreground) is the chosen tradeoff.

</specifics>

<deferred>
## Deferred Ideas

- **Multi-list CRUD UI** — data model supports N blocklists, but creating/naming/selecting lists ships in a later phase. Surfaces as a user-facing feature when there is a clear use case (e.g., "Work" vs "Sleep" contexts).
- **Session-start reconciliation** — adding a second reconciliation point before `StartSessionUseCase` runs. Deferred to Phase 3; reconsider if stale tokens cause reliability failures.
- **On-demand token reconciliation** (e.g., periodic, background) — not needed for MVP. User-facing `scenePhase` event is sufficient.
- **Empty-state suggestions** (e.g., "Block these 5 popular social apps") — deferred; Apple does not expose app names as strings so building a curated suggestion list is non-trivial and not core value.
- **Import / export blocklist JSON** — deferred; power-user feature.

</deferred>

---

*Phase: 02-app-selection*
*Context gathered: 2026-04-18*
