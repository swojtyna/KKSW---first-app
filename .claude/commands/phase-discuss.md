---
description: Discuss phase implementation decisions via AskUserQuestion, produce CONTEXT.md + DISCUSSION-LOG.md
argument-hint: <N> [--advise]
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion, Task]
---

# /phase-discuss

Zbiera decyzje dla fazy `<N>` i zapisuje `<NN>-CONTEXT.md` zgodnie z `.planning/templates/CONTEXT.md`. Plus audit trail w `<NN>-DISCUSSION-LOG.md`.

## Arguments

- `<N>` (required) — numer fazy (np. `04`, `01.1`).
- `--advise` (optional) — spawnuje `advisor` agent do sanity-check proposals przed zapisem.

## Process

### 1. Resolve phase

```
Glob .planning/phases/{N}-*/
```

Jeśli brak katalogu → BLOCK: `Phase {N} not found. Run /phase-add first.`

Zapisz `PHASE_DIR` i `PHASE_SLUG`.

### 2. Idempotency check

```
ls {PHASE_DIR}/{NN}-CONTEXT.md 2>/dev/null
```

Jeśli istnieje → `AskUserQuestion`:

```
CONTEXT.md już istnieje dla Phase {N}. Co zrobić?
  [Update] — załaduj istniejący i kontynuuj discussion (merge new decisions)
  [View]   — pokaż zawartość i exit
  [Skip]   — exit bez zmian
```

`View` → `Read {NN}-CONTEXT.md` → print → exit.
`Skip` → exit.
`Update` → załaduj istniejący jako bazę, continue.

### 3. Load prior context

Read w kolejności:
- `.planning/PROJECT.md` §Hard Constraints from Research
- `.planning/REQUIREMENTS.md` — sekcja odpowiadająca REQ-IDs z ROADMAP Phase N
- `.planning/ROADMAP.md` §Phase N — Goal + Success Criteria + Requirements
- `.planning/STATE.md` — current focus + pending todos

Dla każdej poprzedniej fazy (shipped w ROADMAP):
- `Glob .planning/phases/*/{NN}-SUMMARY.md` → read `provides:` frontmatter żeby wiedzieć co już istnieje

Dla każdej poprzedniej fazy:
- Read `{NN}-CONTEXT.md` → wyekstrahuj D-XX decyzje które mogą mieć wpływ na current fazę (skim, nie cite wszystkie)

### 4. Identify gray areas

Z ROADMAP Phase N + Success Criteria + REQ-IDs:
- 3-5 konkretnych decyzji architektonicznych/UX/API które user musi podjąć zanim plan powstanie
- Przykłady:
  - "Persistence format? (Codable JSON vs SwiftData vs UserDefaults)"
  - "Navigation pattern? (sheet modal vs root-level switch vs stack push)"
  - "Error handling granularity? (per-operation Result vs global error state)"

Gray areas NIE są tematem jeśli poprzednia D-XX już to rozstrzygnęła — pomiń. Np. "DIContainer scope dla repo" jest już D-22 z 01.1 — nie pytaj ponownie.

### 5. Discussion loop (per gray area)

For each gray area:
```
AskUserQuestion:
  question: "{gray area name} — {1 zdanie kontekstu dlaczego to matter}"
  fields:
    choice:
      options:
        - {Option A — 1 zdanie opisu}
        - {Option B — 1 zdanie opisu}
        - {Option C — 1 zdanie opisu}
        - Other (wpisz własne)
    notes: "Uzasadnienie (opcjonalne)"
```

Po każdej odpowiedzi: zapisz do in-memory `discussion_log[]` z timestamp + Q + A + notes.

### 6. (Optional) Advisor sanity check

Jeśli flag `--advise`:

```
Build proposals block:
  ### {Gray area 1}
  - Proposal: {user choice}
  ### {Gray area 2}
  - Proposal: {user choice}
  ...
```

```
Task(
  subagent_type="advisor",
  prompt=<proposals block + phase_number + context_scope paths>
)
```

Advisor zwraca report. Jeśli `BLOCK` flags:
```
AskUserQuestion:
  question: "Advisor znalazł {N} BLOCK konflikt(ów). Co zrobić?"
  options:
    - Revise {Gray area X} → wróć do pytania
    - Ignore flag (z uzasadnieniem w notes)
    - Cancel discussion
```

Po iteracji: powrót do kroku 5 dla revised gray areas, lub kontynuuj do kroku 7.

### 7. Synthesize decisions

