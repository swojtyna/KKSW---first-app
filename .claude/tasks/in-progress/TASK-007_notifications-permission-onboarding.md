# TASK-007: Prośba o uprawnienia powiadomień — fix w onboardingu

**Status**: in-progress
**Created**: 2026-04-26
**Size**: small
**Priority**: high

---

## Opis

Prośba o uprawnienia do powiadomień pojawia się zbyt wcześnie i bez kontekstu ("z dupy"). Trzeba przenieść ją na drugi krok onboardingu z ekranem wyjaśniającym użytkownikowi po co aplikacja potrzebuje uprawnień.

## Kryteria akceptacji

- [x] Prośba o powiadomienia NIE pojawia się przy starcie aplikacji bez kontekstu
- [x] W onboardingu (krok 2) jest ekran wyjaśniający po co potrzebne są powiadomienia
- [x] Dopiero po wyjaśnieniu pojawia się systemowy dialog uprawnień
- [x] Flow działa dla obu przypadków: zgoda i odmowa
- [x] Testy przechodzą (`test_sim`)

## Zależności

- Depends on: brak
- Blocks: brak

## Uwagi

- Zlokalizuj gdzie aktualnie jest `UNUserNotificationCenter.requestAuthorization` — to tam trzeba zoperować
- Wzorzec: najpierw własny ekran ("Chcemy wysyłać Ci..."), potem systemowy dialog
- Sprawdź jak onboarding jest zbudowany (flow/kroki) żeby wstawić nowy krok we właściwym miejscu

---

## Do poprawy (znalezione podczas code review)

### 1. Callback zamiast publishera — naruszenie Wzorca B
`OnboardingNotificationsViewModel` ma `var onCompletion: () -> Void = {}`. Guide nawigacji zabrania callbacków `onX` na VM w Wzorcu B. Poprawny flow: child zapisuje przez UC → Repository emituje `CurrentValueSubject` → parent subskrybuje i aktualizuje `destination`.

### 2. `notificationsOnboardingCompleted()` w złym pliku
Metoda jest czysto nawigacyjna (tylko `destination = .home`, zero UseCase). Per guide nawigacji powinna być w `AppRootViewModel+Destination.swift`, a trafiła do `AppRootViewModel.swift`.

---

## Workflow zamknięcia

- [ ] Napraw błędy z code review (patrz sekcja wyżej)
- [ ] `/review` — code review
- [ ] Poczekaj na akceptację użytkownika
- [ ] Przenieś task do `done/`
- [ ] Zaktualizuj `STATUS.md`
