# Phase 3: Quick Sessions - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

User starts an on-demand block session for a chosen duration (presets 15/30/60/90 min or custom 5 min–8 h via native wheel picker). Immediately, previously selected apps (Phase 2's single implicit blocklist) are shielded via ManagedSettings; a `DeviceActivitySchedule` is scheduled for the duration; a countdown is shown on a dedicated screen in the main app. The session auto-ends when the timer expires (DAM `intervalDidEnd` + main-app self-heal fallback). User can request an early end, gated by a confirm dialog. System-level friction (`requireAutomaticDateAndTime`, `denyAppRemoval`) is active during sessions. Every session is persisted to App Group JSON files with enough fields for Phase 6 gamification.

**In scope:**
- Session start / end lifecycle (shield apply & clear, DAS schedule, ManagedSettings system restrictions)
- Countdown UI with progress ring + digits
- Custom duration picker (5 min – 8 h)
- Early-end confirm dialog (MVP friction, no Deep Focus)
- `active_session.json` + `sessions.json` persistence, 3 outcomes (`completed` / `cancelled_by_user` / `broken_by_revoke`)
- Revoke detection via foreground polling of `AuthorizationCenter.$authorizationStatus`
- Sarcastic-playful copy across all session strings
- Success screen after a completed session

**Out of scope (other phases or post-MVP):**
- Scheduled recurring blocks — Phase 5
- Shield customization / branding / deep link — Phase 4
- Streak, session count UI, session-end local notifications — Phase 6
- Live Activity / Dynamic Island countdown — post-MVP (LAC-01/02)
- Deep Focus friction: passphrase typing, unlock delay, hold-to-end, Emergency Pass — post-MVP (DFO-01/02/03)
- Multi-session concurrency / session queue
- Session history / per-session detail UI

</domain>

<decisions>
## Implementation Decisions

### Timer Enforcement
- **D-01:** End-of-session source of truth is a `DeviceActivitySchedule` with `intervalStart = now`, `intervalEnd = plannedEndAt`, `repeats = false`. The DAM extension's `intervalDidEnd` callback clears the ManagedSettings shield and system restrictions, writes a finalize marker, and fires a Darwin notification. Canonical Apple/Opal/Foqos pattern.
- **D-02:** Main app SELF-HEALS on `scenePhase == .active`: if `active_session` exists and `active_session.plannedEndAt < now`, the main app clears the shield + system restrictions itself and finalizes the session record. Defense against the iOS 26 DAM callback regression documented in research R5. Zero extra moving parts.
- **D-03:** Main app remains sole writer of `sessions.json` (Phase 2 D-02 preserved). DAM extension writes only a tiny finalize marker to a separate App Group file + fires a Darwin notification; main app reconciles the marker into `sessions.json` on the next foreground.
- **D-04:** No pre-start token reconciliation — Phase 2's `scenePhase == .active` reconcile stands. Accepted MVP tradeoff: if a user opened the app hours earlier and tokens rotated before they start a session, the shield may apply to stale tokens. Revisit if this surfaces in beta.

### Session Lifecycle
- **D-05:** Single active session at a time. Start affordance is hidden / disabled while a session is active; countdown screen is the only destination reachable. Starting a new session requires ending the current one first.
- **D-06:** Session reads from Phase 2's single implicit blocklist. If the blocklist is empty, the start affordance is disabled with a "pick apps first" nudge.
- **D-07:** Start sequence (atomic enough that a crash between steps is recoverable via D-02):
  1. Create `SessionRecord` with `outcome = nil, actualEndAt = nil`; write to `active_session.json` and append to `sessions.json`.
  2. Apply `ManagedSettingsStore.shield.applications = tokens` (plus `.webDomains`, `.categories` as applicable from the blocklist).
  3. Start `DeviceActivitySchedule` via `DeviceActivityCenter.startMonitoring`.
  4. Set `ManagedSettingsStore.dateAndTime.requireAutomaticDateAndTime = true` and `ManagedSettingsStore.application.denyAppRemoval = true`.
  5. Navigate to countdown screen.
- **D-08:** End sequence (timer expiry, user cancel, or revoke detection):
  1. Clear ManagedSettings shield + clear `dateAndTime` + clear `denyAppRemoval`.
  2. Stop the `DeviceActivitySchedule`.
  3. Update the `SessionRecord` in `sessions.json`: set `actualEndAt` and `outcome`.
  4. Delete `active_session.json`.
  5. On next `scenePhase == .active` after a `completed` outcome, show the success screen once.

### Anti-Cancel Friction (QSN-05)
- **D-09:** MVP friction = **early-end button + confirm dialog** on the countdown screen. No passphrase, no hold-to-end, no unlock countdown — those are Deep Focus (PROJECT.md DFO-01/02/03, post-MVP).
- **D-10:** While a session is active, the app sets both `ManagedSettingsStore.dateAndTime.requireAutomaticDateAndTime = true` (defeats clock-skew bypass, research §A.8) and `ManagedSettingsStore.application.denyAppRemoval = true` (defeats delete-and-reinstall, research §A.4). Both are reverted in the end sequence (D-08).
- **D-11:** Revoke detection: poll `AuthorizationCenter.shared.authorizationStatus` on `UIApplication.willEnterForegroundNotification` and on every DAM callback, working around the `$authorizationStatus` Combine-publisher-silent-in-background bug (research §A.9). If status is not `.approved` while an active session exists, finalize that session with `outcome = broken_by_revoke`.
- **D-12:** Copy tone across ALL user-facing strings (confirm dialog, empty states, success screen, broken-session screen): **sarcastic-playful**. No emotional guilt-tripping, no dark patterns — aligns with Apple Guideline 5.5 (research §D). Example spirit: "Gratuluję, przeżyłeś 30 min bez Instagrama. Świat się nie zawalił."

### Persistence (extends Phase 2 D-02/D-03)
- **D-13:** Two new files in App Group `group.com.kksw.DeluluDetox`:
  - `active_session.json` — singleton, nullable. Read by DAM extension + main app. Written by main app.
  - `sessions.json` — append-only array of finalized sessions. Read by main app. Written by main app only. DAM extension uses a separate tiny marker file + Darwin notification (D-03).
- **D-14:** `SessionRecord` Codable struct, full schema from day 1 (no Phase 6 migration):
  - `id: UUID`
  - `blocklistId: UUID` (FK to Phase 2 blocklist record)
  - `startedAt: Date`
  - `plannedEndAt: Date` (redundant with `startedAt + plannedDurationSeconds`, but stored so DAM can read without recompute)
  - `plannedDurationSeconds: Int`
  - `actualEndAt: Date?` (nil while active)
  - `outcome: SessionOutcome?` — nil while active; `.completed` / `.cancelled_by_user` / `.broken_by_revoke`
  - `appVersion: String` (debug/audit aid)
- **D-15:** Atomic writes (`Data.write(to:options: .atomic)`) — consistent with Phase 2 D-02. No retention cap in MVP; ~200 B per record makes this a non-issue for years.

### UI (QSN-02, QSN-04)
- **D-16:** Two-screen navigation (push):
  - **Start screen** — preset chips row (15/30/60/90 min) + custom wheel picker (inline or disclosed) + "Start session" button. Drives the VM to transition state to active.
  - **Countdown screen** — pushed on start. Shows progress ring + digits + early-end button. Represented as a `Destination?` case on the session VM (swift-navigation, `@CasePathable`).
- **D-17:** Countdown visual: circular progress ring draining from full → empty, large monospaced digits in the center (`MM:SS` under 1 h; `HH:MM:SS` at or above 1 h), sarcastic caption beneath.
- **D-18:** Custom duration (QSN-02): native `DatePicker(.hourAndMinute)` in wheel style. Range **5 min minimum, 8 h maximum**.
- **D-19:** Post-session success screen: shown exactly once per `completed` outcome, on the next foreground after end. Sarcastic copy, tap-to-dismiss → home idle. Tracked via a flag on the `SessionRecord` or ephemeral user-defaults flag — Claude's Discretion on the exact mechanism.

### Claude's Discretion
- Exact SwiftUI structure of the start screen (Form vs VStack layout; chips arrangement vs picker placement).
- Exact sarcastic copy strings — draft during execution, align with D-12 tone.
- Progress ring animation curve and easing (ease-linear vs ease-out).
- Success screen exact visual design (emoji? confetti? static card?).
- Entry point for the session flow in the main-app navigation graph (aligns with Phase 1 nav structure once scaffolded).
- "Pick apps first" empty-state visual (D-06).
- Handling of the `DeviceActivityCenter` "max 20 activities" limit — unlikely in MVP (we schedule 1 at a time), but graceful error copy if it ever hits.
- Whether the success-screen-shown flag lives on `SessionRecord` or in UserDefaults.

### Folded Todos
- None — no pending todos matched Phase 3.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project constraints
- `.planning/PROJECT.md` §Hard Constraints from Research — opaque tokens, App Group, token instability, DAM 6 MB RAM, `.individual` entitlement, Shield API limits
- `.planning/PROJECT.md` §Multi-Target Structure — Main app, DeviceActivityMonitor, ShieldConfigurationExtension, ShieldActionExtension share `group.com.kksw.DeluluDetox`
- `.planning/REQUIREMENTS.md` §Quick Session — QSN-01 through QSN-06 acceptance criteria
- `.planning/ROADMAP.md` §Phase 3 — goal + success criteria

### Screen Time API / timer mechanism
- `.claude/research/compass_artifact_wf-280372a6-1bd9-4044-95d9-1d65f1d292dc_text_markdown.md` — main-app ↔ extensions comm: App Group as source of truth, atomic writes, Darwin notifications, DAM 6 MB RAM limit, token rotation bug
- `.claude/research/compass_artifact_wf-26aecd00-d219-4bf6-9a30-c4499255cad5_text_markdown.md` — iOS 26 known bugs; DAM callback regressions directly motivate D-02 (self-heal)
- `.claude/research/compass_artifact_wf-719bca2b-9444-49eb-ad10-cbe3c7b6eb88_text_markdown.md` — Live Activities confirmed out-of-MVP; countdown strictly in-app; defensive foreground reconciliation called out as must-have
- `.claude/research/compass_artifact_wf-9f1fb5f8-b639-4ece-808e-76cc0b222990_text_markdown.md` — Foqos as the only production-grade public Screen Time reference; useful concrete code patterns for DAS + DAM + ManagedSettings

### Anti-cancel friction / system restrictions
- `.claude/research/compass_artifact_wf-1862c287-6b03-4a01-a2e4-e53e8d7082b8_text_markdown.md` — anti-bypass catalog; §A.8 (`requireAutomaticDateAndTime`), §A.4 (`denyAppRemoval`), §A.9 revocation detection + `$authorizationStatus` bug workaround, §D ethics / App Store Guideline 5.5 (informs sarcastic-not-manipulative copy)

### Project architecture
- `.claude/guides/architecture/GUIDE.md` — MVVM + UseCase + Repository; `@Observable` VMs do not import SwiftUI; SOLID/KISS/DRY
- `.claude/guides/navigation/GUIDE.md` — `swift-navigation`, single `Destination?` enum per VM, `@CasePathable`, case-path bindings for push navigation and sheets
- `.claude/guides/xcodegen/GUIDE.md` — adding any new target or entitlement via `project.yml`
- `.claude/guides/xcodebuild-mcp/GUIDE.md` — build/run/test tooling

### Prior phase context
- `.planning/phases/02-app-selection/02-CONTEXT.md` — blocklist schema, atomic-write JSON persistence, main-app-sole-writer rule, `scenePhase == .active` token reconcile. Phase 3 extends these decisions with session files, preserving the writer/reader split.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **None yet** — greenfield repo. Phase 1 scaffold and Phase 2 blocklist work both still pending. Phase 3 execution depends on both being run first.

### Established Patterns (from prior phases + project guides)
- Clean Architecture: Phase 3 adds `SessionRepository` (active + history), `StartSessionUseCase`, `EndSessionUseCase`, `FinalizeSessionFromMarkerUseCase`, `DetectRevocationUseCase`. Each UseCase is a single responsibility.
- `@Observable` ViewModels with no SwiftUI import — the `StartScreenViewModel` and `CountdownViewModel` own `Destination?` state and expose intent methods.
- `swift-navigation` push flow: start screen VM has `destination: Destination?` where `Destination` is `@CasePathable` enum including `.countdown(CountdownViewModel)` (and implicitly, via its own destination, `.endConfirmation`).
- JSON files in App Group, atomic `Data.write`, main app sole writer — carried forward from Phase 2.

### Integration Points
- **ManagedSettings framework** — first-use in Phase 3. A shared `ManagedSettingsStore(named: "deluludetox.session")` manages `shield.applications`, `shield.webDomains`, `shield.categories`, `dateAndTime.requireAutomaticDateAndTime`, `application.denyAppRemoval`.
- **DeviceActivity framework** — first-use in Phase 3. `DeviceActivityCenter.startMonitoring(...)` schedules one DAS per session; DAM extension receives `intervalDidEnd`.
- **DeviceActivityMonitor extension target** — scaffolded in Phase 1; receives its first production logic here. Respect the 6 MB RAM ceiling: no 3rd-party SDKs, minimal imports, only Foundation + FamilyControls + ManagedSettings + DeviceActivity.
- **App Group file bus** — continues from Phase 2. New files: `active_session.json`, `sessions.json`, plus a finalize-marker file (exact name at Claude's discretion).
- **Darwin notifications** — new signaling channel: DAM → main app "session finalized". Use `CFNotificationCenterGetDarwinNotifyCenter()` with a namespaced name (e.g., `com.kksw.DeluluDetox.sessionFinalized`).

</code_context>

<specifics>
## Specific Ideas

- **Opal / Foqos** as the UX reference for both the countdown ring and the sarcastic "you survived" vibe. Foqos' MIT-licensed code is a concrete implementation anchor (research R-Foqos).
- **Sarcastic-playful copy** is the project's tonal signature, not just this phase — applies to onboarding polish in Phase 1, empty states in Phase 2's review/edit UI, shield text in Phase 4, streak copy in Phase 6. User explicitly chose this over the neutral default.
- **Deep Focus is explicitly post-MVP.** Do not smuggle passphrase typing, unlock countdowns, or Emergency Pass mechanics into this phase. MVP friction is strictly: confirm dialog + system-level `requireAutomaticDateAndTime` + `denyAppRemoval` + the inherent friction of walking to Settings to revoke authorization.
- **iOS 26 DAM reliability risk is accepted.** User chose iOS 26 as deployment target against research recommendation. D-02 self-heal is the mitigation.

</specifics>

<deferred>
## Deferred Ideas

- **Deep Focus in-app friction** (passphrase typing, unlock delay, hold-to-end, Emergency Pass) — PROJECT.md DFO-01/02/03, post-MVP.
- **Live Activity / Dynamic Island countdown** — LAC-01/02, post-MVP.
- **Local notifications on session end** — Phase 6 NTF-01.
- **Shield visual customization + deep link** — Phase 4 (session-active shield in MVP uses default ShieldConfiguration).
- **Multi-session concurrency / session queue** — out of MVP. Overlapping blocking goes through schedules (Phase 5).
- **Pre-start token reconciliation (belt-and-suspenders)** — D-04 explicitly defers. Revisit if stale-token issues surface in beta.
- **Streak penalty for `cancelled_by_user` / `broken_by_revoke`** — Phase 6 decides whether these outcomes break streak or cost XP.
- **Per-session history UI** (list, detail view) — no MVP requirement; Phase 6 may surface aggregate counts but not per-session detail.
- **Custom sound / haptic on session end** — polish, post-MVP.
- **Emergency Pass (Opal-style "1 free break per day")** — post-MVP gamification lever.

</deferred>

---

*Phase: 03-quick-sessions*
*Context gathered: 2026-04-18*
