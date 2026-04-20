# Research: zrozumieć GSD i zaprojektować lekki, własny zamiennik

> **Dla researchera:** Ten prompt jest **self-contained**. Nie masz dostępu do mojego repo. Wszystkie istotne fragmenty kodu, workflowów GSD, artefaktów i kontekstu projektu są wklejone poniżej w blokach. Nie zgaduj — wszystkie kotwice masz w tym dokumencie.
>
> **Język odpowiedzi:** polski, ludzki (bez żargonu typu "subagent", "orchestrator" — tłumacz na "główny Claude / pomocniczy Claude / komenda nadrzędna"). Tabele i listy zamiast wodolejstwa. Bez emoji.
>
> **Format wyniku:** jeden duży dokument markdown — sekcje dokładnie według punktu **§7 OUTPUT** na końcu tego promptu. Pliki komend wpisz w pełni inline (gotowe do skopiowania).

---

## §1. Kim jestem i nad czym pracuję

Jestem solo-developerem iOS-owym. Buduję apkę **DeluluDetox** — natywny iOS-owy klon Opala (self-control, blokowanie aplikacji przez Apple Screen Time API). Wszystko on-device, bez backendu, bez Family Sharing.

**Stack (zamknięty):**
- Swift 6.2, SwiftUI, iOS 26.0+, Xcode 26+
- Frameworki Apple: `FamilyControls`, `ManagedSettings`, `DeviceActivity`, `ManagedSettingsUI`
- Architektura: Clean Architecture (MVVM + UseCase + Repository), `@Observable` ViewModels (bez `import SwiftUI`), nawigacja state-driven przez `pointfreeco/swift-navigation` (`@CasePathable` Destination enum)
- DI: własny `DIContainer` z scope'ami `.application` / `.unique` + property wrappery `@Injected` / `@LazyInjected`, distributed registration per-feature (`<Feature>Injection.register(in:)`)
- Layout repo: **feature-first** (`Features/<Feature>/{Repository,UseCase,ViewModel,View,Injection,Common}/`) — brak globalnego `FeatureCommons/`
- XcodeGen (`project.yml` → `.xcodeproj`), XcodeBuildMCP do buildów (NIE raw `xcodebuild`)
- Multi-target: main app + 3 extensiony (`DeviceActivityMonitorExtension`, `ShieldConfigurationExtension`, `ShieldActionExtension`), wspólne `group.com.kksw.DeluluDetox`

**Twarde ograniczenia produktowe (z researchu Apple SDK):**
1. Tokeny `ApplicationToken` / `WebDomainToken` są **opaque** — Apple nie udostępnia nazw/ikon, wyświetlanie tylko przez `Label(token)`.
2. Entitlement `com.apple.developer.family-controls` wymaga zatwierdzenia per bundle ID (mediana 2–3 tyg.).
3. `DeviceActivityMonitorExtension` ma **6 MB RAM**, zero third-party SDK.
4. Bug rotacji tokenów (iOS 17.5 – 26.3.1) — rekordy keyed po własnym UUID, token jako best-effort pointer.
5. Shield API zamrożone od 2022, 8-field struct, brak SwiftUI/network/TextField w shield extension.
6. Max 20 activities w sumie dla `DeviceActivityMonitor`.

**Core value (jedno zdanie):** *User can block chosen apps immediately and the block holds until the timer ends.* Każda decyzja architektoniczna idzie przez ten filtr — jeśli coś może osłabić blokadę, to na nie.

**Stan projektu:**
- Ukończone: Phase 01 (Foundation & Onboarding), Phase 01.1 (INSERTED — Architecture/DI migration)
- Do zrobienia: Phase 02 (App Selection — kontekst zebrany), Phase 03 (Quick Sessions — to jest core value), Phase 04 (Shield), Phase 05 (Schedules), Phase 06 (Engagement)
- Phase 02 ma już `02-CONTEXT.md`, `02-DISCUSSION-LOG.md`, `02-RESEARCH.md`, `02-UI-SPEC.md`, `02-PATTERNS.md`, `02-VALIDATION.md` ale plany jeszcze nie odpalone (jest `02-01-PLAN.md` szkic).

---

## §2. Czym jest GSD i dlaczego mnie kłuje

**GSD = "Get Shit Done"** — framework slash-komend i pomocniczych Claude'ów do prowadzenia projektu fazami. Wersja w moim repo: **1.34.2**.

