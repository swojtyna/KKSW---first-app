---
summary: Clean Architecture (MVVM + UseCase + Repository) — warstwy i reguły zależności
read_when: Designing a new feature, adding a screen, or wiring data flow
complexity: medium
status: active
last_updated: 2026-04-18
---

# Architecture

Projekt stosuje **Clean Architecture** z **MVVM** w prezentacji, **UseCase'ami** w domenie i **Repozytoriami** w danych. **SOLID, KISS, DRY** — żadna warstwa ani abstrakcja bez konkretnego powodu.

Ten guide opisuje **warstwy i reguły zależności** — co może o czym wiedzieć.

- Fizyczny układ plików per feature → `.claude/guides/feature-structure/GUIDE.md`
- Wstrzykiwanie zależności → `.claude/guides/dependency-injection/GUIDE.md`

---

## Layers

```
┌─────────────────────────────────────────┐
│ Presentation    View + ViewModel        │  SwiftUI, @Observable
├─────────────────────────────────────────┤
│ Domain          UseCase + Entity        │  Pure Swift, brak frameworków
├─────────────────────────────────────────┤
│ Data            Repository + Source     │  Systemowe API, persistencja, App Group
└─────────────────────────────────────────┘
         ▲ zależności kierują się w górę
```

**Reguły kierunku:**
- Domain nie wie o Presentation ani Data.
- Data implementuje protokoły z Domain (dependency inversion).
- View importuje SwiftUI; ViewModel **nie** (poza `Observation`).
- Dane przekazujemy jako plain Swift types (`struct`, `enum`) — nigdy typy SwiftUI.

---

## Dependency rules

Cztery twarde reguły, egzekwowane w code review:

1. **Repository ↛ Repository.** Żadne repo nie wie o innym repo. Jeśli potrzebujesz łączyć dane z dwóch źródeł — to jest rola UseCase'a (bierze 2 repozytoria i łączy).
2. **UseCase → UseCase / Repository.** UC może zależeć od innych UC'ów i od Repozytoriów. Od niczego więcej — szczególnie nie od systemowych API bezpośrednio (te siedzą w Repository lub źródle pod Repository).
3. **ViewModel → tylko UseCase.** VM nie importuje Repository, nie sięga do `UserDefaults` / `FileManager` / `ManagedSettingsStore` bezpośrednio, nie importuje SwiftUI poza `Observation`.
4. **View → tylko ViewModel.** View nie widzi UseCase'ów ani Repozytoriów. Renderuje stan z VM, forwarduje intent.

**Dlaczego tak twardo:**
- Repo ↛ Repo zapobiega implicitnym cyklom i utrzymuje SRP repozytorium (1 agregat = 1 repo).
- VM bez Repository wymusza bycie UC'a jako jawnego kontraktu domenowego — testy VM nie wymagają stubowania systemowych API.
- View bez UC trzyma VM jako jedyny punkt synchronizacji stanu ekranu.

---

## Shared code between features

Gdy dwa feature'y potrzebują tej samej funkcjonalności:

- **Repository** żyje w **feature-ownerze** (tam, gdzie pojawiło się pierwsze). Inne feature'y **nie sięgają po nie bezpośrednio**.
- **UseCase** jest jedynym kontraktem, który przekracza granicę feature'ów. Siedzi w `Common/UseCase/` feature-ownera.
- Nie istnieje globalny katalog `FeatureCommons/`. Wspólny kod jest lokalny dla feature-ownera.

**Przykład.** `ScreenTimeAuthRepository` używany przez Onboarding i Denial:

- Onboarding jest feature-ownerem (pierwsze użycie).
- Repo żyje w `Features/Onboarding/Common/Repository/`.
- `RequestScreenTimeAuthUseCase` żyje w `Features/Onboarding/Common/UseCase/`.
- Denial wstrzykuje **UseCase**, nie repo.

Detale i kiedy wydzielać `Common/` → `.claude/guides/feature-structure/GUIDE.md`.

---

## MVVM (Presentation)

ViewModel trzyma stan, eksponuje akcje, woła UseCase'y. Używaj `@Observable` (Swift Observation, iOS 17+).

