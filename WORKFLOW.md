# WORKFLOW

Jak prowadzę DeluluDetox fazami. **7 komend**, sekwencyjnie, każda faza ma swój katalog artefaktów w `.planning/phases/<NN>-<slug>/`.

---

## TL;DR — typowa faza

```
/phase-add backup-export          # (opcjonalnie) dodaj nową fazę do ROADMAP
/phase-discuss 04                 # decyzje → 04-CONTEXT.md
/phase-plan 04                    # taski + Plan Approval → 04-PLAN.md
/phase-do 04                      # implementacja, commit per task → 04-SUMMARY.md
/phase-verify 04                  # UAT z pytaniami → 04-VERIFICATION.md
/phase-ship 04                    # checkbox w ROADMAP, bump STATE
```

`/phase-status` w dowolnym momencie żeby zobaczyć gdzie jesteś.

---

## Komendy szczegółowo

### `/phase-status`

**Po co:** Szybki dashboard — aktualna faza, jakie artefakty są w katalogu fazy, następny sugerowany krok.

**Co robi (read-only):**
1. Czyta `STATE.md` → current phase, progress.
2. Glob `.planning/phases/<current>-*/` → lista artefaktów.
3. Decision tree: suggeruje następną komendę (`/phase-discuss`, `/phase-plan`, `/phase-do`, `/phase-verify`, `/phase-ship` lub next phase).
4. Print tabelę + sugestię. Nic nie zapisuje.

**Output przykład:**
```
Current phase: 04 — Shield Customization
  Status: Planned (CONTEXT.md ✓, PLAN.md ✓, SUMMARY.md ✗)
Suggested: /phase-do 04
```

---

### `/phase-add [--after N] <slug>`

**Po co:** Dodać nową fazę do `ROADMAP.md` (na końcu) lub wstawić decimal (`N.1`) między istniejące.

**Co robi:**
1. Parsuje argumenty, wybiera numer fazy (append albo decimal po `--after N`).
2. `AskUserQuestion` × 2 — pyta o name, goal, depends_on, 3-5 success criteria.
3. Wstawia wpis do ROADMAP (lista + Phase Details + Progress table).
4. Bumpuje STATE (`total_phases++`, `last_activity`).
5. Tworzy pusty katalog `.planning/phases/<NN>-<slug>/`.
6. Suggeruje: `/phase-discuss <N>`.

**Przykłady:**
```
/phase-add usage-stats                    # → Phase 07 (next integer)
/phase-add --after 03 timer-bypass        # → Phase 03.1 (INSERTED)
```

**NIE commituje** — ROADMAP i STATE zostają uncommitted (pierwszy commit pójdzie z CONTEXT.md w `/phase-discuss`).

---

### `/phase-discuss <N> [--advise]`

**Po co:** Zebrać twoje decyzje **zanim** plan powstanie. Bez tego planer zgaduje i zwykle źle.

**Co robi:**
1. Czyta poprzednie CONTEXT.md + SUMMARY `provides:` graph (żeby nie pytać o już zdecydowane).
2. Identyfikuje 3-5 gray areas specyficznych dla fazy.
3. Pyta cię przez `AskUserQuestion` — każdy gray area osobno, z 2-4 konkretnymi opcjami + "Other".
4. Numeruje twoje decyzje `D-01..D-NN`, grupuje po tematach.
5. Buduje `<canonical_refs>` (always-on guides + phase-specific + research files).
6. `--advise` opcjonalnie spawnuje **advisor** agent który flaguje konflikty z PROJECT.md Hard Constraints / CLAUDE.md / prior D-XX.
7. Zapisuje `<NN>-CONTEXT.md` + `<NN>-DISCUSSION-LOG.md` (audit trail).

**Output przykład:**
```
Phase 04: Shield Customization
Gray areas — wybierz które chcesz omówić:
  [Visual Identity?] Blur style, tint alpha, SF Symbol icon
  [Copy tone?] Neutral vs sarcasm poziom na shieldzie
  [Unknown token fallback?] Branded vs Apple default
  ...
```

Jeśli CONTEXT już istnieje → pyta `Update / View / Skip`.

---

### `/phase-plan <N> [--research] [--ui]`

**Po co:** Z decyzji w CONTEXT + success criteria w ROADMAP → task-lista z `must_haves` + regex acceptance. Plan Approval ZANIM zapisze.

