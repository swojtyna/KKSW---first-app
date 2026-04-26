# TASK-008: Usprawnienie testów — Swift Testing Agent Skill

**Status**: done
**Created**: 2026-04-26
**Size**: large
**Priority**: medium

---

## Opis

Dodać Swift Testing Agent Skill do projektu, przejrzeć istniejące testy, ocenić ich jakość i pokrycie, następnie usprawnić słabe miejsca. Zaktualizować odpowiednie guide.

## Kryteria akceptacji

- [ ] Swift Testing Agent Skill zainstalowany i skonfigurowany (https://github.com/AvdLee/Swift-Testing-Agent-Skill)
- [ ] Przegląd istniejących testów — lista co jest, co jest słabe, czego brakuje
- [ ] Testy poprawione lub dopisane tam gdzie to konieczne
- [ ] `.claude/guides/xcodebuild-mcp/GUIDE.md` lub nowy guide testów zaktualizowany o wzorce testowania
- [ ] Wszystkie testy przechodzą (`test_sim`)

## Zależności

- Depends on: brak
- Blocks: brak

## Uwagi

- Skill: https://github.com/AvdLee/Swift-Testing-Agent-Skill — przeczytaj README przed instalacją
- Sprawdź czy projekt używa XCTest czy Swift Testing framework (lub mix)
- Przejrzyj testy pod kątem: czy testują właściwą warstwę, czy mockują poprawnie, czy są czytelne
- Skup się na testach domenowych (UseCase, Repository) — tam jest największa wartość

## Guides do wczytania przed startem

- [ ] `.claude/guides/architecture/GUIDE.md`
- [ ] `.claude/guides/dependency-injection/GUIDE.md`
- [ ] `.claude/guides/xcodebuild-mcp/GUIDE.md`