```swift
@MainActor
@Observable
final class OnboardingViewModel: @unchecked Sendable {
    @ObservationIgnored
    @LazyInjected private var requestAuth: RequestScreenTimeAuthUseCase

    private(set) var status: ScreenTimeAuthStatus?
    private(set) var isRequesting = false
    var destination: Destination?   // patrz navigation/GUIDE.md

    func onAuthorizeTapped() async {
        isRequesting = true
        defer { isRequesting = false }
        status = try? await requestAuth()
    }
}
```

View jest cienka — bind do VM, render stanu, forward intentu:

```swift
struct OnboardingView: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        Button("Autoryzuj") {
            Task { await model.onAuthorizeTapped() }
        }
        .disabled(model.isRequesting)
    }
}
```

**Reguły:**
- Brak logiki biznesowej w View.
- VM nie importuje SwiftUI (`View`, `Color`, `Binding`) — wyłącznie `Observation`.
- VM nie dotyka `URLSession` / Keychain / FileManager / ManagedSettings bezpośrednio — zawsze przez UC.

---

## UseCase (Domain)

Każdy UseCase reprezentuje **jedną operację biznesową**. Jedna publiczna metoda `execute(...)` — bez przeciążeń, bez `callAsFunction`.

```swift
protocol RequestScreenTimeAuthUseCase: Sendable {
    func execute() async throws -> ScreenTimeAuthStatus
}

final class RequestScreenTimeAuthUseCaseImpl: RequestScreenTimeAuthUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func execute() async throws -> ScreenTimeAuthStatus {
        try await repository.requestAuthorization()
        return await repository.status
    }
}
```

**Kiedy dodać UseCase, a kiedy wołać Repository bezpośrednio:**

```
Plain read-through (jedno fetch, bez reguł)?
    └─ UC to overkill — ale i tak VM musi iść przez UC (reguła "VM → tylko UC").
       Trywialny passthrough UC to koszt akceptowalny dla spójności kontraktu.

Reguła biznesowa, walidacja, łączenie źródeł?
    └─ UseCase obowiązkowy. Reguły należą do Domain, nie VM.
```

Reguła "VM → tylko UC" jest twarda — nawet trywialny passthrough wymaga UC. To cena za jednolity kontrakt i testowalność.

---

## Repository (Data)

Protokół i implementacja **w tym samym pliku**. Repository ukrywa, **skąd** pochodzą dane.

```swift
// Features/Onboarding/Common/Repository/ScreenTimeAuthRepository.swift

protocol ScreenTimeAuthRepository: Sendable {
    var status: ScreenTimeAuthStatus { get async }
    func requestAuthorization() async throws
}

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository {
    var status: ScreenTimeAuthStatus {
        get async {
            // wywołanie AuthorizationCenter itd.
        }
    }

    func requestAuthorization() async throws {
        // systemowy API call
    }
}
```

Jedno Repository na **agregat** — nie na endpoint, nie na tabelę, nie na systemowy API.

---

## Dependency Injection

