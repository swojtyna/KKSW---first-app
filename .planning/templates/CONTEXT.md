# Phase {N}: {Name} - Context

**Gathered:** {YYYY-MM-DD}
**Status:** Ready for planning

<domain>
## Phase Boundary

{1-2 zdania: co faza dostarcza. Anchor z ROADMAP Phase N Goal.}

**In scope:**
- {konkretne capabilities fazy}
- {...}

**Out of scope (inne fazy lub post-MVP):**
- {co z ROADMAP należy do innych faz}
- {co deferred do post-MVP}

</domain>

<decisions>
## Implementation Decisions

### {Thematic group 1}
- **D-01:** {konkretna decyzja — co, nie dlaczego-inny-wariant-odrzucony}
- **D-02:** {...}

### {Thematic group 2}
- **D-03:** {...}

### Claude's Discretion
- {rzeczy które Claude decyduje w plan/execute — stylistyka, wewnętrzne API klas, nazwy helperów}

### Folded Todos
- None — OR — {inherited pending todos from STATE}

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project constraints
- `.planning/PROJECT.md` §Hard Constraints from Research — {relevant hard constraints z listy 1-9}
- `.planning/REQUIREMENTS.md` §{Phase section} — {REQ-IDs z ROADMAP Phase N}
- `.planning/ROADMAP.md` §Phase {N} — goal + success criteria

### {Domain area — np. Screen Time API, Shield API, Persistence}
- `.claude/research/{compass_artifact_file}.md` — {co ten research dostarcza}
- {...}

### Architecture guides (always-on for DeluluDetox)
- `.claude/guides/architecture/GUIDE.md` — MVVM + UseCase + Repository
- `.claude/guides/dependency-injection/GUIDE.md` — DIContainer scopes + @LazyInjected
- `.claude/guides/navigation/GUIDE.md` — swift-navigation + @CasePathable Destination
- `.claude/guides/feature-structure/GUIDE.md` — feature-first layout, Common/ pattern

### Phase-specific guides
- `.claude/guides/{topic}/GUIDE.md` — {dlaczego relevant dla tej fazy}

### Prior phase context
- `.planning/phases/{prev-phase}/{NN}-CONTEXT.md` — {decyzje z poprzednich faz wpływające na tę}

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- {istniejące komponenty/helpery które ta faza będzie konsumować}

### Established Patterns (from prior phases + project guides)
- {wzorce z poprzednich SUMMARY.md `patterns-established:` list}

### Integration Points
- {gdzie nowy kod wpina się w istniejący — main app VM, extension target, App Group file}

</code_context>

<specifics>
## Specific Ideas

- {konkretne referencje, "I want it like X" moments, produkty które user przywołał jako wzorzec}

</specifics>

<deferred>
## Deferred Ideas

- {idee które padły w discussion ale należą do innych faz / post-MVP}

</deferred>

---

*Phase: {NN}-{slug}*
*Context gathered: {YYYY-MM-DD}*
