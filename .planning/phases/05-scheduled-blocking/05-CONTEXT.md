# Phase 5: Scheduled Blocking - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

User tworzy jeden cykliczny harmonogram — zbiór dni tygodnia + przedział czasu — który automatycznie blokuje apki z Phase 2 blocklist w wybranym oknie. Blokada realizowana przez `DeviceActivityMonitor` extension: `intervalDidStart` aplikuje `ManagedSettingsStore(named: "deluludetox.schedule")` z tokenami blocklisty, `intervalDidEnd` czyści ten store. Shield podczas okna schedule'a wygląda identycznie jak shield quick session (Phase 4 D-14 — ten sam `ShieldConfiguration` dla wszystkich sources). Schedule coexistuje z quick sessions — ManagedSettings merge'uje niezależnie nazwane stores. User w UI widzi jeden implicit schedule (schema supports N) z 7-chipowym days-of-week pickerem, dwoma wheel time pickerami, toggle enable/disable działającym od następnego okna.

**In scope:**
- Edytor schedule'a: days-of-week chips + presety (Work/Weekend/Every day), dwa `DatePicker(.hourAndMinute)` wheel, toggle Enabled, save/update
- Persistencja: `schedule.json` w App Group (`group.com.kksw.DeluluDetox`), schema wspiera N rekordów, MVP zapisuje/czyta jeden implicit
- `ScheduleRepository` + `UseCase`y (CreateOrUpdate, Toggle, ListSchedules) consistent z Phase 2/3 architekturą
- `DeviceActivityCenter.startMonitoring(.schedule{id}{segment})` — jeden DAS `repeats=true` dla okna w ciągu jednego dnia; cross-midnight split na DWA DAS (`...evening` + `...morning`)
- DAM extension: `intervalDidStart` filter po `Calendar.weekday` → apply `deluludetox.schedule` ManagedSettingsStore; `intervalDidEnd` → clear tego store
- Self-heal na `scenePhase == .active`: main app reconciliates "is schedule supposed to be active right now?" i apply/clear jeśli DAM callback pominięty (odpowiednik Phase 3 D-02)
- Event markers: DAM zapisuje `schedule_events.json` (append-only `{scheduleId, kind: .started|.ended, timestamp}`) i emituje Darwin notification — Phase 6 konsument
- UI scaffolding pod zarządzanie (widok aktualnego schedule'a + entry do edycji) w main app nav graph
- Sarkastyczny copy w UI edytora zgodny z tonem projektu (Phase 3 D-12)

**Out of scope (inne fazy lub post-MVP):**
- Multi-schedule UI (MSC-01/02 v2) — schema wspiera, UI pokazuje jeden
- Per-schedule blocklist picker — używamy single implicit blocklist z Phase 2 (blocklistId FK do niego)
- Lokalne notifikacje startu/końca okna (NTF-02) — Phase 6 konsumuje markery z `schedule_events.json`
- Shield visual — Phase 4 zamyka (identyczny design, zero per-source różnicowania w MVP)
- Widget / Live Activity countdown — post-MVP (LAC-01/02)
- Emergency override toggle (immediate disable w środku okna) — post-MVP, deferred
- Schedule template'y / marketplace ("zablokuj sm socialsy 9-17") — post-MVP
- Export/import schedule'a — power user, post-MVP

</domain>

<decisions>
## Implementation Decisions

### Schema & Scope
- **D-01:** `Schedule` Codable struct, zapisany w tablicy w `schedule.json`. MVP UI odczytuje/modyfikuje pierwszy/jedyny rekord (implicit single schedule), ale schema supports N od day 1 — bez migracji w przyszłym Phase v2 (MSC-01/02). Analogicznie do Phase 2 D-01 (blocklist).
- **D-02:** `Schedule` schema:
  - `id: UUID`
  - `name: String?` (nil w MVP)
  - `daysOfWeek: [Int]` (Calendar weekday: 1=Sunday, 7=Saturday — konsystent z `Calendar.current.component(.weekday, from:)`)
  - `startHour: Int` (0-23), `startMinute: Int` (0-59)
  - `endHour: Int` (0-23), `endMinute: Int` (0-59)
  - `enabled: Bool`
  - `blocklistId: UUID` (FK do Phase 2 blocklist; w MVP wskazuje na single implicit blocklist)
  - `appVersion: String` (debug/audit, jak Phase 3 D-14)
- **D-03:** Cross-midnight **wspierany**. Gdy `(endHour, endMinute) < (startHour, startMinute)` traktujemy jako wrap do następnego dnia. Pod maską: `DeviceActivityCenter` dostaje DWA osobne DAS per selected day — `.schedule{id}.evening` (start → 23:59:59) i `.schedule{id}.morning` (00:00:00 → end). Koszt: 2 aktywności z 20 na cross-midnight schedule (zamiast 1). Świadoma zgoda — "sleep block" jest kluczowym use case'em blokera snu.
- **D-04:** `schedule.json` persisted atomic write (`Data.write(to:options: .atomic)`), main app sole writer (rozszerzenie Phase 2 D-02). Shield extensions i DAM czytają tylko.

### Active Window Conflict (Schedule × Quick Session)
- **D-05:** Schedule i quick session (Phase 3) to **niezależne warstwy** na dwóch osobnych nazwanych `ManagedSettingsStore`:
  - `deluludetox.session` — quick session (Phase 3 D-07)
  - `deluludetox.schedule` — schedule (Phase 5, nowy)
  iOS automatycznie merge'uje shieldy z wielu nazwanych stores (union tokenów). Clearing jednego store nie rusza drugiego.
- **D-06:** **Schedule start gdy quick session aktywna:** DAM `intervalDidStart` callback tylko aplikuje `deluludetox.schedule` store. Quick session `deluludetox.session` zostaje nietknięty — trwa do swojego `plannedEndAt` (Phase 3 D-07/D-08). Shield na apce widoczny cały czas (union), user widzi w głównej apce najpierw countdown sesji, po jej końcu samo "schedule blokuje" (ew. UI inform).
- **D-07:** **Quick session start podczas aktywnego okna schedule:** user nie jest blokowany w UI — start button dostępny, Phase 3 flow (D-07) działa normalnie. ManagedSettings union = ten sam set tokenów (Phase 2 MVP = single blocklist). End-of-session (Phase 3 D-08) robi `clear` tylko `deluludetox.session` store — schedule window dalej blokuje. Spójne z pojęciem "schedule = baseline, session = hard-focus na wierzchu".
- **D-08:** Brak specjalnego UI indicatora konfliktu warstw w MVP — main app pokazuje standardowy countdown sesji i standardowy widok schedule'a osobno. Opcjonalny subtle tekst "+ schedule aktywny" (Claude's Discretion, może zostać w execute).

