# TASK-004: Kalendarz na harmonogramie — HorizonCalendar

**Status**: ready-to-work
**Created**: 2026-04-26
**Size**: large
**Priority**: medium

---

## Opis

Obecny kalendarz na ekranie harmonogramu wymaga poprawy. Rozważyć użycie biblioteki HorizonCalendar (Airbnb) i dostosowanie jej wyglądu do stylu aplikacji. Przed implementacją zbadać możliwości customizacji.

## Kryteria akceptacji

- [ ] Analiza HorizonCalendar ukończona (możliwości customizacji, integracja ze SwiftUI)
- [ ] Decyzja: HorizonCalendar vs inne rozwiązanie — zatwierdzona przez użytkownika
- [ ] Kalendarz wygląda zgodnie z designem aplikacji
- [ ] Testy przechodzą (`test_sim`)

## Zależności

- Depends on: brak
- Blocks: brak

## Uwagi

- HorizonCalendar: https://github.com/airbnb/HorizonCalendar
- Zbadaj czy biblioteka działa dobrze ze SwiftUI (jest UIKit-first)
- Kluczowe: czy da się dostosować wygląd do Liquid Glass / design systemu aplikacji
- Dodanie do Package.swift wymaga aktualizacji project.yml (XcodeGen)

---

## Research (2026-04-26) — wyniki analizy, zadanie wstrzymane

### Co znaleziono w kodzie

Nie ma jednego "kalendarza harmonogramu" — są dwa miejsca z widokami dat:

1. **Zakładka Staty** (`StatsView` + `StatsViewModel`) — siatka miesięczna `LazyVGrid` (pure SwiftUI, ~40 linii). Read-only, pokazuje dni z ukończonymi sesjami focusowymi. Ma prev/next nawigację po miesiącach.
2. **Zakładka Plan** (`ScheduleEditorView`) — 7 chipów dni tygodnia (Pn–Nd) + wheel DatePicker godzin. To NIE jest kalendarz — to formularz harmonogramu cyklicznego.

### Rekomendacja dot. HorizonCalendar

**Nie używać HorizonCalendar.** Powody:
- UIKit-based (`UICollectionView`) — brak natywnej integracji z Liquid Glass (iOS 26 `.glassEffect()`)
- Overkill — biblioteka jest pod date-range selection i booking UI; tu mamy prosty read-only grid
- Znane friction ze SwiftUI: toolbar disappears (#215), `.scroll()` nie działa przez wrapper (#211)
- Obecna implementacja w `StatsView` jest już czysta i w pełni kontrolowalna

Alternatywy jeśli potrzeba więcej możliwości: pure-SwiftUI `LazyVGrid` (obecne podejście) lub napisanie custom kalendarza od zera w SwiftUI — oba dają pełną kontrolę nad Liquid Glass.

### Otwarte pytania — do rozstrzygnięcia przed implementacją

1. **Gdzie ma być kalendarz?** W zakładce Staty (już istnieje), w zakładce Plan (nie istnieje), czy w obu miejscach?
2. **Co ma robić?** Read-only (historia sesji jak teraz) / interaktywny wybór dat / wizualizacja kiedy harmonogramy są aktywne?
3. **Jaki kierunek wizualny?**
   - Liquid Glass card (`.glassEffect()` na karcie)
   - Animacje przejść między miesiącami (slide left/right)
   - Streak highlight (ciągły pasek łączący dni w streak)
   - Heat map (intensywność koloru zależna od liczby sesji — wymaga zmiany modelu `Stats`)
4. **Czy model danych wymaga zmian?** Obecny `Schedule` operuje na `daysOfWeek: [Int]` (cyklicznie). Jeśli chcemy blokować konkretne daty (np. 5 maja) — zmiana architektury.

### Pliki referencyjne

- `DeluluDetox/Sources/Features/Stats/View/StatsView.swift` — obecny kalendarz w Staty
- `DeluluDetox/Sources/Features/Stats/ViewModel/StatsViewModel.swift` — logika kalendarza
- `DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` — chipy dni tygodnia w Plan

## Guides do wczytania przed startem

- [ ] `.claude/guides/feature-structure/GUIDE.md`
- [ ] `.claude/guides/dependency-injection/GUIDE.md`
- [ ] `.claude/guides/xcodegen/GUIDE.md`
- [ ] `.claude/guides/xcodebuild-mcp/GUIDE.md`
