# Phase 05: Scheduled Blocking — Research

**Researched:** 2026-04-20
**Domain:** iOS Screen Time (DeviceActivity + ManagedSettings) — recurring schedules via DeviceActivityMonitor extension
**Confidence:** HIGH for architecture/pattern reuse (all established in Phases 2/3/4), MEDIUM for DeviceActivitySchedule cross-midnight semantics (empirically derived from Phase 3 Session code + Apple forum threads)

## Summary

Phase 05 dokleja **scheduled blocking** do istniejącej architektury quick-sessions. Cała warstwa systemowa (DAM extension, App Group file bus, Darwin notifications, atomic JSON writes, ManagedSettings named stores, self-heal na scenePhase) jest już zbudowana i wydebugowana w Phase 3 — Phase 5 ją **rozszerza, a nie duplikuje**.

Kluczowe decyzje są już podjęte w CONTEXT.md (D-01..D-22). Research potwierdza: (a) CONTEXT-owa strategia "1 repeating DAS + filter weekday w extension" jest zgodna ze wzorcem Apple forum thread #742131 i unika szybkiego wyczerpania 20-activity budgetu; (b) cross-midnight wrap **wymaga** dwóch osobnych DAS — to samo ograniczenie dotknęło Phase 3 w `SessionActivityMonitoringRepository.startActivityMonitoring` (inline komentarz w kodzie); (c) Shield parity (success criterion 4) jest zero-work — `ShieldConfigurationExtension` z Phase 4 nie różnicuje sources, więc `ManagedSettingsStore(named: "deluludetox.schedule")` dostaje ten sam branded+fallback shield automatycznie.

**Primary recommendation:** Buduj feature-first moduł `Features/Scheduling/` z **trzema repozytoriami** (mirror Phase 3 split): `ScheduleRepository` (App Group JSON), `ScheduleShieldRepository` (ManagedSettings writes, osobny named store), `ScheduleActivityMonitoringRepository` (DeviceActivityCenter start/stop z segmentem per cross-midnight). DAM extension rozszerz o `intervalDidStart` + `intervalDidEnd` z filtrem activity-name i weekday. Self-heal + marker pattern skopiuj 1:1 z Phase 3.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Schema & Scope**
- **D-01:** `Schedule` Codable struct w tablicy w `schedule.json`. MVP UI odczytuje/modyfikuje pierwszy/jedyny rekord (implicit single), ale schema supports N od day 1 — bez migracji w MSC-01/02.
- **D-02:** `Schedule` schema: `id: UUID`, `name: String?` (nil w MVP), `daysOfWeek: [Int]` (Calendar weekday 1=Sunday..7=Saturday), `startHour/startMinute/endHour/endMinute: Int`, `enabled: Bool`, `blocklistId: UUID` (FK → single implicit blocklist), `appVersion: String`.
- **D-03:** Cross-midnight **wspierany**. Wrap = `(endHour,endMinute) < (startHour,startMinute)` → DWA DAS (`schedule.{id}.evening` 23:59:59 + `schedule.{id}.morning` 00:00:00). Koszt: 2 aktywności z 20 na cross-midnight. Świadoma zgoda (sleep block jako flagship use case).
- **D-04:** `schedule.json` atomic write, main app sole writer. Extensions read-only.

**Active Window Conflict (Schedule × Quick Session)**
- **D-05:** Dwa osobne ManagedSettingsStore'y: `deluludetox.session` (Phase 3) + `deluludetox.schedule` (Phase 5). iOS mergeuje shieldy (union tokenów).
- **D-06:** Schedule start gdy session aktywna → tylko apply `deluludetox.schedule`, nietknięty session store.
- **D-07:** Session start podczas okna schedule'a → normalny flow Phase 3, union = ten sam set tokenów. End-of-session clearuje tylko `deluludetox.session`.
- **D-08:** Brak specjalnego UI konfliktu; opcjonalny subtle "+ schedule aktywny" to Claude's Discretion.

**Create/Edit UX (SCH-01)**
- **D-09:** 7 toggle chipów dni tygodnia (Pn..Nd, krótkie PL etykiety) + 3 presety ("Dni robocze", "Weekend", "Codziennie").
- **D-10:** Dwa `DatePicker(.hourAndMinute)` w stylu `.wheel` (jak Phase 3 D-18 custom duration). Wrap = inline marker "Cross-midnight" + sarkastyczny copy, BEZ walidacji blokującej.
- **D-11:** Enable toggle = efekt od następnego okna. Disable gdy now w oknie → stopMonitoring kasuje DAS, aktualny shield NIE jest natychmiast clearowany (czyści się na intervalDidEnd). Emergency override deferred.
- **D-12:** Dedykowany screen edytora (swift-navigation `Destination.scheduleEditor` na root VM). Bez wizarda, wszystko na jednym screenie + "Zapisz".

**DAM Integration (SCH-03)**
- **D-13:** 1 DAS per segment, `repeats: true`. Single-day: 1 DAS (`schedule.{id}.main`). Cross-midnight: 2 DAS (`.evening` + `.morning`). **Filter dni tygodnia w extension** (Calendar.weekday), NIE osobne DAS per dzień (oszczędza budget 20).
- **D-14:** `SyncScheduleWithSystemUseCase` wołany po save i po launch: stopMonitoring starych `.schedule.{oldId}.*` → jeśli enabled → zbuduj 1-2 DAS → startMonitoring każdego segmentu. Error → sarkastyczny toast + rollback `schedule.json`.
- **D-15:** DAM `intervalDidStart`: parse scheduleId → read schedule.json + check enabled + check weekday → read blocklists.json + collect tokens → `ManagedSettingsStore(named: "deluludetox.schedule").shield.*` = tokens → append event marker → fire Darwin.
- **D-16:** DAM `intervalDidEnd`: parse scheduleId → `ManagedSettingsStore(named: "deluludetox.schedule").clearAllSettings()` → append ended marker → fire Darwin.
- **D-17:** DAM nie pisze bezpośrednio do `schedule_events.json`. Pisze `schedule_event_marker.json` (overwrite, ostatnie event) + Darwin notification. Main app na next foreground appenduje do append-only `schedule_events.json` (Phase 6 konsumuje).
- **D-18:** Self-heal na `scenePhase == .active` (analogicznie do Phase 3 D-02): read `schedule.json`, dla każdego enabled oblicz czy now w oknie uwzględniając cross-midnight i dni tygodnia. Jeśli "powinno być aktywne" ale store clear → apply. Jeśli "nie powinno być aktywne" ale store ma tokeny → clear.
- **D-19:** Shield visual = identyczny co quick session (Phase 4 D-14). ShieldConfigurationExtension BEZ zmian.

**Notifications Boundary**
- **D-20:** Phase 5 zapewnia event source (D-17 markers + Darwin). NTF-02 = Phase 6. Phase 5 NIE wysyła UNUserNotification.

**Architecture**
- **D-21:** `ScheduleRepository` + UseCases: `CreateOrUpdateScheduleUseCase`, `ToggleScheduleUseCase`, `SyncScheduleWithSystemUseCase`, `SelfHealSchedulesUseCase`. `ScheduleEditorViewModel` @Observable bez SwiftUI.
- **D-22:** `AppRootViewModel.Destination` dostaje `.scheduleList` + `.scheduleEditor(ScheduleEditorViewModel)` (swift-navigation, @CasePathable).

### Claude's Discretion
- Treść "Cross-midnight" markera (copy + styl).
- Kolor/style chipów dni-tygodnia (filled vs outline, violet vs neutral).
- Grey-out vs badge dla disabled schedule'a na liście.
- Empty state copy.
- Error toast copy dla DeviceActivityCenter throws.
- Format `schedule_event_marker.json` vs `schedule_events.json` (drobne detale).
- Kolejność chipów dni (Pn-Nd vs Nd-Sb) — visual.
- Czy edytor pozwala nazwać schedule w MVP (schema supports).
- Strategia prezentacji "drugiej warstwy" (D-08).

### Deferred Ideas (OUT OF SCOPE)
- Multi-schedule UI (MSC-01/02 v2)
- Per-schedule blocklist (MVP = single implicit)
- Emergency "disable NOW" w trakcie okna
- Edge case: pusta blocklist podczas aktywnego okna (MVP accept)
- Lokalne notifikacje (NTF-02 Phase 6)
- Schedule templates / marketplace
- Multi-schedule DAS budget management (obecny D-13 scale do ~8 schedule)
- Widget / Live Activity countdown (LAC-01/02)
- Cross-device iCloud sync

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCH-01 | User can create a recurring schedule (select days of week + time range) | §Architecture Patterns → Editor screen pattern; §Code Examples → DAS construction + DatePicker(.hourAndMinute) wheel reuse from Phase 3; §Common Pitfalls → cross-midnight silent fail |
| SCH-02 | User can enable/disable their schedule | §Architecture Patterns → Toggle + `SyncScheduleWithSystemUseCase` calls stop/startMonitoring; §Common Pitfalls → disable mid-window leaves store dirty until intervalDidEnd |
| SCH-03 | Schedule executes via DeviceActivityMonitor extension — apps blocked during scheduled window | §Standard Stack → DeviceActivityMonitor + ManagedSettingsStore; §Code Examples → intervalDidStart + intervalDidEnd handlers; §Common Pitfalls → weekday filtering in-extension vs N DAS per day; §Don't Hand-Roll → Darwin notification center |
| SCH-04 | Shield applies during scheduled blocks same as quick sessions | §State of the Art → Phase 4 D-14 "shield parity" means ShieldConfigurationExtension is source-agnostic — zero-work for SCH-04 gdy `ManagedSettingsStore(named: "deluludetox.schedule")` content merguje się w system-widoczny shield |

