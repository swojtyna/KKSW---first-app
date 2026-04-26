# TASK-006: Large titles — weryfikacja wzorca iOS

**Status**: ready-to-work
**Created**: 2026-04-26
**Size**: small
**Priority**: low

---

## Opis

Każdy ekran ma `navigationBarTitleDisplayMode(.large)`. Trzeba zbadać czy to jest poprawny wzorzec na iOS (HIG, Apple guidelines), czy tak powinno wyglądać w tej aplikacji, i ewentualnie ujednolicić.

## Kryteria akceptacji

- [ ] Zbadano iOS HIG w kwestii large vs inline titles (kiedy co stosować)
- [ ] Decyzja podjęta i opisana (zostawiamy / zmieniamy / mix)
- [ ] Jeśli zmiana — wszystkie ekrany zaktualizowane spójnie
- [ ] Testy przechodzą (`test_sim`)

## Zależności

- Depends on: brak
- Blocks: brak

## Uwagi

- Wzorzec Apple: large title zwykle tylko na root ekranie sekcji, inline na zagłębionych
- Sprawdź przez WebSearch + Context7 jak inne aplikacje iOS 26 to robią
- Może wystarczyć tylko decyzja + ewentualnie mała poprawka

## Guides do wczytania przed startem

- [ ] `.claude/guides/architecture/GUIDE.md`
- [ ] `.claude/guides/xcodebuild-mcp/GUIDE.md`
