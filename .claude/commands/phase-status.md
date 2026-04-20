---
description: Read-only dashboard — current phase, artifacts present, suggested next command
argument-hint: (none)
allowed-tools: [Read, Glob, Bash]
---

# /phase-status

Read-only dashboard. Nic nie zapisuje, nic nie spawnuje.

## Process

### 1. Read STATE

```
Read .planning/STATE.md
```

Parse frontmatter: `progress.completed_phases`, `progress.total_phases`, `progress.completed_plans`, `progress.total_plans`, `progress.percent`, `last_activity`, `stopped_at`.

Parse body §Current Position: `Phase:`, `Plan:`, `Status:`.

### 2. Resolve current phase

Z frontmatter STATE → `Phase:` field z §Current Position (np. `03`, `04`, `01.1`).

```
Glob .planning/phases/{current}-*/
```

Jeśli brak katalogu → next phase jest pierwszą niestartową z ROADMAP.

### 3. Read ROADMAP for phase list

```
Read .planning/ROADMAP.md
```

Zbierz:
- Lista faz top-level (`- [x]` / `- [ ]` + nazwa)
- Dla każdej `- [ ]` fazy zapisz numer + slug

### 4. Enumerate artefakty aktualnej fazy

```
Glob .planning/phases/{current}-{slug}/*.md
```

Sprawdź obecność (kolejność pipeline):
- `{NN}-CONTEXT.md`
- `{NN}-RESEARCH.md` (opcjonalne, jeśli `--research` był użyty)
- `{NN}-UI-SPEC.md` (opcjonalne, jeśli `--ui` był użyty)
- `{NN}-DISCUSSION-LOG.md` (produced przez `/phase-discuss`)
- `{NN}-PLAN.md` (monolityczny — nowy format) LUB `{NN}-NN-PLAN.md` (multi-plan legacy z GSD)
- `{NN}-SUMMARY.md` (monolityczny) LUB `{NN}-NN-SUMMARY.md` (multi-plan legacy)
- `{NN}-VERIFICATION.md`

### 5. Decision tree — suggest next command

Sprawdź w kolejności:

```
If brak CONTEXT.md:
  → Suggestion: /phase-discuss <N>

Elif CONTEXT.md exists && brak PLAN.md (monolityczny) && brak *-01-PLAN.md (legacy):
  → Suggestion: /phase-plan <N>

Elif PLAN.md exists && brak SUMMARY.md:
  → Check git log: `git log --oneline --grep="^[a-z]\+(${N}[.-][0-9]\+):" | head -5`
    If commits found:
      → Suggestion: /phase-do <N>  (resume — komenda wznowi od następnego taska)
    Else:
      → Suggestion: /phase-do <N>  (start)

Elif SUMMARY.md exists && brak VERIFICATION.md:
  → Suggestion: /phase-verify <N>

Elif VERIFICATION.md exists && ROADMAP fazy jest `- [ ]`:
  → Suggestion: /phase-ship <N>

Elif faza shipped (ROADMAP `- [x]`):
  → Next unchecked phase from ROADMAP → Suggestion: /phase-discuss <N+1>

Else (wszystko done):
  → "Milestone complete. Add new phases via /phase-add <slug>"
```

### 6. Print dashboard

Format:

```
## DeluluDetox phase status

Milestone: {milestone from STATE}
Progress: {progress.percent}% ({completed_phases}/{total_phases} phases, {completed_plans}/{total_plans} plans)
Last activity: {last_activity}

Current phase: {N} — {Name}
  Status: {Discussed | Planned | In progress | Verified | Shipped}

Artifacts w {phase_dir}:
  [{check}] {NN}-CONTEXT.md
  [{check}] {NN}-DISCUSSION-LOG.md
  [{check}] {NN}-RESEARCH.md (optional)
  [{check}] {NN}-UI-SPEC.md (optional)
  [{check}] {NN}-PLAN.md
  [{check}] {NN}-SUMMARY.md
  [{check}] {NN}-VERIFICATION.md

  Legacy multi-plan files (jeśli są):
    {NN}-01-PLAN.md..NN-NN-PLAN.md
    {NN}-01-SUMMARY.md..

Suggested next step:
  → {suggestion}
```

`[{check}]` = `[✓]` jeśli istnieje, `[ ]` jeśli nie.

## Constraints

- Nic nie zapisuje. Tylko output do terminala.
- Żadnego Task spawn.
- Żadnego git mutate — tylko `git log` read.
- Jeśli STATE.md nie istnieje LUB jest corrupted (brak frontmatter) → wypisz: `STATE.md missing or malformed. Run /phase-add first to bootstrap.`
