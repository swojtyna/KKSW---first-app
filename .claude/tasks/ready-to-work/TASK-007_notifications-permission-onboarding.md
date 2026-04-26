# TASK-007: Prośba o uprawnienia powiadomień — fix w onboardingu

**Status**: ready-to-work
**Created**: 2026-04-26
**Size**: small
**Priority**: high

---

## Opis

Prośba o uprawnienia do powiadomień pojawia się zbyt wcześnie i bez kontekstu ("z dupy"). Trzeba przenieść ją na drugi krok onboardingu z ekranem wyjaśniającym użytkownikowi po co aplikacja potrzebuje uprawnień.

## Kryteria akceptacji

- [ ] Prośba o powiadomienia NIE pojawia się przy starcie aplikacji bez kontekstu
- [ ] W onboardingu (krok 2) jest ekran wyjaśniający po co potrzebne są powiadomienia
- [ ] Dopiero po wyjaśnieniu pojawia się systemowy dialog uprawnień
- [ ] Flow działa dla obu przypadków: zgoda i odmowa
- [ ] Testy przechodzą (`test_sim`)

## Zależności

- Depends on: brak
- Blocks: brak

## Uwagi

- Zlokalizuj gdzie aktualnie jest `UNUserNotificationCenter.requestAuthorization` — to tam trzeba zoperować
- Wzorzec: najpierw własny ekran ("Chcemy wysyłać Ci..."), potem systemowy dialog
- Sprawdź jak onboarding jest zbudowany (flow/kroki) żeby wstawić nowy krok we właściwym miejscu

## Guides do wczytania przed startem

- [ ] `.claude/guides/navigation/GUIDE.md`
- [ ] `.claude/guides/feature-structure/GUIDE.md`
- [ ] `.claude/guides/dependency-injection/GUIDE.md`
- [ ] `.claude/guides/xcodebuild-mcp/GUIDE.md`
