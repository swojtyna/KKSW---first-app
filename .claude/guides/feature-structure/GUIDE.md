---
summary: Feature-first layout — gdzie który plik żyje, kiedy tworzyć Common/
read_when: Creating new feature, splitting feature, deciding file location
complexity: medium
status: active
last_updated: 2026-04-18
---

# Feature Structure

Feature to całość: **Repository + UseCase + ViewModel + View** żyją blisko siebie, w katalogu feature'a. Ten guide odpowiada na "gdzie położyć nowy plik?" i "kiedy wydzielić `Common/`?".

Zasady zależności (kto może o kim wiedzieć) — patrz `.claude/guides/architecture/GUIDE.md`. Tu opisujemy **fizyczny układ plików**.

---

## Dwa warianty layoutu

Feature zaczyna jako **Simple**. Gdy rośnie do 2+ ekranów ze współdzielonym kodem — migrujemy do **Split**.

### Simple (1 ekran)

```
Features/<Feature>/
├── ViewModel/
│   └── <Feature>ViewModel.swift        // protokół + impl w jednym pliku
├── View/
│   └── <Feature>View.swift
├── UseCase/
│   └── <Action>UseCase.swift           // protokół + impl w jednym pliku
├── Repository/
│   ├── <Entity>Repository.swift        // protokół + impl w jednym pliku
│   └── Models/
│       └── <Entity>.swift              // domain model
└── Injection/
    └── <Feature>Injection.swift        // rejestracja w DIContainer
```

Przykład — Onboarding (stan po refaktorze fazy 01.1):

```
Features/Onboarding/
├── ViewModel/OnboardingViewModel.swift
├── View/OnboardingView.swift
├── UseCase/RequestScreenTimeAuthUseCase.swift
├── Repository/
│   ├── ScreenTimeAuthRepository.swift
│   └── Models/
│       └── ScreenTimeAuthStatus.swift
└── Injection/OnboardingInjection.swift
```

### Split (2+ ekrany, współdzielony kod)

```
Features/<Feature>/
├── Common/                             // kod współdzielony przez ekrany
│   ├── Repository/
│   │   ├── <Entity>Repository.swift
│   │   └── Models/<Entity>.swift
│   ├── UseCase/
│   │   └── <Action>UseCase.swift
│   └── Components/                     // współdzielone UI komponenty
│       └── <Component>.swift
├── <Screen1>/
│   ├── ViewModel/<Feature><Screen1>ViewModel.swift
│   └── View/<Feature><Screen1>View.swift
├── <Screen2>/
│   ├── ViewModel/...
│   └── View/...
└── Injection/<Feature>Injection.swift
```

**Uwaga:** `Common/` jest **lokalne dla feature'a**. Nie istnieje globalny `FeatureCommons/` — to anty-wzorzec (patrz niżej).

---

## Kiedy migrować Simple → Split

Trigger: **2+ ekrany w tym samym feature'ze** dzielą co najmniej jedno z:
- Repository,
- UseCase,
- model domenowy,
- komponent UI (kafelek, wykres, header).

Jeśli dwa ekrany są niezależne (każdy ma swoje repo/UC/model) — to nie jest jeden feature z dwoma ekranami, tylko dwa oddzielne feature'y. Nie wymuszaj `Common/`.

**Nie** migruj do Split profilaktycznie, "bo może kiedyś dojdzie drugi ekran". Split jest reakcją na konkretną duplikację, nie projektowaniem in-advance.

---

## Gdzie żyje Repository?

### Używane przez 1 feature

`Features/<Feature>/Repository/<Entity>Repository.swift`.

Protokół i implementacja **w tym samym pliku** — bez osobnego `Contracts/`:

```swift
// Features/Onboarding/Repository/ScreenTimeAuthRepository.swift

protocol ScreenTimeAuthRepository: Sendable {
    var status: ScreenTimeAuthStatus { get async }
    func requestAuthorization() async throws
}

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository {
    // ...
}
```

### Używane przez 2+ feature'ów

