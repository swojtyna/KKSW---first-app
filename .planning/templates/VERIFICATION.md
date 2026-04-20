---
phase: {NN}-{slug}
date: {YYYY-MM-DD}
overall_status: {passed | partial | failed}
---

# Phase {N}: {Name} — Verification

Conversational UAT — user answered `Pass` / `Fail` / `Skip` / `Defer` per Success Criterion from ROADMAP Phase {N}.

## Success Criteria Matrix

| # | Success Criterion (from ROADMAP) | Status | Notes |
|---|----------------------------------|--------|-------|
| 1 | {SC-1 z ROADMAP Phase N} | Pass | {optional note — np. "verified on iPhone 17 sim iOS 26.2"} |
| 2 | {SC-2} | Fail | {gap opis — patrz <gaps>} |
| 3 | {SC-3} | Pass | — |
| 4 | {SC-4} | Skip | Not testable in simulator (requires physical device for entitlement) |
| 5 | {SC-5} | Defer | Deferred do Phase {N+1} gap-fix plan |

**Overall:** {X/Y passed, Z fails, W skips, V defers}

<gaps>
## Gaps

{tylko jeśli overall_status != passed}

### Gap 1 — SC-{idx}: {criterion}

**User description:**
> {user-provided gap opis z AskUserQuestion}

**Impact:** {high | medium | low — czy blokuje core value?}

**Proposed resolution:** {gap-fix w tej fazie | backlog entry nowa faza | deferred do milestone}

</gaps>

<followup>
## Follow-up

{jeśli gaps istnieją — konkretna sugestia akcji}

- **Option A — Gap-fix w Phase {N}:** run `/phase-plan {N}` z dodatkowym taskiem adresującym Gap 1. PLAN.md zostanie uzupełniony, `/phase-do {N}` wykona tylko nowe taski (resume logic przez git log).
- **Option B — Backlog w ROADMAP:** `/phase-add {slug-for-gap}` dodaje nową fazę po tej; SC-2 zostaje zaznaczony jako `deferred` i nie blokuje `/phase-ship {N}`.
- **Option C — Defer do post-MVP:** update PROJECT.md §Out of Scope, zamknij fazę partial z gap udokumentowanym w Known Limitations.

</followup>

---

*Phase: {NN}-{slug}*
*Verified: {YYYY-MM-DD}*
