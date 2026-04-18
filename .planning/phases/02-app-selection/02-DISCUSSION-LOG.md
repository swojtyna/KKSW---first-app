# Phase 2: App Selection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 02-app-selection
**Areas discussed:** List model, Persistence approach, Review & edit flow, Token reconciliation

---

## List Model

| Option | Description | Selected |
|--------|-------------|----------|
| Single blocklist | One global list. Fastest to core value, simplest model. Opal free tier approach. | |
| Multiple named lists | User creates "Work", "Sleep", "Focus" — Phase 3 picks which list. Matches Opal Pro / Foqos. | |
| Single + expansion later | Data model supports N lists, MVP UI shows one. Evolution without DB migration. | ✓ |

**User's choice:** Single + expansion later
**Notes:** Pragmatic MVP — schema flexibility for free, minimal UI investment now.

---

## Persistence Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Codable + JSON file | Struct Blocklist: Codable. Atomic write to App Group file. Extensions read-only. Zero 3rd-party, RAM-safe for 6 MB extension cap. | ✓ |
| SwiftData | iOS 26 native, relational, observable. Heavy for extensions (CoreData under the hood); first-year bugs. | |
| UserDefaults (suite) | Simplest, extensions trivially read. No schema, poor for complex structures. | |

**User's choice:** Codable + JSON file
**Notes:** Aligned with research pattern for production Opal clones.

---

## File Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Split per domain | `blocklists.json`, `sessions.json`, `schedule.json`. Extension parses only what it needs. | ✓ |
| Monolithic state.json | One file. Simple, but extension over-parses and every write rewrites everything. | |
| Single + lazy codable | Monolithic with lazy decoding. Most complex, error-prone. | |

**User's choice:** Split per domain
**Notes:** Minimizes RAM pressure in DeviceActivityMonitor extension.

---

## Review & Edit Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Own list + re-open picker | Dedicated "Blocked" screen, `Label(token)` rows, swipe-to-delete, "Change selection" opens picker. Opal-like UX. | ✓ |
| FamilyActivityPicker only | No own list; user sees selection only inside Apple's picker. Least code, worst visibility. | |
| List read-only + picker for edits | Shows state but edits go through picker re-open. Compromise. | |

**User's choice:** Own list + re-open picker (after plain-language explanation request)
**Notes:** User asked for a jargon-free walkthrough before answering; selected option A once the tradeoffs were explained in plain Polish.

---

## Token Reconciliation

| Option | Description | Selected |
|--------|-------------|----------|
| Foreground + session start | Two reconciliation points — defensive, belt + suspenders for core value. | |
| Foreground only | One point (scenePhase .active). Simpler, small stale-token risk between foreground and session start. | ✓ |
| On-demand before session | Lazy. Stale labels on review screen until session starts. | |
| Claude decides | Defer to planner. | |

**User's choice:** Foreground only
**Notes:** User explicitly optimized for simplicity ("B idziemy prosciej") after a plain-language walkthrough of the token rotation concept. Risk of rotation between foreground and session start is acknowledged and noted for potential revisit in Phase 3.

---

## Claude's Discretion

- Exact SwiftUI layout and copy for the "Blocked" screen.
- Empty-state copy and illustration.
- Entry point for the "Blocked" screen in the Phase 1 navigation graph.
- Error / retry UX when `FamilyActivityPicker` presentation fails.
- `FamilyActivitySelection` hydration strategy for pre-seeding the picker.

## Deferred Ideas

- Multi-list CRUD UI — future phase.
- Session-start reconciliation — revisit in Phase 3 if stale tokens cause failures.
- Empty-state app suggestions — deferred (Apple doesn't expose app names as strings).
- Import / export blocklist JSON — deferred power-user feature.

## Process Notes

- User invoked `/gsd:discuss-phase 2` without Phase 1 (Xcode scaffold) being executed. This was flagged and accepted — Phase 2 execution will require Phase 1 to have created the multi-target project, entitlements, and App Group first.
- No USER-PROFILE.md, METHODOLOGY.md, spikes, or sketches exist — discussion used standard flow without advisor-mode research.