**Co robi:**
1. Czyta CONTEXT.md (D-XX, canonical_refs) + prior SUMMARY `provides:` graph (anti-duplication).
2. Opcjonalnie spawn `phase-researcher` (`--research`) lub `ui-researcher` (`--ui`).
3. Generuje task-listę T01..TNN — każdy z objective, `guide_refs`, `must_haves.truths`, `must_haves.artifacts` (regex), `key_links`, `read_first`, `action`, `verify.automated`, `acceptance_criteria`.
4. Spawna `plan-checker` (zawsze) — 4 gate'y:
   - **G1** Goal-backward (każdy SC pokryty ≥1 taskiem)
   - **G2** Decision coverage (każda D-XX ma task lub `out_of_scope`)
   - **G3** Anti-duplication (nie dubluje `provides:` z poprzednich faz)
   - **G4** Guide coverage (każdy guide z canonical_refs jest w ≥1 `guide_refs` — WARN tylko, nie BLOCK)
5. Jeśli BLOCK → regeneracja max 3×. Potem user decyduje.
6. **Plan Approval prompt:** `[Accept / Edit / Reject]` — pokazuje tabelę T × D-XX × key artifacts.
7. `Accept` → zapisz `<NN>-PLAN.md`. `Edit` → feedback + regeneracja. `Reject` → exit.

---

### `/phase-do <N>`

**Po co:** Wykonać plan. Kod, commity, koniec.

**Co robi:**
1. Czyta `<NN>-PLAN.md`, parse tasków.
2. **Resume logic:** grep `git log` za commit pattern `<type>(N.tt):` — start od następnego niewykonanego tasku.
3. Sekwencyjnie per task (w głównym Claude, **bez spawn**):
   - Read `guide_refs` + `read_first`
   - Execute `action` (Edit/Write/Bash)
   - XcodeBuildMCP `build_sim` + `test_sim` — auto-fix compilation errors 3× max
   - Grep `must_haves.artifacts` regex — muszą matchować
   - Bash `acceptance_criteria` — muszą pass
   - Atomowy commit `<type>(N.tt): <objective>`
4. Global post-verification: build + test, global `must_haves` regex.
5. Zapisuje `<NN>-SUMMARY.md` z `provides:` graph.
6. Bumpuje STATE (`completed_plans`, `last_activity`).

**Przerwanie:** Ctrl-C w środku zostawi ostatni task commitnięty (atomowość). Re-run `/phase-do <N>` wznowi od następnego.

---

### `/phase-verify <N>`

**Po co:** Sprawdzić **czy faza dowiozła** obiecane value, nie tylko że taski się skończyły.

**Co robi:**
1. Czyta ROADMAP Phase N Success Criteria (ponumerowane).
2. Per criterion: `AskUserQuestion` → `Pass` / `Fail` / `Skip (not testable)` / `Defer`.
3. Jeśli `Fail` → pyta o gap description + impact.
4. Compute `overall_status`: wszystkie Pass → `passed`; jakiś Fail → `failed`; Pass+Skip+Defer → `partial`.
5. Zapisuje `<NN>-VERIFICATION.md` z tabelą + `<gaps>` + `<followup>` sugestiami.

**Jeśli fail:** sugeruje 3 drogi: gap-fix w tej fazie (`/phase-plan` add task), backlog (`/phase-add`), defer do post-MVP (PROJECT.md §Out of Scope).

---

### `/phase-ship <N> [--tag]`

**Po co:** Domknąć fazę — checkbox w ROADMAP + bump STATE.

**Co robi:**
1. Czyta VERIFICATION.md `overall_status`. Jeśli `failed` → wymusza explicit `ship-failed` potwierdzenie. Jeśli `partial` → pyta raz.
2. `[ ] Phase N` → `[x] Phase N` w ROADMAP + append `(completed YYYY-MM-DD)`.
3. Update Progress table row.
4. Bump STATE (`completed_phases++`, `percent`, `stopped_at`).
5. `--tag` opcjonalnie tworzy git tag `phase-N-complete` (lokalny, bez push).
6. Commit `docs({N}): ship phase`.

---

## Najczęstsze sytuacje

**"Zacząłem fazę, chcę przerwać i wrócić jutro"**
- Commity są atomowe per task. `/phase-status` jutro pokaże gdzie jesteś. `/phase-do <N>` wznowi od następnego niewykonanego (resume przez `git log` grep).

**"Pomyłka w decyzji — chcę zmienić CONTEXT po wygenerowaniu"**
- `/phase-discuss <N>` widzi że CONTEXT.md istnieje → pyta `Update / View / Skip`. `Update` merguje nowe D-XX (zachowuje stare numery).
- Jeśli PLAN już wygenerowany → potem re-run `/phase-plan <N>` (Plan Approval pozwoli zdecydować czy regenerować).

