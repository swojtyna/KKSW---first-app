# Phase 01.1 — Architecture Foundation & DI Migration

Wejściowy kontekst dla `/gsd-discuss-phase`. Pełna mapa tarć, decyzji, ryzyk i kryteriów sukcesu, wypracowana w rozmowie poprzedzającej `/gsd-insert-phase`.

---

## Cel fazy

Przestawić projekt z układu warstwowego + ręcznej `DependencyContainer` factory na układ **feature-first** z **`DIContainer`** i jasnymi regułami zależności, zanim dołożymy Phase 2 i kolejne feature'y.

## Dlaczego teraz

- Obecny `.claude/guides/architecture/GUIDE.md` mówi wprost: *"No container framework, no service locator. Constructor injection via protocols."* Nowe wytyczne wprowadzają dokładnie `DIContainer` z `@LazyInjected`. Sprzeczność trzeba rozstrzygnąć w jednym miejscu, zanim rozjedzie się dokumentacja i kod.
- Istnieje już kod (Onboarding, Home, Denial, Root, `ScreenTimeAuthRepository` + `RequestScreenTimeAuthUseCase`) — przy 4 feature'ach refaktor jest tani, przy 12 drogi.
- Phase 2 (app selection) dołoży kolejną feature — jeśli pójdzie w starej strukturze, podwoi dług. `.planning/phases/02-app-selection/02-01-PLAN.md` (draft z przerwanego plannera) będzie wymagał regeneracji po tej fazie.

---

## Nowe reguły architektury (udokumentowane — discuss je tylko egzekwuje)

Spisane w `.claude/guides/architecture/GUIDE.md` i `.claude/guides/feature-structure/GUIDE.md`. Discuss nie renegocjuje tych reguł — wskazuje tylko, gdzie w konkretnym kodzie ich przestrzegać.

- **Feature jest całością** — Repository + UseCase + ViewModel + View w katalogu feature'a.
- **Współdzielenie między feature'ami tylko przez UseCase** — wspólny kod siedzi w `Common/` **feature-ownera** (feature, która pierwsza go wprowadziła). Brak globalnego `FeatureCommons/`.
- **Repozytoria nie wiedzą o innych repozytoriach.**
- **UseCase może wiedzieć o innych UseCase'ach i Repozytoriach** (nic więcej).
- **ViewModel wie tylko o UseCase'ach** — żadnego importu Repository, żadnych serwisów systemowych bezpośrednio.
- **View wie tylko o ViewModel'u.**

---

## Stan obecny (skrót)

### Co istnieje w kodzie
```
DeluluDetox/Sources/
├── App/
│   ├── DeluluDetoxApp.swift
│   └── DependencyContainer.swift            ← ręczna factory, do usunięcia
├── Data/Repositories/
│   └── ScreenTimeAuthRepositoryImpl.swift
├── Domain/
│   ├── Repositories/ScreenTimeAuthRepository.swift
│   └── UseCases/RequestScreenTimeAuthUseCase.swift
├── DesignSystem/Theme.swift
└── Features/
    ├── Denial/        (View + ViewModel — używa RequestScreenTimeAuthUseCase)
    ├── Home/          (View + ViewModel — pusty VM)
    ├── Onboarding/    (View + ViewModel — używa RequestScreenTimeAuthUseCase)
    └── Root/          (AppRootView + AppRootViewModel)
DeluluDetoxTests/
├── AppRootViewModelTests.swift
├── OnboardingViewModelTests.swift
└── Mocks/MockScreenTimeAuthRepository.swift
Extensions/
├── DeviceActivityMonitorExtension/
├── ShieldActionExtension/
└── ShieldConfigurationExtension/
```

### Co dostarcza `to_integrate/`
- `to_integrate/DependencyInjection/DIContainer.swift` — singleton, `NSRecursiveLock`, scope `.unique` / `.application`, factory pod `@MainActor`, `fatalError` przy braku rejestracji, `reset()` dla testów.
- `to_integrate/DependencyInjection/PropertyWrappers/{Injected.swift, LazyInjected.swift}` — property wrappers nad `DIContainer.shared`.
- `to_integrate/dependency-injection/GUIDE.md` — wzorce (Init Injection dla Repo/UC, `@LazyInjected` dla VM/Coordinator, distributed registration, testing).