**Topologia w repo:**
```
.claude/
├── commands/gsd/        # ~70 plików .md — cienkie wrappery, definicja komendy /gsd-*
├── agents/              # 24 wyspecjalizowanych pomocniczych Claude'ów (gsd-*.md)
├── get-shit-done/
│   ├── workflows/       # PEŁNE workflowy — KAŻDY 500–1250 linii
│   ├── templates/       # ~30 szablonów artefaktów (CONTEXT, PLAN, SUMMARY, RESEARCH, ...)
│   ├── references/      # anti-patterns, gate prompts, domain probes (cytowane przez workflowy)
│   ├── contexts/        # config dev/research/review
│   └── bin/gsd-tools.cjs # node CLI do init/state/config/commit operations
└── settings.json
.planning/
├── PROJECT.md           # wizja, ograniczenia, decyzje
├── REQUIREMENTS.md      # ID-aki ONB-01, SEL-01, QSN-01...
├── ROADMAP.md           # fazy, success criteria, dependency graph
├── STATE.md             # frontmatter z postępem + body z kontekstem
└── phases/<NN>-<slug>/  # artefakty per faza
    ├── NN-CONTEXT.md         # decyzje z dyskusji
    ├── NN-DISCUSSION-LOG.md  # audit trail (alternatywy)
    ├── NN-RESEARCH.md        # research techniczny pre-plan
    ├── NN-UI-SPEC.md         # design contract dla frontu
    ├── NN-PATTERNS.md        # wzorce kodu wymagane w fazie
    ├── NN-NN-PLAN.md         # PER PLAN (a nie per faza!) — w 01.1 było 7 PLAN files
    ├── NN-NN-SUMMARY.md      # PER PLAN, post-execution
    ├── NN-VERIFICATION.md    # walidacja celu fazy (goal-backward)
    ├── NN-VALIDATION.md      # macierz Nyquista
    ├── NN-REVIEW.md          # code review
    └── NN-REVIEW-FIX.md      # auto-fixy
```

**Skala kosztu (zmierzona w moim repo):**
| Workflow | Linie |
|---|---|
| `discuss-phase.md` | 1 201 |
| `plan-phase.md` | 1 075 |
| `execute-phase.md` | 1 253 |
| `execute-plan.md` | 514 |
| **Suma 4 głównych** | **4 043 linie** |

Każda komenda ładuje swój workflow przez `<execution_context>` z `@/...` — czyli te 1000+ linii ląduje w kontekście **przed jakąkolwiek pracą**. Plus ładuje 3–5 `references/*.md` (anti-patterns, gate prompts, agent contracts), plus dla każdego pomocniczego Claude'a spawnowanego z workflowa frontmatter agenta + jego prompt + `<files_to_read>` block.

**Mój ból:**
1. Pełne `discuss → plan → execute` na jedną fazę zżera tyle tokenów, że trafiam w dzienny limit zanim faza się skończy.
2. Phase 01.1 wyprodukowała 7 osobnych plików `01.1-NN-PLAN.md` + 7 `SUMMARY.md` — każdy plan to osobny spawn `gsd-executor` w worktree. Z perspektywy solo-dev to overkill.
3. Połowa ze zdefiniowanych pomocniczych Claude'ów (`gsd-nyquist-auditor`, `gsd-security-auditor`, `gsd-codebase-mapper`, `gsd-doc-verifier`, `gsd-research-synthesizer`, `gsd-integration-checker`, `gsd-user-profiler`, `gsd-ui-auditor`) **w mojej historii git nie pojawiła się ani razu** — albo nie są spawnowane domyślnie, albo dotyczą fazy gap-closure której nie odpalam.
4. Workflowy mają tony branchy (PRD express path, --auto / --chain / --reviews / --gaps / --interactive / --power / --text / --skip-research / --skip-verify / --research, advisor mode, copilot fallback, worktree dispatch sequencing) których 95% nie używam.

Złożyłem już bugi do upstream'a, ale czekać nie mogę. Chcę **własne 4–6 komend** które dają mi to co realnie wartościowe i wycinają resztę.

---

## §3. Co GSD realnie robi — fragmenty z mojego repo

Poniżej kluczowe wycinki. Bazuj na nich, **nie zgaduj** zachowań GSD.

### 3.1. Komenda `/gsd-discuss-phase` (cienki wrapper)

```markdown
---
name: gsd:discuss-phase
description: Gather phase context through adaptive questioning before planning.
argument-hint: "<phase> [--auto] [--chain] [--batch] [--analyze] [--text] [--power]"
allowed-tools: [Read, Write, Bash, Glob, Grep, AskUserQuestion, Task, mcp__context7__*]
---

<execution_context>
@.claude/get-shit-done/workflows/discuss-phase.md            # 1201 linii
@.claude/get-shit-done/workflows/discuss-phase-assumptions.md
@.claude/get-shit-done/workflows/discuss-phase-power.md
@.claude/get-shit-done/templates/context.md
</execution_context>

<process>
Reads workflow.discuss_mode config; routes to discuss-phase.md, discuss-phase-assumptions.md, or discuss-phase-power.md.
</process>
```

### 3.2. Workflow `discuss-phase.md` — co w środku (skrót)

Sekcje: `<purpose>`, `<required_reading>` (3 reference files), `<downstream_awareness>`, `<philosophy>`, `<scope_guardrail>`, `<gray_area_identification>`, `<answer_validation>` (text mode handling), `<process>` z 13 krokami:

