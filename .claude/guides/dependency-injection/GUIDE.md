---
summary: DIContainer — rejestracja, resolve, property wrappers, testowanie
read_when: Before injecting dependencies, setting up DI, adding new service
complexity: medium
status: active
last_updated: 2026-04-18
---

# Dependency Injection

Projekt używa `DIContainer` (singleton) z dwoma wzorcami wstrzykiwania:

- **Init Injection** dla warstw niskich (Repository, UseCase, systemowe źródła danych) — jawne zależności w konstruktorze.
- **`@LazyInjected`** dla warstw wysokich (ViewModel) — rozwiązywane leniwie z `DIContainer.shared`.

Każda feature rejestruje własne zależności w `<Feature>Injection.swift`. Rejestracja centralna na poziomie Appa jest anty-wzorcem (patrz niżej).

---

## Quick Summary

| Warstwa | Wzorzec | Sendable | DI Scope |
|---------|---------|----------|----------|
| Systemowe źródło (ScreenTime, Keychain, FileManager) | Init Injection | `@unchecked Sendable` lub `Sendable` | `.application` |
| Repository | Init Injection | `Sendable` | `.application` lub `.unique` |
| UseCase | Init Injection | `Sendable` | `.unique` |
| ViewModel | `@LazyInjected` | `@unchecked Sendable` (z `@MainActor`) | not registered |

`@MainActor` na ViewModelu wymaga `@unchecked Sendable` — `DIContainer` obsługuje ten przypadek przez `MainActor.assumeIsolated` w factory.

---

## Init Injection Pattern

Warstwy niskie jawnie deklarują zależności w init:

```swift
// Features/Onboarding/Common/Repository/ScreenTimeAuthRepository.swift

protocol ScreenTimeAuthRepository: Sendable {
    var status: ScreenTimeAuthStatus { get async }
    func requestAuthorization() async throws
}

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository {
    // ewentualne zależności — np. źródło systemowe, logger
    init() {}

    var status: ScreenTimeAuthStatus { get async { /* ... */ } }
    func requestAuthorization() async throws { /* ... */ }
}
```

```swift
// Features/Onboarding/Common/UseCase/RequestScreenTimeAuthUseCase.swift

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

### Rejestracja przez `container.resolve()`

```swift
// Features/Onboarding/Injection/OnboardingInjection.swift

enum OnboardingInjection {
    static func register(in container: DIContainer) {
        registerRepositories(in: container)
        registerUseCases(in: container)
    }

    private static func registerRepositories(in container: DIContainer) {
        container.register(ScreenTimeAuthRepository.self, scope: .application) { _ in
            ScreenTimeAuthRepositoryImpl()
        }
    }

    private static func registerUseCases(in container: DIContainer) {
        container.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { c in
            RequestScreenTimeAuthUseCaseImpl(repository: c.resolve())
        }
    }
}
```

### Dlaczego Init Injection dla niskich warstw

1. **True `Sendable`** — bez `@unchecked`, kompilator weryfikuje thread safety.
2. **Jawne zależności** — init pokazuje, czego klasa potrzebuje.
3. **Testowalność bez DI** — mock podajesz wprost do init:
   ```swift
   let mockRepo = MockScreenTimeAuthRepository()
   let useCase = RequestScreenTimeAuthUseCaseImpl(repository: mockRepo)
   // test bez DIContainer
   ```

---

## Reactive state: Combine publisher w Repository

Dla globalnych stanów aplikacji (status autoryzacji, active sessions, user preferences) Repository wewnętrznie trzyma `CurrentValueSubject` i eksponuje `AnyPublisher` read-only. Klienci subskrybują przez dedykowany UseCase.

### Kiedy to stosować

- Stan który ma **wielu subskrybentów** (Onboarding VM, Denial VM, AppRoot VM wszystkie obserwują ten sam ScreenTime status).
- Stan który powinien być dostępny **natychmiast przy subskrypcji** (ostatnia znana wartość, nie trzeba osobnego "get current").
- Źródło prawdy żyje w Repository — UC są cienkimi przejścówkami (pass-through + enkapsulacja protokołu).

`CurrentValueSubject` > `AsyncStream.makeStream()` — ten drugi jest single-subscriber, wymagałby broadcastu.

### Wzorzec: Repository + 2 UC (Observe + Refresh)

```swift
// Features/Onboarding/Repository/ScreenTimeAuthRepository.swift
import Combine
import FamilyControls

