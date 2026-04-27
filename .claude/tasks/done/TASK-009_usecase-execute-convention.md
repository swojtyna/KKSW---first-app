# TASK-009 — UseCase: zamiana `callAsFunction` → `execute`

## Cel

Ujednolicenie konwencji: każdy UseCase ma jedną publiczną metodę `execute(...)` zamiast `callAsFunction(...)`. `callAsFunction` nie jest standardowym wzorcem w Swift — utrudnia nawigację (IDE nie podpowiada, grep nie trafia), a `execute` jasno wyraża intencję warstwy domenowej.

## Zakres

### Pliki UseCase (protokół + implementacja) — 34 pliki

Wszystkie pliki w `DeluluDetox/Sources/`:
- `Features/Scheduling/Common/Repository/ScheduleProtocols.swift` (protokoły UseCase)
- `Features/Scheduling/Common/UseCase/*.swift` (7 plików)
- `Features/AppSelection/UseCase/*.swift` (4 pliki)
- `Features/Notifications/UseCase/*.swift` (6 plików)
- `Features/Stats/UseCase/*.swift` (2 pliki)
- `Features/Onboarding/UseCase/*.swift` (5 plików)
- `Features/Session/UseCase/*.swift` (8 plików)

**Zmiana:** `func callAsFunction(...)` → `func execute(...)` (w protokole i implementacji)

### Call sites — ViewModele i inne UseCase'y

Wszędzie tam, gdzie UseCase jest wywoływany jako funkcja (np. `reconcile()`, `observe()`, `finalize(now:)`), zmienić na `reconcile.execute()`, `observe.execute()`, `finalize.execute(now:)` itp.

Znane lokalizacje (grep po wzorcu call-site):
- `Features/Root/ViewModel/AppRootViewModel.swift` (linie ~136, 143, 195)
- Inne ViewModele i UseCase'y wewnątrz `Sources/`

### Testy — 35 wystąpień

`DeluluDetoxTests/` — analogicznie, `callAsFunction` w mockach/testach → `execute`.

### Dokumentacja

Sprawdzić i zaktualizować:
- `.claude/guides/architecture/GUIDE.md`
- `.claude/guides/feature-structure/GUIDE.md`
- `CONVENTIONS.md`

Jeśli któryś z guidów opisuje UseCase z `callAsFunction` → poprawić na `execute`.

## Kroki wykonania

1. Rename `callAsFunction` → `execute` we wszystkich protokołach UseCase.
2. Rename `callAsFunction` → `execute` we wszystkich implementacjach UseCase.
3. Zaktualizować wszystkie call sites (ViewModele, UseCase'y wołające inne UseCase'y) — `useCase(...)` → `useCase.execute(...)`.
4. Zaktualizować mocki i testy w `DeluluDetoxTests/`.
5. Kompilacja (`build_sim`) — wyjść z 0 błędami.
6. Testy (`test_sim`) — wszystkie zielone.
7. Zaktualizować dokumentację (guides + CONVENTIONS.md) jeśli wspominają `callAsFunction`.

## Definition of Done

- [ ] Zero wystąpień `callAsFunction` w plikach `.swift` projektu
- [ ] Kompilacja bez błędów
- [ ] Wszystkie testy zielone
- [ ] Dokumentacja spójna z nową konwencją
