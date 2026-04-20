---
description: Execute plan tasks sequentially in main Claude (no subagent spawn), atomic commit per task, produce SUMMARY.md
argument-hint: <N>
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion, Task]
---

# /phase-do

Wykonuje wszystkie taski z `<NN>-PLAN.md` **sekwencyjnie w głównym Claude**. Żadnego spawn executora w worktree. Atomowy commit per task. Produkuje `<NN>-SUMMARY.md` na koniec.

**Resume logic:** jeśli część tasków już ma commity (git log match) — start od następnego niewykonanego.

## Arguments

- `<N>` (required) — numer fazy.

## Process

### 1. Resolve phase + load PLAN

```
Glob .planning/phases/{N}-*/{NN}-PLAN.md
```

Jeśli brak → BLOCK: `Run /phase-plan {N} first.`

Read:
- `{NN}-PLAN.md` — parse frontmatter (`files_modified`, `requirements`, `must_haves` global) + `<tasks>` bloki + `<verification>` + `<success_criteria>` + `<output>`
- `{NN}-CONTEXT.md` — dla referencji D-XX
- `CLAUDE.md` — project rules
- `.planning/PROJECT.md` §Hard Constraints

### 2. Parse task list

Dla każdego `<task>`:
- id (T01, ...)
- objective
- guide_refs (list paths)
- read_first (list paths)
- files (NEW/MODIFIED/DELETED)
- action (list steps)
- verify.automated (bash commands)
- acceptance_criteria (grep/build/test checks)
- done (exit criterion)

### 3. Resume logic

```bash
git log --oneline --grep="^[a-z]\+({N}[.-][0-9]\+):" | head -20
```

Dla każdego taska TNN — grep commit message za `({N}.{tt}):` pattern. Jeśli match → task done, skip.

Start od pierwszego taska bez commit match.

Jeśli wszystkie taski mają commity → skip do kroku 6 (write SUMMARY) i global verification.

### 4. Use TodoWrite for tracking

```
TodoWrite: dla każdego niewykonanego task — status pending.
```

Per task: TaskUpdate `in_progress` → execute → `completed`.

### 5. Execute per task (sequential)

For each task TNN (w order):

#### 5a. Read required files

Dla każdego `<read_first>` path:
```
Read {path}
```

**Zawsze** read także wszystkie `guide_refs` paths PRZED edycją plików tasku.

Jeśli któryś guide nie istnieje:
- AskUserQuestion: `Guide {path} nie istnieje. Options: Skip guide (proceed), Cancel task, Write guide first (exit, pisz guide, re-run phase-do)`
- Default: Cancel task i zatrzymaj `/phase-do`.

#### 5b. Execute action

Wykonaj kroki z `<action>` — Edit / Write / Bash operations. Respect:
- `CLAUDE.md` §Project Rules (Architecture, DI, Navigation, Build) — **hard constraints**
- `PROJECT.md` §Hard Constraints from Research (1-9) — **hard constraints**
- `guide_refs` sekcje — follow patterns

Jeśli action prowadzi do konfliktu z CLAUDE.md / PROJECT.md / locked D-XX → STOP task, print konflikt, `AskUserQuestion`: `Deviation detected. Options: Modify action, Skip task, Cancel phase-do`.

#### 5c. Build & test

Uruchom via XcodeBuildMCP (per `CLAUDE.md` Build & Test section):

```
mcp__XcodeBuildMCP__session_show_defaults   (raz per session — jeśli już był w tym phase-do, skip)
mcp__XcodeBuildMCP__build_sim                (lub test_sim jeśli task dodał testy)
```

Jeśli build FAIL:
- Auto-fix compilation errors (CLAUDE.md `Fix compilation errors autonomously`). Max 3 próby.
- Po 3 nieudanych próbach → STOP task, print błąd, `AskUserQuestion`: `Build failed after 3 autofix attempts. Options: Manual fix (wait for user), Skip task, Cancel`.

Jeśli test FAIL:
- Per-task zdecyduj: czy failing test testuje **to co task implementuje** (RED test TDD → OK, expected) czy jest to pre-existing regression (BLOCK).
- Pre-existing → stop, ask user.

#### 5d. Verify must_haves

```bash
# must_haves.artifacts per task
grep -q "{contains pattern}" {path}
test -f {path}

# must_haves.key_links (jeśli task ich dotyczy)
grep -q "{pattern}" {from file}
```

Jeśli któryś must_have regex nie matchuje → STOP task: `must_have violation: {pattern} not found in {path}`. Auto-fix 1 próba (re-edit). Potem → ask user.

#### 5e. Verify acceptance_criteria

Bash each acceptance criterion. Wszystkie muszą pass.

#### 5f. Atomic commit