1. `initialize` — woła `node gsd-tools init phase-op`, parsuje JSON z `phase_dir`, `phase_found`, `has_context`, `has_plans`, `response_language`
2. `check_blocking_antipatterns` — szuka `.continue-here.md`, jeśli jest blocking — wymaga inline odpowiedzi 3 pytań
3. `check_existing` — czy CONTEXT.md już jest, czy jest checkpoint, czy są plany; oferuje Update/View/Skip/Resume
4. `load_prior_context` — czyta PROJECT.md, REQUIREMENTS.md, STATE.md + wszystkie poprzednie `*-CONTEXT.md` żeby nie pytać o już zdecydowane
5. `cross_reference_todos` — woła `gsd-tools todo match-phase` żeby spiąć backlog
6. `scout_codebase` — szuka `.planning/codebase/*.md`, jeśli brak — robi targeted grep (~10% kontekstu)
7. `analyze_phase` — identyfikuje "gray areas" (decyzje o których user musi zadecydować), aktywuje **Advisor Mode** jeśli istnieje `USER-PROFILE.md` — wtedy spawnuje `gsd-advisor-researcher` per gray area
8. `present_gray_areas` — `AskUserQuestion(multiSelect)` z phase-specific kategoriami
9. `discuss_areas` — pętla deep-dive per wybrany area, każdy obrót zapisuje checkpoint JSON
10. `synthesize` — buduje `<decisions>` D-01...D-NN
11. `write_context` — zapisuje `NN-CONTEXT.md` zgodnie z templatem (patrz §3.6)
12. `write_discussion_log` — osobny `NN-DISCUSSION-LOG.md` z tabelami alternatyw (audit trail)
13. `commit_and_route` — commit z konwencją `docs(NN): gather phase context`, routing do `/gsd-plan-phase` lub end

Tryby: `--auto` (sam wybiera rekomendowane opcje), `--chain` (interactive discuss → auto plan+execute), `--power` (bulk question generation do pliku), `--text` (zamiast `AskUserQuestion` plain numbered list dla `/rc` remote sessions).

### 3.3. Workflow `plan-phase.md` — co w środku (skrót)

Sekcje + 13+ kroków: `initialize`, parse args, validate phase, **PRD Express Path** (`--prd file.md` skip discuss), **Load CONTEXT.md** (jeśli brak — proponuje run discuss-phase), **Handle Research** (jeśli `RESEARCH.md` brak lub `--research` — spawnuje `gsd-phase-researcher`), **Create Validation Strategy** (Nyquist matrix do `VALIDATION.md` jeśli `nyquist_validation_enabled`), **Spawn gsd-planner** (tworzy `NN-NN-PLAN.md` per task), **Verification Loop** (spawnuje `gsd-plan-checker`, max 3 iteracji rewizji), routing.

Spawny pomocniczych Claude'ów w jednym przebiegu typowej fazy (bez gap-closure):
- `gsd-phase-researcher` × 1 — produkuje `RESEARCH.md`
- `gsd-planner` × 1 (lub więcej w revision loop) — produkuje wszystkie `NN-NN-PLAN.md`
- `gsd-plan-checker` × 1–3 — gate przed execute

Plan-checker zwraca verdict `PASS` / `REVISE` / `BLOCK`. Przy `REVISE` planner dostaje feedback i robi nową wersję — do 3 razy.

### 3.4. Workflow `execute-phase.md` — co w środku (skrót)

Najgrubszy z workflowów. Wave-based parallelization:
- `discover_and_group_plans` — woła `gsd-tools phase-plan-index` zwraca `waves` map
- `execute_waves` — dla każdej fali sprawdza `files_modified` overlap, jeśli nie ma — spawnuje równolegle `gsd-executor` w worktree każdy
- **Sequential dispatch** — Task() per wiadomość z `run_in_background: true`, bo `git worktree add` ma exclusive lock na `.git/config.lock`
- Po każdej fali: merge worktree → main → cleanup
- Po wszystkich falach: spawn `gsd-verifier` (goal-backward verification → `VERIFICATION.md`)
- Opcjonalnie: `gsd-integration-checker` (cross-phase E2E)
- Opcjonalnie: `gsd-nyquist-auditor` (uzupełnia testy do `VALIDATION.md`)
- Update STATE.md, route do `/gsd-ship` lub `/gsd-next`

Tryby: `--wave N` (tylko jedna fala), `--gaps-only` (tylko plany z `gap_closure: true`), `--interactive` (sekwencyjnie inline, bez spawnów — "lower token usage, pair-programming style").

### 3.5. Pełna lista pomocniczych Claude'ów (24 sztuki, z `description` z frontmatter)