Repo mieszka **w feature'ze-właścicielu**, w jego `Common/Repository/`. Inne feature'y **nie sięgają do repo bezpośrednio** — konsumują jedynie UseCase (który też siedzi w `Common/UseCase/` feature'a-właściciela).

**Feature-owner** = feature, która pierwsza wprowadziła to repo. Reguła jest pragmatyczna, nie ma idealnej odpowiedzi "kto powinien posiadać". Jeśli po kilku tygodniach okaże się, że feature-owner jest mniejszym konsumentem — przenosimy repo do większego (osobny refaktor, osobny commit).

**Przykład — `ScreenTimeAuthRepository` używany przez Onboarding i Denial:**

```
Features/Onboarding/
├── Common/
│   ├── Repository/
│   │   ├── ScreenTimeAuthRepository.swift      // protokół + impl
│   │   └── Models/ScreenTimeAuthStatus.swift
│   └── UseCase/
│       └── RequestScreenTimeAuthUseCase.swift  // wywoływany z Onboarding i Denial
├── Main/                                       // ekran Onboarding główny
│   ├── ViewModel/...
│   └── View/...
└── Injection/OnboardingInjection.swift

Features/Denial/
├── ViewModel/DenialViewModel.swift             // zależy od RequestScreenTimeAuthUseCase
├── View/DenialView.swift
└── Injection/DenialInjection.swift
```

Denial wstrzykuje `RequestScreenTimeAuthUseCase` (protokół) przez DI — **nigdy `ScreenTimeAuthRepository`**. Reguła: między feature'ami tylko UC.

### Wiele źródeł danych / domen

Repo siedzi w `Repository/` root feature'a (lub `Common/Repository/` w Split). Jeśli jest kilka domen (np. różne systemowe API), dziel w podfolderach:

```
Repository/
├── ScreenTimeAggregateRepository.swift         // koordynator
├── Models/
│   ├── Authorization/
│   │   └── ScreenTimeAuthStatus.swift
│   └── Activity/
│       └── DeviceActivitySchedule.swift
└── Sources/
    ├── Authorization/
    │   └── ScreenTimeAuthSource.swift
    └── Activity/
        └── DeviceActivityScheduleSource.swift
```

Repository zawsze na **root-level** — agreguje wiele źródeł, stoi ponad podziałem na domeny.

---

## Gdzie żyje UseCase?

Analogicznie do Repository:

- Używane przez 1 feature → `Features/<Feature>/UseCase/<Action>UseCase.swift`.
- Używane przez 2+ feature'ów → `Features/<Feature-owner>/Common/UseCase/<Action>UseCase.swift`.

Protokół + impl w tym samym pliku. Nazywamy po akcji (`RequestScreenTimeAuthUseCase`), nie po warstwie (`ScreenTimeAuthService`).

UseCase może zależeć od innych UseCase'ów i od Repozytoriów (patrz dependency rules w `architecture/GUIDE.md`). Nigdy od ViewModeli, Views, ani od systemowych API bezpośrednio.

---

## Gdzie żyje ViewModel / View?

- **Simple:** `Features/<Feature>/ViewModel/<Feature>ViewModel.swift` + `View/<Feature>View.swift`.
- **Split:** w subfolderze ekranu: `Features/<Feature>/<Screen>/ViewModel/<Feature><Screen>ViewModel.swift` + `View/<Feature><Screen>View.swift`.

Nawet w Simple trzymaj je w folderach `ViewModel/` i `View/` (nie płasko) — ułatwia późniejszy rozrost do Split bez przenoszenia plików.

ViewModel **nigdy** nie importuje Repository. Depenence tylko na UC.

View **nigdy** nie importuje UC ani Repository. Dependence tylko na ViewModel.

---

## Domain models

Model to zwykły `struct` / `enum`. Siedzi obok repo, które go produkuje:

```
Repository/
├── ScreenTimeAuthRepository.swift
└── Models/
    └── ScreenTimeAuthStatus.swift
```

Przy wielu domenach — podfolder per domena (jak w sekcji "Wiele źródeł").

Model jest **Sendable** i plain Swift — nie importuj SwiftUI, nie importuj frameworków systemowych do pól.

---

## Injection

Każdy feature ma własny `<Feature>Injection.swift` w `Features/<Feature>/Injection/`. Plik rejestruje graf feature'a w `DIContainer`:

```swift
// Features/Onboarding/Injection/OnboardingInjection.swift

enum OnboardingInjection {
    static func register(in container: DIContainer) {
        container.register(ScreenTimeAuthRepository.self, scope: .application) { _ in
            ScreenTimeAuthRepositoryImpl()
        }
        container.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { c in
            RequestScreenTimeAuthUseCaseImpl(repository: c.resolve())
        }
    }
}
```

Rejestracja wołana przy starcie aplikacji (lub leniwie per feature — decyzja w CONTEXT fazy 01.1). Szczegóły: `.claude/guides/dependency-injection/GUIDE.md`.

---

## Anti-patterns

### ❌ Globalny `FeatureCommons/` dla repozytoriów

```
FeatureCommons/            ← nie istnieje
├── Repositories/
│   └── ScreenTimeAuthRepository.swift
└── UseCases/
    └── RequestScreenTimeAuthUseCase.swift
```

**Dlaczego nie:** rozmywa ownership, zachęca feature'y do sięgania po repo bezpośrednio (łamie regułę "między feature'ami tylko UC"). Współdzielenie idzie przez feature-owner'a.

### ❌ Przeniesienie zbyt dużo do `Common/`

```
Common/Repository/Models/
├── OnboardingStep.swift      ← używane tylko przez Main
└── ScreenTimeAuthStatus.swift  ← faktycznie współdzielone
```

Do `Common/` trafia **tylko** to, co rzeczywiście jest używane przez 2+ ekrany. Plik używany przez 1 ekran zostaje w subfolderze tego ekranu.

### ❌ Osobny folder `Contracts/` / `Protocols/`

```
Repository/
├── Contracts/
│   └── ScreenTimeAuthRepositoryProtocol.swift    ← nie
└── Implementations/
    └── ScreenTimeAuthRepositoryImpl.swift
```

Protokół żyje **w tym samym pliku** co impl. Jeden plik = jeden typ domenowy + jego protokół. Zmniejsza nawigację, ułatwia czytanie, unika rozjazdu nazw.

### ❌ ViewModel importujący Repository

```swift
// Features/Home/ViewModel/HomeViewModel.swift
import Foundation

@Observable
final class HomeViewModel {
    private let repository: BlockedAppsRepository     ← nie
    // ...
}
```

ViewModel zależy tylko od UseCase. Jeśli repo ma trywialny passthrough — zrób trywialny UseCase albo rozważ, czy ten ekran w ogóle potrzebuje repo (patrz `architecture/GUIDE.md` → decision tree).

### ❌ Repository importujące inne Repository

Repozytoria się nie znają. Jeśli potrzebujesz "coś jak repo, ale łączące dwa źródła" — to jest UseCase. UC bierze dwa repozytoria i łączy.

---

## Decision table — gdzie nowy plik?

| Co dodaję | Gdzie idzie |
|-----------|-------------|
| Nowy ekran w ramach istniejącej feature'y | Simple → Split: nowy `<Screen>/` subfolder + wydzielenie `Common/` jeśli powstaje duplikacja |
| Zupełnie nowa feature | `Features/<NewFeature>/` — zacznij od Simple |
| Repo używane tylko w jednym feature'ze | `Features/<Feature>/Repository/` (Simple) lub `.../Common/Repository/` (Split) |
| Repo, które potrzebują 2 feature'y | `Features/<Feature-owner>/Common/Repository/` + publiczny UC w `Common/UseCase/` |
| UseCase w jednym feature'ze | `Features/<Feature>/UseCase/` lub `.../Common/UseCase/` (jeśli Split) |
| UseCase współdzielony | `Features/<Feature-owner>/Common/UseCase/` |
| Model domenowy | `Repository/Models/` obok repo, które go produkuje |
| Komponent UI używany w 2+ ekranach tego samego feature'a | `Features/<Feature>/Common/Components/` |
| Komponent UI używany w 2+ feature'ach | Design system (przyszła faza — na razie kopiuj, żeby nie blokować) |
| Rejestracja DI | `Features/<Feature>/Injection/<Feature>Injection.swift` |

---

## Checklist przed commitem nowej feature'y / refaktoru

- [ ] Protokół repo/UC w tym samym pliku co impl (bez `Contracts/`).
- [ ] Brak `FeatureCommons/` na poziomie globalnym.
- [ ] `Common/` użyty tylko wtedy, gdy 2+ ekrany faktycznie dzielą kod.
- [ ] Żaden ViewModel nie importuje Repository (grep: `import.*Repository` w plikach `*ViewModel.swift`).
- [ ] Żadne repo nie importuje innego repo.
- [ ] `<Feature>Injection.swift` zarejestrował wszystkie nowe typy.
- [ ] `project.yml` (XcodeGen) zaktualizowany o nowe ścieżki.
- [ ] `xcodegen generate` wykonany.

---

## Related

- Zasady zależności i dlaczego: `.claude/guides/architecture/GUIDE.md`
- DI i property wrappers: `.claude/guides/dependency-injection/GUIDE.md`
- Nawigacja (gdzie siedzi `Destination?`): `.claude/guides/navigation/GUIDE.md`
- XcodeGen (aktualizacja `project.yml` po refaktorze): `.claude/guides/xcodegen/GUIDE.md`

---

**Last Updated**: 2026-04-18