Determine commit type:
- Task tworzy głównie source files → `feat`
- Task modifies existing source (refactor) → `refactor`
- Task dodaje tylko testy → `test`
- Task to docs-only (markdown, README, guides) → `docs`
- Task to config / build / tooling → `chore`

```bash
git add {files from task}
git commit -m "<type>({N}.{tt}): {objective first 60 chars}"
```

**NIE** używaj `--no-verify` / `--amend` / `--force` (CLAUDE.md Git Safety Protocol).

TaskUpdate TNN → `completed`.

### 6. Global post-execution verification

Po wszystkich taskach:

#### 6a. Global build + test

```
mcp__XcodeBuildMCP__build_sim scheme=DeluluDetox
mcp__XcodeBuildMCP__test_sim  scheme=DeluluDetox
```

Oba MUSZĄ PASS. Jeśli nie — stop, report, ask user.

#### 6b. Global must_haves

Z PLAN.md frontmatter `must_haves.truths` + `must_haves.artifacts` + `must_haves.key_links` — weryfikuj globalnie (każdy regex match, każdy path exists).

#### 6c. Clean tree check

```bash
git status --short
```

Powinno być czyste (all committed w taskach). Jeśli są uncommitted changes → WARN, ask user czy dodać do ostatniego tasku czy ignore.

### 7. Write SUMMARY.md

Read `.planning/templates/SUMMARY.md` → wypełnij:

- Frontmatter:
  - `phase`, `subsystem` (feature/infra/ui/test wybrane po dominującym typie taskow)
  - `tags` — semantic (wywnioskowane z D-XX + Success Criteria)
  - `requires:` z poprzedniej fazy (z `depends_on` PLAN.md → prior SUMMARY `provides:` które są konsumowane)
  - `provides:` — zsumowane z `must_haves.artifacts` wszystkich tasków
  - `affects:` — fazy które na tej są zależne (grep ROADMAP `Depends on: Phase {N}`)
  - `tech-stack.added/patterns` — z real observations
  - `key-files.created/modified/deleted` — zsumowane
  - `key-decisions` — deviations od planu (jeśli były)
  - `patterns-established` — wzorce ustalone przez tę fazę
  - `requirements-completed` — REQ-IDs z PLAN.md requirements
  - `duration`, `completed`

- Body:
  - 1-paragraph elevator pitch
  - Performance (duration, tasks count, files count)
  - Accomplishments (bullet points)
  - Task Commits (lista z SHA)
  - Files Created/Modified/Deleted tables
  - Build & Test Results (XcodeBuildMCP output)
  - Acceptance Criteria Matrix (wszystkie kryteria ze wszystkich tasków × wynik)
  - Decisions Made (deviations)
  - Deviations from Plan (list lub "None")
  - Issues Encountered (list lub "None")
  - Known Stubs (list lub "None")
  - User Setup Required (list lub "None")
  - Next Phase Readiness
  - Self-Check: PASSED table (key claims verified post-write)

```
Write {PHASE_DIR}/{NN}-SUMMARY.md
```

### 8. Commit SUMMARY

```bash
git add {PHASE_DIR}/{NN}-SUMMARY.md
git commit -m "docs({N}): complete phase execution"
```

### 9. Update STATE.md

Read STATE.md, edit frontmatter:
- `progress.completed_plans` += N (N = liczba wykonanych tasków w tej fazie)
- `progress.percent` przelicz: `completed_phases/total_phases` (NOT plans — fazy są bardziej user-meaningful)
- `last_updated` → ISO timestamp teraz
- `last_activity` → today
- `stopped_at` → "Phase {N} completed"

Edit body §Current Position:
- `Phase:` pozostaje {N} do momentu `/phase-ship`
- `Plan:` → "Completed"
- `Status:` → "Ready to verify"

```bash
git add .planning/STATE.md
git commit -m "chore({N}): bump state after phase completion"
```

### 10. Report

```
✓ Phase {N} execution complete
  Tasks: {N} completed, {N} atomic commits
  Build: PASS, tests: {X/X} passed
  SUMMARY.md: {PHASE_DIR}/{NN}-SUMMARY.md

Następny krok: /phase-verify {N}
```

## Constraints

- Zero subagent spawn. Wszystko sekwencyjnie w głównym kontekście.
- Zero worktree. Zero parallel execution.
- Commit message format: `<type>({N}.{tt}): <objective>`. Dla monolitycznego PLAN to jest `NN.tt` gdzie `tt` = task number zero-padded (np. `feat(04.01):`, `feat(04.02):`).
- Jeśli PLAN.md jest legacy multi-plan format (`{NN}-01-PLAN.md` etc.) — BLOCK: `Multi-plan legacy format — użyj starej komendy lub skonwertuj do monolitu`.
- **NIE** używać `--no-verify`, `--amend`, `--force`. CLAUDE.md Git Safety Protocol.
- Każdy task to osobny commit — **nie batch**.
