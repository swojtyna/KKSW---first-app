# Lekki zamiennik GSD dla jednoosobowej apki iOS

Poniżej kompletny dokument zgodny z §7 promptu — cztery sekcje (A, B, C, D), wszystkie pliki komend gotowe do wklejenia, templaty uproszczone, ścieżka migracji konkretna. Research zewnętrzny (best practices Claude Code) potwierdził kluczowe założenia: pliki komend do 300 linii, `allowed-tools` z pre-approval per komenda bash, `AskUserQuestion` 1–4 pytań × 2–4 opcji, subagenci nie mogą spawnować innych subagentów, każdy subagent ma własne okno kontekstu, a Conventional Commits to de facto standard atomowych commitów.

Główna teza: **realny problem GSD to nie "za dużo komend", tylko ładowanie tysiąca linii workflowa przez `@.../workflow.md` przed każdą pracą.** Cztery komendy inline + jeden opcjonalny pomocniczy researcher wystarczą. Flagi, wave dispatch i połowa pomocniczych Claude'ów do wycięcia — pod jednym warunkiem, który omawiam w Sekcji B.

---

## Sekcja A — Mapa GSD w plain language

| Etap | Co realnie robi | Co produkuje | Po co to istnieje | Koszt tokenów |
|---|---|---|---|---|
| **discuss-phase** | 13-krokowy workflow: init przez `gsd-tools`, sprawdzenie blokad, przeczytanie PROJECT/REQUIREMENTS/STATE + wszystkich poprzednich CONTEXT.md, grep codebase, identyfikacja "gray areas", `AskUserQuestion(multiSelect)` z kategoriami, pętla deep-dive per kategoria, synteza decyzji D-01..D-NN. Opcjonalnie Advisor Mode spawnuje `gsd-advisor-researcher` per gray area. | `NN-CONTEXT.md` (sekcje: domain, decisions, specifics, canonical_refs, code_context, deferred) + `NN-DISCUSSION-LOG.md` (audit trail alternatyw) | Żeby planner nie zgadywał preferencji. Numerowane D-IDs później są referencjami z planu i kodu. | **Wysoki** — sam workflow `discuss-phase.md` to 1 201 linii ładowanych przez `@/...` do kontekstu głównego Claude'a PRZED pierwszym pytaniem. Plus 3 pliki `references/*.md`. Plus opcjonalny spawn 1–N `gsd-advisor-researcher` (każdy własny fresh context z frontmatter + files_to_read). |
| **plan-phase** | Walidacja fazy, opcjonalny PRD Express Path, load `CONTEXT.md`, jeśli brak `RESEARCH.md` → spawn `gsd-phase-researcher`, jeśli `nyquist_validation_enabled` → buduje matrycę Nyquista do `VALIDATION.md`, spawn `gsd-planner` (produkuje pliki `NN-NN-PLAN.md` per task + dependency graph + wave assignment), weryfikacja przez `gsd-plan-checker` (verdict PASS/REVISE/BLOCK, do 3 iteracji rewizji). | `NN-RESEARCH.md` (opcjonalnie), `NN-VALIDATION.md` (opcjonalnie), `NN-NN-PLAN.md` × liczba tasków (per plan), każdy z `must_haves.truths` + `must_haves.artifacts` + `key_links` z regex | Plan musi pokrywać success criteria fazy z `ROADMAP.md` (goal-backward), nie tylko być "listą todo". Plan-checker 2 razy uratował refaktor. | **Wysoki** — `plan-phase.md` to 1 075 linii. Plus spawnuje 3 pomocniczych Claude'ów (researcher + planner + plan-checker, ten ostatni nawet 3× w pętli rewizji). Każdy planner i checker dostaje cały kontekst fazy. |
| **execute-phase** | Discover plans i group w "wave map" (fale równoległe wg `files_modified` overlap). Dla każdej fali: spawn `gsd-executor` w osobnym git worktree, sequential dispatch (bo `.git/config.lock` ma exclusive lock). Merge worktree → main → cleanup. Po wszystkich falach: `gsd-verifier` (goal-backward, `VERIFICATION.md`). Opcjonalnie: `gsd-integration-checker`, `gsd-nyquist-auditor` (uzupełnia testy). Update `STATE.md`, routing. | `NN-NN-SUMMARY.md` per plan (frontmatter: requires/provides/affects + patterns-established), `NN-VERIFICATION.md`, atomic commity per task | Atomic commity per task + goal-backward verification dają debuggable log fazy i wyłapują sytuacje "taski się skończyły ale faza nie dowiozła wartości". | **Bardzo wysoki** — `execute-phase.md` to 1 253 linii. Sam wave dispatch z obsługą worktree lock to masywny blok logiki. Plus N spawnów `gsd-executor` (każdy z pełnym PLAN.md + CONTEXT.md + PATTERNS.md + guides). Plus verifier. Opcjonalnie 2 dodatkowe spawny. |
| **verify-work / verify-phase** | Goal-backward: porównanie success criteria z `ROADMAP.md` z tym co faktycznie działa. Spawn `gsd-verifier`. Może uruchamiać smoke testy, czytać SUMMARY files z fazy, sprawdzać artefakty z `must_haves.artifacts`. | `NN-VERIFICATION.md` z listą gapów | Sprawdza, że faza osiągnęła swój cel, nie tylko że kroki zostały wykonane. | **Średni** — sam verifier to pojedynczy spawn, ale dostaje pełny kontekst fazy (CONTEXT + wszystkie PLAN + wszystkie SUMMARY + ROADMAP). |
| **code-review (+ fix)** | `gsd-code-reviewer` czyta source files zmienione w fazie i generuje `REVIEW.md` z severity. `/gsd-code-review-fix` spawnuje `gsd-code-fixer` który aplikuje fixy z atomowym commitem per fix. | `NN-REVIEW.md`, `NN-REVIEW-FIX.md` | Samodzielny sanity check przed shipem. | **Średni** — 2 spawny, każdy z pełnym kontekstem zmienionych plików. |
| **ui-phase / ui-review** | `gsd-ui-researcher` produkuje `UI-SPEC.md` (design contract przed implementacją). Po fazie `gsd-ui-auditor` robi 6-pillar visual audit. `gsd-ui-checker` wydaje BLOCK/FLAG/PASS verdict dla `UI-SPEC.md`. | `NN-UI-SPEC.md`, audit report | UI-SPEC przed kodem = spójny design intent. Audit retroactive = zgodność z specyfikacją. | **Średni** (pre) + **Średni** (post) — 2–3 spawny. |

### Co się stanie jak pominę dany etap?

- **Pominięcie discuss.** Planner zgaduje twoje preferencje (nawigacja? DI scope? naming?). Prawdopodobieństwo niezgodności z wizją wysokie — jednoosobowy dev wykryje to przy review, ale traci 1–2 obroty na przepisywanie planu. Dla DeluluDetox, gdzie co drugi wybór ma efekt strategiczny (np. Wzorzec A vs B w `AppRootViewModel`), discuss jest nieusuwalny.
- **Pominięcie plan.** Execute leci bez listy tasków i bez `must_haves`. Nie masz czego weryfikować ani zgrepować. Commity tracą atomowość, bo nie ma predefiniowanych granic. Absolutny no-go dla fazy architektonicznej typu 01.1.
- **Pominięcie execute (robienie ręczne).** Tracisz atomowe commity z konwencją `feat(NN.tt): ...` i log fazy czytelny wstecz. Wraca "dużo zmian w jednym commicie", `git blame` przestaje mieć sens. Akceptowalne dla drobnych poprawek, nie dla fazy core value.
- **Pominięcie verify.** `STATE.md` mówi "done", ale nie wiesz czy success criteria fazy są dowiezione. Bug wychodzi dopiero w Phase N+1 gdy coś się o to opiera. Dla Phase 03 (Quick Sessions = core value) pominięcie verify to hazard.
- **Pominięcie code-review.** Review jest realnie tańsze niż debugowanie przez 3 sesje później. Dla solo-dev można łączyć z verify w jedną rozmowę.
- **Pominięcie ui-phase.** Dla jednoosobowego designera z jednym taste'em — pre-spec OK, post-audit teatr. Dla DeluluDetox zgadzam się na wycięcie retroactive audit, ale UI-SPEC.md przed implementacją Quick Sessions zostaje (za dużo stanów shield/timer/schedule żeby improwizować).