| Plik | Spawnowany przez | Po co |
|---|---|---|
| `gsd-advisor-researcher` | discuss-phase (advisor mode) | Research single gray area, zwraca tabelę porównawczą |
| `gsd-assumptions-analyzer` | discuss-phase (assumptions mode) | Deep codebase analysis, surface assumptions |
| `gsd-code-fixer` | /gsd-code-review-fix | Aplikuje fixy z REVIEW.md, atomowy commit per fix |
| `gsd-code-reviewer` | /gsd-code-review | Review source files, REVIEW.md z severity |
| `gsd-codebase-mapper` | /gsd-map-codebase | Pisze .planning/codebase/{tech,arch,quality,concerns}.md |
| `gsd-debugger` | /gsd-debug | Scientific method debug session, persistent state |
| `gsd-doc-verifier` | /gsd-docs-update | Verify factual claims w wygenerowanych docach |
| `gsd-doc-writer` | /gsd-docs-update | Pisze i updateuje docs |
| `gsd-executor` | /gsd-execute-phase | Wykonuje PLAN.md, atomowe commity, SUMMARY.md, deviation handling, checkpointy |
| `gsd-integration-checker` | /gsd-execute-phase (post-verify) | Cross-phase integration + E2E flows |
| `gsd-intel-updater` | /gsd-intel | Pisze .planning/intel/ (codebase intelligence files) |
| `gsd-nyquist-auditor` | /gsd-validate-phase | Generuje testy i sprawdza coverage requirements |
| `gsd-phase-researcher` | /gsd-plan-phase | RESEARCH.md, technical approach pre-plan |
| `gsd-plan-checker` | /gsd-plan-phase | Goal-backward analysis jakości planu |
| `gsd-planner` | /gsd-plan-phase | Tworzy NN-NN-PLAN.md, dependency graph, wave assignment |
| `gsd-project-researcher` | /gsd-new-project | Research domain ecosystem przed roadmapem |
| `gsd-research-synthesizer` | /gsd-new-project | Synthesizes 4 parallel researchers' output do SUMMARY.md |
| `gsd-roadmapper` | /gsd-new-project | Tworzy ROADMAP.md z phase breakdown |
| `gsd-security-auditor` | /gsd-secure-phase | Verify threat mitigations z PLAN.md threat model |
| `gsd-ui-auditor` | /gsd-ui-review | 6-pillar visual audit zaimplementowanego frontu |
| `gsd-ui-checker` | /gsd-ui-phase | BLOCK/FLAG/PASS verdict dla UI-SPEC.md |
| `gsd-ui-researcher` | /gsd-ui-phase | Produkuje UI-SPEC.md design contract |
| `gsd-user-profiler` | /gsd-profile-user | Behavioral profile w 8 wymiarach |
| `gsd-verifier` | /gsd-execute-phase | Goal-backward verification, VERIFICATION.md |

### 3.6. Sample artefakt — `01.1-CONTEXT.md` (real, fragmenty)

```markdown
# Phase 01.1: Architecture Foundation & DI Migration - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Przestawienie projektu z układu warstwowego (Domain/, Data/, Features/<Feature>/) +
ręcznej DependencyContainer factory na układ feature-first z DIContainer i jasnymi
regułami zależności (Repo ↛ Repo, UseCase → UseCase/Repo, VM → tylko UseCase,
View → tylko VM). Refaktor 4 istniejących feature'ów (Onboarding, Home, Denial,
Root) bez zmian funkcjonalnych.
</domain>

<decisions>
## Implementation Decisions

### Navigation & Root State

- **D-01:** AppRootViewModel zależy WYŁĄCZNIE od UseCase — zero Repository.
- **D-02:** Nawigacja root-level przez swift-navigation Destination? na AppRootViewModel:
  @CasePathable enum Destination { case onboarding, denial, home } + var destination: Destination?.
  Enum BEZ payloadu VM — to zasadnicza różnica od wzorca modal.
- **D-03:** Child view tworzy własny VM: @State private var model = <Feature>ViewModel().
- ... (D-04 do D-31)

### Event Flow (Combine statusPublisher)
- **D-07:** ScreenTimeAuthRepositoryImpl ma prywatny CurrentValueSubject<AuthorizationStatus, Never>...
- ... (do D-14)

### DI Container
- **D-18:** Pliki DI lądują w DeluluDetox/Sources/Core/DependencyInjection/...
- **D-20:** Jednorazowa rejestracja w DeluluDetoxApp.init() — wszystkie feature'y upfront.
- **D-21:** Fail-fast: brak rejestracji → crash przy starcie.
- ... (do D-23)

### Test Infrastructure
- **D-27..D-29**: mirror layout testów, DIContainer.reset(), 4 mocks w feature-owner.
</decisions>

<canonical_refs>
### Architecture Guides
- .claude/guides/architecture/GUIDE.md — feature-first layout + DI rules
- .claude/guides/feature-structure/GUIDE.md — Common/ feature-owner pattern
- .claude/guides/dependency-injection/GUIDE.md — DIContainer scopes
- .claude/guides/navigation/GUIDE.md — swift-navigation Wzorzec A vs B
</canonical_refs>
```

(Realny plik: 31 decyzji D-01..D-31, ~250 linii. Każda decyzja ma uzasadnienie + rejected alternatives.)

### 3.7. Sample artefakt — `01.1-04-PLAN.md` (real, frontmatter + initial sections)

