---
phase: {NN}-{slug}
type: execute
depends_on: [{previous phase summary ids — np. 03-quick-sessions}]
files_modified:
  - {aggregated list from all tasks}
autonomous: true
requirements: [{REQ-IDs from ROADMAP — np. SHL-01, SHL-02, SHL-03, SHL-04}]
user_setup: []

must_haves:
  truths:
    - "{global invariants po wykonaniu wszystkich tasków — np. 'Shield extensions są read-only wobec App Group plików (D-16)'}"
    - "{App buduje się zielony pod Swift 6.2, wszystkie testy przechodzą.}"
  artifacts:
    - path: "{path/to/new/file.swift}"
      provides: "{co ten plik dostarcza downstream}"
      contains: "{regex pattern — np. 'class ShieldConfigurationDataSource'}"
  key_links:
    - from: "{plik / symbol A}"
      to: "{plik / symbol B}"
      via: "{mechanizm — np. 'openApp(URL) call'}"
      pattern: "{regex potwierdzający link}"
---

<objective>
{Phase-level purpose. Co powstaje, dlaczego teraz, jak to się łączy z poprzednim i następnym Phase.}

Output:
- {lista kluczowych plików + katalogów które pojawią się po wykonaniu planu}
</objective>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/{NN}-{slug}/{NN}-CONTEXT.md
@CLAUDE.md
{wybrane canonical_refs guides z CONTEXT.md — np. @.claude/guides/navigation/GUIDE.md}

<interfaces>
<!-- Istniejące API z poprzednich faz (z `provides:` graph), których taski będą konsumować. -->

```swift
// Z Phase 03 SUMMARY (active_session.json schema):
public struct SessionRecord: Codable {
    public let id: UUID
    public let plannedEndAt: Date
    // ...
}
```

</interfaces>
</context>

<tasks>

<task type="auto" id="T01">
  <name>T01: {1-zdaniowe objective}</name>

  <guide_refs>
    - {subset canonical_refs z CONTEXT.md — np. `.claude/guides/navigation/GUIDE.md` §Deep Link Patterns}
    - {...}
  </guide_refs>

  <read_first>
    - {pliki które trzeba przeczytać PRZED edycją — guides, referenced code, istniejące implementacje}
    - {...}
  </read_first>

  <files>
    {path/to/file.swift} (NEW | MODIFIED | DELETED)
    {...}
  </files>

  <action>
    1. {krok 1 — konkretny, executable}
    2. {krok 2 — ...}
    3. {...}
  </action>

  <verify>
    <automated>
      # {opis co sprawdzamy}
      test -f {path/to/expected/file}
      grep -q "{expected pattern}" {path/to/file}
      # Build + test via XcodeBuildMCP:
      # session_show_defaults → build_sim → exit 0
    </automated>
  </verify>

  <acceptance_criteria>
    - `grep -c "{pattern}" {file}` → **≥ 1**
    - XcodeBuildMCP `build_sim` scheme=DeluluDetox → **exit 0**
    - XcodeBuildMCP `test_sim` scheme=DeluluDetox → **wszystkie zielone**
    - {inne zapobiegawcze checki}
  </acceptance_criteria>

  <done>
    {1-zdaniowe exit criterion — co musi być true żeby task był "done"}
  </done>
</task>

<!-- T02 .. TNN same format -->

</tasks>

<verification>
{global post-execution checks dla całej fazy:
- XcodeBuildMCP build_sim exit 0
- XcodeBuildMCP test_sim: all pass
- grep regex matches dla must_haves.artifacts across all tasks
- żadne pliki z Phase 01/01.1/02/03 nie zmodyfikowane nieinterencjonalnie (git diff)}
</verification>

<success_criteria>
{phase-level — maps do ROADMAP Success Criteria 1:1:
1. SC-1 z ROADMAP → realized przez {T01, T03}
2. SC-2 z ROADMAP → realized przez {T02}
...}
</success_criteria>

<output>
Po ukończeniu wszystkich tasków: utwórz `.planning/phases/{NN}-{slug}/{NN}-SUMMARY.md` wg templatu `.planning/templates/SUMMARY.md` wypełniając:
- `requires:` / `provides:` / `affects:` graph
- Acceptance criteria matrix (wszystkie taski × acceptance checks)
- Build / test results
- Decisions made (deviations od planu)
- Next phase readiness note
</output>