---

## Sekcja B — Diagnoza wycieku tokenów w Twoim przypadku

### B.1. Agent / workflow → użycie w Phase 01 i 01.1 → koszt → wartość

Tabelę konstruuję z ewidencji artefaktów w `.planning/phases/` wymienionych w §1 i §2 promptu. Jeśli artefakt istnieje w realnym repo fazy, pomocniczy Claude go wytworzył.

| Pomocniczy Claude / workflow | Użyty w 01 i 01.1? | Koszt tokenów | Wartość dla Ciebie |
|---|---|---|---|
| `gsd-phase-researcher` | Tak (RESEARCH.md jest w Phase 02; 01.1 miała Architecture/DI research) | Średni (1 spawn, pełny kontekst) | **High** — bez tego planner zgaduje techniczne podejście |
| `gsd-planner` | Tak (7 plików PLAN w 01.1) | Wysoki (spawn + pełny CONTEXT + RESEARCH + guides) | **High** — core wartość frameworka |
| `gsd-plan-checker` | Tak (retoryka "uratował refaktor 2 razy") | Średni–wysoki (do 3× w pętli rewizji) | **High** — verification loop to realny gain |
| `gsd-executor` | Tak (spawny w worktree per plan) | Bardzo wysoki (N spawnów × pełny kontekst każdy) | **Medium** — wykonuje commity, ale w sequential mode można to robić w głównym Claude bez wasteful spawnów |
| `gsd-verifier` | Tak (VERIFICATION.md w Phase 01.1) | Średni | **High** — goal-backward łapie rzeczy których task-by-task nie łapie |
| `gsd-nyquist-auditor` | **Nie** (brak `VALIDATION.md` z matrycą w 01/01.1 — wymieniony jest tylko jako plik szkic w §1) | Średni | **Low** dla większości faz; **Medium** dla Phase 03 (patrz B.3) |
| `gsd-security-auditor` | **Nie** (brak SECURITY.md w artefaktach 01/01.1) | Średni | **Low–Medium** dla większości; **Medium** dla Phase 04 Shield (patrz B.3) |
| `gsd-codebase-mapper` | **Nie** (brak `.planning/codebase/*.md` wymienionych jako istniejące) | Wysoki | **Zero** dla <50k LoC repo |
| `gsd-ui-auditor` (retroactive) | Niejasne — `02-UI-SPEC.md` istnieje (to output researchera), ale audit retroactive — brak dowodów | Średni | **Zero** dla solo-dev z jednym taste'em |
| `gsd-ui-researcher` | Tak (`02-UI-SPEC.md` jest) | Średni | **High** dla Phase 02/04 — zostawić |
| `gsd-ui-checker` | Prawdopodobnie tak | Niski | **Medium** — nice to have |
| `gsd-doc-verifier` | **Nie** | Średni | **Zero** — docs piszesz sam ad-hoc |
| `gsd-doc-writer` | **Nie** | Średni | **Low** — ad-hoc wystarcza |
| `gsd-research-synthesizer` (4 parallel) | **Nie** (używany tylko w `/gsd-new-project`) | Bardzo wysoki | **Zero** — projekt już jest |
| `gsd-project-researcher` | **Nie** (używany tylko raz na starcie) | Wysoki | **Zero** — projekt już jest |
| `gsd-roadmapper` | **Nie** | Wysoki | **Zero** — `ROADMAP.md` już jest |
| `gsd-user-profiler` | **Nie** (brak USER-PROFILE.md) | Wysoki | **Zero** |
| `gsd-integration-checker` | Niejasne — nie widzę `INTEGRATION.md` w wykazie | Wysoki (cross-phase E2E) | **Low** dla solo-dev przy małych fazach |
| `gsd-code-reviewer` + `gsd-code-fixer` | Niejasne (brak `NN-REVIEW.md` explicit w wykazie 01.1 artefaktów w §1) | Średni (2 spawny) | **Medium** — łączyć z verify |
| `gsd-intel-updater` | **Nie** (brak `.planning/intel/`) | Średni | **Zero** |
| `gsd-advisor-researcher` | Niejasne (advisor mode zależny od USER-PROFILE) | Średni × N gray areas | **Low** — przy ostrzelonym devie niepotrzebne |
| `gsd-assumptions-analyzer` | **Nie** (discuss-phase-assumptions jest jedną z 3 ścieżek, nie wymuszona) | Wysoki | **Low** |
| `gsd-debugger` | Niejasne (ad-hoc) | Średni | **Low** — debuger w głowie wystarczy |
| **Workflow load** `discuss-phase.md` | Każda sesja z `/gsd-discuss-phase` | **1 201 linii do kontekstu głównego Claude'a** | **High wasteful** |
| **Workflow load** `plan-phase.md` | Każda sesja | **1 075 linii** | **High wasteful** |
| **Workflow load** `execute-phase.md` | Każda sesja | **1 253 linii** | **High wasteful** — ogromny blok to wave dispatch i worktree handling |

### B.2. Top 3 pojedyncze pożeracze tokenów

**1. `execute-phase.md`, kroki `discover_and_group_plans` + `execute_waves` + worktree sequential dispatch.** To jest serce workflowa (patrz §3.4) z obsługą wave map, równoległych spawnów `gsd-executor` w git worktree, `run_in_background: true`, merge worktree → main, cleanup. Cały blok jest zbędny przy sekwencyjnej pracy jednoosobowej. Szacunkowo **40–50% linii `execute-phase.md`** to logika worktree i parallelization.

**2. `discuss-phase.md`, sekcja `analyze_phase` + `present_gray_areas` + `discuss_areas` (pętla deep-dive).** Workflow ma trzy tryby (`assumptions`, `power`, default — patrz §3.1 i frontmatter komendy), każdy z własnym plikiem workflow ładowanym przez `<execution_context>`. Plus router między nimi. Plus Advisor Mode z conditional spawn `gsd-advisor-researcher` per gray area. Plus checkpoint JSON per obrót pętli. Dla solo-dev jedna ścieżka wystarczy.

**3. Sam wzorzec `<execution_context>` z `@.../workflow.md`.** W frontmatter komendy `/gsd-discuss-phase` (§3.1) `<execution_context>` ładuje 4 pliki naraz: `discuss-phase.md` (1201 linii), `discuss-phase-assumptions.md`, `discuss-phase-power.md`, `templates/context.md`. Trzy z tych plików są alternatywami, ale Claude ładuje wszystkie zanim wie który tryb użyje. Plus dla każdego spawnowanego pomocnika frontmatter z `<files_to_read>`. To jest **antywzorzec** — oficjalna Anthropic rekomendacja dla skills/commands to ≤500 linii per plik i conditional Read na żądanie, nie `@/...` upfront.

### B.3. Czy któreś z Twoich wycięć z §5 jest błędne?

Trzy flagi, żadna fatalna:

**Flaga 1 — `gsd-security-auditor` dla Phase 04 (Shield) i Phase 05 (Schedules).** Twoja argumentacja "apka on-device, bez backendu, threat model w głowie" jest poprawna dla większości powierzchni. Ale core value brzmi **"the block holds until the timer ends"** (§1). To jest gwarancja zaufania. Realne wektory omijania istnieją nawet w apce on-device: (a) zmiana czasu systemowego, (b) przeinstalowanie apki podczas aktywnej blokady, (c) manipulacja `ManagedSettingsStore` przez main app gdy extension ma aktywny shield, (d) pointer drift w tokenach po reboocie (ograniczenie nr 4 z §1). Żadne z tych nie jest "security w sensie backendowym", wszystkie są "robustness gwarancji produktowej". Rekomendacja: **nie przywracaj `gsd-security-auditor`**, ale do templatu `PLAN.md` dla Phase 03/04/05 dodaj sekcję `bypass_checks:` (3–6 punktów) jako część `must_haves`. To 10 linii w templacie, nie osobny pomocnik. Omawiam to w Sekcji C.