### Create/Edit UX (SCH-01)
- **D-09:** Days-of-week picker = rząd **7 toggle chips** (Pn Wt Śr Cz Pt Sb Nd, krótkie etykiety PL). Pod chipami trzy przyciski presetów: "Dni robocze" (Pn-Pt), "Weekend" (Sb-Nd), "Codziennie" (wszystkie 7). Tap w preset ustawia toggle state wszystkich chipów. Pattern: Apple Clock app (alarm repeat picker).
- **D-10:** Time picker = **dwa `DatePicker(.hourAndMinute)` w stylu `.wheel`** (konsystentny z Phase 3 D-18 custom duration picker). Label "Od" i "Do". Wrap detection: gdy `end <= start`, UI pokazuje mały inline marker "Cross-midnight" + subtle sarkastyczny copy ("nocna zmiana, co?"), zero walidacji blokującej.
- **D-11:** Enable toggle = SwiftUI `Toggle` z labelem "Harmonogram aktywny". **Efekt od następnego okna:**
  - Enable gdy `now` w oknie: schedule zacznie blokować od kolejnego `intervalStart` (następne wystąpienie). `now`-em nie rusza.
  - Disable gdy `now` w oknie: `DeviceActivityCenter.stopMonitoring(...)` kasuje DAS; aktualnie aktywny shield (ze `deluludetox.schedule` store) NIE jest natychmiast czyszczony — czyści się dopiero gdy pierwotne `intervalDidEnd` nadchodzi (self-heal w D-13 też to sprzątnie po reboot).
  - Świadome: mniej imperatywnej logiki w main app, mniej edge case'ów. Emergency "disable NOW" deferred.
- **D-12:** Edytor schedule'a jako dedykowany screen (swift-navigation `Destination.scheduleEditor` na root VM). Brak wizarda — wszystko na jednym screenie: days chips + presety, time pickery, enable toggle, "Zapisz". "Zapisz" persistuje `schedule.json` i wywołuje `SyncScheduleUseCase` (patrz D-14) który ustawia DAS pod iOS.

