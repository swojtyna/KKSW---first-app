---
summary: Strategia testowania — Swift Testing vs XCTest, wzorce mocków, parameterized testy
read_when: Writing new tests, reviewing a test file, deciding which framework to use
complexity: medium
status: active
last_updated: 2026-04-26
---

# Testing Guide

Projekt używa **Swift Testing** (iOS 16+ / Xcode 16+) jako domyślnego frameworka testów jednostkowych. XCTest zostaje tam, gdzie Swift Testing nie może go zastąpić.

---

## Framework selection

| Użyj **Swift Testing** | Zostaw **XCTest** |
|---|---|
| UseCase tests (pure logic) | ViewModel tests z `DIContainer.shared.reset()` |
| Repository tests (filesystem, in-memory) | Tests z `XCTestExpectation` / `fulfillment(of:)` |
| Pure computation (Stats, Schedule window) | UI automation (`XCUIApplication`) |
| Nowe testy od zera | Performance (`XCTMetric`) |
| | Tests bridgujące Objective-C APIs |

XCTest i Swift Testing mogą **koegzystować w tym samym targecie**. Migruj przyrostowo — nie przepisuj wszystkiego naraz.

**Skill:** Wywołaj `swift-testing-expert` dla szczegółowych wzorców.

---

## Import rules

```swift
// ✅ Test target only
import Testing
@testable import DeluluDetox

// ❌ Nigdy w production code
import Testing // NIE TUTAJ
```

---

## Suite structure

Preferuj `struct` — wartościowa semantyka zapobiega przypadkowemu współdzieleniu stanu między testami.

```swift
@Suite("StartSessionUseCase")
struct StartSessionUseCaseTests {
    // Shared setup → stored let properties + init()
    private let mockRepo: MockSessionRepository
    private let sut: StartSessionUseCaseImpl

    init() {
        mockRepo = MockSessionRepository()
        sut = StartSessionUseCaseImpl(repository: mockRepo, ...)
    }

    @Test("happy path invokes repo then shield then monitoring")
    func happyPath() async throws {
        // ...
        #expect(mockRepo.startSessionCallCount == 1)
    }
}
```

---

## Assertions

`#expect` jest domyślnym wyborem. `#require` używaj gdy dalsza część testu zależy od warunku.

```swift
// Domyślnie
#expect(stats.currentStreak == 3)
#expect(vm.destination == nil)
#expect(!list.records.isEmpty)

// Unwrapping opcjonali (zastępuje XCTUnwrap / guard + XCTFail)
let record = try #require(repo.startSessionCallCount == 1 ? result : nil)

// Pattern matching z wyraźnym błędem
guard case let .active(endsAt) = window.state else {
    Issue.record("Expected .active, got \(window.state)")
    return
}
#expect(endsAt == expectedEnd)

// Throw verification
#expect(throws: SessionStoreError.noActiveSession) {
    try await repo.finalizeActiveSession(...)
}
```

### Mapping XCTest → Swift Testing

| XCTest | Swift Testing |
|---|---|
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertNotNil(x)` | `#expect(x != nil)` |
| `XCTFail("msg")` | `Issue.record("msg")` |
| `try XCTUnwrap(x)` | `try #require(x)` |
| `XCTAssertThrowsError(try f())` | `#expect(throws: (any Error).self) { try f() }` |

---

## Parameterized tests

Kiedy masz wiele testów z identyczną strukturą, różniących się tylko danymi wejściowymi — użyj `@Test(arguments:)`.

```swift
struct ScheduleWindowCase: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let nowHour: Int
    let expectedState: ScheduleWindowState
}

@Test("schedule window state", arguments: [
    ScheduleWindowCase(testDescription: "active mid-window", nowHour: 12, expectedState: .active(endsAt: ...)),
    ScheduleWindowCase(testDescription: "upcoming today", nowHour: 7, expectedState: .upcomingToday(startsAt: ...)),
])
func scheduleWindowState(_ tc: ScheduleWindowCase) {
    #expect(uc(schedule: s, now: now).state == tc.expectedState)
}
```

**Kiedy NIE parametryzować:**
- Testy testujące różne zachowania (nie tylko różne inputy)
- Kiedy parametryzacja wymaga logiki `if/switch` wewnątrz testu

---

## Mock pattern (XCTest — istniejący wzorzec)

Projekt używa ręcznie pisanych mocków z `callCount` / `last*` / `stubbed*` properties. W testach ViewModeli — DI przez `DIContainer.shared`.

```swift
// Standardowy mock UseCase
final class MockStartSessionUseCase: StartSessionUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastBlocklistId: UUID?
    var stubbedResult: SessionRecord?
    var stubbedError: Error?

    func execute(blocklistId: UUID, ...) async throws -> SessionRecord {
        callCount += 1
        lastBlocklistId = blocklistId
        if let stubbedError { throw stubbedError }
        return stubbedResult!
    }
}

// ViewModel tests — rejestracja w DI
override func setUp() async throws {
    DIContainer.shared.reset()
    mockStart = MockStartSessionUseCase()
    DIContainer.shared.register(StartSessionUseCase.self, scope: .application) { [mockStart] _ in mockStart! }
}

override func tearDown() async throws {
    DIContainer.shared.reset()
}
```

---

## Async tests

```swift
// Swift Testing — async działa natywnie
@Test func startSessionSetsIsStartingFlag() async {
    let vm = SessionStartViewModel()
    await vm.startTapped(now: Date())
    #expect(!vm.isStarting) // after await, flag must be reset
}

// Task.yield() zamiast sleep gdy czekasz na Combine `.receive(on: .main)`
private func yield() async {
    await Task.yield()
    await Task.yield()
    await Task.yield()
}
```

---

## File organization

```
DeluluDetoxTests/
├── DeluluDetoxTests.swift          # Cross-cutting smoke tests (Swift Testing)
└── Features/
    └── Session/
        ├── StartSessionUseCaseTests.swift      # XCTest (async + mocks)
        ├── SessionRepositoryTests.swift        # XCTest (filesystem)
        ├── CountdownViewModelTests.swift       # XCTest (DI)
        └── Mocks/
            ├── MockStartSessionUseCase.swift
            └── MockSessionRepository.swift
```

**Reguła:** Mocki żyją obok testów, które ich używają (`Mocks/` folder). Fixture builders dla złożonych danych testowych → `Fixtures/` (np. `SessionRecordFixtures.swift`).

---

## Wartość testów per warstwa

| Warstwa | Wartość | Framework |
|---|---|---|
| **UseCase** | Najwyższa — logika domenowa, rollback, orchestration | Swift Testing (nowe) / XCTest (stare) |
| **Repository** | Wysoka — trwałość, kodowanie, edge cases filesystem | XCTest (setUp/tearDown z tmpdir) |
| **ViewModel** | Wysoka — UI state, navigation, guard gates | XCTest (DIContainer reset pattern) |
| **Pure computation** | Wysoka — deterministyczne, zero deps | Swift Testing + parameterized |

---

## Related

- Architecture: `.claude/guides/architecture/GUIDE.md`
- Dependency Injection (DIContainer, mock registration): `.claude/guides/dependency-injection/GUIDE.md`
- Swift Testing skill: `.claude/skills/swift-testing-expert/SKILL.md`
- Build & test runner: `.claude/guides/xcodebuild-mcp/GUIDE.md`

---

**Last Updated**: 2026-04-26
