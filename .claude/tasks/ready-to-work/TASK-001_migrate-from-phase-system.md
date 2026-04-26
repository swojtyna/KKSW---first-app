# TASK-001: Migrate from phase system

**Status**: ready-to-work
**Created**: 2026-04-26
**Size**: large
**Priority**: high

---

## Opis

Projekt ma istniejący system fazowy (ROADMAP.md z fazami 2–6 + PLAN.md pliki + `.planning/` artefakty) i nowo wprowadzony system TASK-XXX. Trzeba zdecydować co zrobić ze starymi artefaktami i czy/jak migrować plany do formatu TASK.

## Kryteria akceptacji

- [ ] Decyzja podjęta: co się dzieje z ROADMAP.md (archiwum vs konwersja na taski)
- [ ] Decyzja podjęta: co się dzieje z istniejącymi PLAN.md dla faz 2–6 (przepakowujemy w _files/ vs zostawiamy w .planning/)
- [ ] Ewentualna migracja przeprowadzona (lub świadoma decyzja "nie migrujemy")
- [ ] `.planning/` zachowane lub przeniesione zgodnie z decyzją

## Kontekst

**Fazy 1 i 01.1**: ukończone — kod zaimplementowany, artefakty w `.planning/phases/01-*/` i `.planning/phases/01.1-*/`

**Fazy 2–6**: plany zapisane (PLAN.md istnieją w `.planning/phases/02-*/` itd.), ale żaden kod nie napisany. Szczegóły faz:
- Phase 2: App Selection (7 planów, SEL-01..SEL-05)
- Phase 3: Quick Sessions (7 planów, QSN-01..QSN-06) — core value
- Phase 4: Shield Customization (7 planów, SHL-01..SHL-04)
- Phase 5: Scheduled Blocking (8 planów, SCH-01..SCH-04)
- Phase 6: Engagement Layer (5 planów, GAM-01/02 + NTF-01/02)

## Zależności

- Depends on: brak (można zacząć natychmiast)
- Blocks: brak (nowe TASK-XXX możemy tworzyć równolegle bez migracji)

## Uwagi

- Nie spiesz się — możemy pracować na nowym systemie TASK-XXX bez migracji i wrócić tu kiedy wygodnie
- `.planning/` artefakty dla ukończonych faz (1, 01.1) mają wartość historyczną — nie kasować
- ROADMAP.md jako dokument poglądowy projektu jest nadal wartościowy niezależnie od decyzji workflow