### DAM Integration (SCH-03)
- **D-13:** **Jedna `DeviceActivitySchedule` per cross-midnight segment, `repeats: true`.** 
  - Single-day schedule (endHour > startHour): 1 DAS, name `schedule.{id}.main`, `intervalStart = (startHour, startMinute)`, `intervalEnd = (endHour, endMinute)`, `repeats = true`.
  - Cross-midnight (endHour < startHour lub endHour == startHour && endMinute < startMinute): 2 DAS, `schedule.{id}.evening` i `schedule.{id}.morning`. 
  - **Filter dni tygodnia w extension:** DAM `intervalDidStart(for:)` sprawdza `Calendar.current.component(.weekday, from: Date())`. Jeśli dzień nie jest w `schedule.daysOfWeek` → skip apply. To pozwala użyć `repeats = true` (codzienne) i filtrować in-code zamiast tworzyć osobne DAS per dzień (każdy dzień = osobna aktywność = szybko wyczerpuje 20 limit).
  - Activity budget MVP: max 2 aktywności z 20 wykorzystywane przez schedule (plus 1 dla quick session = 3). Zapas 17 na przyszłe multi-schedule / Deep Focus.
- **D-14:** `SyncScheduleUseCase` (main app, wołane po save i po app launch):
  1. `DeviceActivityCenter.shared.stopMonitoring()` dla wszystkich starych DAS związanych z tym schedule (`.schedule.{oldId}.*`).
  2. Jeśli `enabled == false` — zostajemy. Inaczej:
  3. Zbuduj 1 lub 2 `DeviceActivitySchedule` (single-day / cross-midnight split).
  4. `DeviceActivityCenter.shared.startMonitoring(name: .schedule.{id}.{segment}, during: schedule)` dla każdego segmentu.
  5. Error handling: catch `DeviceActivityCenter` throws — pokaż sarkastyczny error toast ("iOS się zbuntował, spróbuj jeszcze raz"), rollback `schedule.json` do stanu sprzed save.
- **D-15:** DAM `intervalDidStart(for: DeviceActivityName)`:
  1. Parse activity name do `scheduleId`.
  2. Read `schedule.json` z App Group, find schedule by id. Jeśli `!enabled` → ignore (race z niedokończonym stop).
  3. Check `Calendar.weekday` ∈ `schedule.daysOfWeek`. Jeśli nie → skip.
  4. Read `blocklists.json`, find blocklist by `schedule.blocklistId`, collect tokens.
  5. `ManagedSettingsStore(named: "deluludetox.schedule").shield.applications = tokens` (+ `.webDomains`, `.categories` jak w Phase 3 D-07).
  6. Append `ScheduleEvent(scheduleId, kind: .started, timestamp: now)` do `schedule_events.json` (via marker-file pattern, nie direct write z DAM — patrz D-17).
  7. Fire Darwin notification `com.kksw.DeluluDetox.scheduleStarted`.
- **D-16:** DAM `intervalDidEnd(for:)`:
  1. Parse `scheduleId`.
  2. `ManagedSettingsStore(named: "deluludetox.schedule").clearAllSettings()`.
  3. Append `ScheduleEvent(kind: .ended)` przez marker.
  4. Fire Darwin notification `com.kksw.DeluluDetox.scheduleEnded`.
- **D-17:** **Event markers dla Phase 6** — DAM NIE pisze bezpośrednio do `schedule_events.json` (respekt zasady Phase 3 D-03: extension → marker only, main app reconciles). DAM zapisuje pojedynczy `schedule_event_marker.json` (overwrite, ostatnie event) + Darwin notification. Main app na next foreground odczytuje marker i appenduje do `schedule_events.json`. Append-only semantyka; Phase 6 subskrybuje.

  > **D-17 amendment (2026-04-20, planning iteration 1):** Overwrite semantics superseded by timestamp-suffixed multi-marker naming (`schedule_event_marker_{unix_ms}.json`). Reason: cross-midnight schedule (D-03) splits into evening + morning segments; if no foreground occurs between segments, a single overwrite loses the evening event. Per RESEARCH OQ#4, timestamp-suffixed files prevent event loss. `ConsumeScheduleEventMarkerUseCase` reads all matching files, sorts by timestamp, processes in order, then deletes.