### Kluczowe tarcia obecnego kodu z nowymi regułami
- `Features/Onboarding` i `Features/Denial` **dzielą `RequestScreenTimeAuthUseCase`**. Zgodnie z `feature-structure/GUIDE.md`: UC ląduje w `Features/Onboarding/Common/UseCase/` (Onboarding = feature-owner, pierwsze użycie). Samo `ScreenTimeAuthRepository` idzie do `Features/Onboarding/Common/Repository/`. Denial wstrzykuje **tylko UC**, nie repo.
- `HomeViewModel()` — pusty, żadnych zależności. Reguła "VM wie tylko o UseCase" w trywialnym przypadku wymusiłaby sztuczny UseCase. Otwarta decyzja (niżej, #3).
- `DependencyContainer` (ręczna factory, konstruktor DI) — do wymiany na `DIContainer` (singleton + `@LazyInjected`). Sprzeczność z poprzednim guide'em ("no service locator") rozwiązana — nowy `architecture/GUIDE.md` wprowadza `DIContainer` jako kontrolowany wyjątek, szczegóły w `dependency-injection/GUIDE.md`.

---

## Zakres — warstwa dokumentów

1. **Przepisać `.claude/guides/architecture/GUIDE.md`:**
   - Sekcja *File layout* → feature-first (`Features/<Feature>/{Data,Domain,Presentation}/`) + `FeatureCommons/`.
   - Nowa sekcja **Dependency rules** z czterema zasadami (Repo ↛ Repo, UseCase → UseCase/Repo, VM → tylko UseCase, View → tylko VM).
   - Nowa sekcja **FeatureCommons** — co tam trafia, a co nie.
   - Sekcja *Dependency Injection* → odesłanie do nowego guide'a DI; wywalić zdanie "No container framework, no service locator".
   - Sekcja *Decision tree* zaktualizowana pod feature-first.
   - Pitfall "ViewModel importuje Repository" dodany do listy.
2. **Przenieść `to_integrate/dependency-injection/GUIDE.md` → `.claude/guides/dependency-injection/GUIDE.md`:**
   - Zamienić przykłady (`DashboardRepositoryImpl`, `FearGreed…`) na realia DeluluDetox (`ScreenTimeAuthRepositoryImpl`, `RequestScreenTimeAuthUseCase`).
   - Usunąć martwe linki: `localization/GUIDE.md`, `repository/GUIDE.md`, `testing/GUIDE.md`, `swift-concurrency/GUIDE.md`.
   - Zastąpić je: istniejące guide'y + odesłanie do skilla `swift-concurrency:swift-concurrency`.
   - Opisać konwencję `<Feature>Injection.swift` w układzie feature-first (gdzie plik leży, jak jest wołany).
3. **Zaktualizować `.claude/guides/README.md`** (indeks — dodać wpis DI).
4. **Zaktualizować `CLAUDE.md`:**
   - Sekcja *Project Rules → Architecture* — nowe reguły, wzmianka o `FeatureCommons`.
   - *Quick Reference* — dodać wiersz dla DI.
   - Usunąć ewentualne sformułowania sprzeczne z `DIContainer`.

## Zakres — warstwa kodu

5. **Zintegrować pliki DI** z `to_integrate/DependencyInjection/` do projektu (docelowa lokalizacja do ustalenia w discuss — np. `DeluluDetox/Sources/Core/DependencyInjection/`).
6. **Zaktualizować `project.yml`** (XcodeGen) pod nowe katalogi; `xcodegen generate`.
7. **Przeorganizować istniejące źródła w feature-first:**
   - `Features/Onboarding/{Presentation,Domain,Data}/…`
   - `Features/Home/…`, `Features/Denial/…`, `Features/Root/…`
   - `FeatureCommons/UseCases/RequestScreenTimeAuthUseCase.swift` (używany przez Onboarding + Denial).
   - Lokalizacja `ScreenTimeAuthRepository` / `…Impl` — decyzja w discuss (patrz niżej).
8. **Dodać `<Feature>Injection.swift`** per feature (distributed registration).
9. **Usunąć `DeluluDetox/Sources/App/DependencyContainer.swift`**, podmienić wiring w `DeluluDetoxApp.swift` — rejestracja w `DIContainer` przy starcie.
10. **Przepisać testy:**
    - `AppRootViewModelTests`, `OnboardingViewModelTests` pod `DIContainer` + `@LazyInjected` (vertical slice z `DIContainer.reset()` w `setUp`).
    - `MockScreenTimeAuthRepository` — zachować, użyć w init injection.
11. **Usunąć katalog `to_integrate/`** jako ostatni krok.

---

## Poza zakresem (świadomie)

- Zmiany funkcjonalne w feature'ach — Onboarding, Home, Denial zachowują dotychczasowe zachowanie.
- `DeviceActivityMonitorExtension`, `ShieldActionExtension`, `ShieldConfigurationExtension` — rozszerzenia z limitem 6 MB RAM i ograniczeniami Shield API; dotykamy tylko jeśli importują coś z app targetu (do sprawdzenia).
- Phase 2 (app selection) — osobna faza, po tej.
- Wprowadzanie nowych feature'ów, nowych ekranów, zmian w UI.

---

## Otwarte decyzje dla `/gsd-discuss-phase`

### Zamknięte przed discuss (udokumentowane w guide'ach)

1. ~~**Współdzielone Repository między feature'ami.**~~ **Zamknięte.** Zgodnie z `feature-structure/GUIDE.md`: repo żyje w **feature-ownerze** (pierwszym użytkowniku), w jego `Common/Repository/`. Inne feature'y konsumują tylko UC z `Common/UseCase/`. Dla `ScreenTimeAuthRepository` feature-owner = **Onboarding**. Nie ma globalnego `FeatureCommons/`.
2. ~~**Wewnętrzna struktura feature'a.**~~ **Zamknięte.** `feature-structure/GUIDE.md` definiuje dwa warianty: **Simple** (1 ekran) i **Split** (`Common/` + subfoldery per ekran, gdy 2+ ekrany dzielą kod). Dla obecnych 4 feature'ów z 1 ekranem na feature → Simple; dla Onboarding (który współdzieli UC z Denial) → Split z `Common/`. Podwarstwy `{Data,Domain,Presentation}/` **odrzucone** na rzecz folderów per typ pliku (`Repository/`, `UseCase/`, `ViewModel/`, `View/`, `Injection/`).

### Do rozbrojenia w discuss

3. **VM → tylko UseCase nawet przy trywialnym passthrough?** `HomeViewModel()` dziś nic nie robi. Trzymać regułę twardo (wymusić UseCase), czy dopuścić wyjątek "VM bez danych = bez UC"? `architecture/GUIDE.md` skłania się w stronę twardej reguły (spójność kontraktu), ale dla pustego VM w praktyce jest to pusty UC — do ustalenia.
4. **`DIContainer.shared` vs injected container.** `dependency-injection/GUIDE.md` używa singletona + `@LazyInjected`. Obecny `CLAUDE.md` (przed tym commitem) zabraniał globali — po commicie dokumentów dopuszcza `DIContainer` jako jawny, kontrolowany wyjątek. Sformalizować w discuss: w jakich okolicznościach inny singleton jest OK (odpowiedź powinna być: w żadnych poza `DIContainer`).
5. **Rejestracja:** jednorazowa w `App.init()` (wszystkie feature'y od razu) vs leniwa per feature przy pierwszym resolve. Wpływa na start-up time, testy, kolejność rejestracji. `dependency-injection/GUIDE.md` pokazuje przykład jednorazowy — ale to nie jest twarda decyzja.
6. **Scope dla ViewModeli w DI.** Guide mówi "not registered" dla VM (wrapper rezolwuje UC). To OK — potwierdzić w discuss i dopilnować, że plan egzekucji nie rejestruje VM niechcący.

---

## Ryzyka

- **Swift 6.2 strict concurrency** + `@unchecked Sendable` + `MainActor.assumeIsolated` w `DIContainer` — może wymagać drobnych poprawek pod iOS 26 / Swift 6.2. Do weryfikacji przez XcodeBuildMCP w trakcie integracji.
- **Testy na `DIContainer.shared`** — ryzyko kolizji między testami bez `reset()` w `tearDown`. Wzorzec trzeba zakodować w guide testowym.
- **XcodeGen** — przenoszenie plików między katalogami wymaga precyzyjnej aktualizacji `sources:` w `project.yml`; przeoczenie ścieżki = target nie kompiluje.
- **Rozszerzenia targetów** (DeviceActivityMonitor/Shield) — mają własny target w `project.yml`, nie biorą z app targetu. Jeśli dotąd nie importują nic z głównego modułu, refaktor ich nie dotyczy. Sprawdzić na wejściu.
- **Regeneracja `02-01-PLAN.md`** — Phase 2 planner zdążył zacząć pisać plan pod starą architekturę. Po tej fazie trzeba go wyrzucić i odpalić `/gsd-plan-phase 02` od nowa.

---

## Kryteria sukcesu (Nyquist)

- Istniejące testy przechodzą (`AppRootViewModelTests`, `OnboardingViewModelTests`).
- App buduje się i startuje na symulatorze (XcodeBuildMCP `build_run_sim`).
- Onboarding → auth → Home — przepływ działa ręcznie, zachowanie identyczne jak przed refaktorem.
- `grep -r "Repository" DeluluDetox/Sources/Features/*/Presentation/*ViewModel.swift` → 0 trafień (VM nie importuje repo).
- `grep -r "import.*Repository" DeluluDetox/Sources/**/*RepositoryImpl.swift` (cross-references) → 0 trafień (repo ↛ repo).
- `DeluluDetox/Sources/App/DependencyContainer.swift` — usunięty.
- Katalog `to_integrate/` — nie istnieje.
- `.claude/guides/architecture/GUIDE.md` i `.claude/guides/dependency-injection/GUIDE.md` — spójne; żadnych sprzeczności typu "no container" vs `DIContainer`.
- `CLAUDE.md` — nie zawiera już sformułowań zabraniających service locatora; zawiera wiersz DI w Quick Reference.

---

## Sugerowana kolejność planowania

1. `/gsd-discuss-phase 01.1` — rozbić 6 otwartych decyzji.
2. `/gsd-plan-phase 01.1` — plan podzielony na bloki: (a) docs/guide'y, (b) integracja `DIContainer`, (c) refaktor feature-first per feature, (d) testy, (e) cleanup `to_integrate/` + starej factory.
3. `/gsd-execute-phase 01.1`.
4. `/gsd-verify-work 01.1`.
5. Potem: usunąć `.planning/phases/02-app-selection/02-01-PLAN.md` (stary draft) i `/gsd-plan-phase 02` od nowa — już na nowej architekturze.
