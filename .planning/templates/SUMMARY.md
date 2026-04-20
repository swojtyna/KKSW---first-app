---
phase: {NN}-{slug}
subsystem: {feature | infra | ui | test}
tags: [{semantic tags — np. shield, deep-link, managed-settings-ui, d-08, d-10}]

# Dependency graph
requires:
  - phase: {previous phase slug}
    provides: "{co poprzednia faza dostarczyła, że tej fazy potrzebuje}"
provides:
  - "{artifact 1 — np. 'ShieldConfigurationExtension renderujący branded shield dla apps/webDomains/categories/activities'}"
  - "{artifact 2 — np. 'Deep link handler deluludetox://session/active → AppRootViewModel.Destination.countdown'}"
affects: [{downstream phase ids — np. 05-scheduled-blocking}]

# Tech tracking
tech-stack:
  added: [{nowe frameworki / biblioteki — np. ManagedSettingsUI}]
  patterns:
    - "{ustanowiony wzorzec — np. 'Shield extension reads active_session.json via SessionReader SPM module, never parses blocklists.json (6MB RAM budget)'}"

key-files:
  created:
    - {path/to/new/file.swift}
  modified:
    - {path/to/modified/file.swift}
  deleted:
    - {path/to/removed/file.swift}

key-decisions:
  - "{decyzja podjęta w trakcie execute — odbiegająca lub rozwijająca CONTEXT.md D-XX}"

patterns-established:
  - "{wzorzec ustalony przez tę fazę do re-use w kolejnych}"

requirements-completed: [{REQ-IDs które faza zamknęła — np. SHL-01, SHL-02, SHL-03, SHL-04}]

# Metrics
duration: {Xmin lub Xh}
completed: {YYYY-MM-DD}
---

# Phase {N}: {Name} — Summary

**{1-paragraph elevator pitch — co faza dowiozła w jednym akapicie, język aktywny "Shield extensions render..." nie "zostało ustanowione że..."}**

## Performance

- **Duration:** {Xmin}
- **Tasks:** {N} ({M auto}, {K checkpoint})
- **Files created:** {count}
- **Files modified:** {count}

## Accomplishments

- {bullet points — co działa po fazie, z referencją do Success Criterion który został domknięty}
- {...}

## Task Commits

{N commitów atomowych per task — format `<type>(NN.tt): <objective>`}:

1. **T01: {name}** — `{sha}` ({type})
2. **T02: {name}** — `{sha}` ({type})
...

## Files Created/Modified

### Created ({count})

| File | Purpose |
|------|---------|
| `{path}` | {purpose} |

### Modified ({count})

| File | Change |
|------|--------|
| `{path}` | {1-zdaniowe podsumowanie zmiany} |

### Deleted ({count})

| File | Reason |
|------|--------|
| `{path}` | {dlaczego usunięte} |

## Build & Test Results

### Build

- **Command:** `session_show_defaults` → `build_sim` scheme=DeluluDetox
- **Simulator:** {iPhone model, iOS version}
- **Result:** BUILD SUCCEEDED
- **Swift 6.2 strict concurrency warnings:** {count, explain if any}

### Tests

- **Command:** `test_sim` scheme=DeluluDetox
- **Result:** {X/X passed}
- **New tests added:** {list — np. `ShieldConfigurationTests` (3/3), `DeepLinkHandlerTests` (4/4)}

## Acceptance Criteria Matrix

| # | Criterion | Result |
|---|-----------|--------|
| 1 | {acceptance z PLAN.md T01} | **PASS** |
| 2 | {...} | **PASS** |

Wszystkie kryteria zaliczone: **{K/K}**.

## Decisions Made

- **{Deviation vs plan}** — {opis + uzasadnienie, ref do Rule 1-4 auto-fix jeśli dotyczy}

## Deviations from Plan

None — OR — {lista z kategorią: added / adjusted / skipped, każda z uzasadnieniem}

## Issues Encountered

{1 bullet per issue + resolution. None if nothing surprising.}

## Known Stubs

None — OR — {placeholder / TODO markers które zostaną zamknięte w kolejnej fazie}

## User Setup Required

None — OR — {konkretne akcje które user musi wykonać ręcznie, np. Apple approval entitlementu}

## Next Phase Readiness

- **Phase {N+1} can begin:** {co teraz jest dostępne dla następnej fazy — `provides:` items}
- **No blockers** (lub lista blockerów jeśli są)

## Self-Check: PASSED

| Claim | Check | Result |
|-------|-------|--------|
| {file created} | `test -f` | **FOUND** |
| {pattern exists} | `grep -c ... ≥ 1` | **N** |
| {task commit} | `git log` | **FOUND `{sha}`** |

---

*Phase: {NN}-{slug}*
*Completed: {YYYY-MM-DD}*