## Project Constraints (from CLAUDE.md)

- **Tech stack lock:** Swift 6.2, SwiftUI, iOS 26.0+ — brak UIKit poza bridge'ami (edytor schedule'a w czystym SwiftUI).
- **XcodeGen source of truth:** edytuj `project.yml`, potem `xcodegen generate`. Nigdy ręcznie `.xcodeproj`.
- **Build flow:** XcodeBuildMCP (`session_show_defaults` → `build_sim` → `test_sim`). Nigdy raw `xcodebuild`.
- **Default simulator:** iPhone 17 · iOS 26.2 (UUID `C958163F-49E1-4B46-8A6D-C2056CD25A37`).
- **Clean Architecture:** MVVM (Presentation) + UseCase (Domain) + Repository (Data). **Twarde reguły zależności:**
  - Repository ↛ Repository (łączenie źródeł = UseCase)
  - UseCase → UseCase / Repository (nie systemowe API bezpośrednio)
  - ViewModel → tylko UseCase (brak import SwiftUI poza `Observation`)
  - View → tylko ViewModel
- **Feature-first:** Repository + UseCase + ViewModel + View w katalogu feature'a. Kod cross-feature → `Common/` feature-ownera, konsumowany PRZEZ UseCase (nie Repository bezpośrednio). Brak `FeatureCommons/`.
- **ViewModels:** `@Observable`, nie importują SwiftUI (poza `Observation`).
- **DI:** `DIContainer` (singleton, scope'y `.application`/`.unique`). `@LazyInjected` dla VM, init injection dla Repository/UseCase/źródeł. Distributed registration w `Features/<Feature>/Injection/<Feature>Injection.swift`. Rejestracja wołana z `DeluluDetoxApp.init()`, **feature-owner first**.
- **Navigation:** swift-navigation (`SwiftUINavigation`), `Destination?` enum z `@CasePathable`, case-path bindings.
- **KISS/DRY/SOLID:** żadna warstwa bez konkretnego powodu; trywialny pass-through UC OK jeśli utrzymuje kontrakt VM→UC.
- **DAM extension 6 MB RAM limit + no third-party SDKs** (dotyczy też Phase 5 rozszerzeń DAM code).
- **App Group:** `group.com.kksw.DeluluDetox` — wszystkie targety mają entitlement.
- **URL scheme:** `deluludetox` (CFBundleURLSchemes). Phase 5 nie dodaje nowych deep linków.
- **GSD workflow:** wszystkie zmiany kodu przez GSD commands (`/gsd-execute-phase`).

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DeviceActivity (Apple framework) | iOS 15+ / używamy iOS 26.0+ | `DeviceActivityCenter.startMonitoring(_:during:)` + `DeviceActivitySchedule` (DateComponents + repeats) + `DeviceActivityMonitor` extension class z `intervalDidStart`/`intervalDidEnd` callbacks | Jedyny sposób na scheduled blocking w iOS. Zero alternatyw w ekosystemie Apple. `[CITED: developer.apple.com/documentation/deviceactivity]` |
| ManagedSettings (Apple framework) | iOS 15+ / iOS 26.0+ | `ManagedSettingsStore(named: "deluludetox.schedule")` — osobny named store od Phase 3's `deluludetox.session`. Od iOS 16 **settings są współdzielone** między main app a DAM extension per named store. | Jedyny sposób na egzekwowanie shield. Named stores są canonical multi-layer pattern (Foqos używa tego samego). `[CITED: developer.apple.com forums — iOS 16 shared named stores]` |
| FamilyControls (Apple framework) | iOS 15+ / iOS 26.0+ | Token types (`ApplicationToken`, `WebDomainToken`, `ActivityCategoryToken`) czytane z `blocklists.json` Phase 2 | Konsumpcja, nie re-use. Phase 5 nie używa `FamilyActivityPicker` — blocklistId FK do Phase 2. `[VERIFIED: Phase 2 BlocklistRepository.swift]` |
| Combine | iOS 13+ | `CurrentValueSubject<Schedule?, Never>` w `ScheduleRepository` → `schedulePublisher` → `ObserveScheduleUseCase` → subskrybowane w ViewModel | Wzorzec repository-driven reactive state ustalony w Phases 1/2/3 (ScreenTimeAuthRepository, BlocklistRepository, SessionRepository). `[VERIFIED: .claude/guides/dependency-injection/GUIDE.md §Reactive state]` |
| swift-navigation (pointfreeco) | 2.8.0+ (pinned w `project.yml`) | `@CasePathable` enum Destination + case-path bindings dla sheet/push/alert | Już zintegrowane, używane w AppRootViewModel + HomeViewModel. `[VERIFIED: project.yml linia 39-40]` |
| Swift Observation | iOS 17+ / Swift 5.9+ | `@Observable` na `ScheduleEditorViewModel`, `ScheduleListViewModel` | Apple-native, już używane w każdym VM projektu. `[VERIFIED: HomeViewModel.swift, OnboardingViewModel.swift]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | iOS 2.0+ | `Calendar.current.component(.weekday, from: Date())` dla filtrowania dni w extension; `JSONEncoder/Decoder`; `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` | Wszędzie. Extension też (SessionPaths.swift używa Foundation). |
| CoreFoundation (Darwin notifications) | Always | `CFNotificationCenterGetDarwinNotifyCenter()` + `CFNotificationCenterPostNotification` w DAM → `CFNotificationCenterAddObserver` w main AppRootViewModel | Patrz Phase 3 pattern. Phase 5 dodaje dwie nowe nazwy: `com.kksw.DeluluDetox.scheduleStarted`, `com.kksw.DeluluDetox.scheduleEnded`. `[VERIFIED: AppRootViewModel.swift registerDarwinFinalizeObserver()]` |
| os.Logger | iOS 14+ | `Logger(subsystem: "com.kksw.DeluluDetox", category: "ScheduleRepository")` | Wszędzie. Extensions też (DAM logger już jest). |
| SwiftUI DatePicker(.hourAndMinute, displayedComponents:) w `.wheel` style | iOS 15+ | Edytor godziny startu/końca w edytorze schedule'a | Phase 3 SessionStartView używa tego samego wzorca dla custom duration. Re-use, nie re-invent. `[VERIFIED: Phase 3 D-18 comment in CONTEXT.md]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 1 DAS `repeats=true` + weekday filter w DAM extension | 7 osobnych DAS per dzień tygodnia (Mon, Tue, ..., Sun) każdy `repeats=true` z `weekday:` w DateComponents | **Odrzucone** (D-13). 7 DAS per schedule vs 1-2. Przy 3 schedule'ach cross-midnight = 6 DAS → wyczerpujesz 20 szybko. Apple forum thread #742131 pokazuje że developerzy też używają in-extension filter. `[CITED: developer.apple.com/forums/thread/742131]` |
| 2 osobne stores (`deluludetox.session` + `deluludetox.schedule`) | 1 wspólny store `deluludetox.main` + logika "who owns what" | **Odrzucone** (D-05). Wspólny store wymagałby imperatywnego mergowania/diffowania tokenów przy overlapping windows. Named stores + auto-merge iOS = zero logiki, zero race conditions. `[VERIFIED: iOS 16+ ManagedSettings shared named stores, Apple forum #726494]` |
| Cross-midnight jako 1 DAS z `(22:00, 06:00)` repeats=true | Dwa DAS `.evening` (22:00→23:59:59) + `.morning` (00:00:00→06:00) | **Odrzucone** (D-03). Inline komentarz w `SessionActivityMonitoringRepository.swift` potwierdza: bez `.year/.month/.day` (czyli repeats=true) `endHour < startHour` albo rzuca albo natychmiast fire intervalDidEnd. Ten sam bug dotknął Phase 3 dla sesji cross-midnight. `[VERIFIED: SessionActivityMonitoringRepository.swift linie 68-77]` |
| Main app writes `schedule_events.json` directly z DAM | DAM pisze `schedule_event_marker.json` (overwrite), main app appenduje na foreground | **Odrzucone** (D-17). Phase 3 D-03 ustalił: extension = writer ONLY markerów, main app = reconciler. Append z extension → race conditions + 6 MB RAM ryzyko. `[VERIFIED: Phase 3 CONTEXT D-03]` |

**Installation:** Zero new dependencies. Phase 5 używa wyłącznie Apple frameworks + istniejącego swift-navigation.

**Version verification:** Nie dotyczy — wszystkie zależności to Apple frameworks (pinned do iOS 26.0+) lub już pinned swift-navigation 2.8.0+.

## Architecture Patterns

### Recommended Project Structure

Feature-first, zgodnie z `.claude/guides/feature-structure/GUIDE.md` Split variant (2 ekrany: list + editor — kwalifikuje się do Split od razu):

```
DeluluDetox/Sources/Features/Scheduling/
├── Common/
│   ├── Repository/
│   │   ├── ScheduleRepository.swift                      // protokół + impl (App Group JSON, CurrentValueSubject)
│   │   ├── ScheduleShieldRepository.swift                // protokół + impl (ManagedSettings named "deluludetox.schedule")
│   │   ├── ScheduleActivityMonitoringRepository.swift    // protokół + impl (DeviceActivityCenter start/stop z segmentami)
│   │   └── Models/
│   │       ├── Schedule.swift                            // Codable struct (D-02)
│   │       ├── ScheduleSegment.swift                     // enum: .single / .evening / .morning (cross-midnight helper)
│   │       ├── ScheduleActivityNames.swift               // shared z DAM extension
│   │       ├── SchedulePaths.swift                       // App Group URL helpers (shared z DAM)
│   │       ├── ScheduleEvent.swift                       // append-only history row
│   │       └── ScheduleEventMarker.swift                 // overwrite-marker z DAM (shared z DAM)
│   └── UseCase/
│       ├── ObserveScheduleUseCase.swift                  // VM subscription
│       ├── CreateOrUpdateScheduleUseCase.swift           // editor save
│       ├── ToggleScheduleUseCase.swift                   // enable/disable flip
│       ├── SyncScheduleWithSystemUseCase.swift           // (D-14) stop/start DAS
│       ├── SelfHealSchedulesUseCase.swift                // (D-18) scenePhase.active
│       ├── ConsumeScheduleEventMarkerUseCase.swift       // reconcile marker → events.json
│       └── ComputeScheduleWindowUseCase.swift            // pure: "should be active now?" (testowalne)
├── List/
│   ├── ViewModel/ScheduleListViewModel.swift             // @Observable, list → editor nav
│   └── View/ScheduleListView.swift
├── Editor/
│   ├── ViewModel/ScheduleEditorViewModel.swift           // @Observable
│   └── View/ScheduleEditorView.swift
└── Injection/SchedulingInjection.swift                   // rejestracja 3 repo + 7 UC w DIContainer

Extensions/DeviceActivityMonitorExtension/
└── DeviceActivityMonitorExtension.swift                   // rozszerzony: filtr po activity.rawValue prefix, dispatch do per-source handlera
```

**Naming convention:**
- Feature katalog: **`Scheduling`** (nie "Schedule" — spójne z "AppSelection", nie "BlocklistSelection"; rzeczownik odczasownikowy).
- ManagedSettingsStore: `"deluludetox.schedule"` (D-05 — singular, mirror `"deluludetox.session"`).
- DAS names: `"deluludetox.schedule.{uuid}.main"` lub `"...evening"` / `"...morning"`.
- Darwin notifications: `"com.kksw.DeluluDetox.scheduleStarted"` / `"...scheduleEnded"`.
- App Group files: `schedule.json`, `schedule_event_marker.json`, `schedule_events.json`.

### Pattern 1: Three-Repository Split (mirror Phase 4 SessionEnforcer refactor)

**What:** Poprzednie `SessionEnforcer` (Phase 3) został w Phase 4 rozbity na 3 repozytoria (`SessionRepository`, `SessionShieldRepository`, `SessionActivityMonitoringRepository`) zgodnie z zasadą "1 aggregate = 1 repository". Phase 5 buduje tę samą strukturę od razu.

**When to use:** Dla każdego feature'a który dotyka ManagedSettings + DeviceActivity jednocześnie.

**Example:**
```swift
// Features/Scheduling/Common/Repository/ScheduleRepository.swift
// Mirror: Features/Session/Repository/SessionRepository.swift
import Combine
import Foundation
import os

protocol ScheduleRepository: Sendable {
    var schedulesPublisher: AnyPublisher<[Schedule], Never> { get }
    func upsert(_ schedule: Schedule) async throws
    func remove(id: UUID) async throws
    func loadFromDisk() async throws -> [Schedule]
    func appendEvent(_ event: ScheduleEvent) async throws
    func consumeEventMarker() async throws -> ScheduleEventMarker?
}

// Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift
// Mirror: SessionShieldRepository.swift — tylko inny named store.
protocol ScheduleShieldRepository: Sendable {
    func applyShield(for blocklist: Blocklist) async throws
    func clearShield() async
}

final class LiveScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable {
    private let store: ManagedSettingsStoreWriter   // reuse seam z Phase 4
    convenience init() { self.init(store: LiveManagedSettingsStoreWriter(storeName: "deluludetox.schedule")) }
    // ... rest identyczne co SessionShieldRepository ale named store "deluludetox.schedule"
}

// Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift
// Różnica vs Session: dostaje listę segmentów (1 lub 2), repeats=true, name-per-segment.
protocol ScheduleActivityMonitoringRepository: Sendable {
    func startMonitoring(schedule: Schedule) async throws
    func stopMonitoring(scheduleId: UUID) async
}
```

**Key insight:** Protokół `ManagedSettingsStoreWriter` z Phase 4 (`SessionShieldRepository.swift` linia 28) jest ready to reuse — Phase 5 konstruuje `LiveManagedSettingsStoreWriter(storeName: "deluludetox.schedule")` i wstrzykuje go do `LiveScheduleShieldRepository`. Testy Phase 5 używają tego samego fake writera.

### Pattern 2: UseCase Layer — "compute" UC jako osobny UC

**What:** Obliczenie "czy dany Schedule powinien być aktywny w `now`" jest **pure logic** — Calendar math + weekday filter + cross-midnight wrap. Wydzielamy jako `ComputeScheduleWindowUseCase` bez zależności (tylko Calendar). To pozwala:
- Testy jednostkowe z deterministic `now` i dowolną konfiguracją schedule.
- Reuse w DAM extension filter (D-15 step 3), w self-heal (D-18), i w UI (preview "będzie aktywny za Xh").

**When to use:** Zawsze gdy logika jest czysto deterministyczna — pure UC bez Repository dependency nie łamie "VM → tylko UC" reguły, a jednocześnie izoluje skomplikowaną logikę czasową.

**Example:**
```swift
// Features/Scheduling/Common/UseCase/ComputeScheduleWindowUseCase.swift
protocol ComputeScheduleWindowUseCase: Sendable {
    func callAsFunction(schedule: Schedule, now: Date, calendar: Calendar) -> ScheduleWindow
}

struct ScheduleWindow: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case active(endsAt: Date)
        case upcomingToday(startsAt: Date)
        case notToday(nextDate: Date?)   // brak dzisiaj, ale jutro/pojutrze...
        case inactive                    // schedule disabled
    }
    let state: State
    let currentWeekday: Int              // 1..7
}

final class ComputeScheduleWindowUseCaseImpl: ComputeScheduleWindowUseCase {
    func callAsFunction(schedule: Schedule, now: Date, calendar: Calendar) -> ScheduleWindow {
        guard schedule.enabled else { return ScheduleWindow(state: .inactive, currentWeekday: 0) }
        let weekday = calendar.component(.weekday, from: now)
        // ... cross-midnight wrap logic + weekday membership check ...
    }
}
```

### Pattern 3: Editor VM z `@Observable` + draft state

**What:** `ScheduleEditorViewModel` trzyma **draft** (mutowalny roboczy stan) + publikuje save → `CreateOrUpdateScheduleUseCase`. Pattern reuse z `SessionStartViewModel` (draft duration).

**Example:**
```swift
// Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift
import Observation
import SwiftUINavigation   // @CasePathable dla Destination; VM SwiftUI-free w reszcie

@MainActor
@Observable
final class ScheduleEditorViewModel: @unchecked Sendable {

    @CasePathable
    enum Destination: Equatable {
        case errorAlert(String)
    }

    var destination: Destination?

    // Draft fields — binding targets w View.
    var daysOfWeek: Set<Int>   // 1..7
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var enabled: Bool

    var isCrossMidnight: Bool { /* (endHour, endMinute) < (startHour, startMinute) */ }

    @ObservationIgnored @LazyInjected private var createOrUpdate: CreateOrUpdateScheduleUseCase
    @ObservationIgnored @LazyInjected private var sync: SyncScheduleWithSystemUseCase

    private let editingId: UUID?   // nil = create, non-nil = update

    init(existing: Schedule? = nil) {
        self.editingId = existing?.id
        // ... seed draft fields from existing or defaults ...
    }

    func saveTapped() async {
        do {
            let schedule = Schedule(
                id: editingId ?? UUID(),
                daysOfWeek: Array(daysOfWeek).sorted(),
                startHour: startHour, startMinute: startMinute,
                endHour: endHour, endMinute: endMinute,
                enabled: enabled,
                blocklistId: /* single implicit from blocklistRepo via UC */,
                appVersion: /* ... */
            )
            try await createOrUpdate(schedule)
            try await sync(schedule: schedule)
        } catch {
            destination = .errorAlert("iOS się zbuntował, spróbuj jeszcze raz.")
            // + rollback schedule.json handled w UseCase
        }
    }
}
```

### Anti-Patterns to Avoid

- **N DAS per dzień tygodnia zamiast filter w extension.** 7 schedules × 7 dni = 49 activities. 20-activity budget pada natychmiast. Używaj `repeats: true` z `Calendar.weekday` filtering w `intervalDidStart`.
- **Pisanie `schedule_events.json` bezpośrednio z DAM.** Łamie D-17 / Phase 3 D-03. Potencjalny race z main app + 6 MB RAM pressure z JSON serializacji całej historii.
- **Synchroniczne poll `isCurrentlyActive` computed property na Schedule struct.** VM musi iść przez UC (`ComputeScheduleWindowUseCase`) — inaczej łamie regułę "VM → tylko UC".
- **Dodawanie nowego URL scheme dla schedule deep linków.** Phase 5 D-20 explicite: notifications to Phase 6. MVP nie dotyka URL scheme.
- **Rejestracja DI schedule'a w `SessionInjection` albo `AppSelectionInjection`.** Każdy feature rejestruje własne zależności (`SchedulingInjection.swift`). Wywoływane z `DeluluDetoxApp.init()` po `SessionInjection`.
- **Używanie jednego `ManagedSettingsStore(named: "deluludetox.session")` dla obu źródeł.** Phase 3 clearAllSettings by wyczyścił schedule shield. Must be separate named stores.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-process notifications extension ↔ main app | Polling pliku co 500ms / GCD signal | `CFNotificationCenterGetDarwinNotifyCenter()` + `CFNotificationCenterAddObserver` | Phase 3 już to ma (`AppRootViewModel.registerDarwinFinalizeObserver()`). Cross-process. Zero polling. |
| App Group container URL resolution | Hardcode path | `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` | SessionPaths.swift już tę abstrakcję ma — Phase 5 dodaje `SchedulePaths.swift` w tej samej konwencji |
| Atomic JSON write | Własny temp-file + rename | `try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])` | Phase 2/3 wzorzec. `[VERIFIED: SessionRepository.writeAtomic]` |
| Reactive repository state w extension ↔ main app | Shared memory / XPC | **Pattern hybrid:** main app = `CurrentValueSubject` (in-process reactive), DAM = marker file + Darwin notification (cross-process) | Phase 3 solved — nie duplikuj. Main app reconciliates marker na foreground. |
| Shield visual configuration | Reinvent SwiftUI shield layout | **Nic nie rób.** `ShieldConfigurationExtension.buildShieldConfiguration()` z Phase 4 jest source-agnostic. Blokada z `deluludetox.schedule` store automatycznie dostaje ten sam branded shield | Phase 4 D-14 / SCH-04 — zero-code delivery |
| Calendar.weekday conversions | Sunday-first vs Monday-first debates | `Calendar.current.component(.weekday, from: Date())` zawsze zwraca 1=Sunday..7=Saturday (locale-independent for the component enum; only week-start formatting is locale-sensitive) | D-02 zamraża schemat. UI potem mapuje na PL labels. |
| `ManagedSettingsStoreWriter` seam dla testów | Mock całego `ManagedSettingsStore` (nie-Sendable, hard to mock) | Reuse `ManagedSettingsStoreWriter` protokół + `LiveManagedSettingsStoreWriter(storeName:)` z Phase 4 | `SessionShieldRepository.swift` linia 28-36 |
| `DeviceActivityCenterRunner` seam dla testów | Mock `DeviceActivityCenter` bezpośrednio | Reuse `DeviceActivityCenterRunner` protokół + `LiveDeviceActivityCenterRunner` z Phase 4 | `SessionActivityMonitoringRepository.swift` linia 29-46 |

**Key insight:** Phases 2/3/4 zbudowały **kompletną infrastrukturę cross-process state management** (App Group, Darwin, markers, atomic writes, named stores, self-heal). Phase 5 to gł. aplikacja tej infrastruktury do innego event source (schedule boundary zamiast session timer). Nie re-implementuj — skopiuj wzorce 1:1.

## Runtime State Inventory

> Phase 5 to **greenfield feature** — brak kodu, brak persistowanego state do migracji. Sekcja poniżej dokumentuje nowy state, który Phase 5 wprowadza (dla jasności przy wycofaniu w dev test).

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **Nowy** `schedule.json` (main app sole writer, App Group). **Nowy** `schedule_events.json` (append-only historia). **Nowy** `schedule_event_marker.json` (DAM overwrite, main app consumes). `UserDefaults` — brak nowych kluczy. | Zero migracji istniejących danych. Nowe pliki pojawiają się na pierwszym save. |
| Live service config | `ManagedSettingsStore(named: "deluludetox.schedule")` — nowy store, osobny od `"deluludetox.session"`. Jego shield.* fields są odczytywane przez system iOS. | Clear na uninstall dzieje się automatycznie (iOS kasuje store przy removenięciu entitlementa). |
| OS-registered state | **Nowe** DeviceActivity registrations: `deluludetox.schedule.{uuid}.main` lub `.evening`+`.morning`. Zarejestrowane w iOS DeviceActivityCenter, persistują przez reboot. `Sync...UseCase` zarządza lifecyclem (stop starych przed register nowych). | DAM extension musi nauczyć się filtrować `activity.rawValue.hasPrefix("deluludetox.schedule.")` vs `activity == SessionActivityNames.quickSession`. |
| Secrets/env vars | None. | — |
| Build artifacts | Nowe source-shares w `project.yml` (SchedulePaths, ScheduleActivityNames, ScheduleEventMarker, Schedule.swift — dla DAM extension target). Po zmianie `project.yml` → `xcodegen generate`. | Standardowy flow XcodeGen. |

**Nothing found in category:** Secrets/env vars — Phase 5 nie dotyka API keys ani SOPS.

## Common Pitfalls

### Pitfall 1: Cross-midnight DAS fires immediately on startMonitoring
**What goes wrong:** Rejestrujesz `DeviceActivitySchedule(intervalStart: DateComponents(hour: 22), intervalEnd: DateComponents(hour: 6), repeats: true)`. iOS albo throw'uje, albo natychmiast fire'uje `intervalDidEnd` — shield aplikuje się na moment i znika.
**Why it happens:** iOS traktuje `intervalEnd < intervalStart` w tym samym dniu jako malformed. Ten sam problem dotknął Phase 3 dla sesji cross-midnight — inline komentarz w `SessionActivityMonitoringRepository.swift` (linie 68-77) udokumentowany.
**How to avoid:** D-03 = split na dwa DAS. `.evening` (start → 23:59:59) + `.morning` (00:00:00 → end). Oba repeats=true. Filter weekday w extension dotyczy daty kalendarzowej bieżącego intervalu.
**Warning signs:** Sleep block "nie działa" — user widzi shield na sekundę i znika. Logi `Logger: intervalDidStart` natychmiast po `intervalDidEnd`.

### Pitfall 2: Token rotation between main app and extension
**What goes wrong:** Main app odczytuje blocklist, zapisuje tokeny do `blocklists.json`. DAM extension później odczytuje ten plik w `intervalDidStart` — ale iOS rotated tokens (znany bug iOS 17.5+). Shield aplikuje się do niczego lub złych aplikacji.
**Why it happens:** Udokumentowane w `STATE.md` §Blockers: iOS 17.5 through 26.3.1 rotuje opaque tokens między procesami.
**How to avoid:** Phase 2 D-04 (SEL-05) — records są keyed by own UUID, token to best-effort pointer. `BlocklistRepository.reconcile()` na `scenePhase.active` odświeża pointers. Phase 5 D-18 self-heal też reconciliuje.
**Warning signs:** User reporting "blokada działa rano ale wieczorem już nie blokuje YouTube".

### Pitfall 3: DAM 6 MB RAM limit exceeded
**What goes wrong:** Dokładasz nową logikę do `intervalDidStart` — JSON parsowanie całej historii, pobieranie blocklisty, decoding wielu modeli. DAM extension przekracza 6 MB i jest killed przez iOS. Shield nie aplikuje się.
**Why it happens:** DAM extension ma twardy 6 MB RAM ceiling. Każdy import Framework (SwiftUI, Combine full, custom SPM) zżera pamięć.
**How to avoid:**
- DAM source-share tylko minimalne pliki (SchedulePaths, ScheduleActivityNames, Schedule struct, ScheduleEventMarker).
- Unikaj `import Combine` w DAM. Używaj Foundation only + `os` + DeviceActivity + ManagedSettings.
- Token parsing z blocklists.json → lokalna Decodable envelope (tylko te pola, które potrzeba) — wzór: `struct SessionIdEnvelope: Decodable { let id: UUID }` z Phase 3 DAM (linia 85).
- NIE importuj `ScheduleRepository` do DAM — tylko modele + paths.

**Warning signs:** Shield "czasami działa, czasami nie". iOS crashes w Console `com.apple.deviceactivity` z termination reason OutOfMemory.

### Pitfall 4: Schedule save race między main app a foreground reconcile
**What goes wrong:** User naciska "Zapisz" w edytorze. UC pisze `schedule.json` atomic. W tym samym momencie `SelfHealSchedulesUseCase` (wywołany z `scenePhase.active`) czyta poprzednią wersję i aplikuje stary state → chwilowy mismatch.
**Why it happens:** `Data.write(atomic:)` jest atomic na poziomie filesystem, ale reader nie blocuje pisarza. Dwa async Task'i mogą czytać różne wersje.
**How to avoid:** `ScheduleRepository` używa `CurrentValueSubject<[Schedule], Never>` jako source of truth w pamięci. Read path = `repo.schedulesPublisher.first()`. Disk to persistency layer, nie source of truth dla live VMs. Self-heal czyta z pamięci (subject), nie z dysku.
**Warning signs:** "Zapisałem, ale od razu po zapisie schedule pokazuje stary wpis" — potem po foreground refresh ok.

### Pitfall 5: Disable toggle mid-window leaves dirty store
**What goes wrong:** Schedule aktywny (shield nakłożony). User disable'uje toggle. `stopMonitoring` kasuje DAS, ale `ManagedSettingsStore(named: "deluludetox.schedule").shield.applications` **nie znika sam** — musi być explicite clearowany.
**Why it happens:** iOS nie łączy "DAS ended by user" z "shield should clear". `stopMonitoring` jest purely scheduling-side.
**How to avoid:** **Świadoma decyzja D-11:** disable nie czyści store od razu. Czeka na pierwotne `intervalDidEnd`. Self-heal (D-18) wykrywa mismatch na następnym scenePhase.active i clearuje. Akceptowalne UX: "wyłączyłem, ale apka jeszcze blokuje przez X" — user widzi.
**Warning signs:** User reporting "wyłączyłem harmonogram ale Instagram dalej zablokowany". **Jeśli to jest blocker UX → zaimplementuj emergency override w Phase 5 execute** (Claude's Discretion — CONTEXT.md marked deferred, ale można revisit).

### Pitfall 6: Quick session end clearuje schedule store przypadkiem
**What goes wrong:** Phase 3 `EndSessionUseCase` woła `SessionShieldRepository.clearShield()` który clearuje `"deluludetox.session"` store. Jeśli przez pomyłkę (copy-paste bug) woła `"deluludetox.schedule"` → schedule window miganie.
**Why it happens:** Named stores isolation zależy od literal string. Literal rozjedzie się jeśli ktoś zrefaktoruje.
**How to avoid:** Stały plik `ManagedSettingsStoreNames.swift` (w `Common/` na poziomie app, bo używane przez 2+ feature'y):
```swift
enum ManagedSettingsStoreNames {
    static let session = "deluludetox.session"
    static let schedule = "deluludetox.schedule"
}
```
Phase 4 już wprowadził concepty (storeName init-arg). Phase 5 to formalizuje.
**Warning signs:** Tests przechodzą ale manual test pokazuje "schedule się resetuje gdy kończę quick session".

### Pitfall 7: Weekday offset confusion (1=Sunday vs 1=Monday)
**What goes wrong:** `Calendar.weekday` zwraca 1=Sunday..7=Saturday. UI pokazuje Pn jako pierwszy dzień. Programista zapisuje daysOfWeek jako 1=Monday i popisuje offsetem.
**Why it happens:** PL convention "tydzień zaczyna się od Pn" ≠ Apple `Calendar.weekday` values.
**How to avoid:** D-02 zamraża: schema `daysOfWeek: [Int]` używa **Calendar.weekday** values (1=Sun..7=Sat). UI to display layer — mapowanie w View (Pn→2, Wt→3, ..., Nd→1). Nigdy nie zmieniaj semantyki schematu.
**Warning signs:** "Ustawiłem schedule na Pn-Pt, ale blokuje w weekend".

### Pitfall 8: scenePhase.active self-heal pisze do disku przed reading
**What goes wrong:** `SelfHealSchedulesUseCase` czyta `schedule.json`, computes expected state, writes reconciled shield. Ale reader kopiuje już-nieaktualne subject value (repo nie load'ował z disk po launch).
**Why it happens:** Repository impl czyta z disk TYLKO w init. Jeśli main app był killed, po restart subject ma initial value z disk — OK. Jeśli DAM wrote marker w międzyczasie → main app **musi najpierw consume marker**, dopiero potem self-heal.
**How to avoid:** Kolejność operacji w `AppRootViewModel.refreshStatus()` (już jest w Phase 3 Plan): consume marker → self-heal → detect revocation. Phase 5 dokłada `ConsumeScheduleEventMarkerUseCase` + `SelfHealSchedulesUseCase` **w tej kolejności**.
**Warning signs:** Scheduled event marker pozostaje niezrealizowany po scenePhase.active.

## Code Examples

### Example 1: DeviceActivitySchedule construction for single-day recurring schedule

```swift
// Source: mirror Phase 3 SessionActivityMonitoringRepository.swift lines 68-93
// + Apple forum thread #742131 (repeats=true + weekday filter in extension)

import DeviceActivity
import Foundation

extension Schedule {
    /// Returns 1 or 2 activity name + DAS pairs to register.
    /// Cross-midnight produces 2 pairs (evening + morning), single-day 1 pair.
    func buildDeviceActivitySchedules() -> [(name: DeviceActivityName, schedule: DeviceActivitySchedule)] {
        let startMin = startHour * 60 + startMinute
        let endMin = endHour * 60 + endMinute
        let crossesMidnight = endMin <= startMin

        if !crossesMidnight {
            let name = DeviceActivityName("deluludetox.schedule.\(id.uuidString).main")
            let das = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: startHour, minute: startMinute),
                intervalEnd: DateComponents(hour: endHour, minute: endMinute, second: 0),
                repeats: true
            )
            return [(name, das)]
        }

        // Cross-midnight split (D-03)
        let evening = (
            DeviceActivityName("deluludetox.schedule.\(id.uuidString).evening"),
            DeviceActivitySchedule(
                intervalStart: DateComponents(hour: startHour, minute: startMinute),
                intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
                repeats: true
            )
        )
        let morning = (
            DeviceActivityName("deluludetox.schedule.\(id.uuidString).morning"),
            DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
                intervalEnd: DateComponents(hour: endHour, minute: endMinute, second: 0),
                repeats: true
            )
        )
        return [evening, morning]
    }
}
```

### Example 2: DAM extension — intervalDidStart with weekday filter

```swift
// Source: extension of Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
// Phase 5 ADDS handling; Phase 3 intervalDidEnd for quickSession remains untouched.

import DeviceActivity
import Foundation
import ManagedSettings
import os

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "...", category: "Monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart: \(activity.rawValue, privacy: .public)")

        let raw = activity.rawValue
        guard raw.hasPrefix("deluludetox.schedule.") else {
            // Not our scheduling event — ignore.
            return
        }

        // Parse schedule id from "deluludetox.schedule.{uuid}.{segment}".
        let parts = raw.split(separator: ".")
        guard parts.count >= 4, let scheduleId = UUID(uuidString: String(parts[2])) else {
            logger.error("malformed schedule activity name: \(raw, privacy: .public)")
            return
        }

        // Load schedule.json and find matching schedule.
        guard let schedule = loadSchedule(id: scheduleId), schedule.enabled else {
            logger.info("schedule \(scheduleId.uuidString, privacy: .public) disabled or missing")
            return
        }

        // D-15 step 3: weekday filter.
        let weekday = Calendar.current.component(.weekday, from: Date())
        guard schedule.daysOfWeek.contains(weekday) else {
            logger.info("weekday \(weekday, privacy: .public) not in schedule days \(schedule.daysOfWeek, privacy: .public); skip apply")
            return
        }

        // Read blocklist tokens (same blocklists.json as Phase 2/3).
        guard let tokens = loadBlocklistTokens(id: schedule.blocklistId) else {
            logger.info("blocklist missing; schedule skipped")
            return
        }

        // Apply shield to SCHEDULE-specific named store (D-05).
        let store = ManagedSettingsStore(named: .init("deluludetox.schedule"))
        store.shield.applications = tokens.apps.isEmpty ? nil : tokens.apps
        store.shield.webDomains = tokens.webs.isEmpty ? nil : tokens.webs
        // categories set identically to Phase 3 SessionShieldRepository.applyShield
        // (ShieldSettings.ActivityCategoryPolicy<Application>.specific(tokens) or nil)

        // D-17: write event marker + fire Darwin notification.
        writeEventMarker(scheduleId: scheduleId, kind: .started)
        postDarwin(name: "com.kksw.DeluluDetox.scheduleStarted")

        logger.info("schedule shield applied id=\(scheduleId.uuidString, privacy: .public) apps=\(tokens.apps.count, privacy: .public)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let raw = activity.rawValue

        // Phase 3 path — quick session finalize (existing code).
        if activity == SessionActivityNames.quickSession {
            // ... existing Phase 3 handler ...
            return
        }

        // Phase 5 path — schedule end.
        guard raw.hasPrefix("deluludetox.schedule.") else { return }
        let parts = raw.split(separator: ".")
        guard parts.count >= 4, let scheduleId = UUID(uuidString: String(parts[2])) else { return }

        // D-16: clear the schedule-specific store only.
        let store = ManagedSettingsStore(named: .init("deluludetox.schedule"))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        writeEventMarker(scheduleId: scheduleId, kind: .ended)
        postDarwin(name: "com.kksw.DeluluDetox.scheduleEnded")

        logger.info("schedule shield cleared id=\(scheduleId.uuidString, privacy: .public)")
    }

    // MARK: helpers — tight (no Combine, no third-party imports; 6 MB budget)

    private func loadSchedule(id: UUID) -> Schedule? {
        do {
            let url = try SchedulePaths.schedulesURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            let all = try JSONDecoder().decode([Schedule].self, from: data)
            return all.first(where: { $0.id == id })
        } catch {
            return nil
        }
    }

    // loadBlocklistTokens, writeEventMarker, postDarwin — analogous to Phase 3
    // helpers. All read-only from App Group; marker write is atomic overwrite.
}
```

### Example 3: SchedulingInjection (DI registration, feature-owner)

```swift
// Features/Scheduling/Injection/SchedulingInjection.swift
// Mirror: SessionInjection.swift — register BEFORE HomeInjection + RootInjection.

enum SchedulingInjection {
    static func register(in container: DIContainer) {
        // Repositories — singletons (one CurrentValueSubject per process).
        container.register(ScheduleRepository.self, scope: .application) { _ in
            ScheduleRepositoryImpl()
        }
        container.register(ScheduleShieldRepository.self, scope: .application) { _ in
            LiveScheduleShieldRepository()
        }
        container.register(ScheduleActivityMonitoringRepository.self, scope: .application) { _ in
            LiveScheduleActivityMonitoringRepository()
        }

        // Pure compute UC — no deps, used by VM + self-heal + list preview.
        container.register(ComputeScheduleWindowUseCase.self, scope: .unique) { _ in
            ComputeScheduleWindowUseCaseImpl()
        }

        // Observe UC — VM subscription wrapper.
        container.register(ObserveScheduleUseCase.self, scope: .unique) { c in
            ObserveScheduleUseCaseImpl(repository: c.resolve())
        }

        // Sync UC — DAS register/unregister orchestration.
        container.register(SyncScheduleWithSystemUseCase.self, scope: .unique) { c in
            SyncScheduleWithSystemUseCaseImpl(
                monitoring: c.resolve()
            )
        }

        // Editor save path.
        container.register(CreateOrUpdateScheduleUseCase.self, scope: .unique) { c in
            CreateOrUpdateScheduleUseCaseImpl(
                repository: c.resolve(),
                sync: c.resolve()
            )
        }

        // Toggle enable/disable.
        container.register(ToggleScheduleUseCase.self, scope: .unique) { c in
            ToggleScheduleUseCaseImpl(
                repository: c.resolve(),
                sync: c.resolve()
            )
        }

        // Self-heal (scenePhase.active).
        container.register(SelfHealSchedulesUseCase.self, scope: .unique) { c in
            SelfHealSchedulesUseCaseImpl(
                scheduleRepo: c.resolve(),
                shieldRepo: c.resolve(),
                // Self-heal needs BlocklistRepository for token lookup — so it sits
                // at UseCase layer (can depend on both). Phase 2 BlocklistRepository
                // is already singleton-registered by AppSelectionInjection.
                blocklistRepo: c.resolve(),
                compute: c.resolve()
            )
        }

        // Marker reconcile (scenePhase.active).
        container.register(ConsumeScheduleEventMarkerUseCase.self, scope: .unique) { c in
            ConsumeScheduleEventMarkerUseCaseImpl(repository: c.resolve())
        }
    }
}

// DeluluDetoxApp.init() — add BETWEEN SessionInjection and DenialInjection.
// Rationale: Scheduling owns its graph but depends on BlocklistRepository
// (Phase 2) for token lookup at self-heal time. BlocklistRepository is
// registered by AppSelectionInjection which runs earlier.
```

### Example 4: AppRootViewModel.refreshStatus() — add schedule self-heal

```swift
// Features/Root/ViewModel/AppRootViewModel.swift — Phase 5 adds 2 UC resolutions
// and 2 steps in the Task closure. Existing 5 steps preserved.

@ObservationIgnored
@LazyInjected private var consumeScheduleMarker: ConsumeScheduleEventMarkerUseCase

@ObservationIgnored
@LazyInjected private var selfHealSchedules: SelfHealSchedulesUseCase

// Inside refreshStatus():
Task {
    let now = Date()
    // ... existing Phase 2/3 steps (reconcile, finalizeFromMarker, selfHealExpired, detectRevocation) ...

    // Phase 5 step 5: consume schedule event marker (DAM-written).
    do {
        _ = try await consumeScheduleMarker(now: now)
    } catch {
        log.error("consumeScheduleMarker failed: \(String(describing: error), privacy: .public)")
    }

    // Phase 5 step 6: self-heal schedule shields.
    do {
        _ = try await selfHealSchedules(now: now)
    } catch {
        log.error("selfHealSchedules failed: \(String(describing: error), privacy: .public)")
    }
}

// Also: add Darwin observer for "com.kksw.DeluluDetox.scheduleStarted" + "...scheduleEnded".
// Pattern mirror registerDarwinFinalizeObserver(); on fire → Task { @MainActor in refreshStatus() }.
```

### Example 5: Editor View — SwiftUI day chips + time wheels

```swift
// Features/Scheduling/Editor/View/ScheduleEditorView.swift
// Pattern reference: Apple Clock app alarm repeat picker.

import SwiftUI
import SwiftUINavigation

struct ScheduleEditorView: View {
    @Bindable var model: ScheduleEditorViewModel

    // Display order (Mon..Sun) vs Calendar.weekday (1=Sun..7=Sat).
    // Store uses Calendar.weekday values; view maps display→value.
    private let displayOrder: [(label: String, weekday: Int)] = [
        ("Pn", 2), ("Wt", 3), ("Śr", 4), ("Cz", 5), ("Pt", 6), ("Sb", 7), ("Nd", 1)
    ]

    var body: some View {
        Form {
            Section("Dni tygodnia") {
                HStack(spacing: 8) {
                    ForEach(displayOrder, id: \.weekday) { item in
                        DayChip(
                            label: item.label,
                            isOn: model.daysOfWeek.contains(item.weekday),
                            action: { toggle(item.weekday) }
                        )
                    }
                }
                HStack {
                    Button("Dni robocze") { model.daysOfWeek = [2, 3, 4, 5, 6] }
                    Button("Weekend") { model.daysOfWeek = [7, 1] }
                    Button("Codziennie") { model.daysOfWeek = [1, 2, 3, 4, 5, 6, 7] }
                }
            }

            Section("Przedział czasu") {
                DatePicker("Od",
                    selection: Binding(
                        get: { dateFromComponents(hour: model.startHour, minute: model.startMinute) },
                        set: { date in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                            model.startHour = c.hour ?? 0
                            model.startMinute = c.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)

                DatePicker("Do", selection: /* same pattern */, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)

                if model.isCrossMidnight {
                    Label("Cross-midnight — nocna zmiana, co?", systemImage: "moon.zzz")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Section {
                Toggle("Harmonogram aktywny", isOn: $model.enabled)
                Button("Zapisz") { Task { await model.saveTapped() } }
                    .tint(Color(red: 0.486, green: 0.227, blue: 0.929))   // electric violet #7C3AED
            }
        }
        .alert(
            "Błąd",
            isPresented: Binding(
                get: { model.destination.flatMap { /* pattern match errorAlert */ _ in true } ?? false },
                set: { if !$0 { model.destination = nil } }
            ),
            presenting: model.destination.flatMap { /* extract message */ }
        ) { _ in
            Button("OK") { model.destination = nil }
        } message: { msg in
            Text(msg)
        }
    }

    private func toggle(_ weekday: Int) {
        if model.daysOfWeek.contains(weekday) { model.daysOfWeek.remove(weekday) }
        else { model.daysOfWeek.insert(weekday) }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom polling timer w main app do enforce schedule | `DeviceActivitySchedule` + DAM extension | iOS 15 (2021) — API introduction | Foundational. Phase 5 używa canonical API. |
| Settings rewritten per-action w main app | `ManagedSettingsStore(named:)` shared between main app + extension | iOS 16+ | DAM może aplikować shield bez round-trip do main app. `[CITED: Apple forum #726494]` |
| Single ManagedSettingsStore dla wszystkich shieldów | Multiple named stores per concern | iOS 16+ | Phase 5 D-05 — schedule i session to osobne warstwy. Union merge jest zero-logic. |
| Shield custom per-source (quick vs scheduled różne UI) | Single ShieldConfiguration source-agnostic | Phase 4 D-14 (project decision) | **Phase 5 SCH-04 success criterion = zero code.** ShieldConfigurationExtension.buildShieldConfiguration() nie rozróżnia źródła. |
| XPC / shared memory dla extension↔main notifications | Darwin notifications + marker files | Phase 3 canonical pattern | Phase 5 reuse bez zmian. |
| SessionEnforcer "one god class" managing shield + DAS + persistence | Three-repo split (Repository + ShieldRepository + ActivityMonitoringRepository) | Phase 4 refactor (commits 3f819f6 + 0292419) | **Phase 5 greenfield build już z split'em** — unika debt. |

**Deprecated/outdated:**
- **`FamilyControls.AuthorizationCenter` `.family` mode (parental control, child device).** Phase 5 używa `.individual` (self-control) — już zdeklarowane w Phase 1. `[VERIFIED: already settled]`
- **`DeviceActivitySchedule.intervalStart/End` bez `.year/.month/.day` dla non-repeating schedules.** Phase 3 odkryła silent fail (cross-midnight bug). **Dla Phase 5 `repeats=true` jest OK**, bo iOS traktuje DateComponents jako time-of-day template; jeśli repeats=false — MUST include date. Phase 5 zawsze `repeats=true`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | iOS 26 na real device honoruje `DeviceActivitySchedule(repeats: true)` bez dodatkowej daty; fires daily at hour:minute. | Standard Stack / Example 1 | Jeśli iOS 26 wymaga explicit year/month/day dla repeats=true — trzeba re-register DAS codziennie (lot of complexity). `[ASSUMED]` — empirycznie popularny wzorzec w Foqos + Apple forums, ale żadna projektowa weryfikacja nie potwierdziła na iOS 26 real device. **Wave 0 spike recommended.** |
| A2 | `Calendar.weekday` w DAM extension process jest consistent z main app (ta sama lokalizacja, TZ). | Pattern 1 / Example 2 | Jeśli extension ma inny Calendar/TZ niż main — weekday może być different przy midnight edge. `[ASSUMED]` — forum thread implikuje TAK, ale nie weryfikowane. |
| A3 | iOS 16+ ManagedSettingsStore(named:) sharing między main app i DAM extension działa na iOS 26 tak samo jak na 16/17. | Standard Stack | Jeśli zmieniło się sharing → schedule store zapisany z main app może nie być widoczny przez DAM. `[CITED: developer.apple.com forum #726494, iOS 16]` — ale nie weryfikowane na iOS 26. Phase 3 już używa tego pattern'u i działa, więc ryzyko LOW. |
| A4 | Apple Clock app-style 7-chipowy picker dla days-of-week jest optymalny UX dla power users. | Architecture Patterns § Editor | Może część user'ów woli tabular/list. **Nie blocker** — Claude's Discretion kolor/style. `[ASSUMED]` based on CONTEXT.md §Specifics (user mentioned Apple Clock jako reference). |
| A5 | Single implicit blocklist pozostaje jedyną blocklist w Phase 5 scope (blocklistId zawsze wskazuje na ten sam UUID). | D-02 schema | Jeśli user w międzyczasie skasuje blocklist i zrobi nową — blocklistId stanie się orphan. CONTEXT.md D-02 mówi "single implicit blocklist" ale nie specyfikuje czy UUID jest stabilny. **Recommendation:** ScheduleRepository przy save discoveruje aktualne `blocklists.json` i bierze pierwszy UUID. `[ASSUMED]`. |
| A6 | DAM extension uruchamiany dla `intervalDidStart` ma ≤ 6 MB RAM dostępne na wykonanie całej logiki (JSON read schedule + blocklist + apply shield + write marker + Darwin). | Pitfall 3 | Phase 3 DAM current implementation jest minimal (Session only) — Phase 5 dodaje więcej kodu. Jeśli przekroczymy 6 MB, iOS killuje extension. **Mitigation:** tight minimalna logika, zero Combine/SwiftUI imports w DAM. Empirical budget z Foqos + Phase 3 pokazuje że tight Foundation-only extension vešcie. `[ASSUMED]` ale LOW risk. |
| A7 | `DeviceActivityCenter.startMonitoring` dla 2 segmentów (evening + morning) tego samego logicznego schedule'a nie produkuje "duplicate activity" error. | D-03 / Example 1 | Jeśli iOS wyrzuci "activity name must be unique" (nie wyrzuca — nazwy różne: `.evening` vs `.morning`) — no risk. **Sanity-checked:** to są różne DeviceActivityName values. LOW risk. `[VERIFIED: developer.apple.com/documentation/deviceactivity/deviceactivitycenter/startmonitoring]` — uniqueness per name. |
| A8 | Darwin notifications z extension dochodzą do main app niezależnie od scenePhase (foreground, background, suspended). | Standard Stack / Code Examples | Phase 3 confirms działa na foreground. Background wakeup = nie (iOS nie gwarantuje wake dla Darwin). Phase 5 compensates przez scenePhase.active self-heal (D-18). `[VERIFIED: Phase 3 working in foreground, Phase 5 self-heal covers background case]`. |

## Open Questions

1. **iOS 26 real device behavior dla `DeviceActivitySchedule(repeats: true)` spanning weekdays.**
   - What we know: Apple forum thread #742131 developers używają weekday filter w extension (jedno repeating DAS). Phase 3 Session używa non-repeating DAS z datą.
   - What's unclear: Real device iOS 26.2 — czy `intervalDidStart` fires codziennie o ustawionej godzinie niezawodnie? Bug DAM eventDidReachThreshold na iOS 26.2 (z WebSearch #2) sugeruje, że DAM callbacks są dalej buggy.
   - Recommendation: **Plan Phase 5 Wave 0 spike** — zaregister 1 repeating DAS na jutro 09:00, obserwuj czy `intervalDidStart` fires. Jeśli nie — fallback to non-repeating + re-register every midnight (complexity up). Test przed implementacją pełnego editora.

2. **Multi-schedule blocklist tokens conflict resolution.**
   - What we know: MVP = single implicit blocklist, więc conflict nie istnieje.
   - What's unclear: MSC-02 v2 "overlapping schedules merge blocked app sets". W Phase 5 D-05 dwie warstwy (session + schedule) mergują przez iOS union. Dla Phase 7 MSC-02 trzeba decydować: czy schedule'y też używają union (jeden named store) czy osobne stores per schedule (wyjście z 20-budget).
   - Recommendation: Deferred — Phase 5 implementuje single schedule. Decision dla MSC-02 w Phase 7 research.

3. **Exact behavior Calendar.weekday gdy user zmieni timezone lub region mid-window.**
   - What we know: iOS re-initializuje Calendar.current per-call. Podczas flight TZ change.
   - What's unclear: Czy schedule "22:00 local time codziennie" pójdzie twice w dniu landu (stary TZ i nowy)? Testable w UAT (tablet → set new timezone).
   - Recommendation: Akceptuj MVP behavior; udokumentuj w user docs "harmonogram działa zgodnie z TZ urządzenia". Post-MVP można eksplorować "absolute UTC schedule" opcję.

4. **DAM extension — writing marker file z concurrent intervalDidStart calls.**
   - What we know: `schedule_event_marker.json` jest overwrite-only (D-17). Main app consumes on next foreground.
   - What's unclear: Jeśli schedule.evening fires o 22:00, przez 6 godzin żadnego foregroundu, schedule.morning fires o 00:00 — oba piszą tę samą marker path. Second overwrites first. **Event #1 (started at 22:00) zostaje utracony w events.json.**
   - Recommendation: **Bug potential.** Phase 5 execute planner powinien rozważyć: `schedule_event_marker_{timestamp}.json` (multi-marker) zamiast single overwrite. LUB DAM writes `schedule_events_pending.json` jako append-only (ale to rzuca pod D-17 kontrakt "marker overwrite"). **Recommendation dla planner:** użyj multi-marker (timestamp-suffixed), main app konsumuje wszystkie, sortuje po timestamp. Drobny refactor D-17.

5. **Error handling w `SyncScheduleWithSystemUseCase` gdy startMonitoring rzuca.**
   - What we know: D-14 mówi "rollback `schedule.json` do stanu sprzed save + sarkastyczny toast".
   - What's unclear: `DeviceActivityCenter.startMonitoring` może rzucić z specyficznymi błędami (exceedsBudget, authorizationDenied). Czy UI ma różnicować komunikaty?
   - Recommendation: Test w execute z mockiem runner'a rzucającego każdy case. Dla MVP single sarkastyczny toast wystarczy, ale log severity dla debugging.

## Environment Availability

> Phase 5 jest greenfield code + config. Nie dodaje nowych external dependencies.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| XcodeBuildMCP | Build/test flow | ✓ | from CLAUDE.md | — |
| XcodeGen | project.yml regen | ✓ (implicit — Phase 1 used it) | — | — |
| iOS 26 simulator iPhone 17 | Unit tests + simulator smoke | ✓ | UUID C958163F... | — |
| Physical iOS 26+ device | UAT for DeviceActivitySchedule recurring behavior (open question #1) | ? | — | Simulator smoke is NOT sufficient — DeviceActivity callbacks on simulator are unreliable (Phase 3 learned). **Must verify on real device** — known from Phase 3 UAT. |
| swift-navigation 2.8.0+ | Destination enum bindings | ✓ | 2.8.0 (pinned) | — |
| Apple frameworks (DeviceActivity, ManagedSettings, FamilyControls, Combine, Observation, UserNotifications) | Everything | ✓ | iOS 26.0 SDK | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None for build; **physical device required for meaningful UAT** (marked as blocker for phase completion, same as Phase 3 D-20).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing + XCTest (DeluluDetoxTests target, mixed per existing convention) |
| Config file | `project.yml` target `DeluluDetoxTests` |
| Quick run command | `xcodebuild test -scheme DeluluDetox -destination 'platform=iOS Simulator,id=C958163F-49E1-4B46-8A6D-C2056CD25A37' -only-testing:DeluluDetoxTests/Features/Scheduling` (via XcodeBuildMCP `test_sim` with filter) |
| Full suite command | XcodeBuildMCP `test_sim` (all tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCH-01 | User can create a recurring schedule (select days + time range) | unit (VM) | `test_sim` filter `ScheduleEditorViewModelTests` | ❌ Wave 0 |
| SCH-01 | Cross-midnight detection in editor draft | unit (VM) | `test_sim` filter `ScheduleEditorViewModelTests/testCrossMidnightDetection` | ❌ Wave 0 |
| SCH-01 | Presets (Dni robocze / Weekend / Codziennie) set expected weekday values | unit (VM) | `test_sim` filter `ScheduleEditorViewModelTests/testPresets` | ❌ Wave 0 |
| SCH-01 | `Schedule` Codable round-trip (write to tmp → read → equal) | unit (Repo) | `test_sim` filter `ScheduleRepositoryTests/testCodableRoundTrip` | ❌ Wave 0 |
| SCH-02 | Toggle enable → `ToggleScheduleUseCase` calls sync with enabled=true | unit (UC) | `test_sim` filter `ToggleScheduleUseCaseTests` | ❌ Wave 0 |
| SCH-02 | Toggle disable → sync called with enabled=false (expects stopMonitoring) | unit (UC + mock runner) | `test_sim` filter `ToggleScheduleUseCaseTests/testDisableStopsMonitoring` | ❌ Wave 0 |
| SCH-03 | `Schedule.buildDeviceActivitySchedules()` returns 1 DAS single-day, 2 DAS cross-midnight | unit (pure) | `test_sim` filter `ScheduleBuildDASTests` | ❌ Wave 0 |
| SCH-03 | `SyncScheduleWithSystemUseCase` unregisters old, registers all segments | unit (UC + mock runner) | `test_sim` filter `SyncScheduleWithSystemUseCaseTests` | ❌ Wave 0 |
| SCH-03 | `ComputeScheduleWindowUseCase` single-day | unit (pure) | `test_sim` filter `ComputeScheduleWindowUseCaseTests/testSingleDay` | ❌ Wave 0 |
| SCH-03 | `ComputeScheduleWindowUseCase` cross-midnight before midnight | unit (pure) | `test_sim` filter `ComputeScheduleWindowUseCaseTests/testCrossMidnightEvening` | ❌ Wave 0 |
| SCH-03 | `ComputeScheduleWindowUseCase` cross-midnight after midnight | unit (pure) | `test_sim` filter `ComputeScheduleWindowUseCaseTests/testCrossMidnightMorning` | ❌ Wave 0 |
| SCH-03 | `ComputeScheduleWindowUseCase` weekday not in set → inactive | unit (pure) | `test_sim` filter `ComputeScheduleWindowUseCaseTests/testWeekdayExclusion` | ❌ Wave 0 |
| SCH-03 | `ScheduleShieldRepository.applyShield` uses `"deluludetox.schedule"` store, not `"deluludetox.session"` | unit (Repo + mock writer) | `test_sim` filter `ScheduleShieldRepositoryTests/testStoreNameIsolation` | ❌ Wave 0 |
| SCH-03 | `SelfHealSchedulesUseCase` applies shield when should-be-active but store clear | unit (UC + mocks) | `test_sim` filter `SelfHealSchedulesUseCaseTests/testAppliesWhenMissing` | ❌ Wave 0 |
| SCH-03 | `SelfHealSchedulesUseCase` clears shield when store dirty but not active | unit (UC + mocks) | `test_sim` filter `SelfHealSchedulesUseCaseTests/testClearsWhenOrphaned` | ❌ Wave 0 |
| SCH-04 | (parity — no code change; verification by Phase 4 existing `ShieldConfigurationBuilderTests` covering both named stores implicitly) | contract test | `test_sim` filter `ShieldConfigurationBuilderTests` | ✅ exists (Phase 4) |
| SCH-04 | **Manual UAT on real device:** schedule window fires shield, shield looks identical to quick session shield | manual-only | physical iPhone 26+ UAT in Plan 05-0X | ❌ Phase plan 05-0X |

### Sampling Rate
- **Per task commit:** `test_sim` with filter `-only-testing:DeluluDetoxTests/Features/Scheduling` (fast subset, ~30s)
- **Per wave merge:** `test_sim` full suite (all features)
- **Phase gate:** Full suite green + UAT on physical device (open question #1 empirical answer) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `DeluluDetoxTests/Features/Scheduling/` — directory + placeholder
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift` — covers Codable round-trip + atomic write + consumeMarker
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift` — covers `"deluludetox.schedule"` store isolation via `ManagedSettingsStoreWriter` mock (reuse Phase 4 mock)
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift` — covers DAS build + start/stop via `DeviceActivityCenterRunner` mock (reuse Phase 4 mock)
- [ ] `DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift` — pure logic tests (no mocks needed; clock injected)
- [ ] `DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift`
- [ ] `DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift`
- [ ] `DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift`
- [ ] `DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift`
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift` — VM tests z `DIContainer.reset()` + register mocks (pattern: Phase 3 SessionStartViewModelTests)
- [ ] `DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift`
- [ ] `DeluluDetoxTests/Features/Scheduling/Mocks/` — 7+ mocks (MockScheduleRepository, MockScheduleShieldRepository, MockScheduleActivityMonitoringRepository, MockComputeScheduleWindowUseCase, MockSyncScheduleWithSystemUseCase, MockObserveScheduleUseCase, MockCreateOrUpdateScheduleUseCase, MockToggleScheduleUseCase)
- [ ] Framework install: not needed — Swift Testing + XCTest already in project

### Security Domain

> `security_enforcement` nie jest explicite wyłączone w config.json — traktujemy jako enabled. Phase 5 to on-device, no network, no user accounts → ograniczony security surface.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | App nie ma user accounts. Screen Time authorization to Apple-managed (Phase 1). |
| V3 Session Management | no | No server sessions. App "session" to in-process @Observable state. |
| V4 Access Control | yes | App Group container access kontrolowany przez entitlement `group.com.kksw.DeluluDetox`. File Protection class `.completeFileProtectionUntilFirstUserAuthentication` na atomic writes (inherited z Phase 2/3). |
| V5 Input Validation | yes | Editor inputs (hour/minute 0-23, 0-59; daysOfWeek 1-7): walidacja przy save w `CreateOrUpdateScheduleUseCase`. JSON decoding: `JSONDecoder` rzuca przy malformed → throw propaguje. |
| V6 Cryptography | no | No secrets, no keys. iOS file protection dostarcza at-rest encryption. Nie hand-roll. |
| V9 Communication | no | Zero network. |
| V11 Business Logic | yes | Cross-midnight wrap: logika zamrożona w `ComputeScheduleWindowUseCase` + unit tests. Overlapping session × schedule: iOS union merge (nie własna logika). |

### Known Threat Patterns for iOS Screen Time blockers

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| User uninstalls app, reinstalls, schedule survives (anti-feature?) | — | iOS 26.0 `denyAppRemoval = true` while shield active (Phase 3 D-10 pattern) — **nie dotyczy Phase 5 MVP** bo schedule window jest user-configurable. Deferred. |
| Clock-skew bypass: user sets device clock back to 21:00, schedule window ends | Tampering | Phase 3 `requireAutomaticDateAndTime = true` on shield apply — **zastosuj w Phase 5** `ScheduleShieldRepository.applyShield` (mirror `SessionShieldRepository.applyShield` linie 109-111). |
| Screen Time authorization revoked by user mid-window | Elevation of Privilege (sort of) | Phase 3 `DetectRevocationUseCase` — extend do schedule self-heal: jeśli auth revoked → clear wszystkie shield stores. **Phase 5 dodaje revocation check dla schedule'a w `SelfHealSchedulesUseCase`**. |
| Malformed `schedule.json` → DAM crash / infinite retries | DoS | Defensive JSON decode: DAM → lokalna minimal Decodable envelope (wzorzec Phase 3 line 85). Main app → `readFromDisk` catch + defaults to empty. |
| Token rotation causes shield to point to nothing / wrong app | Tampering (iOS bug) | Phase 2 SEL-05 UUID-keyed records; Phase 5 self-heal reconciliates (D-18). |
| Schedule marker file forged by another app in same App Group (hypothetical) | Tampering | App Group is isolated to entitlement-matching apps (only main + 3 extensions). **No threat in MVP single-target distribution.** |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/05-scheduled-blocking/05-CONTEXT.md` — user decisions D-01..D-22 (locked)
- `.planning/REQUIREMENTS.md` — SCH-01..SCH-04 acceptance criteria
- `.planning/ROADMAP.md` — Phase 5 goal + success criteria
- `CLAUDE.md` — project constraints (iOS 26+, Swift 6.2, SwiftUI-only, Clean Architecture, DIContainer, swift-navigation)
- `.claude/guides/architecture/GUIDE.md` — layered dependency rules
- `.claude/guides/feature-structure/GUIDE.md` — feature-first Split/Simple + Common/ semantics
- `.claude/guides/dependency-injection/GUIDE.md` — DIContainer patterns + CurrentValueSubject + `@LazyInjected`
- `.claude/guides/navigation/GUIDE.md` — Wzorzec A (sheet/modal) + Wzorzec B (root switch)
- `DeluluDetox/Sources/Features/Session/Repository/SessionShieldRepository.swift` — ManagedSettings named store pattern (reuse seam `ManagedSettingsStoreWriter`)
- `DeluluDetox/Sources/Features/Session/Repository/SessionActivityMonitoringRepository.swift` — DeviceActivityCenter runner pattern (reuse seam `DeviceActivityCenterRunner`) + cross-midnight issue dokumentowany inline
- `DeluluDetox/Sources/Features/Session/Repository/SessionRepository.swift` — Repository + CurrentValueSubject + atomic write pattern
- `DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift` — feature-first DI registration template
- `DeluluDetox/Sources/Features/Root/ViewModel/AppRootViewModel.swift` — Darwin observer + scenePhase.active self-heal sequence
- `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` — DAM extension baseline (Phase 3)
- `project.yml` — target definitions + source-share pattern dla extensions

### Secondary (MEDIUM confidence)
- [Apple forum thread #742131 — Multiple Days Schedules](https://developer.apple.com/forums/thread/742131) — verifies community pattern: single repeating DAS + weekday filter in extension (vs N DAS per weekday)
- [Apple forum thread #726494 — Interact with ManagedSettingsStore](https://developer.apple.com/forums/thread/726494) — verifies iOS 16+ named store sharing between main app and DAM extension
- [WWDC22 What's new in Screen Time API](https://developer.apple.com/videos/play/wwdc2022/110336/) — confirms iOS 16 shared named stores direction
- [Apple DeviceActivitySchedule documentation](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule) — exists, body empty via WebFetch
- [Apple intervalStart documentation](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/intervalstart) — referenced

### Tertiary (LOW confidence — needs validation)
- [A Developer's Guide to Apple's Screen Time APIs (Medium, Julius Brussee)](https://medium.com/@juliusbrussee/a-developers-guide-to-apple-s-screen-time-apis-familycontrols-managedsettings-deviceactivity-e660147367d7) — third-party writeup, consistent with Apple forums
- [Apple forum #746416 — DeviceActivityMonitor Extension not called](https://developer.apple.com/forums/thread/746416) — references DAM reliability issues
- iOS 26 DAM callback reliability (A1 assumption) — empirical validation needed via Wave 0 spike

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple frameworks already used and proven in Phases 2/3/4.
- Architecture: HIGH — feature-first Split + three-repo split + DI pattern are established code in repo.
- Pitfalls: HIGH for pitfalls 1, 2, 3, 6, 7 (documented in Phase 3 commits and CLAUDE.md); MEDIUM for pitfalls 4, 5, 8 (inferred from architecture but not empirically witnessed).
- DeviceActivitySchedule recurring behavior: MEDIUM — based on Apple forum thread + Phase 3 Session code + training knowledge; **recommend Wave 0 spike** on real device.
- Cross-midnight split: HIGH — same issue observed in Phase 3 code, documented inline.
- Shield parity (SCH-04): HIGH — Phase 4 D-14 locked design; zero code work.

**Research date:** 2026-04-20
**Valid until:** 2026-05-20 (30 days for stable Apple frameworks; shorter only if iOS 26 minor update ships addressing DAM reliability bugs).

## RESEARCH COMPLETE
