# TASK-002 — Wydzielenie nawigacji do `+Destination.swift`

## Cel

Każdy ViewModel trzyma `enum Destination` i metody nawigacyjne (`goToX`, `dismiss` itp.) w tym samym pliku co UseCase'y i logikę biznesową. Chcemy rozdzielić te dwie role **fizycznie** — przez osobny plik `ViewModelName+Destination.swift` per ViewModel.

Architektura pozostaje bez zmian: `destination` nadal na ViewModel, View nadal `@Bindable var model`, testy bez zmian. To czysta reorganizacja plików.

## Konwencja nazewnictwa

```
HomeViewModel.swift                 ← biznes: UseCases, stan, var destination
HomeViewModel+Destination.swift     ← nawigacja: enum Destination, metody goToX()
```

## Co idzie do `+Destination.swift`

- `@CasePathable enum Destination` (z całą zawartością i Equatable)
- Wszystkie typy pomocnicze do Destination (np. `PickerSession` w HomeViewModel)
- Metody nawigacyjne (`func goToSessionStart()`, `func dismiss()` itp.)

## Co zostaje w głównym pliku

- `var destination: Destination?` — stored property, musi być w głównym pliku (ograniczenie Swift)
- UseCase'y, stan biznesowy, logika domenowa

## Pliki do zmiany (6 par)

| ViewModel | Nowy plik |
|---|---|
| `HomeViewModel.swift` | `HomeViewModel+Destination.swift` |
| `AppRootViewModel.swift` | `AppRootViewModel+Destination.swift` |
| `ScheduleListViewModel.swift` | `ScheduleListViewModel+Destination.swift` |
| `ScheduleEditorViewModel.swift` | `ScheduleEditorViewModel+Destination.swift` |
| `SessionStartViewModel.swift` | `SessionStartViewModel+Destination.swift` |
| `CountdownViewModel.swift` | `CountdownViewModel+Destination.swift` |

Wszystkie pliki w tym samym katalogu co ich ViewModel (`ViewModel/`).

## `project.yml` — nowe pliki

Każdy nowy `+Destination.swift` musi być dodany do `project.yml` (XcodeGen). Po zmianach: `xcodegen generate`.

## Aktualizacja guidów

- `navigation/GUIDE.md` — dodać sekcję o konwencji `+Destination.swift`

## Weryfikacja

1. `build_sim` — zero błędów kompilacji
2. `test_sim` — wszystkie testy przechodzą (bez zmian w testach)
3. Każdy ViewModel ma osobny `+Destination.swift` w tym samym katalogu

## Uwagi

- Testy **bez zmian** — sprawdzają `vm.destination` bezpośrednio, co nadal działa
- View **bez zmian** — `@Bindable var model`, bindingi na `$model.destination.*`
- Kolejność wykonania nie ma znaczenia — każdy ViewModel jest niezależny
