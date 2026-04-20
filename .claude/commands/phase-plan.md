---
description: Generate monolithic PLAN.md from CONTEXT.md with plan-checker gate + Plan Approval
argument-hint: <N> [--research] [--ui]
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion, Task]
---

# /phase-plan

Generuje jeden monolityczny `<NN>-PLAN.md` dla fazy `<N>`, z task-listą T01..TNN, `must_haves.truths`, `must_haves.artifacts`, `key_links`, `guide_refs`.

**Plan Approval mandatory** — `plan-checker` agent robi 4 gate'y przed user approval. Max 3 iteracje regeneracji.

## Arguments

- `<N>` (required) — numer fazy.
- `--research` (optional) — spawnuje `phase-researcher` przed planem.
- `--ui` (optional) — spawnuje `ui-researcher` przed planem.

## Process

### 1. Resolve phase + read CONTEXT

```
Glob .planning/phases/{N}-*/
```

Check `{NN}-CONTEXT.md` istnieje. Jeśli nie → BLOCK: `Run /phase-discuss {N} first.`

Read:
- `{NN}-CONTEXT.md` — parse `<decisions>` (D-XX), `<canonical_refs>`, `<domain>`, `<deferred>`
- `.planning/ROADMAP.md` §Phase N — Goal + Success Criteria + Requirements
- `.planning/PROJECT.md` §Hard Constraints
- `CLAUDE.md` — project rules

### 2. Load prior SUMMARY graph

```
Glob .planning/phases/*/{NN}-SUMMARY.md
Glob .planning/phases/*/{NN}-NN-SUMMARY.md (legacy multi-plan)
```

Dla każdego: parse frontmatter `provides:` + `key-files:` (created section).

Zbuduj in-memory `available_artifacts` graph — każdy symbol / plik który już istnieje. Plan nie może to duplikować (G3 anti-duplication).

### 3. Optional research

#### 3a. --research

Jeśli flag:
```
AskUserQuestion:
  question: "Research question for phase-researcher:"
  fields:
    - question: textarea
    - scope: multiSelect [apple-sdk, library, compatibility, perf, code-patterns]
```

```
Task(
  subagent_type="phase-researcher",
  prompt=<phase_number + phase_dir + research_question + scope_hints>
)
```

Wynik: `<NN>-RESEARCH.md` produced by agent. Zapisz path do context for planning.

#### 3b. --ui

```
Task(
  subagent_type="ui-researcher",
  prompt=<phase_number + phase_dir + context_path + reference_spec_paths>
)
```

Wynik: `<NN>-UI-SPEC.md`.

### 4. Generate task list (draft)

Dla każdego Success Criterion z ROADMAP Phase N → ≥1 task.
Dla każdej D-XX z CONTEXT → task który ją realizuje (lub jawne `out_of_scope: D-XX — reason`).
Dla każdego wymagania z REQUIREMENTS.md (REQ-IDs wymienione w ROADMAP) → task.

Per task:
- `id`: T01, T02, ...
- `objective`: 1 zdanie imperatyw ("Implement ShieldConfigurationDataSource z 4 overrides")
- `guide_refs`: subset `<canonical_refs>` z CONTEXT — tylko guides relevant dla tego taska
- `must_haves.truths`: 2-5 inwariantów po tasku
- `must_haves.artifacts`: per nowy plik `{path, provides, contains regex}`
- `must_haves.key_links`: dla każdej ważnej relacji between plikami `{from, to, via, pattern}`
- `read_first`: pliki do przeczytania przed edycją (guides, istniejące implementacje)
- `files`: pliki NEW/MODIFIED/DELETED
- `action`: 3-8 kroków
- `verify.automated`: bash commands (test -f, grep, build/test via XcodeBuildMCP)
- `acceptance_criteria`: weryfikowalne warunki (grep counts, diff empty, build exit 0)
- `done`: 1 zdanie exit criterion

Format: XML-ish w PLAN.md zgodnie z `.planning/templates/PLAN.md`.

Ordering: topologically po `depends_on` między taskami. Testy last, docs last.

### 5. Build full PLAN.md content (in-memory, not yet written)

Read `.planning/templates/PLAN.md` → wypełnij:
- Frontmatter (`phase`, `depends_on`, `files_modified` aggregated, `requirements`, `must_haves` global)
- `<objective>`
- `<context>` z `@` refs
- `<interfaces>` z SUMMARY `provides:` graph (prior phases)
- `<tasks>` bloki
- `<verification>` global
- `<success_criteria>` mapping SC-N → T-N
- `<output>` instruction dla SUMMARY

### 6. Plan-checker gate (iterate max 3×)

```
Task(
  subagent_type="plan-checker",
  prompt=<phase_number + plan_content inline + context_path + roadmap_path + prior_summary_paths>
)
```

Parse verdict:
- G1, G2, G3: PASS / BLOCK
- G4: PASS / WARN
- Overall: PASS / BLOCK

Jeśli `BLOCK`:
- Iteracja 1-2: main Claude regeneruje plan adresując naruszenia. Znów spawn plan-checker.
- Iteracja 3 (3rd block): STOP. Print blockers. `AskUserQuestion`:
  ```
  Plan-checker zwrócił BLOCK po 3 iteracjach. Co zrobić?
    [Accept anyway] — zapisz plan mimo flag (user zaakceptuje ryzyko)
    [Revise CONTEXT] — wróć do /phase-discuss {N} (context może mieć braki)
    [Cancel] — exit bez zapisu
  ```

Jeśli `PASS` → kontynuuj.

### 7. Plan Approval prompt

Pokaż user tabelę preview:

```
## Plan dla Phase {N}: {Name}

| Task | Objective | Covers | Key artifacts |
|------|-----------|--------|---------------|
| T01  | {objective} | D-01, D-03 | {path1.swift}, {path2.swift} |
| T02  | ... | D-02, SC-1 | ... |
| ... | | | |

Plan-checker: PASS ({G1/G2/G3 PASS, G4 WARN: {N} guides nie referenced}).

{Jeśli G4 WARN — wypisz guides jako info}
```

```
AskUserQuestion:
  question: "Accept this plan?"
  options:
    - Accept — zapisz PLAN.md
    - Edit — podaj uwagę, regeneruję
    - Reject — exit bez zapisu
```

`Edit`:
```
AskUserQuestion:
  fields:
    - feedback: textarea "Co zmienić w planie?"
```

Main Claude regeneruje plan z uwzględnieniem feedback → wróć do kroku 5.

`Accept` → krok 8.
`Reject` → exit.

### 8. Write PLAN.md

```
Write {PHASE_DIR}/{NN}-PLAN.md
```

### 9. Report

```
✓ Phase {N} plan saved
  PLAN.md: {PHASE_DIR}/{NN}-PLAN.md
    Tasks: {N}
    Requirements covered: {REQ-IDs}
    Plan-checker: PASS (G1/G2/G3 PASS, G4: {count} warnings)

Następny krok: /phase-do {N}
```

## Commit

Nie commituje. Suggest: `git add .planning/ && git commit -m "docs({NN}): plan phase {N}"`.

## Constraints

- Max 3 plan-checker iterations. 4th iteration → user decides.
- Max 1 `--research` spawn per command invocation. Jeśli user chce więcej questions → re-run komendę.
- Max 1 `--ui` spawn.
- `guide_refs` per task MUSI być subset CONTEXT `<canonical_refs>`. Plan-checker G4 wymusza to.
- Plan MUSI zmieścić się w ≤300 linii **template** ale sam wygenerowany PLAN.md może być dłuższy (to output, nie komenda).