```markdown
---
phase: 01.1-architecture-foundation
plan: 04
type: execute
wave: 4
depends_on: [03]
files_modified:
  - DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift
  - DeluluDetox/Sources/Features/Root/View/AppRootView.swift
  - DeluluDetox/Sources/Features/Root/Injection/RootInjection.swift
  - DeluluDetox/Sources/Features/Onboarding/ViewModel/OnboardingViewModel.swift
  - DeluluDetox/Sources/Features/Denial/ViewModel/DenialViewModel.swift
  - DeluluDetox/Sources/App/DeluluDetoxApp.swift
  - DeluluDetox/Sources/App/DependencyContainer.swift  # DELETED
autonomous: true
requirements: []  # Covers D-01, D-02, D-04, D-05, D-10, D-11, D-13, D-14, D-16, D-20, D-23

must_haves:
  truths:
    - "AppRootViewModel zależy WYŁĄCZNIE od UseCase ... (D-01)."
    - "AppRootViewModel ma @CasePathable enum Destination: Equatable ... (D-02); B5."
    - "Combine .sink subscription na ObserveUC z [weak self] ... (D-10)."
    - "scenePhase → refreshStatus structural co-location verified (B4)."
    - "DependencyContainer.swift USUNIĘTY z repo (D-23)."
    - "App buduje się zielony, Phase 1 flow działa (smoke test gate I19)."
  artifacts:
    - path: "DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift"
      provides: "Destination enum (Equatable); Combine subscription; refreshStatus()"
      contains: "@CasePathable"
      also_contains: "enum Destination: Equatable"
      also_contains: "var destination: Destination?"
      also_contains: "@ObservationIgnored @LazyInjected private var observe"
      ...
  key_links:
    - from: "AppRootViewModel.init"
      to: "observeStatus().sink { destination = map($0) }"
      via: "Combine Set<AnyCancellable>"
      pattern: "\\.sink[\\s\\S]*self\\.destination"
---

<objective>
Atomowy final commit fazy 01.1: ... (long objective with WHY this is atomic)
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/01.1-architecture-foundation/01.1-CONTEXT.md
@.planning/phases/01.1-architecture-foundation/01.1-PATTERNS.md
@.planning/phases/01.1-architecture-foundation/01.1-03-SUMMARY.md
@.claude/guides/architecture/GUIDE.md
... (4 więcej guide files)

<interfaces>
... (publiczne API z poprzednich fal — co już jest dostępne)
</interfaces>
</context>

<tasks>
[Task 1: ...] [Task 2: ...] [Task 3: ...]
</tasks>

<verification>
[per-task acceptance + final smoke test]
</verification>
```

**Skala:** Plan ma typowo 200–600 linii, każdy z bardzo szczegółowym `must_haves` (twierdzenia + artefakty + regex pattern key_links). To jest "prompt dla executora" — gęsty, regex-grade.

### 3.8. Sample artefakt — `01.1-04-SUMMARY.md` (real, frontmatter)

```markdown
---
phase: 01.1-architecture-foundation
plan: 04
subsystem: root-architecture
tags: [feature-first, case-pathable, combine, di-bootstrap, wzorzec-b, ...]

requires:
  - phase: 01.1-architecture-foundation
    plan: 03
    provides: "Onboarding/Denial/Home VM feature-first + @LazyInjected; ..."
provides:
  - "Features/Root/{ViewModel,View,Injection}/ feature-first: AppRootViewModel z @CasePathable Destination..."
  - "RootInjection no-op enum (symetria architektoniczna, D-01)"
  - "DeluluDetoxApp.init() pełny bootstrap 4 feature'ów..."
affects: [01.1-05, 01.1-06, 01.1-07]

tech-stack:
  added:
    - "SwiftUINavigation (aktywacja @CasePathable macro)"
  patterns:
    - "Wzorzec B (D-24): @CasePathable enum Destination z cases BEZ VM payload"
    - "Combine .sink { [weak self] in self?.destination = Self.map($0) }.store(in: &cancellables)"
    - "B6 co-location: @ObservationIgnored bezpośrednio przed każdą @LazyInjected"
    - "B5 explicit Equatable: enum Destination: Equatable"
    - "B4 structural co-location: .onChange(of: scenePhase) blok zawiera oba ..."

key-files:
  created: [...]
  modified: [...]
  deleted: [...]

key-decisions:
  - "Wzorzec B (enum payload-free Destination) wybrane zgodnie z D-02 + D-24..."
  - "Theme.background (Color) użyty bezpośrednio dla .none placeholder..."
  - ...

patterns-established:
  - "Atomic finale commit: refaktor AppRoot + delete DependencyContainer w jednym planie..."
  - "Autonomous smoke test gate (I19) — exit code z simctl launch/install jako non-blocking signal"
---

# Body z opisem co zostało zrobione, jak, jakie deviations, jak verified
```

### 3.9. Pełna lista ~70 komend `/gsd-*` (z `description` z frontmatter)

```
add-backlog, add-phase, add-tests, add-todo, analyze-dependencies, audit-fix,
audit-milestone, audit-uat, autonomous, check-todos, cleanup, code-review,
code-review-fix, complete-milestone, debug, discuss-phase, do, docs-update,
execute-phase, explore, fast, forensics, health, help, import, insert-phase,
intel, join-discord, list-phase-assumptions, list-workspaces, manager,
map-codebase, milestone-summary, new-milestone, new-project, new-workspace,
next, note, pause-work, plan-milestone-gaps, plan-phase, plant-seed, pr-branch,
profile-user, progress, quick, reapply-patches, remove-phase, remove-workspace,
research-phase, resume-work, review, review-backlog, scan, secure-phase,
session-report, set-profile, settings, ship, stats, thread, ui-phase, ui-review,
undo, update, update-phase, validate-phase, verify-work, workstreams
```