- **D-18:** **Self-heal na `scenePhase == .active`** (odpowiednik Phase 3 D-02):
  1. Read `schedule.json`. Dla każdego enabled schedule'a:
  2. Oblicz czy `now` mieści się w oknie dziś (z uwzględnieniem cross-midnight i dni tygodnia).
  3. Jeśli "powinno być aktywne" ale `ManagedSettingsStore(named: "deluludetox.schedule").shield` jest clear → apply.
  4. Jeśli "nie powinno być aktywne" ale store ma tokeny → clear.
  Pokrywa: reboot w środku okna, pominięty DAM callback (iOS 26 DAM reliability risk, PROJECT.md).
- **D-19:** Shield visual dla schedule = **identyczny co quick session** (Phase 4 D-14). Zero per-source różnicowania w MVP. `ShieldConfigurationExtension` nie zmienia kodu — jego `buildShieldConfiguration()` używa tego samego branded+fallback ścieżki niezależnie czy blokada pochodzi z quick session czy schedule.

### Notifications Boundary (wrt Phase 6)
- **D-20:** Phase 5 zapewnia event source (D-17 markers + Darwin notifications). Phase 5 NIE wysyła `UNUserNotification` — NTF-02 jest explicite Phase 6. Separation of concerns: Phase 5 = "block happens", Phase 6 = "user gets notified".

### Architecture
- **D-21:** Clean Architecture (spójnie z Phase 1-4): `ScheduleRepository` (read/write `schedule.json`), `ScheduleReader` w SPM module współdzielonym z DAM extension (analogicznie do `SessionReader` z Phase 3). UseCases: `CreateOrUpdateScheduleUseCase`, `ToggleScheduleUseCase`, `SyncScheduleWithSystemUseCase`, `SelfHealSchedulesUseCase`. `ScheduleEditorViewModel` @Observable bez SwiftUI.
- **D-22:** Navigation: `AppRootViewModel.Destination` dostaje `.scheduleList` + `.scheduleEditor(ScheduleEditorViewModel)` (swift-navigation, `@CasePathable`). MVP: przycisk "Harmonogram" w głównym nav graph → list (pokazuje jeden implicit schedule lub empty state "brak harmonogramu + przycisk stwórz") → edytor.

  > **D-22 amendment (2026-04-20, planning iteration 1):** Navigation entry point is `HomeViewModel.Destination`, not `AppRootViewModel.Destination`. Reason: Phase 3 precedent — Home is feature-level navigation parent; AppRoot manages app lifecycle (onboarding → home), not feature navigation. `ScheduleListViewModel` is pushed from HomeViewModel; `ScheduleEditorViewModel` is pushed from ScheduleListViewModel.

### Claude's Discretion
- Dokładna treść subtelnego "Cross-midnight" markera w edytorze (copy + styl).
- Kolor/style chipów dni-tygodnia (filled vs outline, violet vs neutral).
- Wizualne rozróżnienie state'ów enabled/disabled na liście harmonogramu (grey out? badge?).
- Empty state copy w liście harmonogramu ("nie masz jeszcze harmonogramu, może stwórz? bo życie nie będzie się samo blokować").
- Error toast copy dla `DeviceActivityCenter` throws w `SyncScheduleUseCase`.
- Dokładna struktura `schedule_event_marker.json` (single-event overwrite) vs `schedule_events.json` (append-only) — drobne format detale.
- Kolejność toggle chipów dni (Pn-Nd vs Nd-Sb zgodnie z Calendar weekday=1 Sunday) — visual preference, funkcjonalnie bez różnicy bo schema `daysOfWeek` abstrakcyjne.
- Czy edytor pozwala na nazwanie schedule'a w MVP (input `name` field, skopiowane do `D-02 name: String?`) — funkcjonalnie opcjonalne, schema supports.
- Strategia prezentacji "drugiej warstwy" (D-08) — subtle helper text w countdown screen czy oddzielny indicator.

### Folded Todos
- None — no pending todos matched Phase 5.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project constraints
- `.planning/PROJECT.md` §Hard Constraints from Research — DAM 6 MB RAM, max 20 activities total across app + extensions, opaque tokens, App Group requirement, zero third-party SDKs in extensions
- `.planning/PROJECT.md` §Multi-Target Structure — Main app + DeviceActivityMonitor extension share `group.com.kksw.DeluluDetox`
- `.planning/REQUIREMENTS.md` §Schedules — SCH-01/02/03/04 acceptance criteria
- `.planning/REQUIREMENTS.md` §Multi-Schedule — MSC-01/02 v2, wpływa na D-01 (schema supports N)
- `.planning/ROADMAP.md` §Phase 5 — goal + success criteria

