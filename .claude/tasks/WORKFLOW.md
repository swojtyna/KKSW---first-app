# WORKFLOW

Jak prowadzę pracę w DeluluDetox. Wszystko przez system **TASK-XXX** w `.claude/tasks/`.

---

## TL;DR

```
# Małe zadanie
.claude/tasks/ready-to-work/TASK-NNN_slug.md

# Duże zadanie (wiele sesji/kontekstów)
.claude/tasks/ready-to-work/TASK-NNN_slug.md
.claude/tasks/ready-to-work/TASK-NNN_files/
    MASTERPLAN.md
    phase-01.md
    phase-02.md

# Zmiana statusu: przenieś folder+plik, zaktualizuj STATUS.md
```

---

## Struktura katalogów

```
.claude/tasks/
├── ready-to-work/        # do zrobienia
├── in-progress/          # aktywnie robione
├── done/                 # ukończone
├── STATUS.md             # dashboard
├── TASK-TEMPLATE.md      # szablon małego taska
└── PHASE-TEMPLATE.md     # szablon pliku fazy (dla dużych tasków)
```

---

## Naming

- Plik taska: `TASK-NNN_kebab-case-slug.md` (leading zeros, NNN od 001)
- Katalog dużego taska: `TASK-NNN_files/` (obok pliku taska, w tym samym folderze statusowym)
- Plik fazy: `phase-NN.md` (od 01)
- Masterplan: `MASTERPLAN.md`

---

## Mały task — kiedy używać

Wszystko co zmieści się w jednej sesji czatu. Jeden plik `.md`, bez podkatalogów.

**Flow:**
1. Utwórz `TASK-NNN_slug.md` w `ready-to-work/` wg szablonu
2. Zaktualizuj `STATUS.md`
3. Kiedy zaczynam: przenieś do `in-progress/`
4. Kiedy skończone: przenieś do `done/`, zaktualizuj `STATUS.md`

---

## Duży task — kiedy używać

Zadanie wymagające wielu kontekstów czatu lub złożonej analizy przed implementacją.

**Flow:**
1. Utwórz `TASK-NNN_slug.md` + `TASK-NNN_files/MASTERPLAN.md` w `ready-to-work/`
2. Zaktualizuj `STATUS.md`
3. Kiedy zaczynam: przenieś oba (plik + folder) do `in-progress/`
4. Każda faza: nowy plik `TASK-NNN_files/phase-NN.md` wg szablonu
5. Kiedy skończone: przenieś do `done/`, zaktualizuj `STATUS.md`

**MASTERPLAN.md** zawiera:
- Cel i success criteria całego taska
- Zależności od innych tasków
- Kolejność faz z krótkim opisem każdej

**phase-NN.md** zawiera:
- Plan kroków dla tej fazy
- Notatki z wykonania (decyzje, problemy)
- SHA commita po ukończeniu

---

## Zmiana statusu

Folder określa status — nie ma pola Status do aktualizowania.

```
# Przenieś task do in-progress
mv .claude/tasks/ready-to-work/TASK-001_foo.md .claude/tasks/in-progress/
mv .claude/tasks/ready-to-work/TASK-001_files/ .claude/tasks/in-progress/  # jeśli istnieje

# Przenieś task do done
mv .claude/tasks/in-progress/TASK-001_foo.md .claude/tasks/done/
mv .claude/tasks/in-progress/TASK-001_files/ .claude/tasks/done/  # jeśli istnieje
```

Zaktualizuj `STATUS.md` ręcznie po każdym przeniesieniu.

---

## Konwencja commitów

```
feat(TASK-NNN): krótki opis zmiany
fix(TASK-NNN): krótki opis
docs(TASK-NNN): krótki opis
refactor(TASK-NNN): krótki opis
```

Dla zmiany statusu taska (bez kodu):
```
task(TASK-NNN): move to done
```

---

## STATUS.md

Ręcznie aktualizowany dashboard. Format:

```markdown
# Task Status

**Last Updated**: YYYY-MM-DD

## Ready to Work
- **TASK-NNN**: Opis (priority)

## In Progress
- **TASK-NNN**: Opis — Started: YYYY-MM-DD

## Done
- **TASK-NNN**: Opis — Done: YYYY-MM-DD

## Statystyki
- Łącznie: N
- Ukończone: N
```

---

## Research & Analysis

Przy research API, frameworków lub bibliotek — zawsze używaj zewnętrznych źródeł, nie tylko wiedzy treningowej.

| Sytuacja | Narzędzie |
|----------|-----------|
| Apple API (SwiftUI, UIKit, Combine, Screen Time, ManagedSettings…) | Context7 + WebSearch równolegle |
| 3rd party lib (swift-navigation, Swinject…) | Context7 first, WebSearch jeśli niewystarczające |
| Niezindeksowane / nowe API / błąd Context7 | WebSearch |

**Workflow:**
1. `resolve-library-id` → znajdź library ID w Context7
2. `query-docs` → pobierz dokumentację
3. Jeśli Context7 nie daje pełnego obrazu → uzupełnij WebSearch
4. Dla Apple APIs: oba narzędzia równolegle od razu

---

## Archiwum: system fazowy

Projekt wcześniej używał systemu 7 komend fazowych (`/phase-discuss`, `/phase-plan`, itp.).
Artefakty ukończonych faz 1 i 01.1 żyją w `.planning/phases/` — zachowane jako archiwum.
ROADMAP.md pozostaje jako czytelny przegląd projektu (nie napędza już workflow).