protocol ScreenTimeAuthRepository: Sendable {
    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> { get }
    func requestAuthorization() async throws
    func refreshStatus()
}

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository, @unchecked Sendable {
    private let statusSubject: CurrentValueSubject<AuthorizationStatus, Never>

    var statusPublisher: AnyPublisher<AuthorizationStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    init() {
        self.statusSubject = CurrentValueSubject(AuthorizationCenter.shared.authorizationStatus)
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        statusSubject.send(AuthorizationCenter.shared.authorizationStatus)
    }

    func refreshStatus() {
        statusSubject.send(AuthorizationCenter.shared.authorizationStatus)
    }
}
```

```swift
// Features/Onboarding/UseCase/ObserveScreenTimeAuthStatusUseCase.swift
protocol ObserveScreenTimeAuthStatusUseCase: Sendable {
    func execute() -> AnyPublisher<AuthorizationStatus, Never>
}

final class ObserveScreenTimeAuthStatusUseCaseImpl: ObserveScreenTimeAuthStatusUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func execute() -> AnyPublisher<AuthorizationStatus, Never> {
        repository.statusPublisher
    }
}
```

```swift
// Features/Onboarding/UseCase/RefreshScreenTimeAuthStatusUseCase.swift
protocol RefreshScreenTimeAuthStatusUseCase: Sendable {
    func execute()
}

final class RefreshScreenTimeAuthStatusUseCaseImpl: RefreshScreenTimeAuthStatusUseCase {
    private let repository: ScreenTimeAuthRepository

    init(repository: ScreenTimeAuthRepository) {
        self.repository = repository
    }

    func execute() {
        repository.refreshStatus()
    }
}
```

### Rejestracja w DIContainer

```swift
// Features/Onboarding/Injection/OnboardingInjection.swift
enum OnboardingInjection {
    static func register(in container: DIContainer) {
        container.register(ScreenTimeAuthRepository.self, scope: .application) { _ in
            ScreenTimeAuthRepositoryImpl()
        }
        container.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { c in
            ObserveScreenTimeAuthStatusUseCaseImpl(repository: c.resolve())
        }
        container.register(RefreshScreenTimeAuthStatusUseCase.self, scope: .unique) { c in
            RefreshScreenTimeAuthStatusUseCaseImpl(repository: c.resolve())
        }
    }
}
```

Repository musi mieć scope `.application` — to **singleton trzymający stan subjectu**. Gdyby scope był `.unique`, każdy resolve tworzyłby nowy repo → nowy subject → subskrybenci pracujący na różnych streamach. UC mogą być `.unique` (bezstanowe przejścówki).

### Konsumpcja w ViewModelu

```swift
@MainActor
@Observable
final class AppRootViewModel: @unchecked Sendable {
    @ObservationIgnored @LazyInjected private var observeStatus: ObserveScreenTimeAuthStatusUseCase
    @ObservationIgnored @LazyInjected private var refreshStatus: RefreshScreenTimeAuthStatusUseCase
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var destination: SomeEnum?

    init() {
        observeStatus()
            .sink { [weak self] status in
                self?.destination = Self.map(status)
            }
            .store(in: &cancellables)
    }

    /// Wywoływane np. z `.onChange(of: scenePhase)` w View — user cofa permission w Settings → repo emituje → destination się aktualizuje.
    func refresh() {
        refreshStatus()
    }
}
```

**Uwaga na `@ObservationIgnored`** przed `@LazyInjected` i przed `cancellables` — inaczej każdy dostęp invaliduje observation. Swift Observation wymóg.

### Refresh vs observe — dlaczego OBA

- **Observe** — stream przyszłych zmian (prompt grant → repo emituje nowy status → subskrybenci reagują).
- **Refresh** — wymuszenie odczytu **teraz** z systemowego źródła (user cofa Screen Time w Settings iOS → poza app → brak powiadomienia → trzeba "zapytać ponownie" przy `scenePhase == .active`).

Bez Refresh dziura w logice: user może cofnąć zgodę poza app, AppRoot myśli że nadal .approved → pokaże Home choć blokada nie działa. To **core value violation** w apce blokującej. Refresh jest obroną.

### Antywzorzec — sync `var status: AuthorizationStatus { get }`

```swift
// ❌ ŹLE — synchroniczny getter bez notyfikacji zmian
protocol BadRepository {
    var status: SomeStatus { get }
    func request() async throws
}
```

Subskrybenci musieliby pollować (timer co 1s?) lub ręcznie dostawać powiadomienia (NotificationCenter?). Zamiast — CurrentValueSubject daje *both* "last known value on subscribe" i "emit future changes" w jednym API.

---

## `@LazyInjected` Pattern

Dla warstw wysokich (ViewModel) używamy property wrappera:

```swift
// Features/Onboarding/ViewModel/OnboardingViewModel.swift