### DeviceActivity / ManagedSettings API
- `.claude/research/compass_artifact_wf-280372a6-1bd9-4044-95d9-1d65f1d292dc_text_markdown.md` — main-app ↔ DAM extension: App Group as source of truth, atomic writes, writer/reader split, Darwin notifications, 6 MB RAM limit, token rotation bug
- `.claude/research/compass_artifact_wf-26aecd00-d219-4bf6-9a30-c4499255cad5_text_markdown.md` — iOS 26 known bugs; DAM callback regressions directly motivate D-18 (self-heal) — już cytowane przez Phase 3
- `.claude/research/compass_artifact_wf-9f1fb5f8-b639-4ece-808e-76cc0b222990_text_markdown.md` — Foqos jako production-grade reference; konkretne wzorce DeviceActivityCenter.startMonitoring + DAM callback dla repeating schedules

### Anti-bypass / ethics
- `.claude/research/compass_artifact_wf-1862c287-6b03-4a01-a2e4-e53e8d7082b8_text_markdown.md` — §A (anti-bypass catalog) + §D (App Store Guideline 5.5), wpływa na copy toastów / sarkastycznych komunikatów w UI

### Project architecture
- `.claude/guides/architecture/GUIDE.md` — MVVM + UseCase + Repository, @Observable bez SwiftUI, SOLID/KISS/DRY
- `.claude/guides/navigation/GUIDE.md` — swift-navigation, Destination? enum, @CasePathable
- `.claude/guides/xcodegen/GUIDE.md` — konfiguracja DAM extension + App Group entitlement
- `.claude/guides/xcodebuild-mcp/GUIDE.md` — build/run/test tooling

### Prior phase context (MUST READ)
- `.planning/phases/02-app-selection/02-CONTEXT.md` — blocklist schema, App Group file bus, atomic-write JSON, main-app sole writer rule. Phase 5 `blocklistId` FK do tej samej encji, `schedule.json` dołącza do file bus.
- `.planning/phases/03-quick-sessions/03-CONTEXT.md` — ManagedSettingsStore(named: "deluludetox.session") wzorzec (Phase 5 D-05 dodaje "deluludetox.schedule"), self-heal pattern na scenePhase.active (D-02 tam → D-18 tu), marker-file + Darwin notification pattern dla DAM → main app (D-03 tam → D-17 tu), active_session.json + sessions.json współistnieją z schedule.json.
- `.planning/phases/04-shield-customization/04-CONTEXT.md` — Shield visual settled (D-14): `ShieldConfigurationExtension` zwraca ten sam shield dla wszystkich sources (apps, webDomains, categories, activities). Phase 5 nie dotyka shield kodu.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Greenfield dla Phase 5** — zero kodu istnieje. Scaffolding DAM extension i App Group z Phase 1 są puste; Phase 5 dopisuje produkcyjną logikę DAM.
- **Wzorce z Phase 2/3 do reuse'u:** atomic JSON writer, App Group file path helper, `ManagedSettingsStore` naming convention, marker-file + Darwin notification pattern. Jeśli Phase 3 execute wyciągnie te w SPM module (`SessionPersistence`, `DarwinSignals`), Phase 5 reuses.
- **Electric violet `#7C3AED`** z Phase 1 — używany dla chipów dni-tygodnia (selected state) i primary button "Zapisz".
- **`DatePicker(.hourAndMinute)` wheel style** z Phase 3 D-18 — ten sam komponent w edytorze schedule'a (D-10).

### Established Patterns (from prior phases)
- Clean Architecture: `ScheduleRepository` + UseCase layer (D-21), @Observable VMs bez SwiftUI import.
- swift-navigation: `Destination?` enum + @CasePathable, nowy case `.scheduleEditor` na root VM (D-22).
- App Group JSON, atomic writes, sole-writer (main app) — Phase 5 zapisuje `schedule.json`, DAM/Shield czytają.
- Marker-file + Darwin notification: DAM → `schedule_event_marker.json` + `com.kksw.DeluluDetox.schedule*`, main app reconciles na foreground (D-17).
- Self-heal na scenePhase.active (D-18) — analogiczny do Phase 3 D-02 dla aktywnych sesji.
- Sarkastyczno-playful copy (Phase 3 D-12, Phase 4 D-03) — stosujemy w edytorze, emptystatach, error toastach.