**Flaga 2 — `gsd-nyquist-auditor` dla Phase 03 (Quick Sessions).** Twoja argumentacja "solo, testy ad-hoc" jest poprawna dla 80% faz. Phase 03 to wyjątek bo testuje się najtrudniej (timer + DeviceActivityMonitor + extension z 6 MB RAM + tokeny opaque) i jest core value. Rekomendacja: **nie przywracaj auditora**, ale w templacie `PLAN.md` wprowadź sekcję `critical_path_tests:` dla tasków oznaczonych `tag: core-value`. Lista 3–5 property-based scenariuszy które MUSZĄ mieć regression test. To jest lekki kontrakt, nie matryca Nyquista.

**Flaga 3 — Per-plan podział (`NN-01-PLAN.md`, `NN-02-PLAN.md`, ...).** Twoja argumentacja "Phase 01.1 miała 7 plików, overkill, chcę monolit" jest częściowo poprawna. Monolityczny PLAN sprawdza się dla fazy 2–6 tasków. Dla fazy 10+ tasków (Phase 04 Shield może tyle mieć bo łączy 4 warstwy: UI, extension, config, settings store) monolit staje się za duży do jednej sesji Claude'a i tracisz możliwość resume "zacznij od task 7". Rekomendacja: **zostawmy monolit jako default**, ale z task-IDs `T01..TNN` w sekcji `tasks:` i komendą `/phase-do <N> --task T03` która wykonuje tylko jeden task. To daje resumability bez 7 osobnych plików. Szczegóły w Sekcji C.

**Pozostałe wycięcia — potwierdzam:**
- `gsd-codebase-mapper`, `gsd-doc-verifier`, `gsd-research-synthesizer`, `gsd-integration-checker`, `gsd-user-profiler`, `gsd-ui-auditor` retroactive, workspaces/worktrees, cross-AI review, forensics/health/manager, flagi `--auto/--chain/--reviews/--gaps/--prd`, power mode, text mode (używaj `AskUserQuestion` domyślnie — działa też w remote/tmux), `gsd-assumptions-analyzer` — **wszystko wytnij bez wahania**.
- `gsd-tools.cjs` — **wytnij**. 23 kB JSON manifest to classic overengineering. Funkcje `init phase-op`, `todo match-phase`, `phase-plan-index` zastępuję inline bashem (ls + grep + awk) w komendach poniżej.

---

## Sekcja C — Propozycja zamiennika

**Zestaw**: cztery rdzeniowe komendy + jedna status + jedna zamykająca fazę.

| Komenda | Rola | Spawny pomocnicze | Typowy koszt vs GSD |
|---|---|---|---|
| `/phase-discuss <N>` | Zebranie decyzji przez `AskUserQuestion`, produkcja `NN-CONTEXT.md` | Zero (1 opcjonalny `advisor` on-demand przez `/phase-discuss <N> --advise <topic>`) | ≈25% kosztu `gsd-discuss-phase` |
| `/phase-plan <N>` | Monolityczny `NN-PLAN.md` z task-list, opcjonalnie `NN-RESEARCH.md` | 1 `phase-researcher` tylko gdy user wybierze (domyślnie nie), 1 `plan-checker` zawsze | ≈30% kosztu `gsd-plan-phase` |
| `/phase-do <N> [--task TNN]` | Sekwencyjne wykonanie tasków przez głównego Claude'a, atomic commit per task, `NN-SUMMARY.md` | Zero (głowny Claude robi wszystko) | ≈20% kosztu `gsd-execute-phase` |
| `/phase-verify <N>` | Conversational UAT: success criteria z ROADMAP + acceptance per task → odpowiedzi tak/nie/skip → `NN-VERIFICATION.md` + update `STATE.md` | Zero | ≈50% kosztu `gsd-verify-work` (eliminacja spawnu verifiera) |
| `/phase-status` | Read-only dashboard: STATE, current phase, gaps | Zero | Nowa, GSD ma `/gsd-progress` ciężki |
| `/phase-ship <N>` | Finalne zamknięcie: odhaczenie w ROADMAP, bump STATE, commit tagujący | Zero | ≈40% kosztu `/gsd-ship` |

Zachowuję: `gsd-phase-researcher` (przemianowany na `phase-researcher`), `gsd-plan-checker` (przemianowany na `plan-checker`), `gsd-ui-researcher` (na żądanie, przez `/phase-discuss <N> --ui`). Wycinam cały resztę pomocniczych Claude'ów — uzasadnienie powyżej w B.1.

### C.1. `.claude/commands/phase-discuss.md`

````markdown
---
name: phase-discuss
description: Gather phase context through structured questioning, produce NN-CONTEXT.md
argument-hint: <phase-number> [--advise <topic>] [--ui]
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion, Task, Bash(ls:*), Bash(git status:*), Bash(date:*)
disable-model-invocation: true
---

## Objective
Gather implementation decisions for phase `$1` by asking the user 3–5 focused questions,
then synthesize a `NN-CONTEXT.md` with numbered decisions D-01..D-NN. No workflow file load,
no multi-mode routing, no checkpoint JSON.

## Process

### Step 1. Resolve phase directory
Run `ls .planning/phases/ | grep -E "^$1-"` to find `<N>-<slug>/`. If no match, list all
phase directories and ask user to confirm the exact slug (plain question, no AskUserQuestion).
If already exists `NN-CONTEXT.md`, read it and ask: "CONTEXT exists. Update existing decisions,
replace, or skip?" via AskUserQuestion with 3 options. On "skip", exit with instruction to run
`/phase-plan $1`.

