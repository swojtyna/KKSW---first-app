---
description: Mark phase complete in ROADMAP + bump STATE + optional git tag
argument-hint: <N> [--tag]
allowed-tools: [Read, Edit, Bash, AskUserQuestion]
---

# /phase-ship

Zamyka fazę formalnie: `- [ ]` → `- [x]` w ROADMAP, bump STATE, opcjonalny git tag `phase-{N}-complete`.

Requires: `{NN}-VERIFICATION.md` istnieje z `overall_status: passed` (lub `partial` z user override).

## Arguments

- `<N>` (required) — numer fazy.
- `--tag` (optional) — utwórz git tag `phase-{N}-complete`.

## Process

### 1. Resolve phase + check prerequisites

```
Glob .planning/phases/{N}-*/{NN}-VERIFICATION.md
```

Jeśli brak → BLOCK: `Run /phase-verify {N} first.`

Read VERIFICATION.md frontmatter → `overall_status`.

### 2. Gate on overall_status

```
If overall_status == passed:
  → proceed silently
Elif overall_status == partial:
  AskUserQuestion:
    question: "Phase {N} verification is partial (skips/defers present, no fails). Ship anyway?"
    options:
      - Ship partial — oznacz fazę jako completed mimo skips/defers
      - Cancel — nie ship (user może re-run /phase-verify po retestach)
  
  Cancel → exit.
Elif overall_status == failed:
  AskUserQuestion:
    question: "🚫 Phase {N} verification FAILED. Ship anyway (not recommended)?"
    context: "Gaps will remain open. Consider: /phase-plan {N} dla gap-fix przed ship."
    options:
      - Ship failed (force — silnie niezalecane)
      - Cancel
  
  Ship failed → require explicit text confirmation: "Wpisz 'ship-failed' żeby potwierdzić:"
  Cancel → exit.
```

### 3. Update ROADMAP.md

Read `.planning/ROADMAP.md`.

#### 3a. Top-level list entry

Find line:
```
- [ ] **Phase {N}: {Name}** - {goal}
```

Replace z:
```
- [x] **Phase {N}: {Name}** - {goal} (completed {YYYY-MM-DD})
```

#### 3b. Progress table row

Find row dla Phase {N} w `## Progress` table (format `| {N}. {Name} | X/Y | Not started | - |`).

Replace `Not started` → `Complete` + `| -` → `| {YYYY-MM-DD}`.

Dla decimal phases (N.1) — use tez odpowiedni row.

### 4. Update STATE.md

Read STATE.md frontmatter:
- `progress.completed_phases` += 1
- `progress.percent` = `round(completed_phases / total_phases * 100)`
- `last_updated` = ISO timestamp
- `last_activity` = today
- `stopped_at` = `"Phase {N} shipped"`

Body §Current Position:
- `Phase:` → next unchecked phase from ROADMAP (jeśli jest) albo `None (milestone complete)`
- `Plan:` → `Not started`
- `Status:` → `Ready to discuss` (jeśli jest next faza) lub `Milestone complete`

### 5. Git tag (if --tag)

Jeśli `--tag` flag:

```
AskUserQuestion:
  question: "Create git tag `phase-{N}-complete`?"
  options:
    - Yes — git tag (local only, no push)
    - No — skip tag
```

Yes:
```bash
git tag "phase-{N}-complete" -m "Phase {N}: {Name} completed {YYYY-MM-DD}"
```

**NIE** pushuj automatycznie. User decyduje kiedy push.

### 6. Commit changes

```bash
git add .planning/ROADMAP.md .planning/STATE.md
git commit -m "docs({N}): ship phase — mark complete in roadmap"
```

### 7. Report

#### 7a. Success path:
```
✓ Phase {N}: {Name} shipped (YYYY-MM-DD)
  ROADMAP: [x] Phase {N}
  STATE: completed_phases = {X}/{Y} ({percent}%)
  {jeśli --tag: Git tag: phase-{N}-complete}

{Jeśli są kolejne fazy:}
Następny krok: /phase-discuss {next_N}
{Jeśli brak kolejnych faz:}
Milestone {v1.0} complete!  Wszystkie fazy shipped.
  Możesz:
    - /phase-add <slug> — dodać nową fazę
    - Start nowego milestone (manually update STATE.md + ROADMAP.md milestone label)
```

## Constraints

- Zero Task spawn.
- Zero VERIFICATION.md regeneration — ta komenda tylko czyta.
- Git operacje ograniczone do `tag` (lokalne) i `commit`. Żadnego push, żadnego force, żadnego reset.
- `--tag` opt-in. Default = bez taga.
- Jeśli ROADMAP już ma `[x]` dla tej fazy → WARN: `Phase {N} already shipped on {date}. Re-running is idempotent — STATE will be re-bumped. Continue?`.