### Integration Points
- **`DeviceActivityMonitor` extension target** — scaffoldowany w Phase 1, używany produkcyjnie już w Phase 3 (intervalDidEnd dla quick session). Phase 5 dokłada obsługę recurring schedule (intervalDidStart + intervalDidEnd), dzieląc kod extension wspólnymi helperami.
- **`DeviceActivityCenter.shared`** — main app API. Phase 5 `SyncScheduleUseCase` (D-14) wywołuje `startMonitoring/stopMonitoring` z namespace'd DAS names (`schedule.{id}.{segment}`).
- **`ManagedSettingsStore(named: "deluludetox.schedule")`** — nowy store, osobny od Phase 3's "deluludetox.session". iOS automatycznie merge'uje.
- **App Group file bus** — nowe pliki: `schedule.json` (main app sole writer, DAM/main read), `schedule_event_marker.json` (DAM writes single event, main app read + append do `schedule_events.json`), `schedule_events.json` (append-only historia dla Phase 6).
- **Root nav graph** (Phase 1) — dodaje entry "Harmonogram" → `.scheduleList` → `.scheduleEditor` (D-22). Spójne z `Destination?` enum pattern.
- **`blocklists.json`** (Phase 2) — Schedule referencje blocklistId; DAM na intervalDidStart czyta ten sam plik co ShieldConfigurationExtension i Phase 3 StartSessionUseCase.

</code_context>

<specifics>
## Specific Ideas

- **"Sleep block" (22:00 → 06:00) jako motyw przewodni UX** — user explicitly chose cross-midnight support bo to najbardziej naturalny use case blokera. Edytor powinien "czuć się dobrze" przy krzyżowaniu północy (subtle marker, nie walidacja blokująca, nie dialog).
- **Schedule = baseline, quick session = hard-focus na wierzchu** — mentalny model podczas diskussji konfliktu warstw. User może mieć schedule "codziennie 22:00-06:00" (sleep block) i dodatkowo odpalić quick session na 2h w środku dnia dla hyper-focus. Semantyka union jest pożądana, nie accidental.
- **Apple Clock app alarm repeat picker** jako reference UX dla days chips + presety — user familiar z tym patternem z natywnych apek iOS.
- **Phase 6 czeka** — event markers (D-17) to kontrakt między Phase 5 i Phase 6. Phase 5 pisze marker atomowo, Phase 6 czyta i reaguje notifikacjami. Zero coupling extension-to-UserNotifications w Phase 5.

</specifics>

<deferred>
## Deferred Ideas

- **Multi-schedule UI** (multiple named schedules: "Work", "Sleep", "Weekend chill") — schema wspiera (D-01), UI w Phase 7 / v2 (MSC-01/02).
- **Per-schedule blocklist** — każdy schedule mógłby mieć inną listę blokowanych apek. MVP single implicit blocklist. Post-MVP jak w MSC-02 (overlapping schedules merge blocklists).
- **Emergency "disable NOW" w trakcie okna** — obecny toggle (D-11) działa od następnego okna. Emergency override wymaga imperatywnej ManagedSettings clear z main app + UI confirmation (podobnie do Phase 3 D-09 early-end dialog). Post-MVP.
- **Edge case: usunięcie wszystkich tokenów z blocklisty podczas aktywnego okna schedule** — DAM by miał pusty set tokenów na apply. MVP: akceptacja (shield nie aplikuje się do niczego, user widzi "nic nie blokowane" mimo enabled schedule). Phase 6 może pokazać warning przy selection edit.
- **Notifikacje startu/końca okna** — NTF-02 / Phase 6. Phase 5 dostarcza event source (D-17), Phase 6 buduje notification delivery.
- **Schedule templates / preset library** ("Block social 9-17", "Sleep 22-6", "Weekend detox") — post-MVP, community/marketplace feature.
- **Multi-schedule concurrency w DAS** — gdy Phase 7 doda N schedule'ów, trzeba będzie zarządzać 20-activity budget budżetem. Obecny D-13 zapewnia 2 aktywności per cross-midnight schedule — scale OK do ~8 schedule'ów jednocześnie.
- **Widget z aktualnym statusem schedule'a** — post-MVP.
- **Live Activity z countdownem do końca okna** — LAC-01/02, post-MVP.
- **Cross-device sync schedule'ów przez iCloud** — out of scope, MVP on-device.

</deferred>

---

*Phase: 05-scheduled-blocking*
*Context gathered: 2026-04-18*