### 3.10. Template `context.md` (kanon outputu discuss-phase)

```markdown
# Phase [X]: [Name] - Context

**Gathered:** [date]
**Status:** Ready for planning

<domain>
## Phase Boundary
[Co faza dostarcza — anchor scope, z ROADMAP.md, fixed]
</domain>

<decisions>
## Implementation Decisions
### [Area 1]
- **D-01:** [konkretna decyzja]
- **D-02:** [...]

### Claude's Discretion
[areas user said "you decide"]
</decisions>

<specifics>
## Specific Ideas
[konkretne referencje, "I want it like X"]
</specifics>

<canonical_refs>
## Canonical References
**Downstream agents MUST read these.**
### [Topic 1]
- `path/to/spec.md` — [co decyduje]
[Jeśli nic: "No external specs — fully captured in decisions"]
</canonical_refs>

<code_context>
## Existing Code Insights
### Reusable Assets / Established Patterns / Integration Points
</code_context>

<deferred>
## Deferred Ideas
[ideas out of phase scope; jeśli nic: "None — discussion stayed within phase scope"]
</deferred>
```

---

## §4. Co GSD daje dobrego — co realnie chcę zachować

Mówię to z perspektywy 2 ukończonych faz, nie z teorii:

1. **`PROJECT.md` + `REQUIREMENTS.md` + `ROADMAP.md` + `STATE.md`** w `.planning/` — single source of truth o co buduję, w jakiej kolejności, na jakim jestem etapie. Bez tego rozsypię się przez 2 sesje.
2. **`CONTEXT.md` z numerowanymi decyzjami D-01..D-NN** — bezcenne, bo planowanie i implementacja referują się do ID, więc zero zgubienia decyzji w trakcie codingu.
3. **`PLAN.md` z `must_haves.truths` jako zdaniami + `key_links` z regex** — to jest egzekwowalne. Po implementacji można zgrepować i sprawdzić czy pattern jest. Bez tego "a, sprawdzę później" → bug.
4. **Atomowe commity per task w planie** — łatwo cofnąć jednostkową zmianę, blame ma sens, log fazy czytelny.
5. **`SUMMARY.md` z `provides` / `affects` graph** — kolejne fazy widzą co już jest w kodzie bez czytania całego kodu.
6. **Discuss przed planowaniem** — bez tego planner zgaduje moje preferencje i zwykle źle. Pytania `AskUserQuestion` z konkretnymi opcjami dają mi szansę zatwierdzić *zanim* coś powstanie.
7. **`VERIFICATION.md` goal-backward** — sprawdza że faza dowiozła to co obiecała, nie tylko że taski się skończyły.
8. **Verification loop planera (max 3 iteracje)** — `gsd-plan-checker` wyłapuje plany które nie pokrywają success criteria z ROADMAP. To uratowało mi już 2 razy refaktor.

---

## §5. Co chcę wyciąć (i dlaczego, otwórz na dyskusję)

Założenia robocze — **flaguj jeśli któreś jest błędne dla tego kontekstu**:

| Wyciąć | Dlaczego (moje założenie) |
|---|---|
| `gsd-nyquist-auditor` + `VALIDATION.md` matrix | Solo dev, brak QA. Generuję testy ad-hoc do tego co buduję, nie potrzebuję matrycy pokrycia per requirement. |
| `gsd-security-auditor` + `SECURITY.md` | Apka on-device, bez backendu, bez user data leaving device. Threat surface = Apple sandbox + App Group. Threat model w głowie. |
| `gsd-ui-auditor` (retroactive 6-pillar) | Single dev, single design taste. UI-SPEC.md przed implementacją OK, audit retroactive — teatr. |
| `gsd-codebase-mapper` + `.planning/codebase/` | Repo małe (jedno feature/wiek), znam je. Mapper to overkill dla projektu < 50k LoC. |
| `gsd-doc-verifier` | Docs piszę sam tylko gdy potrzebne. Auto-weryfikator faktów to overengineering. |
| `gsd-research-synthesizer` (4 parallel researchers) | Phase research robi mi 1 researcher i wystarczy — synthesis dla solo proj to przepalenie. |
| `gsd-integration-checker` | Phase'y są małe, integracja sprawdzona przez build + Phase 01.1 smoke test. Osobny pomocnik niepotrzebny. |
| `gsd-user-profiler` | Wiem kim jestem. |
| Cross-AI review (`/gsd-review`) | Nie mam płaconego dostępu do innych AI CLI. |
| Workspaces + worktrees parallelization | Pracuję sekwencyjnie. Worktree contention (git lock) to cały blok kodu w workflow execute-phase który nie istnieje gdy pracujesz sequential. |
| `forensics`, `health`, `manager` (interactive command center) | Niepotrzebne dla projektu jednoosobowego. |
| `power` mode dyskusji (bulk question generation) | Wolę 5–10 pytań naraz niż formularz. |
| `--auto`, `--chain`, `--reviews`, `--gaps`, `--prd` flags w discuss/plan | Każdy flag = branch w workflow. Wycięcie 5 flag = wycięcie ~30% workflow. |
| Per-plan podział (`NN-01-PLAN.md`, `NN-02-PLAN.md`, ...) | Phase 01.1 miała 7 plików planu. Każdy plan = osobny spawn executora w worktree. Wolę **jeden monolityczny PLAN.md per faza** z task-listą, executowany sekwencyjnie inline. |
| `gsd-tools.cjs` (node CLI) | 23kB JSON manifest, init/state/config logic. Wolę zastąpić bashem + 1 Pythonem jeśli muszę. Ale jeśli to ratuje 50% kodu workflow przez parsing JSON — może zostać. **Twoja ocena.** |