Z `discussion_log[]` → numerowane `D-01..D-NN`, grupowane po sekcjach tematycznych (po nazwach gray areas).

Jeśli `Update` mode z kroku 2 — zachowaj istniejące D-XX numery (nie renumeruj), dokładaj nowe z kolejnym numerem.

### 8. Build canonical_refs

Zawsze:
- `.planning/PROJECT.md` §Hard Constraints from Research
- `.planning/REQUIREMENTS.md` §{phase section}
- `.planning/ROADMAP.md` §Phase {N}
- `.claude/guides/architecture/GUIDE.md`
- `.claude/guides/dependency-injection/GUIDE.md`
- `.claude/guides/navigation/GUIDE.md`
- `.claude/guides/feature-structure/GUIDE.md`

Phase-specific (heurystyki):
- Faza dotyka Shield/DAM/ScreenTime → dodaj relevantne `.claude/research/compass_artifact_*.md`
- Faza dotyka UI → dodaj `.claude/guides/xcodegen/GUIDE.md` (jeśli nowe targets)
- Faza dotyka build → dodaj `.claude/guides/xcodebuild-mcp/GUIDE.md`

Prior phase context:
- Każdy poprzedni `{NN}-CONTEXT.md` którego decyzje mają wpływ na tę fazę (nie lista wszystkich — tylko relevantne)

### 9. Detect missing guides

Jeśli user w dyskusji referuje guide który nie istnieje (np. `.claude/guides/testing/GUIDE.md` — check `ls`):
- Dodaj do `<deferred>` sekcji: `Guide {topic}/GUIDE.md brakuje — napisać przed /phase-plan`.
- NIE blokuj. User zdecyduje potem.

### 10. Write CONTEXT.md + DISCUSSION-LOG.md

Read `.planning/templates/CONTEXT.md` → wypełnij placeholdery:
- `{N}`, `{Name}` (z ROADMAP), `{YYYY-MM-DD}`, `{NN}-{slug}`
- `<domain>` sekcję z ROADMAP Goal + In scope / Out of scope (wywnioskowane z SC + deferred)
- `<decisions>` z synthesized D-XX
- `<canonical_refs>` z kroku 8
- `<code_context>` — lekki skim istniejącego kodu (Glob `Features/` + prior SUMMARY `provides`) dla Reusable Assets / Established Patterns / Integration Points
- `<specifics>` — user-quoted preferences z discussion_log notes
- `<deferred>` — ideas out-of-scope + missing guides z kroku 9

Write `{PHASE_DIR}/{NN}-CONTEXT.md`.

Write `{PHASE_DIR}/{NN}-DISCUSSION-LOG.md`:
```markdown
# Phase {N}: {Name} — Discussion Log

**Date:** {YYYY-MM-DD}
**Mode:** {Fresh | Update}

## Questions & Answers

### Q1 — {Gray area name}
**Asked:** {timestamp}
**Context:** {1 zdanie}
**Options shown:**
  - {option A}
  - {option B}
  - Other

**User choice:** {selected option}
**Notes:** {user notes if any}

→ Mapped to **D-01**: {decision summary}

### Q2 — ...

## Advisor report (jeśli --advise)

{advisor report verbatim}

## Timestamps

- Discussion started: {timestamp}
- Completed: {timestamp}
- Total duration: {X min}
```

### 11. Report

Wypisz:
```
✓ Phase {N} context captured
  CONTEXT.md: {PHASE_DIR}/{NN}-CONTEXT.md
    Decisions: {count D-XX}
    Canonical refs: {count paths}
  DISCUSSION-LOG.md: {PHASE_DIR}/{NN}-DISCUSSION-LOG.md

Następny krok: /phase-plan {N}
  Options: --research (SDK research), --ui (UI spec)
```

## Commit

Nie commituje. User commituje ręcznie lub następna komenda (`/phase-plan`) zrobi to atomowo razem z PLAN.md.

Suggest: `git add .planning/ && git commit -m "docs({NN}): gather phase context"`.

## Constraints

- Max 5 AskUserQuestion rounds (pięć gray areas) per discussion — więcej = gray areas są za drobne, re-scope.
- Advisor spawn tylko jeśli `--advise` flag.
- Jeśli wszystkie gray areas są już decided w prior CONTEXT.md → wypisz "No new gray areas — all decisions inherited from Phase {X}. CONTEXT.md created with inherited decisions and empty new section." Zapisz minimalny CONTEXT.md.
