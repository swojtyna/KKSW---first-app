# TASK-005: Tłumaczenia — lokalizacja aplikacji

**Status**: ready-to-work
**Created**: 2026-04-26
**Size**: large
**Priority**: medium

---

## Opis

Dodać obsługę wielu języków. Przenieść i dostosować instrukcję lokalizacji z innego projektu, zaktualizować guide w tym projekcie, zaimplementować tłumaczenia dla 4 języków: polski + 3 najpopularniejsze (angielski, hiszpański, chiński lub arabski).

## Kryteria akceptacji

- [ ] Guide lokalizacji z ios-template-app przeniesiony i dostosowany do tego projektu
- [ ] `.claude/guides/` uzupełniony o guide lokalizacji
- [ ] Wszystkie stringi w aplikacji używają `String(localized:)` lub `LocalizedStringKey`
- [ ] 4 języki skonfigurowane: polski, angielski + 2 inne popularne
- [ ] Tłumaczenia pokrywają wszystkie ekrany onboardingu i główne ekrany
- [ ] Testy przechodzą (`test_sim`)

## Zależności

- Depends on: brak
- Blocks: brak

## Uwagi

- Źródłowy guide: `/Users/swojtyna/Documents/code/swojtyna/ios-template-app/.ai/guides/localization`
- Dostosować do tego projektu (inna struktura, XcodeGen zamiast ręcznego .xcodeproj)
- 3 najpopularniejsze języki globalne: angielski (bazowy), hiszpański, arabski lub chiński uproszczony
- Sprawdzić czy XcodeGen wymaga specjalnej konfiguracji dla plików `.xcstrings` / `.strings`

## Guides do wczytania przed startem

- [ ] `.claude/guides/feature-structure/GUIDE.md`
- [ ] `.claude/guides/xcodegen/GUIDE.md`
- [ ] `.claude/guides/xcodebuild-mcp/GUIDE.md`