---

## §6. Twardo zachowane wymagania zamiennika

1. **Zero auto-ładowania workflowów >300 linii.** Cała logika komendy mieści się w pliku komendy + max 1 zwięzły reference. Jeśli komenda potrzebuje >300 linii instrukcji to znaczy że robi za dużo — rozdziel.
2. **Discuss zostaje, ale ma jedną ścieżkę.** `AskUserQuestion` z 3–5 phase-specific pytaniami, output do `NN-CONTEXT.md` zgodnego z templatem §3.10 (zachowaj sekcje: domain, decisions z D-IDs, canonical_refs, deferred). `DISCUSSION-LOG.md` opcjonalny — jeśli alternatywy były ważne, niech idzie do CONTEXT.md jako collapsed details.
3. **Plan jest per-faza monolityczny.** Jeden `NN-PLAN.md` na fazę, w środku task-lista. Każdy task ma `must_haves.truths` + `must_haves.artifacts` (zachowaj ten format z §3.7 — to działa).
4. **Execute idzie sekwencyjnie po taskach z task-listy.** Główny Claude (nie pomocniczy) robi commit-per-task. Brak wave-based parallelization, brak spawnu `gsd-executor`. Po każdym tasku — atomowy commit z wiadomością `<type>(NN.tt): <imperatyw>` (jak w moim git logu).
5. **Verify to conversational UAT.** Lista success criteria z ROADMAP.md + acceptance per task → user odpowiada `tak / nie / skip` → jeśli wszystko `tak` to `STATE.md` updated, faza closed. Jeśli `nie` — task w `NN-VERIFICATION.md` z gapem do fix.
6. **`STATE.md` zostaje jedynym źródłem prawdy o postępie** (frontmatter z `progress`, `current_phase`, `last_activity` — patrz §8 sample) i jest updateowany wyłącznie przez execute / verify.
7. **`ROADMAP.md` w obecnym formacie** (`- [x]` / `- [ ]` per phase z success criteria) — bez zmian.
8. **Atomowe commity z konwencją z dotychczasowych phase'ów.** `feat(NN.tt): ...` / `refactor(NN.tt): ...` / `docs(NN): ...` / `test(NN.tt): ...`.
9. **CLAUDE.md projektu zawsze respektowany.** W moim repo CLAUDE.md ma sekcję "GSD Workflow Enforcement" — nowy zestaw musi być spójny z tym założeniem (komenda jako entry point przed Edit/Write).
10. **Polski w warstwie user-facing**, angielski w kodzie/promptach komend (jak teraz w `01.1-CONTEXT.md` — decyzje po polsku, frontmatter po angielsku).

---

## §7. OUTPUT — czego od Ciebie chcę

Zwróć JEDEN dokument markdown z czterema sekcjami w tej kolejności:

### Sekcja A — Mapa GSD w plain language

Tabela: dla każdego z głównych etapów (`discuss-phase`, `plan-phase`, `execute-phase`, `verify-work / verify-phase`, `code-review (+ fix)`, `ui-phase / ui-review`) wypełnij:

| Etap | Co realnie robi (po polsku, ludzkim językiem) | Co produkuje (artefakt) | Po co to istnieje | Szacunek kosztu (główny prompt + spawn pomocników + template'y) — w "porcjach": niski/średni/wysoki/bardzo wysoki + uzasadnienie |
|---|---|---|---|---|

Pod tabelą: dla każdego etapu krótkie "**Co się stanie jak go pominę?**" (np. "pominięcie discuss → planner zgaduje, prawdopodobieństwo niezgodności z moją wizją wysokie, jednoosobowy dev to wykryje przy review ale traci 1–2 obroty").

### Sekcja B — Diagnoza wycieku tokenów w MOIM przypadku

Bazując na fragmentach z §3 i mojej liście wycięć z §5:

1. Tabela "**agent / workflow → realnie używany w moich Phase 01 i 01.1? → koszt → wartość dla mnie (high/medium/low/zero)**". Kolumna "realnie używany" — wnioskuj z artefaktów: jeśli w `.planning/phases/01.1-architecture-foundation/` widać `VERIFICATION.md` to `gsd-verifier` był; jeśli nie ma `VALIDATION.md` to `gsd-nyquist-auditor` nie był. (Patrz lista artefaktów w §2 — masz pełen obraz co powstało.)
2. Top 3 pojedyncze pożeracze tokenów w workflowach z §3 (cytuj nazwę kroku/sekcji + wyjaśnij dlaczego jest drogi).
3. Czy któreś z moich wycięć z §5 jest błędne dla DeluluDetox? Uzasadnij.

### Sekcja C — Propozycja zamiennika

**Zaprojektuj zestaw 4–6 komend.** Sugestia (dyskutowalna): `/phase-discuss`, `/phase-plan`, `/phase-do`, `/phase-verify`, `/phase-ship` (+ ewentualnie `/phase-status`). Dla **każdej** komendy zwróć:

1. **Pełną treść pliku `.md`** gotową do wklejenia do `.claude/commands/` — frontmatter (name, description, argument-hint, allowed-tools) + objective + cały process inline (bez `@/...` referencji do workflowów >100 linii). Cel: każdy plik komendy ≤300 linii self-contained.
2. **Jakie artefakty produkuje** — zachowaj kompatybilność z istniejącym `.planning/phases/<n>-<slug>/` (templaty CONTEXT, PLAN, SUMMARY, VERIFICATION zostają ale uproszczone).
3. **Jakie pomocnicze Claude'y zachowuje (Task spawny), jakie wycina** — z jednozdaniowym uzasadnieniem każdego wyboru.
4. **Szacunek redukcji tokenów** vs odpowiednik GSD (np. "≈30% kosztu `gsd-execute-phase` — usunięcie wave dispatch, sequential dispatch, worktree handling, integration checker spawn, nyquist auditor spawn").

**Dodatkowo — uproszczone templaty** dla `CONTEXT.md`, `PLAN.md`, `SUMMARY.md`, `VERIFICATION.md` (jeśli proponujesz zmiany vs §3.6 / §3.7 / §3.8 / template w §3.10). Jeśli któryś zostawiasz bez zmian — powiedz to wprost.

### Sekcja D — Ścieżka migracji w MOIM repo

Konkretne, ponumerowane kroki:

1. Co zrobić z istniejącymi artefaktami Phase 02 (`02-CONTEXT.md`, `02-RESEARCH.md`, `02-UI-SPEC.md`, `02-PATTERNS.md`, `02-VALIDATION.md`, `02-DISCUSSION-LOG.md`, szkic `02-01-PLAN.md`) — co skopiować, co dostosować do nowego formatu, co odłożyć.
2. Czy `STATE.md` / `ROADMAP.md` wymagają edycji do nowego zestawu komend (jakich konkretnie pól / sekcji).
3. Czy zostawić stare `.claude/commands/gsd/` jako fallback przez np. 1 fazę, czy `mv` do `.claude/commands/_gsd-archived/`.
4. Pierwsza faza testowa nowego zestawu — proponuję Phase 02 (kontekst już jest, więc start od `/phase-plan 02`). Wskaż jakie ryzyka tego wyboru i alternatywę.
5. **Smoke test plan** dla pierwszego użycia — co konkretnie sprawdzić po `/phase-plan 02 → /phase-do 02 → /phase-verify 02` żeby wiedzieć że nowy zestaw nie zgubił czegoś krytycznego.

---

## §8. Załącznik — sample frontmatter STATE.md (real, do zachowania kompatybilności)

```yaml
---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Phase 01.1 context gathered
last_updated: "2026-04-19T01:18:21.960Z"
last_activity: 2026-04-19
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 11
  completed_plans: 10
  percent: 91
---
```

I body: sekcje `Project Reference`, `Current Position`, `Performance Metrics`, `Accumulated Context` (Decisions / Roadmap Evolution / Pending Todos / Blockers), `Session Continuity`. Nowy zestaw komend musi tę strukturę utrzymać, bo używa tego zarówno user (czytanie) jak i komendy `/phase-status`.

---

## §9. Zasady researchu (powtórka, dla pewności)

- **Czytaj fragmenty kodu wklejone wyżej, nie zgaduj.** Każde stwierdzenie "GSD robi X" musi mieć kotwicę w §3.
- **Polski, ludzkim językiem.** Bez emoji, bez wodolejstwa.
- **Nie pisz komend "na oko".** Zanim zaproponujesz `/phase-plan`, popatrz na jego mocne strony w §3.3 (verification loop, gates, Goal-backward) i zdecyduj świadomie czy zostają.
- **Jeśli któraś teza z §5 jest błędna w kontekście DeluluDetox** (apka on-device, Screen Time API, twarde ograniczenia 1–9 z §1, Phase 03 = core value) — powiedz to i uzasadnij. Nie dopasowuj wniosków do moich założeń.
- **Output to jeden dokument markdown** — nie zapisuj nic do plików (w odpowiedzi po prostu zwróć cały markdown). Ja go potem sam zapiszę gdzie chcę.