@MainActor
@Observable
final class OnboardingViewModel: @unchecked Sendable {

    @ObservationIgnored
    @LazyInjected private var requestAuth: RequestScreenTimeAuthUseCase

    private(set) var status: ScreenTimeAuthStatus?
    private(set) var isRequesting = false

    func onAuthorizeTapped() async {
        isRequesting = true
        defer { isRequesting = false }
        status = try? await requestAuth()
    }
}
```

### Dlaczego `@LazyInjected` dla ViewModeli

1. **Mniej boilerplate** — ViewModel z 5 UC nie musi mieć init z 5 parametrami.
2. **Wygoda** — `@MainActor @Observable` VM i tak musi być `@unchecked Sendable`; `DIContainer.shared` ma wewnętrzny lock.
3. **Leniwe rozwiązanie** — UC jest tworzony przy pierwszym dostępie, nie przy inicjalizacji VM.

**Ważne:** ViewModeli **nie rejestrujemy** w `DIContainer`. Są tworzone bezpośrednio (`OnboardingViewModel()`), a `@LazyInjected` rozwiązuje ich zależności z globalnego containera przy pierwszym użyciu.

---

## Zasady, które to wymusza

Architektura ma twarde reguły (patrz `.claude/guides/architecture/GUIDE.md`):

```
ViewModel → UseCase → Repository → (systemowe źródło)
    ↓          ↓           ↓
  (jeden kierunek, żadnych cykli, repo ↛ repo)
```

Jeśli `DIContainer` pozwala Ci zarejestrować coś, co łamie te reguły — to nie znaczy, że tak trzeba. Enforcement zasad jest w code review (i docelowo w skrypcie walidującym).

---

## Typowe problemy

### Brak rejestracji (runtime crash)

```swift
container.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { c in
    RequestScreenTimeAuthUseCaseImpl(repository: c.resolve())  // CRASH jeśli repo niezarejestrowane
}
```

**Zachowanie:** app crashuje z czytelną wiadomością:

```
📛 DIContainer: ScreenTimeAuthRepository not registered. Check Injection files.
```

**To jest OK** — fail fast, jasny błąd. Naprawiasz brakującą rejestrację w odpowiednim `<Feature>Injection.swift`.

### Cykliczne zależności (problem architektury)

```swift
// A zależy od B
container.register(A.self, scope: .unique) { c in A(b: c.resolve()) }
// B zależy od A
container.register(B.self, scope: .unique) { c in B(a: c.resolve()) }
// WYNIK: stack overflow
```

**Jeśli to widzisz — masz błąd w architekturze.**

Cykle oznaczają:
- warstwy nie są właściwie oddzielone,
- odpowiedzialności się mieszają,
- trzeba zrefaktorować.

**Fix:**
1. Wydziel wspólną logikę do trzeciego komponentu.
2. Użyj delegate / callback zamiast bezpośredniej zależności.
3. Przemyśl, która warstwa powinna właścicielować którą odpowiedzialność.

---

## DIContainer API

### Register

```swift
// Application scope — singleton, tworzony raz, cache'owany
container.register(ProtocolType.self, scope: .application) { container in
    Implementation(dependency: container.resolve())
}

// Unique scope — nowy instance przy każdym resolve
container.register(ProtocolType.self, scope: .unique) { container in
    Implementation()
}
```

Factory jest `@MainActor` — `DIContainer` wrappuje ją w `MainActor.assumeIsolated`, dzięki czemu można bezpiecznie tworzyć komponenty UI (ViewModel, Observable) z tym samym API co serwisy niskopoziomowe.

### Resolve

```swift
// Explicit type
let useCase: RequestScreenTimeAuthUseCase = container.resolve(RequestScreenTimeAuthUseCase.self)

// Inferred type (z kontekstu)
let useCase: RequestScreenTimeAuthUseCase = container.resolve()