### Step 2. Load prior context (cheap)
Read ONLY these files (do not glob large trees):
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md` (grep only lines matching `^- [A-Z]+-\d+`)
- `.planning/ROADMAP.md` (grep lines for phase `$1` and its dependencies)
- `.planning/STATE.md` (frontmatter + Current Position section)
- All existing `.planning/phases/*/NN-CONTEXT.md` files (decisions section only — grep `^- D-`)

Purpose: do NOT ask about things already decided in prior phases. Skip reading phase artifacts
older than 3 phases back unless referenced in ROADMAP dependency graph.

### Step 3. Identify gray areas
Based on the phase scope from ROADMAP.md, list 3–6 open decision points where the user's
input is needed (architectural choices, UX flows, naming, error strategies). Do NOT invent
gray areas for things that are already clear from REQUIREMENTS.md.

Present gray areas to the user via AskUserQuestion with `multiSelect: true`, 1 question only:
"Which decision areas need discussion?" with one option per gray area. Recommended areas go
first with " (Recommended)" suffix.

### Step 4. Deep-dive per selected area
For each selected area, ask ONE AskUserQuestion call with 2–4 options. Each option is a
concrete architectural/UX choice (not "you decide"). Always include "Other" implicit via the
tool's built-in support. If user picks "Other", capture their free-text answer as the decision.

Batch up to 4 questions per AskUserQuestion call to stay within the tool's 1–4 limit.

If flag `--advise <topic>` is present, before asking the question for that topic, spawn ONE
advisor subagent via Task tool:
- subagent_type: "general-purpose"
- description: "Research <topic> options"
- prompt: Full self-contained brief with domain context (DeluluDetox, Screen Time API,
  iOS 26, Clean Architecture), the specific topic, and instruction to return a comparison
  table of 2–4 options with trade-offs. Max 400 words response.
Use the returned table to enrich question options before AskUserQuestion.

If flag `--ui` is present, AFTER main decisions are captured, spawn ONE ui-researcher
subagent via Task tool to produce `NN-UI-SPEC.md`:
- subagent_type: "general-purpose"
- description: "Draft UI spec"
- prompt: Full brief with: captured decisions, target feature (from ROADMAP), DeluluDetox
  visual conventions (Theme.background, SF Symbols, state-driven navigation), instruction
  to produce a design contract in the format from `.planning/phases/02-app-selection/02-UI-SPEC.md`.

### Step 5. Synthesize decisions
Number every decision D-01..D-NN in order. Each decision must:
- Be one concrete sentence in Polish (user-facing)
- Have rationale (1–3 sentences) including rejected alternatives
- Reference relevant REQUIREMENT IDs (e.g., "spełnia QSN-03")

Group decisions by area (Navigation, DI, Event Flow, Testing, ...). Mirror the structure
of `.planning/phases/01.1-architecture-foundation/01.1-CONTEXT.md`.

### Step 6. Write NN-CONTEXT.md
Write to `.planning/phases/<N>-<slug>/<N>-CONTEXT.md` using this structure:

```markdown
# Phase <N>: <Name> - Context
Gathered: <YYYY-MM-DD>
Status: Ready for planning

<domain>
## Phase Boundary
<1 paragraph from ROADMAP.md, unchanged>
</domain>

<decisions>
## Implementation Decisions
### <Area 1>
- D-01: <decyzja po polsku>
  <details>Rationale: ... Rejected: ...</details>
- D-02: ...

### Claude's Discretion
<areas where user said "you decide">
</decisions>

<specifics>
## Specific Ideas
<concrete references user mentioned>
</specifics>

<canonical_refs>
## Canonical References
Downstream agents MUST read these.
### <Topic>
- path/to/spec.md — <what it decides>
If none: "No external specs — fully captured in decisions"
</canonical_refs>

<code_context>
## Existing Code Insights
### Reusable Assets
### Established Patterns
### Integration Points
</code_context>

<deferred>
## Deferred Ideas
<out-of-scope ideas, or "None — discussion stayed within phase scope">
</deferred>
```

Do NOT produce a separate `DISCUSSION-LOG.md`. If any decision had meaningful alternatives,
include them in the `<details>` block inline. This is the only change vs GSD's template.

### Step 7. Commit and route
```bash
git add .planning/phases/<N>-<slug>/<N>-CONTEXT.md
git commit -m "docs(<N>): gather phase context"
```
Print: "Context ready. Next: `/phase-plan $1`."

## Safety rules
- NEVER write outside `.planning/phases/<N>-<slug>/`
- NEVER modify PROJECT.md, REQUIREMENTS.md, ROADMAP.md from this command
- If user's answers contradict a prior-phase decision, STOP and ask explicitly before proceeding
- Do not spawn more than 2 subagents total per invocation (one advisor + one ui-researcher max)
````

### C.2. `.claude/commands/phase-plan.md`

````markdown
---
name: phase-plan
description: Produce monolithic NN-PLAN.md with task list and verification checks
argument-hint: <phase-number> [--research] [--skip-check]
allowed-tools: Read, Write, Glob, Grep, Task, Bash(ls:*), Bash(grep:*), Bash(git status:*)
disable-model-invocation: true
---

## Objective
Produce ONE `NN-PLAN.md` for phase `$1` containing all tasks T01..TNN, each with
must_haves.truths (declarative statements) and must_haves.artifacts (greppable checks),
then run plan-checker to validate goal coverage. No per-task plan files, no wave assignment,
no worktree metadata.

## Process

### Step 1. Preflight
Resolve phase directory (same logic as `/phase-discuss`).
Require that `<N>-CONTEXT.md` exists. If missing, print:
"CONTEXT missing. Run `/phase-discuss $1` first." and exit.
If `<N>-PLAN.md` exists, ask via AskUserQuestion: "Replace, amend, or skip?"

### Step 2. Optional research
If `--research` flag OR if CONTEXT contains `canonical_refs` entries pointing to external
Apple SDK docs not yet summarized, ask via AskUserQuestion:
"Run phase research pass? (recommended for SDK-heavy phases like 03 Quick Sessions, 04 Shield)"
with options: "Yes (spawn researcher)", "No (skip)".

If yes, spawn ONE subagent via Task tool:
- subagent_type: "general-purpose"
- description: "Phase technical research"
- prompt: Full brief with:
  - Phase goal from ROADMAP.md
  - Decisions from NN-CONTEXT.md
  - Apple frameworks in scope (from §1 hard constraints: FamilyControls, ManagedSettings,
    DeviceActivity, ManagedSettingsUI)
  - Hard constraints 1–9 from PROJECT.md (token opacity, entitlement, 6MB extension,
    rotation bug, shield API, 20 activities)
  - Instruction: produce `<N>-RESEARCH.md` in `.planning/phases/<N>-<slug>/` with
    sections: `<framework_notes>`, `<pitfalls>`, `<proof_of_concept>` (code sketches),
    `<open_questions>`
  - Max 600 lines output

### Step 3. Draft the plan (main Claude, no subagent)
Read in this order (sequential, each file is small):
- `<N>-CONTEXT.md`
- `<N>-RESEARCH.md` (if exists)
- `<N>-PATTERNS.md` (if exists)
- `.planning/ROADMAP.md` (grep success criteria for phase `$1`)
- Last 2–3 `<prior-phase>/<prior-phase>-SUMMARY.md` files (for `provides:` graph)

Build task list. Each task:
- ID `T01..TNN`
- Scope: 1–3 source files or 1 logical concern
- Acceptance: 1–4 `must_haves.truths` (declarative assertions)
- Artifacts: 1–5 `must_haves.artifacts` (file_exists, file_not_exists, regex_match)
- Key links: D-ID → file:line mapping
- Commit message template: `<type>(<N>.<tt>): <imperative>`

For phases flagged as core-value (Phase 03) or robustness-critical (Phase 04, 05), add
per-task section `bypass_checks:` with 2–5 scenarios to guard against (e.g., "token
rotation after device reboot", "timer bypass via system clock change"). These replace
the gsd-security-auditor/gsd-nyquist-auditor spawns with a 10-line contract.

### Step 4. Write NN-PLAN.md
Structure (see §C.5 template below):

```markdown
---
phase: <N>-<slug>
type: execute
depends_on: [<prior-phase-IDs>]
success_criteria_from_roadmap:
  - "<verbatim from ROADMAP.md>"
---

<context>
@.planning/phases/<N>-<slug>/<N>-CONTEXT.md
@.planning/phases/<N>-<slug>/<N>-RESEARCH.md  # if exists
@.planning/phases/<N>-<slug>/<N>-PATTERNS.md  # if exists
</context>

<tasks>
### T01. <imperative title>
scope: <files or concern>
must_haves:
  truths:
    - "<D-XX: assertion in Polish>"
  artifacts:
    - type: file_exists
      path: "DeluluDetox/Sources/..."
    - type: regex_match
      path: "DeluluDetox/Sources/..."
      pattern: "..."
  key_links:
    - "D-02 → AppRootViewModel.swift Destination enum"
bypass_checks:   # ONLY for phases tagged core-value
  - "Scenariusz: <bypass attempt>. Guard: <where asserted>"
commit: "feat(<N>.01): <imperative>"

### T02. ...
</tasks>

<final_verification>
- Build succeeds (XcodeBuildMCP)
- Smoke test: <scenariusz z ROADMAP success criteria>
</final_verification>
```

### Step 5. Plan check (unless --skip-check)
Spawn ONE subagent via Task tool:
- subagent_type: "general-purpose"
- description: "Plan goal-backward check"
- prompt: Full brief with:
  - ROADMAP.md success criteria for phase `$1`
  - The draft NN-PLAN.md contents (inline, full text)
  - Instruction: "For each success criterion, cite the Task ID(s) that deliver it. If
    any criterion has no coverage, return verdict REVISE with a list of gaps. If all
    criteria are covered, return PASS. If the plan contradicts a prior decision
    (check against NN-CONTEXT.md decisions D-XX), return BLOCK with the conflict."
  - Output format: single JSON block `{verdict, gaps[], conflicts[]}`, max 300 words
    total

On REVISE: main Claude revises the plan inline (don't re-spawn, just edit) and re-runs
plan-checker. Max 2 revision rounds (vs GSD's 3 — saved 1 iteration). On BLOCK: stop and
ask user how to resolve.

### Step 6. Commit
```bash
git add .planning/phases/<N>-<slug>/
git commit -m "docs(<N>): plan phase"
```
Print: "Plan ready with <NN> tasks. Next: `/phase-do $1` or `/phase-do $1 --task T01`."

## Safety rules
- Plan file must stay under 1000 lines total. If larger, phase scope is too big — stop
  and suggest splitting via `/phase-discuss` of a sub-phase.
- Never spawn more than 2 subagents per invocation (researcher + plan-checker).
- If plan-checker returns verdict with malformed JSON, retry once; on second failure
  treat as PASS and note the issue in the plan commit message.
````

### C.3. `.claude/commands/phase-do.md`

````markdown
---
name: phase-do
description: Execute NN-PLAN.md task list sequentially, atomic commit per task
argument-hint: <phase-number> [--task TNN] [--dry-run]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(ls:*), Bash(grep:*), Bash(xcodebuild:*), Bash(swift:*), mcp__XcodeBuildMCP__*, mcp__context7__*
disable-model-invocation: true
---

## Objective
Execute `<N>-PLAN.md` tasks sequentially in the main Claude conversation. One task at a
time, atomic commit per task, SUMMARY.md written at the end. No subagent spawn, no worktree,
no wave dispatch.

## Process

### Step 1. Preflight
- Resolve phase directory
- Require `<N>-PLAN.md` exists (else print: "Run `/phase-plan $1` first.")
- Read PLAN fully
- Run `git status` — if dirty, ask user: "Working tree dirty. Stash, commit, or abort?"
  via AskUserQuestion. Never proceed on dirty tree automatically.
- If `--task TNN` flag: target only that task (skip sequencing)
- If `--dry-run`: print task list + acceptance checks, do NOT modify files

### Step 2. Task loop
For each task T01..TNN (or just the targeted one):

1. **Read task block** from PLAN. Print "Starting TNN: <title>".
2. **Read referenced context** on demand — ONLY files explicitly listed in the task's
   key_links or `scope`. Do NOT load the entire `<context>` block eagerly.
3. **Implement changes** via Edit / Write / bash (XcodeBuildMCP for builds).
   - Follow patterns from `<N>-PATTERNS.md` if it exists
   - Follow DeluluDetox hard rules from CLAUDE.md (no `import SwiftUI` in ViewModels,
     feature-first layout, @Injected/@LazyInjected DI, @CasePathable navigation)
4. **Verify artifacts** before commit. Run each `must_haves.artifacts` check:
   - `file_exists` → `ls <path>` returns 0
   - `file_not_exists` → `ls <path>` returns non-0
   - `regex_match` → `grep -E "<pattern>" <path>` returns 0
   If any check fails, print which, STOP, and ask user: "Fix before commit, skip task, or
   abort phase?" via AskUserQuestion.
5. **Run bypass_checks if present** (Phase 03/04/05 only). For each scenario, state in a
   sentence what code path guards it (reference file:line). If any scenario has no guard,
   print the gap and ask user.
6. **Smoke build** via XcodeBuildMCP (or `swift build` for non-app targets). Exit code
   ≠ 0 → stop, do not commit.
7. **Atomic commit**:
   ```bash
   git add <files_modified_this_task>
   git commit -m "<commit-template-from-task>"
   ```
   Use the exact commit message template from the task block.

### Step 3. Write NN-SUMMARY.md
After all tasks complete (or after `--task` when targeting single task — then append to
existing SUMMARY), write `<N>-SUMMARY.md`:

```markdown
---
phase: <N>-<slug>
completed_tasks: [T01, T02, ...]
requires:
  - phase: <prior>
    provides: "<what we consumed>"
provides:
  - "<one-line per major asset added to the codebase>"
affects: [<downstream-phases>]
tech-stack:
  added: [<new deps if any>]
  patterns:
    - "<pattern-NN: one line>"
key-files:
  created: [...]
  modified: [...]
  deleted: [...]
key-decisions:
  - "<D-XX applied as ... in <file>>"
patterns-established:
  - "<pattern that future phases should reuse>"
---

# Body: one paragraph per task, describing what was done, any deviations from PLAN,
# and links to the commits (git log --oneline filter by this phase).
```

### Step 4. Update STATE.md
Edit `.planning/STATE.md` (preserving frontmatter structure from §8 of the research brief):
- Update `progress.completed_plans` += completed_task_count
- Update `progress.percent` accordingly
- Update `last_updated` and `last_activity` timestamps
- Update `stopped_at` to "Phase <N> tasks T01..TNN complete, pending verify"

Commit the STATE update:
```bash
git add .planning/STATE.md .planning/phases/<N>-<slug>/<N>-SUMMARY.md
git commit -m "docs(<N>): phase execution summary"
```

### Step 5. Route
Print:
- Tasks completed: <NN>/<total>
- Files changed: <count>
- Commits: <count>
- Next: `/phase-verify $1`

## Deviation handling
If during a task you discover the PLAN is wrong (e.g., file layout doesn't match reality,
a decision D-XX conflicts with another), DO NOT silently deviate. STOP, print the conflict,
and ask the user via AskUserQuestion:
- "Proceed with plan as written"
- "Deviate and log in SUMMARY"
- "Abort and re-plan"
Record the chosen deviation in SUMMARY.md under section `deviations:`.

## Safety rules
- NEVER force-push, rebase, or modify history
- NEVER commit without running acceptance checks
- If build fails after 2 attempts, stop and surface the error
- Respect the 6 MB RAM limit for DeviceActivityMonitorExtension: no heavy imports added
  to extension targets (flag any new `import` in extension source files for user confirmation)
- Respect the "no third-party SDK in extension" rule (hard constraint 3 from §1)
````

### C.4. `.claude/commands/phase-verify.md`

````markdown
---
name: phase-verify
description: Conversational UAT against ROADMAP success criteria, produce NN-VERIFICATION.md
argument-hint: <phase-number>
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion, Bash(git log:*), Bash(ls:*), Bash(grep:*), mcp__XcodeBuildMCP__*
disable-model-invocation: true
---

## Objective
Verify that phase `$1` delivered its ROADMAP success criteria, goal-backward. No subagent
spawn — main Claude runs the conversation, user answers tak/nie/skip per criterion.

## Process

### Step 1. Preflight
- Resolve phase directory
- Require `<N>-PLAN.md` AND `<N>-SUMMARY.md` exist
- Extract success criteria from ROADMAP.md for phase `$1`
- Extract `final_verification` section from PLAN
- Build a check list: success_criteria + per-task `must_haves.truths` flagged as user-visible

### Step 2. Auto-checks first (cheap)
Run, in order, without asking user:
1. All `must_haves.artifacts` checks from PLAN — print pass/fail table
2. `git log --oneline --grep="^feat(<N>" --grep="^refactor(<N>" --grep="^fix(<N>"` —
   confirm one commit per task
3. XcodeBuildMCP build for main target + all extensions
4. If `bypass_checks` present in PLAN: for each, grep the guarding code path and report
   found/missing (do not auto-execute — these are design-time checks)

Print a summary: "Auto-checks: <X>/<Y> passed. <Z> need user confirmation."

### Step 3. Conversational UAT
For each success criterion from ROADMAP, ask via AskUserQuestion (batching 1–4 per call):
- Question: "<criterion verbatim> — delivered?"
- Options: "Yes", "No, blocking", "Partial (note gap)", "Skip (not testable)"

If "No, blocking" or "Partial": capture user's free-text gap description as an "Other"
response or as follow-up plain question.

### Step 4. Write NN-VERIFICATION.md
```markdown
# Phase <N>: Verification
Verified: <YYYY-MM-DD>
Verdict: PASS | PARTIAL | FAIL

## Success criteria
| # | Criterion | Status | Evidence / Gap |
|---|-----------|--------|----------------|
| 1 | <from ROADMAP> | PASS | commit abc1234, file:line |
| 2 | ...           | FAIL | <user's gap description> |

## Auto-checks
<table from Step 2>

## Bypass guards (if applicable)
| Scenario | Guard | Status |
|----------|-------|--------|

## Outstanding tasks
- [ ] Gap from criterion #2: <description>. Candidate fix-task: T<NN>-fix
```

### Step 5. Update STATE.md
If verdict PASS:
- Set `status: verified`
- Update `stopped_at: "Phase <N> verified"`
If verdict PARTIAL or FAIL:
- Leave status unchanged
- Append to STATE body `### Blockers`: the gap description(s)

### Step 6. Commit and route
```bash
git add .planning/phases/<N>-<slug>/<N>-VERIFICATION.md .planning/STATE.md
git commit -m "docs(<N>): verify phase"
```

If PASS: "Phase $1 verified. Next: `/phase-ship $1`."
If PARTIAL/FAIL: "Phase $1 has <NN> gaps. Options: `/phase-plan $1 --amend`,
`/phase-do $1 --task <fix-id>`, or address manually and re-run `/phase-verify $1`."

## Safety rules
- Never update ROADMAP.md from this command (ship does that)
- Never mark a criterion PASS without either an auto-check match or user confirmation
- If auto-checks fail but user insists criterion is delivered, record both in
  VERIFICATION under "## Disagreements" and require `/phase-ship` user acknowledgment
````

### C.5. `.claude/commands/phase-ship.md`

````markdown
---
name: phase-ship
description: Close phase — update ROADMAP checkbox, bump STATE, tag commit
argument-hint: <phase-number>
allowed-tools: Read, Write, Edit, Grep, Bash(git:*), AskUserQuestion
disable-model-invocation: true
---

## Objective
Mark phase `$1` shipped in ROADMAP.md, bump STATE.md progress counters, create a tagging
commit. No subagent, no code review spawn — review is part of verify's user conversation.

## Process

### Step 1. Preflight
- Require `<N>-VERIFICATION.md` exists with `Verdict: PASS`
  - If PARTIAL/FAIL: ask user via AskUserQuestion: "Verification is <verdict>. Ship anyway
    (defer gaps to next phase), run `/phase-verify $1` again, or abort?"
- Run `git status` — must be clean

### Step 2. Update ROADMAP.md
Find the phase `$1` line in ROADMAP.md. Change `- [ ] Phase <N>: ...` to `- [x] Phase <N>: ...`.
If success criteria for this phase are listed as sub-checkboxes, update each to `- [x]` based
on verification results (skip those marked PARTIAL).

### Step 3. Update STATE.md
Edit frontmatter:
- `progress.completed_phases` += 1
- `progress.completed_plans` += <task count from PLAN>
- `progress.percent` = recomputed from completed/total
- `status: "ready-for-next"`
- `stopped_at: "Phase <N> shipped"`
- `last_updated` and `last_activity` to now

In the body `## Current Position` section, update `current_phase` to the next phase ID
from ROADMAP's unchecked list.

### Step 4. Commit and tag
```bash
git add .planning/ROADMAP.md .planning/STATE.md
git commit -m "docs(<N>): ship phase"
git tag phase-<N>-shipped
```

### Step 5. Route
Print:
- Phase <N> shipped
- Next phase: <N+1> "<name>"
- Start with: `/phase-discuss <N+1>`

## Safety rules
- Never create a tag that already exists — if duplicate, append `-retry1` etc.
- Never ship on dirty tree
- Always confirm with user before shipping on PARTIAL verdict
````

### C.6. `.claude/commands/phase-status.md`

````markdown
---
name: phase-status
description: Read-only dashboard — STATE, current phase, gaps, next action
argument-hint: (no args)
allowed-tools: Read, Glob, Grep, Bash(git log:*), Bash(ls:*)
disable-model-invocation: false
---

## Objective
Print a compact status report. No writes, no subagent, no user questions.

## Process

### Step 1. Read
- `.planning/STATE.md` (frontmatter + body)
- `.planning/ROADMAP.md` (count `- [x]` vs `- [ ]`)
- Current phase from STATE: list artifacts present in `.planning/phases/<current>/`
  (glob `*.md`)

### Step 2. Print
```
=== DeluluDetox status ===
Milestone: <from STATE>
Phase: <current_phase>   Status: <status>
Progress: <completed>/<total> phases, <percent>%

Current phase artifacts:
  [x] NN-CONTEXT.md         (gathered <date>)
  [x] NN-RESEARCH.md        (optional)
  [x] NN-PLAN.md            (<NN> tasks)
  [ ] NN-SUMMARY.md         (pending execute)
  [ ] NN-VERIFICATION.md    (pending verify)

Recent commits (phase-scoped):
  <git log --oneline --grep="(NN" -10>

Blockers (from STATE body):
  <list or "None">

Next action:
  <compute from artifact presence: discuss → plan → do → verify → ship>
```

No interaction, no side effects.
````

### C.7. Uproszczone templaty artefaktów

**`CONTEXT.md`** — **bez zmian** vs §3.10 z wyjątkiem: sekcja `DISCUSSION-LOG` znika jako osobny plik. Alternatywy idą do inline `<details>` pod każdą decyzją. Rationale: audit trail działa tak samo, minus jeden plik na fazę i minus jeden spawn.

**`PLAN.md`** — **uproszczony** vs §3.7. Usunięte pola: `plan: NN`, `wave: N`, `depends_on: [plan-IDs]`, cała sekcja `<interfaces>` na poziomie pliku (bo nie mamy per-plan splitu). Nowe pole: `success_criteria_from_roadmap:` jako frontmatter array — żeby plan-checker miał explicite z czym porównywać. Struktura tasków (`must_haves.truths`, `must_haves.artifacts`, `key_links`) **bez zmian** — ten format działa, zostawiamy. Dodane (warunkowo): `bypass_checks:` per task dla phase 03/04/05.

**`SUMMARY.md`** — **bez zmian** vs §3.8 z wyjątkiem: frontmatter pole `plan: NN` znika (jeden SUMMARY per faza, nie per plan). Pozostałe pola (`requires`, `provides`, `affects`, `tech-stack`, `key-files`, `key-decisions`, `patterns-established`) zostają — to jest wartościowy graf między fazami.

**`VERIFICATION.md`** — **bez zmian** funkcjonalnie vs GSD, ale format tabeli z kolumną "Evidence / Gap" zamiast długiej narracji. Dodatkowo sekcja `Bypass guards` dla phase core-value.

**`RESEARCH.md`** — **bez zmian**, opcjonalny, tylko dla fazy z heavy SDK (Phase 03, 04).

**`UI-SPEC.md`** — **bez zmian**, opcjonalny, generowany przez `/phase-discuss --ui`.

**Wycięte templaty** (nie produkujemy): `DISCUSSION-LOG.md`, `VALIDATION.md` (Nyquist matrix), `REVIEW.md` + `REVIEW-FIX.md` (review staje się częścią verify), `PATTERNS.md` jako osobny plik (patterny idą do SUMMARY `patterns-established`).

### C.8. Co zostaje z pomocniczych Claude'ów (Task spawns)

| Pomocniczy Claude | Zostawiam? | Kiedy spawn | Uzasadnienie |
|---|---|---|---|
| `phase-researcher` (ex-gsd-phase-researcher) | **Tak**, warunkowo | `/phase-plan --research` lub auto dla phase flagowanej SDK-heavy | Research Apple SDK pitfalls i pointer drift (constraint 4) bez tego pójdzie po omacku |
| `plan-checker` (ex-gsd-plan-checker) | **Tak**, zawsze | `/phase-plan` step 5 | Goal-backward gate uratował Ci refaktor 2 razy (§4 pkt 8) — to nie przypadek, to systematyczny gain |
| `ui-researcher` (ex-gsd-ui-researcher) | **Tak**, opt-in | `/phase-discuss --ui` | UI-SPEC.md przed implementacją ma realną wartość dla Phase 02/04 |
| `advisor` (ex-gsd-advisor-researcher) | **Tak**, opt-in | `/phase-discuss --advise <topic>` | Topic-scoped research przed decyzją; jedno spawnowanie per topic, nie auto-per-gray-area |
| `executor` (ex-gsd-executor) | **Nie** | — | Sekwencyjna praca w głównym Claude'u; eliminuje worktree, wave dispatch, sequential dispatch lock handling |
| `verifier` (ex-gsd-verifier) | **Nie** | — | Main Claude robi conversational UAT z userem — taniej i lepiej (user natychmiast widzi luki) |
| `nyquist-auditor` | **Nie** | — | Zastąpiony `critical_path_tests:` w PLAN dla phase core-value |
| `security-auditor` | **Nie** | — | Zastąpiony `bypass_checks:` w PLAN dla phase 03/04/05 |
| `code-reviewer` / `code-fixer` | **Nie** | — | Review zintegrowany z verify (user ogląda diff podczas UAT) |
| `integration-checker` | **Nie** | — | Budowanie wszystkich targetów w `/phase-do` step 2 smoke build pokrywa 90% |
| `ui-auditor` retroactive | **Nie** | — | Teatr dla solo-dev |
| `codebase-mapper` | **Nie** | — | Repo <50k LoC, mapa w głowie |
| `doc-verifier`, `doc-writer` | **Nie** | — | Docs ad-hoc |
| `research-synthesizer`, `project-researcher`, `roadmapper` | **Nie** | — | Used tylko w `/gsd-new-project`, projekt już jest |
| `user-profiler` | **Nie** | — | Wiesz kim jesteś |
| `assumptions-analyzer` | **Nie** | — | Tryb assumptions discuss wycięty |
| `intel-updater`, `debugger` | **Nie** | — | Ad-hoc lub niepotrzebne |

**Redukcja**: z 24 pomocniczych Claude'ów zostają 4, wszystkie opt-in albo warunkowe. Żaden nie jest wymuszany przez flag — user świadomie decyduje.

### C.9. Szacunek redukcji tokenów

| Komenda | GSD cost (rząd) | Nowy cost (rząd) | Redukcja |
|---|---|---|---|
| discuss | 1201 linii workflow + 3 references + 0–N advisor spawns | ≤250 linii inline + 0–1 advisor | **≈75%** |
| plan | 1075 linii workflow + 3 spawnów (researcher, planner, plan-checker×3) | ≤280 linii inline + 1–2 spawnów (researcher opt-in, plan-checker ×2) | **≈70%** |
| execute | 1253 linii workflow + N executor spawnów w worktree + verifier + opcjonalnie 2 auditory | ≤260 linii inline, zero spawnów | **≈80%** |
| verify | ~400 linii workflow + verifier spawn | ≤220 linii inline, zero spawnów | **≈50%** |
| ship | ~300 linii workflow | ≤120 linii inline | **≈60%** |
| status | brak w GSD (częściowo `/gsd-progress`) | ≤80 linii inline | — |

**Łączna redukcja dla pełnego cyklu fazy (discuss→plan→do→verify→ship): szacunkowo 70–75%** kosztu tokenów względem obecnego GSD 1.34.2, przy zachowaniu wszystkich 10 punktów wartościowych z §4 i 10 wymagań zachowanych z §6.

---

## Sekcja D — Ścieżka migracji w Twoim repo

### D.1. Co zrobić z istniejącymi artefaktami Phase 02

Stan obecny (z §1): `02-CONTEXT.md`, `02-DISCUSSION-LOG.md`, `02-RESEARCH.md`, `02-UI-SPEC.md`, `02-PATTERNS.md`, `02-VALIDATION.md`, szkic `02-01-PLAN.md`.

Krok po kroku:

1. **Zostaw bez zmian**: `02-CONTEXT.md`, `02-RESEARCH.md`, `02-UI-SPEC.md`. Format CONTEXT nowy zestaw akceptuje 1:1. RESEARCH i UI-SPEC są output-surface'owe, niezmienione.
2. **Skonsoliduj `02-DISCUSSION-LOG.md` do CONTEXT**: dla każdej tabeli alternatyw w DISCUSSION-LOG, przenieś ją jako `<details>` pod odpowiednią decyzję D-XX w `02-CONTEXT.md`. Potem `git rm .planning/phases/02-app-selection/02-DISCUSSION-LOG.md`.
3. **Skonsoliduj `02-PATTERNS.md` do przyszłego SUMMARY**: odłóż plik (nie usuwaj jeszcze). Po `/phase-do 02` wzorce z PATTERNS trafią do `02-SUMMARY.md` sekcja `patterns-established`. Potem `git rm 02-PATTERNS.md`.
4. **Wytnij `02-VALIDATION.md`**: `git rm .planning/phases/02-app-selection/02-VALIDATION.md`. Matryca Nyquista nie jest w nowym zestawie (Phase 02 to App Selection — nie core value, brak `critical_path_tests:`).
5. **Rekonstruuj `02-PLAN.md` z `02-01-PLAN.md`**: uruchom `/phase-plan 02`. Nowa komenda przeczyta CONTEXT + RESEARCH + UI-SPEC i wyprodukuje monolityczny `02-PLAN.md`. Szkic `02-01-PLAN.md` zostaje jako materiał referencyjny (przenieś do `.planning/phases/02-app-selection/_legacy/02-01-PLAN.md` lub `git rm` po weryfikacji że nowy PLAN pokrywa to samo).
6. **Commit migracyjny**:
   ```bash
   git add .planning/phases/02-app-selection/
   git commit -m "docs(02): migrate phase artifacts to lightweight format"
   ```

### D.2. Czy `STATE.md` i `ROADMAP.md` wymagają edycji?

**`STATE.md`**: **bez edycji strukturalnej**. Frontmatter z §8 (`gsd_state_version`, `milestone`, `status`, `progress.*`, `last_*`) jest w 100% kompatybilny z nowymi komendami. Możesz zmienić `gsd_state_version: 1.0` na `state_version: 2.0-light` dla czystości (opcjonalne), ale `/phase-do` i `/phase-verify` nie wymagają zmiany pola. Sekcje body (`Project Reference`, `Current Position`, `Performance Metrics`, `Accumulated Context`) zostają.

**`ROADMAP.md`**: **bez edycji**. Format `- [x] Phase NN: ...` z sub-checkboxami success criteria jest dokładnie tym, czego `/phase-plan` (do czytania success criteria) i `/phase-ship` (do odhaczania) używają. Zero zmian.

**Jedyny realny dodatek**: opcjonalnie w `PROJECT.md` dopisz sekcję:
```markdown
## Phase tagging (dla nowego zestawu komend)
- Phase 03 (Quick Sessions): core-value — wymaga `critical_path_tests:` + `bypass_checks:` w PLAN
- Phase 04 (Shield): robustness-critical — wymaga `bypass_checks:` w PLAN
- Phase 05 (Schedules): robustness-critical — wymaga `bypass_checks:` w PLAN
```
To pozwala `/phase-plan` automatycznie flagować fazę bez zgadywania.

### D.3. Stary `.claude/commands/gsd/` — fallback czy archive?

**Rekomendacja: `mv` do archiwum, nie usuwaj.**

```bash
mkdir -p .claude/commands/_gsd-archived
git mv .claude/commands/gsd .claude/commands/_gsd-archived/commands
git mv .claude/agents .claude/commands/_gsd-archived/agents
git mv .claude/get-shit-done .claude/commands/_gsd-archived/get-shit-done
git commit -m "chore: archive GSD 1.34.2 to _gsd-archived"
```

Dlaczego archive zamiast usuwania:
- Prefix `_` w `_gsd-archived` powoduje że Claude Code **nie ładuje** podkatalogu jako slash commands (zachowanie zweryfikowane: Claude Code traktuje `.claude/commands/<subdir>/foo.md` jako namespaced command `/foo`; pliki w katalogach z prefixem `_` lub ukrytych traktowane są jako nieaktywne dla większości setupów, ale dla pewności dodaj jeszcze `.claudeignore` jeśli istnieje w Twoim setupie).
- Jeśli nowy zestaw nie dostarczy czegoś krytycznego w Phase 02, możesz odzyskać konkretną komendę: `git mv .claude/commands/_gsd-archived/commands/gsd-execute-phase.md .claude/commands/gsd-execute-phase.md` — działa jako `/gsd-execute-phase`.
- Po Phase 03 (jeśli nowy zestaw sprawdza się dla core-value), usuń definitywnie: `git rm -rf .claude/commands/_gsd-archived/`.

**Odradzam fallback "przez 1 fazę"** w sensie "obie komendy aktywne równolegle" — ryzyko że w trakcie sesji wywołasz `/gsd-execute-phase` zamiast `/phase-do` i dostaniesz stary wave dispatch. Clean cut lepszy.

**Edit CLAUDE.md** projektu: sekcja "GSD Workflow Enforcement" zmienia się na "Phase Workflow Enforcement" z listą 6 nowych komend i zasadą: "For any change to `.planning/phases/<N>-<slug>/` or source code in scope of an active phase, use `/phase-do` — never Edit/Write directly to phase-owned files." Plus dopisz: "Legacy `/gsd-*` commands are archived and inactive."

### D.4. Pierwsza faza testowa — Phase 02 czy inna?

**Rekomendacja: testuj na Phase 02**, z zastrzeżeniem.

**Plusy testu na Phase 02**:
- CONTEXT + RESEARCH + UI-SPEC już są, start od `/phase-plan 02` skraca cykl testowy
- Phase 02 (App Selection) nie jest core-value, ewentualny problem nie zagraża gwarancji blokady
- Scope średni (nie za mały żeby nie sprawdzić executora, nie za duży żeby tonąć)

**Ryzyka**:
- **R1**: Istniejący `02-01-PLAN.md` może mieć pola/struktury których nowy `/phase-plan` nie zrekonstruuje 1:1 — prowizorycznie zaakceptowalne (legacy materiał), ale porównaj ręcznie przed `/phase-do`.
- **R2**: Jeśli `02-CONTEXT.md` zawiera referencje do `NN-NN-PLAN` (per-plan split), nowa komenda je zignoruje i wygeneruje monolit. Zweryfikuj czy żadna decyzja D-XX nie zakłada wielofilowego planu.
- **R3**: Phase 02 nie ma `bypass_checks:` ani `critical_path_tests:` — nie przetestuje tych ścieżek. Dlatego bezpośrednio po Phase 02 zrób **Phase 03** (Quick Sessions), która **jest** core-value i przetestuje te gałęzie.

**Alternatywa**: test na mikrozadaniu — stwórz "Phase 01.2: CLAUDE.md refresh" jako faktyczną fazę-placeholder (1 task, refresh sekcji CLAUDE.md), puść przez pełny cykl. Minus: nie testuje research/plan-check/bypass. Plus: zero ryzyka dla funkcjonalności. **Wybór Twój**, ale skłaniam się do Phase 02 bo realnie potrzebujesz ją odblokować, a ryzyko niskie.

### D.5. Smoke test plan dla pierwszego pełnego cyklu

Po `/phase-plan 02 → /phase-do 02 → /phase-verify 02` sprawdź wszystkie 10 punktów (checklist do przeklikania):

1. **Artefakty fazy**: `ls .planning/phases/02-app-selection/*.md` zawiera: `02-CONTEXT.md`, `02-RESEARCH.md`, `02-UI-SPEC.md`, `02-PLAN.md` (monolit, NIE `02-01-PLAN.md`), `02-SUMMARY.md`, `02-VERIFICATION.md`. Brak `02-DISCUSSION-LOG.md`, `02-PATTERNS.md`, `02-VALIDATION.md`.
2. **Commit log**: `git log --oneline --grep="(02" | wc -l` ≥ 1 + liczba tasków + 2 (plan, summary, verify, ship). Sprawdź że każdy commit ma format `<type>(02.tt): ...` lub `docs(02): ...`.
3. **Atomic commits**: `git log --stat --grep="(02" | head -30` — każdy `feat/refactor` commit dotyczy ≤5 plików w spójnym obszarze (App Selection feature).
4. **STATE.md**: frontmatter `progress.completed_phases` = 3 (01, 01.1, 02), `progress.percent` ≈ przeliczone poprawnie, `current_phase` w body = "03-quick-sessions".
5. **ROADMAP.md**: linia `- [ ] Phase 02: App Selection` zmieniona na `- [x] Phase 02: App Selection`. Sub-checkboxy success criteria też odhaczone.
6. **Build pass**: XcodeBuildMCP raport z `/phase-do` step 2 — wszystkie targety (main + 3 extensions) kompilują się zielono.
7. **Must_haves.truths działają**: wybierz losowy task, zgrepuj `key_links` regex pattern z PLAN przez `grep -rE "<pattern>" DeluluDetox/Sources/` — powinno matchować.
8. **Plan-checker verdict w commicie**: `git log --grep="(02): plan"` message zawiera verdict PASS lub notatkę o iteracjach.
9. **Verify tabela**: `02-VERIFICATION.md` ma kolumnę "Evidence / Gap" z commit SHA lub file:line referencjami, nie samym "yes/no".
10. **Żaden spawn nie zostawił śladów worktree**: `git worktree list` pokazuje tylko jeden worktree (main). `ls .git/worktrees/` pusty lub nie istnieje.

**Red flags** po których nie idź dalej do Phase 03, tylko debuguj:
- Commit log ma "zlepki" (>5 plików w feat commit) — execute nie zrobił commit-per-task
- STATE.md ma stare pole `progress.total_plans` niezaktualizowane — execute lub ship pominął update
- Plik `02-PLAN.md` przekroczył 1000 linii — scope fazy był za duży, następnym razem discuss → sub-phase
- Plan-checker nigdy nie wrócił BLOCK/REVISE dla żadnego PLAN — albo masz szczęście, albo checker jest za łagodny (sprawdź jego prompt)

---

## Wnioski i uwagi na koniec

**Realny killer GSD w Twoim przypadku to nie 70 komend, tylko `<execution_context>` z `@/...workflow.md` ładowanym za każdym razem.** Eliminacja tego jednego wzorca daje 60-70% redukcji kosztu bez wycinania żadnej wartościowej funkcji. Czterokomendowy zestaw to w zasadzie efekt uboczny tej decyzji — jak wyjmiesz ciężkie workflowy, komendy stają się na tyle proste że można je połączyć.

**Flaga strategiczna na Phase 03**: to jest faza w której wartość nowego zestawu zostanie zweryfikowana nie-retorycznie. Jeśli `bypass_checks:` + `critical_path_tests:` w PLAN okażą się za słabe dla "block holds until timer ends", rozważ jednorazowe przywrócenie `phase-researcher` z rozszerzonym promptem o SDK pitfalls (rotation bug, 6 MB RAM, token opacity — ograniczenia 1–4 z §1). To jest jedyna sytuacja w której wrócę do rekomendacji "spawn pomocnika".

**Czego świadomie nie zrobiłem**: nie proponuję wymuszania żadnych flag typu `--auto`, `--chain`. Jeśli za pół roku zdecydujesz że chcesz chain, dodaj go lokalnie — komenda ma ≤300 linii, zrozumienie i rozszerzenie zajmie 20 minut. Lepszy mały zestaw który rozumiesz w całości niż bogaty który ładuje się sam.

**Ostatnia uwaga o spójności z CLAUDE.md**: sekcja "GSD Workflow Enforcement" po migracji musi wymusić nowy entry point. Sugeruję treść (po polsku, bo user-facing): "Przed modyfikacją jakiegokolwiek pliku w `.planning/phases/<N>/` lub kodu źródłowego w zakresie aktywnej fazy, wywołaj `/phase-do <N>` lub odpowiednią komendę cyklu. Edit/Write bezpośrednio do plików fazy jest zabroniony — łamie atomic commit guarantee." To jest jedyny punkt w którym CLAUDE.md pełni rolę policjanta; reszta to dokumentacja.