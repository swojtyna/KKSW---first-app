---
description: Add a new phase to ROADMAP.md — append to end or --after N decimal insert (N.1)
argument-hint: [--after N] <slug>
allowed-tools: [Read, Edit, Grep, Bash, AskUserQuestion]
---

# /phase-add

Dodaje nową fazę do `ROADMAP.md` + bumpuje `STATE.md` + tworzy pusty katalog fazy.

Nie tworzy CONTEXT/PLAN/SUMMARY — to zadanie dla kolejnych komend.

## Arguments

- `<slug>` (required) — kebab-case identyfikator fazy, np. `backup-export`, `deep-focus`.
- `--after N` (optional) — decimal insert między Phase N a N+1 → nowa faza dostaje numer `N.1`. Jeśli N.1 już istnieje, inkrementuj do N.2, N.3 itd.

## Process

### 1. Parse args

```
SLUG=<słowo po --after N lub ostatni argument jeśli brak --after>
AFTER=<liczba po --after lub pusty>
```

Validate:
- `<slug>` MUSI match regex `^[a-z][a-z0-9-]{2,50}$` (kebab-case).
- Jeśli `--after` podany — MUSI być prawidłowym numerem fazy z ROADMAP (`\d+(\.\d+)?`).

### 2. Read ROADMAP + STATE

```
Read .planning/ROADMAP.md
Read .planning/STATE.md
```

Wydobądź z ROADMAP:
- Lista istniejących faz (numery + statusy `- [x]/- [ ]`)
- Sekcja `## Progress` (tabela na końcu)

Wydobądź z STATE frontmatter: `progress.total_phases`, `last_activity`.

### 3. Compute phase number

```
If --after N:
  Zlicz istniejące fazy decimalne po N (N.1, N.2, ...) w ROADMAP list
  NEW_NUMBER = N.{count + 1}
  NEW_LABEL_SUFFIX = " (INSERTED)"
Else:
  Max integer phase w ROADMAP + 1
  NEW_NUMBER = {max + 1}
  NEW_LABEL_SUFFIX = ""
```

Format numbering:
- Integer: `1`, `2`, ..., `10`. W ROADMAP lista nagłówek używa `Phase N`, w headerach sekcji `### Phase N:`.
- Decimal: `01.1`, `01.2`, ... (z leading zero), `03.1`. W headerach `### Phase NN.1:`.

### 4. AskUserQuestion — zebrać content fazy

**Question 1:** Human-readable name + goal + depends_on (multi-field form):

```
AskUserQuestion:
  question: "Nowa Phase {NEW_NUMBER} — podaj szczegóły:"
  fields:
    - name: "Human-readable name" (np. "Deep Focus Anti-Bypass")
    - goal: "Goal — 1 zdanie 'User can ...'" (np. "User cannot dismiss session by typing passphrase")
    - depends_on: "Depends on Phase" (np. "3" lub "3, 5")
```

**Question 2:** Success criteria (3-5 punktów jako multi-line):

```
AskUserQuestion:
  question: "Success criteria — 3 do 5 punktów 'what must be TRUE'. Każdy w nowej linii."
  fields:
    - success_criteria: textarea
```

Parse multi-line textarea → numbered list.

### 5. Update ROADMAP.md

#### 5a. Top-level list

Format wpisu:
```
- [ ] **Phase {NEW_NUMBER}: {Name}**{NEW_LABEL_SUFFIX} - {goal first 80 chars}
```

Insert position:
- **Integer append** → na końcu listy, przed `## Phase Details`.
- **Decimal insert** → bezpośrednio po wpisie Phase N, zachowując kolejność N.1, N.2, ...

#### 5b. Phase Details section

Dodaj sekcję:
```markdown
### Phase {NEW_NUMBER}: {Name}{NEW_LABEL_SUFFIX}
**Goal**: {goal}
**Depends on**: Phase {depends_on}
**Requirements**: TBD
**Success Criteria** (what must be TRUE):
{numbered success criteria}
**Plans**: TBD
```

Insert position:
- Po `### Phase {AFTER}:` dla decimal (bezpośrednio).
- Na końcu sekcji `## Phase Details` (przed `## Progress`) dla integer append.

#### 5c. Progress table

Dodaj wiersz:
```
| {NEW_NUMBER}. {Name}{NEW_LABEL_SUFFIX} | 0/? | Not started | - |
```

Insert position: odpowiednie miejsce w numerycznym porządku tabeli.

### 6. Update STATE.md

Edit frontmatter:
- `progress.total_phases` → +1
- `last_activity` → today (YYYY-MM-DD)

### 7. Create empty phase directory

```
Bash: mkdir -p .planning/phases/{NEW_NUMBER}-{SLUG}/
```

Format directory name: `02-app-selection`, `03-quick-sessions`, `01.1-architecture-foundation`. Leading zero dla integer < 10, kropka dla decimal.

Optionally create `.gitkeep` jeśli użytkownik commituje puste katalogi.

### 8. Report

Wypisz:
```
✓ Phase {NEW_NUMBER}: {Name} added to ROADMAP
  Katalog: .planning/phases/{NEW_NUMBER}-{SLUG}/
  STATE: total_phases → {new_count}

Następny krok: /phase-discuss {NEW_NUMBER}
```

## Nie commituje

`phase-add` zostawia ROADMAP.md + STATE.md jako uncommitted. Pierwszy commit pójdzie razem z `<NN>-CONTEXT.md` podczas `/phase-discuss`. Ułatwia user'owi poprawę goal/SC przed commitem.

Jeśli user woli commit od razu: suggest `git add .planning/ROADMAP.md .planning/STATE.md && git commit -m "docs(roadmap): add Phase {NEW_NUMBER} {Name}"`.

## Constraints

- Zero Task spawn (bez advisora — discuss-phase jest follow-up krokiem, tam jest advisor opt-in).
- Zero file creation poza katalogiem fazy.
- Jeśli directory już istnieje → BLOCK: "Phase {NEW_NUMBER}-{SLUG}/ already exists. Choose different slug or use /phase-discuss {NEW_NUMBER}."
- Jeśli `--after N` i Phase N nie istnieje w ROADMAP → BLOCK: "Phase {N} not found. Run /phase-status to see available phases."