**"Plan się nie podoba na Plan Approval"**
- Wybierz `Edit`, podaj uwagę tekstowo ("scal T02 i T03", "dodaj task na error handling"). Komenda regeneruje i znów pokazuje do approval.
- `Reject` anuluje bez zapisu.

**"Dowiozłem N-1 success criteriów ale jeden nie wyszedł"**
- `/phase-verify <N>` → `Fail` na problematycznym SC → VERIFICATION.md zapisuje gap + proposed resolutions.
- Najczęściej: `/phase-plan <N>` doda gap-fix task, `/phase-do <N>` go wykona (resume z git log — nie powtarza już zrobionych).

**"Build failuje w środku `/phase-do`"**
- Komenda auto-fixuje compilation errors 3× max (CLAUDE.md rule).
- Po 3 nieudanych próbach → stop, ask user. User fixuje ręcznie lub decyduje Skip/Cancel.

**"Guide nie istnieje ale CONTEXT go referuje"**
- `phase-do` ask: `Skip guide / Cancel task / Write guide first`. User pisze guide (następując `create-new-guide/GUIDE.md` Pattern 1/2), re-run `/phase-do`.

---

## Konwencje plików

```
.planning/
├── PROJECT.md             # wizja, hard constraints (rzadko edytowane)
├── REQUIREMENTS.md        # ID-aki ONB-01, SEL-01, QSN-01... (rzadko)
├── ROADMAP.md             # fazy + success criteria (edytowane przez /phase-add, /phase-ship)
├── STATE.md               # postęp (auto-bumped przez /phase-do, /phase-ship, /phase-add)
├── templates/             # źródła prawdy dla komend
│   ├── CONTEXT.md
│   ├── PLAN.md
│   ├── SUMMARY.md
│   └── VERIFICATION.md
└── phases/<NN>-<slug>/
    ├── <NN>-CONTEXT.md            # produced by /phase-discuss
    ├── <NN>-DISCUSSION-LOG.md     # audit trail /phase-discuss
    ├── <NN>-RESEARCH.md           # optional, /phase-plan --research
    ├── <NN>-UI-SPEC.md            # optional, /phase-plan --ui
    ├── <NN>-PLAN.md               # produced by /phase-plan (MONOLITYCZNY — jeden per faza)
    ├── <NN>-SUMMARY.md            # produced by /phase-do
    └── <NN>-VERIFICATION.md       # produced by /phase-verify
```

**Reguła:** wszystko w `.planning/` czytaj bez ryzyka. Edytuj ręcznie tylko `PROJECT.md` / `REQUIREMENTS.md` / `ROADMAP.md`. Per-phase pliki edytuj **przez komendy** (re-run z `Update` mode).

**Legacy multi-plan:** fazy 01, 01.1, 02, 03 używają starego formatu `<NN>-NN-PLAN.md` + `<NN>-NN-SUMMARY.md` (kilka plików per faza). Nie migrujemy. Nowe fazy (od 04 wzwyż) używają monolitu.

---

## Co poszło źle (rollback)

- **Pomyłkowy `/phase-do` task** → `git log` ostatnie commity → `git revert <sha>` tylko problematycznego taska (atomowość pomaga). `STATE.md` ręcznie dostosuj lub re-run `/phase-status` żeby przeliczyło.
- **Plan kompletnie nie ten** → usuń `<NN>-PLAN.md`, re-run `/phase-plan <N>`. SUMMARY (jeśli było) zachowaj osobno — ale jeśli `/phase-do` był na złym planie, lepszy `git reset --hard <sha-przed-phase-do>` + re-run od plan.
- **Cała faza do wyrzucenia** → `git reset --hard <sha-przed-fazą>` (znajdź przez `git log --grep="^docs({N}): gather phase context"`). Ręcznie odznacz w ROADMAP. Zachowaj `<NN>-CONTEXT.md` jeśli decyzje były dobre — re-run `/phase-plan` od razu.
- **VERIFICATION failed i nie umiem fixnąć** → update PROJECT.md §Out of Scope z uzasadnieniem, re-run `/phase-verify` z `Defer`, potem `/phase-ship` z partial override.

---

*Aktualizuj ten plik manualnie tylko gdy zmienia się **semantyka komend** (np. nowy flag, nowa komenda, zmiana gate'a w plan-checker). NIE per faza, NIE per release.*