Projekt używa `DIContainer` (singleton z scope'ami `.application` i `.unique`) + property wrapperów:

- **Init Injection** dla Repository / UseCase / źródeł danych.
- **`@LazyInjected`** dla ViewModeli.

Każdy feature rejestruje swoje zależności w `<Feature>Injection.swift` (distributed registration).

Pełne API, wzorce testowania i anty-wzorce → `.claude/guides/dependency-injection/GUIDE.md`.

---

## SOLID applied

- **S**ingle Responsibility — jeden UC = jedna operacja; jedno Repo = jeden agregat.
- **O**pen/Closed — dodawaj nowe UC'y; nie modyfikuj istniejącego żeby obsłużyć nowy case.
- **L**iskov — podmiana prawdziwej impl na fake'a nie może psuć callerów.
- **I**nterface Segregation — VM zależy od wąskich protokołów (per UC), nie od fat'owego `DataManagera`.
- **D**ependency Inversion — Presentation i Domain zależą od abstrakcji; Data je implementuje.

---

## KISS & DRY

- **KISS.** Nie dodawaj warstwy "na wszelki wypadek". Jeśli UC jest trywialnym passthrough'em, to **jeszcze** nie powód, żeby łamać regułę VM→UC — ale to też znaczy, że nie potrzebujesz tam repo, jeśli dane pochodzą z pamięci procesu.
- **DRY.** Wydzielaj, kiedy ta sama logika pojawia się 3× między feature'ami / ekranami — nie wcześniej. Dwa podobne bloki biją premature abstraction.
- **YAGNI.** Warstwy dodajemy, kiedy pojawia się konkretna potrzeba, nie "może się przyda".

---

## iOS design patterns used

- **Observer** — `@Observable` / `@Bindable` (Swift Observation).
- **Factory** — `container.register(...) { ... }` w `<Feature>Injection.swift`.
- **Decorator** — wrap Repository dla cache'owania / loggingu bez zmiany callerów.
- **Strategy** — wymiana impl UC'a dla A/B testów / feature flags.
- **State-driven navigation** — `Destination?` enum na VM; patrz `.claude/guides/navigation/GUIDE.md`.
- **Unikaj:** globalnych singletonów poza `DIContainer` (który jest jawnym, kontrolowanym wyjątkiem), god objects, service locatorów rozsianych po kodzie.

---

## Decision tree: gdzie idzie nowy kod?

```
Nowy ekran?
    └─ Features/<Feature>/<Screen>/ (w Split) lub Features/<Feature>/ (w Simple)
       — patrz feature-structure/GUIDE.md

Reguła biznesowa lub operacja wieloetapowa?
    └─ UseCase w Features/<Feature>/UseCase/ lub .../Common/UseCase/ (jeśli współdzielone)

Nowe źródło danych (systemowe API, cache, App Group, Keychain)?
    └─ Repository w Features/<Feature>/Repository/ lub .../Common/Repository/
       — protokół i impl w tym samym pliku

Model danych współdzielony między warstwami?
    └─ plain struct w Repository/Models/ obok repo, które go produkuje
```

---

## Localization rules

Tłumaczenia żyją **tylko w warstwie View i ViewModel** — nigdy w Domain ani Repository.

```swift
// ✅ View
Text("sessionStartHeader")
// ✅ ViewModel (display string)
let title = String(localized: "statsNavigationTitle")

// ❌ UseCase — nie tutaj
// ❌ Repository — nie tutaj
```

**Wyjątek:** push notification body (`NotificationCaptionLibrary`) używa `NSLocalizedString` w Repository, bo treść powiadomienia to dane, nie UI. Dokumentuj takie wyjątki komentarzem.

Szczegóły, nazewnictwo kluczy, pluralizacja → `.claude/guides/localization/GUIDE.md`.

---

## Common pitfalls

- **ViewModel importujący SwiftUI.** Tylko `Observation` jest OK — nigdy `View`, `Color`, `Binding`, `Image`.
- **ViewModel importujący Repository.** Łamie regułę "VM → tylko UC". Trywialny passthrough UC to koszt spójności, nie overhead.
- **Repository importujące inne Repository.** Łamie regułę Repo ↛ Repo. Potrzebujesz łączyć dwa źródła? To UseCase.
- **UseCase, który tylko forwarduje jeden call repo.** Zostaw. Spójność kontraktu VM→UC warta jest tego jednego pliku.
- **Repository zwracające `Result<T, Error>`.** Używaj `async throws` — idiomatyczny Swift.
- **Shared mutable state między ViewModelami.** Przenieś do Repozytorium; konsumuj przez `AsyncStream` albo async read.
- **Mock przez subclassing.** Używaj protokołów, nie dziedziczenia po klasach.
- **Entity lecące prosto do View.** Zwykle OK — ale jeśli View potrzebuje formatowanych stringów albo pól UI-only, mapuj do display structa w ViewModelu.

---

## Related

- Layout plików per feature: `.claude/guides/feature-structure/GUIDE.md`
- Dependency Injection: `.claude/guides/dependency-injection/GUIDE.md`
- Nawigacja: `.claude/guides/navigation/GUIDE.md`
- Lokalizacja (xcstrings, reguły warstwowe, pluralizacja): `.claude/guides/localization/GUIDE.md`
- **Testowanie** (Swift Testing vs XCTest, wzorce mocków, parameterized testy): `.claude/guides/testing/GUIDE.md`
- Swift concurrency — wywołaj skill `swift-concurrency:swift-concurrency` przy pracy z async/await, aktorami, Sendable.
- SwiftUI patterns — wywołaj skill `swiftui-expert:swiftui-expert-skill` przy projektowaniu widoków.

---

**Last Updated**: 2026-04-18