// W init (typ inferowany z parametru)
RequestScreenTimeAuthUseCaseImpl(repository: container.resolve())
```

### `@LazyInjected` Property Wrapper

```swift
@LazyInjected private var useCase: RequestScreenTimeAuthUseCase
```

- Rozwiązywane przy pierwszym dostępie (leniwie).
- Używa `DIContainer.shared`.
- Thread-safe (container ma wewnętrzny `NSRecursiveLock`).

---

## Testowanie

### Niskie warstwy (Init Injection)

Mock podajesz wprost, bez `DIContainer`:

```swift
@Test("Repository autoryzuje przez source")
func requestAuthorization() async throws {
    let mockSource = MockScreenTimeAuthSource()
    mockSource.stubAuthorize = .success(())

    let repository = ScreenTimeAuthRepositoryImpl(source: mockSource)
    try await repository.requestAuthorization()

    #expect(mockSource.authorizeCallCount == 1)
}
```

### Wysokie warstwy (vertical slice)

ViewModel używa `@LazyInjected` — test wstawia mocki w `DIContainer` na czas testu:

```swift
@Test("VM ładuje status po autoryzacji")
@MainActor
func onboardingAuthorizes() async throws {
    let container = DIContainer.shared
    container.reset()  // czysty stan między testami

    container.register(ScreenTimeAuthRepository.self, scope: .application) { _ in
        MockScreenTimeAuthRepository(status: .authorized)
    }
    container.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { c in
        RequestScreenTimeAuthUseCaseImpl(repository: c.resolve())
    }

    let viewModel = OnboardingViewModel()
    await viewModel.onAuthorizeTapped()

    #expect(viewModel.status == .authorized)
}
```

Rekomendowane: `DIContainer.reset()` w `setUp` (lub na początku każdego testu) dla testów używających `.shared`.

---

## Rule: nowy serwis → rejestracja w Injection feature'a

Każdy nowy Repository, UseCase albo systemowe źródło **musi** zostać zarejestrowany w `<Feature>Injection.swift` feature'a, który go wprowadza. Nigdy nie instancjonuj bezpośrednio w ViewModelu / UseCase'ie:

```swift
// ✅ Dobrze — zarejestrowane w DI
container.register(BlockedAppsRepository.self, scope: .application) { _ in
    BlockedAppsRepositoryImpl()
}

// ❌ Źle — bezpośrednie instancjonowanie poza DI
let repository = BlockedAppsRepositoryImpl()
```

---

## Registration Ownership

### Zasada: każdy feature rejestruje własne zależności

| Komponent | Rejestrowany w |
|-----------|----------------|
| `ScreenTimeAuthRepositoryImpl` | `Features/Onboarding/Injection/OnboardingInjection.swift` |
| `RequestScreenTimeAuthUseCaseImpl` | `Features/Onboarding/Injection/OnboardingInjection.swift` |
| `BlockedAppsRepositoryImpl` (hipotetyczny) | `Features/AppSelection/Injection/AppSelectionInjection.swift` |

Jeśli repo jest współdzielone — rejestruje je **feature-owner** (ten, w którego `Common/` repo fizycznie żyje). Feature-consument (np. Denial dla `RequestScreenTimeAuthUseCase`) konsumuje wyłącznie UC, nie rejestruje nic od siebie.

### Anty-wzorzec: rejestracja centralna

```swift
// ❌ ŹLE — App rejestruje zależności feature'ów
AppInjection.swift:
    container.register(ScreenTimeAuthRepository.self) { ... }
    container.register(RequestScreenTimeAuthUseCase.self) { ... }
    container.register(BlockedAppsRepository.self) { ... }
```

### Poprawnie: rozproszona rejestracja

```swift
// ✅ DOBRZE — każdy moduł rejestruje siebie

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

// Features/AppSelection/Injection/AppSelectionInjection.swift
enum AppSelectionInjection {
    static func register(in container: DIContainer) {
        container.register(BlockedAppsRepository.self, scope: .application) { _ in
            BlockedAppsRepositoryImpl()
        }
    }
}

// App/DeluluDetoxApp.swift — tylko wołanie rejestracji feature'ów
@main
struct DeluluDetoxApp: App {
    init() {
        let container = DIContainer.shared
        OnboardingInjection.register(in: container)
        AppSelectionInjection.register(in: container)
        // ...
    }

    var body: some Scene { /* ... */ }
}
```

### Dlaczego?

- **Feature'y są self-contained** — cały kod, w tym DI, w jednym module.
- **Dodanie / usunięcie feature'a** nie wymaga zmian w App.
- **Jasny ownership** — każdy moduł odpowiada za swoje rejestracje.
- **Łatwiejsze testowanie** — można zarejestrować feature w izolacji.

---

## Related

- Zasady zależności między warstwami: `.claude/guides/architecture/GUIDE.md`
- Fizyczny układ plików per feature: `.claude/guides/feature-structure/GUIDE.md`
- Swift concurrency (Sendable, `@MainActor`, `assumeIsolated`) — wywołaj skill `swift-concurrency:swift-concurrency` przy pracy z async/await i izolacją.

---

**Last Updated**: 2026-04-18
