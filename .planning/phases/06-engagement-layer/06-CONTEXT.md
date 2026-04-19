# Phase 6: Engagement Layer - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Warstwa feedbacku i powiadomień zamykająca MVP. Trzy obszary funkcjonalne: (1) statystyki — łączna liczba ukończonych sesji (GAM-01) i seria kolejnych dni z przynajmniej jedną zakończoną sesją (GAM-02), pokazane zarówno jako karta na home screen jak i w dedykowanym Stats ekranie z kalendarzem miesięcznym; (2) powiadomienia lokalne na koniec quick session (NTF-01) dostarczane przez pre-scheduled `UNCalendarNotificationTrigger` ustawiany w Phase 3 start sequence (aby pokryć przypadek app-killed); (3) powiadomienia na start okna schedule'a (NTF-02) dostarczane przez pre-scheduling wszystkich przyszłych `intervalStart` czasów jako `UNCalendarNotificationTrigger(repeats: true)` per dzień tygodnia. Copy notyfikacji: miękki sarkazm + celebracja. Copy złamanej serii: ostry shame (konsystent z Phase 4 D-03 shield tonem). Żadnej nowej blokady, żadnej modyfikacji Phase 3/4/5 stack'a poza extend Phase 3 D-07 Start o notification scheduling i D-08 End o notification cancel (gdy outcome ≠ .completed).

**In scope:**
- `StatsRepository` / `ComputeStatsUseCase` czytające `sessions.json` (Phase 3 D-13) i `Calendar.current` → current streak, longest streak, total count
- Home screen card z 🔥 current streak + total count + mini 7-day dot row
- Dedykowany Stats screen: kalendarz miesięczny z violet kropkami na dniach z ≥1 `.completed`, current/longest streak, total count, swipe między miesiącami
- Notification permission prompt: lazy, po pierwszej sesji `.completed` (przed success screen z Phase 3 D-19)
- NTF-01 delivery: main app w Phase 3 D-07 Start sequence schedule'uje `UNNotificationRequest(trigger: UNCalendarNotificationTrigger(dateMatching: plannedEndAt, repeats: false))`. Cancel w Phase 3 D-08 End sequence gdy outcome == .cancelled_by_user || .broken_by_revoke. Dla .completed outcome iOS dostarcza automatycznie (cover killed-app case).
- NTF-02 delivery: main app w Phase 5 D-14 SyncScheduleUseCase po save/toggle pre-schedule'uje `UNNotificationRequest(trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(weekday, hour, minute), repeats: true))` per wybrany dzień tygodnia. Reconcile na foreground: re-schedule jeśli schedule zmienił się.
- Broken streak UX: pierwsza wizyta home card po dniu bez `.completed` pokazuje ostry shame message ("Straciłeś 12-dniową serię. Imponujące.") + szary flame, streak = 0
- Stats compute eagerly on-demand (zero cache) z `sessions.json`

**Out of scope (inne fazy lub post-MVP):**
- Paid streak freeze (MON feature) — v2 monetization
- Per-session detail UI (lista zakończonych sesji) — Phase 3 deferred utrzymane
- DeviceActivityReport statistics (usage time per app) — post-MVP (STS-01/02)
- Widget z current streak — post-MVP
- Live Activity z countdown do końca okna — LAC-01/02 post-MVP
- In-app daily reminder notification ("nie zapomnij zrobić sesji dziś") — post-MVP engagement nudge
- Per-notification granular toggles (disable NTF-01 separately od NTF-02) — Apple Settings > Notifications toggle wystarcza w MVP
- A/B testing copy wariantów — post-MVP
- Haptic feedback na streak increment — post-MVP polish
- Share stats ("moja 30-dniowa seria!") — post-MVP social

</domain>

<decisions>
## Implementation Decisions

### Streak Semantics (GAM-02)
- **D-01:** Dzień kalendarzowy w `TimeZone.current` (local device). Dzień = 00:00 → 23:59:59 `Calendar.current`. Akceptowane: zmiana strefy czasowej przy podróży może artificially wydłużyć/skrócić jeden dzień (corner case, consumer app).
- **D-02:** "Zakończona sesja dnia" = istnieje `SessionRecord` z `outcome == .completed` i `Calendar.current.isDate(actualEndAt, inSameDayAs: candidateDay)`. `.cancelled_by_user` i `.broken_by_revoke` NIE liczą się. Zgodne z semantyką Phase 3 D-08.
- **D-03:** Current streak = najdłuższy ciąg kolejnych dni (licząc od dziś w tył) z przynajmniej 1 `.completed` sesją. Jeśli dziś nie ma `.completed` ale wczoraj było — streak ciągle "żyje" do końca dziś (tj. brak `.completed` dzisiaj łamie serię dopiero na następny dzień). Reguła uproszczona: "ostatni day z .completed + 0 lub 1 dzień gap" = streak żyje; "ostatni day + 2+ dni gap" = streak = 0.
- **D-04:** Zero grace period / freeze w MVP. Dzień bez `.completed` → seria zerowana (zgodnie z D-03). "Streak freeze" feature deferred (potencjalny hook monetizacyjny v2).
- **D-05:** Longest streak = maximum najdłuższy ciąg kolejnych dni z `.completed` kiedykolwiek w historii `sessions.json`. Compute on-demand jak current streak.

### Stats Compute (GAM-01/02)
- **D-06:** Stats computed on-demand on every foreground i every Stats screen open. Parse `sessions.json` → grupa po `Calendar.current` day → oblicz current streak, longest streak, total count (liczba `.completed`). Rozsądny koszt: ~200 rekordów/rok × 3 pól daty = trivial parse, zero percievable latency nawet na iPhone SE.
- **D-07:** Żaden cache w MVP. Zero `stats.json`, zero counter incremental. Single source of truth = `sessions.json`. Upraszcza consistency (session rollback = stats rollback automatyczny), zero migration concerns, zero "stats dryft od reality" bugs.
- **D-08:** Eager expiry: seria computed from source na każdy read, nie jest persisted. Nie trzeba "wyzerować" na północy — compute logic sam zobaczy że gap > 1 dzień i zwróci 0. Deterministyczne, zero "state ghost".

### Stats Presentation (GAM-01/02)
- **D-09:** Home screen card (na Start screenie Phase 3 D-16, górna sekcja) pokazuje:
  - 🔥 `{current streak}` dni (duża liczba, violet accent gdy > 0, szara gdy == 0)
  - "Ukończonych sesji: `{total count}`" (mniejsza liczba poniżej)
  - Mini 7-day dot row: 7 kropek reprezentujących ostatnie 7 dni, violet kropka = dzień z `.completed`, szara = dzień bez. Dzień od prawej = dziś.
  - Tap w card → push `Destination.stats` (nowy case na root VM, swift-navigation).
- **D-10:** Broken streak display: gdy current streak == 0 ORAZ longest streak >= 3 (nie pokazujemy shame jeśli user nigdy serii nie miał):
  - Szary flame ikon + liczba `0` + copy pod spodem: "Straciłeś {longest}-dniową serię. Imponujące." (ostry shame, konsystent z Phase 4 D-03 shield tonem)
  - Świadome ryzyko: "app mi dokucza → deinstal". User's call, brand voice over safe engagement.
  - Drafting konkretnych stringów copy w execute (kilka wariantów do rotacji żeby nie stało się nudne — Claude's Discretion).
- **D-11:** Dedykowany Stats screen (`Destination.stats`):
  - Header: "🔥 `{current}` | Rekord: `{longest}` | Σ `{total}`"
  - Kalendarz miesięczny: SwiftUI custom grid 7 kolumn × ~5 wierszy, każda komórka = dzień miesiąca. Violet kropka w komórce jeśli ≥1 `.completed` sesja tego dnia. Dziś = violet border.
  - Nawigacja miesięcy: swipe left/right lub strzałki w header. Granica: od miesiąca pierwszej sesji wstecz, wprzód do bieżącego.
  - Brak per-session list (Phase 3 deferred utrzymany).
  - Brak wykresów time-in-session (nie w GAM-01/02 scope).
- **D-12:** "Longest streak" widoczny:
  - Na home card tylko w broken streak context (D-10 copy).
  - Na Stats screen zawsze w headerze.
  - Zasada: home jest "focus na now", Stats jest "drill-down historii".

### Notification Permission Flow
- **D-13:** **Lazy permission prompt** — po pierwszej sesji z outcome `.completed`, przed wyświetleniem success screen (Phase 3 D-19):
  1. W `FinalizeSessionUseCase` (main app, po set `outcome = .completed`), sprawdź `UNUserNotificationCenter.current().getNotificationSettings()`. Jeśli `authorizationStatus == .notDetermined` → present permission prompt.
  2. Copy przy prompt (najbardziej custom tekst przed iOS dialog): "Chcesz dostać subtelny tap gdy sesja się kończy?"
  3. Niezależnie od odpowiedzi: pokaż success screen.
- **D-14:** User może później zmienić decyzję w iOS Settings > DeluluDetox > Notifications. Nie dodajemy custom in-app "notification settings" w MVP — Apple wystarcza.

### NTF-01: Session End Notification
- **D-15:** **Pre-scheduled notification w Phase 3 D-07 Start Sequence** (extend tej decyzji w Phase 6 execute):
  1. Przy session start, main app tworzy `UNNotificationRequest`:
     - `identifier`: `"session.end.\(sessionId.uuidString)"`
     - `content.title`: miękki sarkazm + celebracja (D-17 copy library)
     - `trigger`: `UNCalendarNotificationTrigger(dateMatching: DateComponents(year, month, day, hour, minute, second) from plannedEndAt, repeats: false)`
  2. `UNUserNotificationCenter.current().add(request)`.
  3. Jeśli `authorizationStatus != .authorized` — skip add (iOS anyway by failed). Zero user impact.
- **D-16:** **Cancel w Phase 3 D-08 End Sequence** (extend):
  - Outcome `.completed`: NIE cancel (notification fired naturalnie o `plannedEndAt`). Jeśli main app jest foreground gdy notification fires — iOS tak czy siak je pokazuje jako banner, ale user widzi też success screen, lekka redundancja akceptowalna. Alternatywa: `.willPresent` delegate zwraca `[]` gdy app foreground — zero banner, iOS default. Claude's Discretion.
  - Outcome `.cancelled_by_user` lub `.broken_by_revoke`: `UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session.end.\(sessionId)"])`. Notification nigdy się nie pojawi.
- **D-17:** Copy library dla NTF-01 (miękki sarkazm + celebracja), przykłady (draft, execute dobiera finalne):
  - "Przetrwałeś `{duration}` min bez scrollowania. Świat się nie zawalił."
  - "Sesja `{N}`-go ukończona. Możesz wrócić do chaosu."
  - "Gratuluję, `{duration}` min w realnym świecie. Teraz możesz pojeździć palcem."
  Rotacja po `hash(sessionId) % count` żeby nie powtarzać tego samego tekstu.

### NTF-02: Schedule Start Notification
- **D-18:** **Pre-schedule wszystkich przyszłych intervalStart jako UNCalendarNotificationTrigger(repeats: true)**. Dodane do Phase 5 D-14 `SyncScheduleUseCase` (Phase 6 execute extenduje ten use case):
  1. Po `startMonitoring(...)` dla każdego segmentu DAS, dla każdego wybranego `weekday` w `schedule.daysOfWeek`:
     - `identifier`: `"schedule.start.\(scheduleId.uuidString).\(weekday)"`
     - `content`: miękki sarkazm + info (D-20 library)
     - `trigger`: `UNCalendarNotificationTrigger(dateMatching: DateComponents(weekday: weekday, hour: startHour, minute: startMinute), repeats: true)`
     - `UNUserNotificationCenter.add(request)`
  2. Dla cross-midnight schedule'a (D-03 Phase 5) notyfikacja tylko dla części wieczornej (start usera widocznego okna, nie dla `.morning` segmentu który jest artefaktem technicznym).
  3. `removePendingNotificationRequests` dla wszystkich `"schedule.start.{scheduleId}.*"` przed każdym re-add (reconcile).
- **D-19:** `iOS UNCalendarNotificationTrigger repeats: true` działa niezależnie od stanu main app (foreground/background/killed). iOS sam dostarcza. NIE potrzebujemy Darwin notification subscription z Phase 5 D-17 dla NTF-02 delivery — markery Phase 5 służą tylko dla stats (gdyby Phase 6 chciał w przyszłości aggregować schedule-execution stats) oraz potencjalnej self-healing logic. MVP Phase 6 nie używa `schedule_events.json` bezpośrednio — może być użyty jako telemetry sink.
- **D-20:** Copy library dla NTF-02 (miękki sarkazm + info), przykłady:
  - "Schedule właśnie zaczął blokadę. Powodzenia."
  - "`{startTime}` — apki wyłączone. Realny świat prosi o uwagę."
  - "Blokada zaczyna się teraz. Telefon idzie spać."
  Rotacja analogiczna do D-17.

### Architecture
- **D-21:** Clean Architecture (spójnie z Phase 1-5):
  - `StatsRepository` (read-only interface nad `sessions.json`), zero writes.
  - `ComputeStatsUseCase` (zwraca `Stats: {currentStreak, longestStreak, totalCount, last7DaysFlags}`)
  - `SchedulePermissionPromptUseCase` (sprawdza `.notDetermined` + present)
  - `ScheduleSessionEndNotificationUseCase`, `CancelSessionEndNotificationUseCase` (NTF-01)
  - `ReconcileScheduleNotificationsUseCase` (NTF-02, wołane z Phase 5 D-14 + na foreground)
  - `StatsViewModel` + `HomeStatsCardViewModel` — oba @Observable bez SwiftUI.
- **D-22:** Navigation: `AppRootViewModel.Destination` dostaje `.stats` case (swift-navigation, @CasePathable). Home card tap → push. Spójne z Phase 1-5 nav pattern.

### Claude's Discretion
- Dokładna treść wariantów copy dla NTF-01, NTF-02, broken streak (library z 3-5 wariantów każdy, rotation strategy — hash based lub round-robin).
- Visual design home card (shadow, radius, padding, exact placement górna sekcja Start screen).
- Exact layout kalendarza miesięcznego na Stats screen (header month/year, dots size, today highlight style).
- Czy last 7 dni dot row renderowane od prawej (dziś po prawej) czy od lewej (Monday-first). PL users typicznie Monday-first; can go either — Claude decyduje po visual test.
- Kolejność kalendarza: Monday-first (PL convention) vs Sunday-first.
- `.willPresent` notification delegate behavior w main app: pokaż banner vs sound only vs nothing gdy app foreground. Default: nothing (redundant z success screen).
- Success screen post-permission-prompt sequencing: pokazać prompt potem success, czy success potem w overlay prompt. Claude po testach UX.
- Szara empty state flame visual (0% opacity? 30%? outlined vs filled?).
- Empty state dla Stats screen gdy user ma 0 sesji (sarkastyczne "nothing to see yet, może odpal sesję?").
- Granice nawigacji kalendarza: czy pozwalamy scroll w przyszłość (zawsze puste — ma sens?), czy blokujemy na bieżącym miesiącu.

### Folded Todos
- None — no pending todos matched Phase 6.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project constraints
- `.planning/PROJECT.md` §Hard Constraints from Research — App Group requirement, token opacity (Stats screen nie może pokazać nazw zablokowanych apek)
- `.planning/REQUIREMENTS.md` §Gamification — GAM-01/02 acceptance criteria
- `.planning/REQUIREMENTS.md` §Notifications — NTF-01/02 acceptance criteria
- `.planning/ROADMAP.md` §Phase 6 — goal + success criteria

### UserNotifications / Screen Time API
- `.claude/research/compass_artifact_wf-280372a6-1bd9-4044-95d9-1d65f1d292dc_text_markdown.md` — App Group as file bus (`sessions.json` read-only access z main app)
- `.claude/research/compass_artifact_wf-1862c287-6b03-4a01-a2e4-e53e8d7082b8_text_markdown.md` §D — App Store Guideline 5.5, sarkastyczny vs manipulacyjny ton — wpływa na copy notyfikacji i broken streak message (ostry shame musi przejść sanity check "to ironia, nie atak")

### Project architecture
- `.claude/guides/architecture/GUIDE.md` — MVVM + UseCase + Repository, @Observable bez SwiftUI
- `.claude/guides/navigation/GUIDE.md` — swift-navigation, `Destination?` enum, @CasePathable
- `.claude/guides/xcodebuild-mcp/GUIDE.md` — build/run/test tooling

### Prior phase context (MUST READ)
- `.planning/phases/03-quick-sessions/03-CONTEXT.md` — **kluczowy**. `SessionRecord` schema (D-14) = źródło danych stats. D-07 Start sequence = gdzie Phase 6 extenduje o scheduling NTF-01. D-08 End sequence = gdzie Phase 6 extenduje o cancel NTF-01. D-19 success screen = sekwencja z permission prompt (D-13 tu).
- `.planning/phases/04-shield-customization/04-CONTEXT.md` — D-03 ostry sarkastyczny ton shielda; Phase 6 broken streak copy (D-10) powtarza ten sam tonal register.
- `.planning/phases/05-scheduled-blocking/05-CONTEXT.md` — **kluczowy dla NTF-02**. D-14 SyncScheduleUseCase = hook point dla Phase 6 ReconcileScheduleNotificationsUseCase. D-17 event markers = potencjalne przyszłe użycie (MVP Phase 6 nie korzysta). D-03 cross-midnight = Phase 6 wysyła notification tylko dla evening segmentu (nie morning).
- `.planning/phases/02-app-selection/02-CONTEXT.md` — Main app sole writer rule, app group file bus pattern. Phase 6 czytuje `sessions.json` read-only, nie zapisuje niczego.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`sessions.json`** (Phase 3 D-13/D-14) — gotowy format dla stats compute. `SessionRecord.outcome`, `SessionRecord.actualEndAt`, `SessionRecord.plannedEndAt` — wszystkie potrzebne pola.
- **Success screen + sekwencja end** (Phase 3 D-19) — Phase 6 D-13 permission prompt interpoluje przed success screen.
- **`SyncScheduleUseCase`** (Phase 5 D-14) — Phase 6 dodaje etap "schedule notifications" po etapie "startMonitoring".
- **Electric violet `#7C3AED`** (Phase 1) — flame active state, calendar dot color, Stats header accent.
- **`swift-navigation` Destination? pattern** — nowy case `.stats` na root VM, zero nowego routing paradigm.
- **@Observable VM pattern** — `StatsViewModel`, `HomeStatsCardViewModel`.

### Established Patterns (from prior phases)
- Clean Architecture: Repository → UseCase → VM → View.
- App Group file bus, main app sole writer — Phase 6 czyta sessions.json, nie zapisuje. `stats.json` explicite NIE tworzony (D-07).
- swift-navigation single Destination? enum na VM.
- Sarkastyczno-playful tone (project-wide), ostry na shieldzie (Phase 4 D-03) + ostry na broken streak (Phase 6 D-10), miękki w notyfikacjach (D-17/D-20).

### Integration Points
- **`UNUserNotificationCenter.current()`** — nowa zależność w main app (nie w extensions). `requestAuthorization`, `add(request:)`, `removePendingNotificationRequests`, `getNotificationSettings()`.
- **Phase 3 D-07 Start Sequence hook** — Phase 6 dodaje krok 0 lub N+1: schedule `session.end.{id}` notification. Collab point: minor code change w `StartSessionUseCase`.
- **Phase 3 D-08 End Sequence hook** — Phase 6 dodaje krok: jeśli outcome != .completed → remove pending notification. Collab: `EndSessionUseCase` albo `FinalizeSessionUseCase`.
- **Phase 5 D-14 SyncScheduleUseCase hook** — Phase 6 dodaje etap final: reconcile scheduled notifications. Collab: extend istniejącego use case.
- **Home screen (Start screen z Phase 3 D-16)** — Phase 6 dodaje górną sekcję card. Ad-hoc VM wire.
- **Navigation graph** — dodanie `.stats` case do `Destination?` enum, wire tap handler.
- **`Calendar.current` + `TimeZone.current`** — standardowe Foundation API, zero dodatkowych zależności.

### Risk Notes
- **Notification permission denial** — user może odmówić; Phase 6 musi gracefully skip notification scheduling (D-15 "if !authorized skip"). Stats screen i home card działają niezależnie od notification permission.
- **Token rotation doesn't affect stats** — Phase 6 operates only on `SessionRecord` metadata (daty, outcome), zero wymagania na token resolvalność. Safe wrt Phase 2 token instability risks.
- **Broken streak shame copy risk** — app deinstal potential. Akceptowane przez usera jako explicit brand voice (konsystent z shield ostrym tonem). Może być ważne do śledzenia w beta — jeśli signal "too harsh", można złagodzić w dot-release.

</code_context>

<specifics>
## Specific Ideas

- **"Pure source of truth" na `sessions.json`** (D-07) — decyzja świadomie wyklucza stats cache w `stats.json`. Consistency trumps micro-performance. 200 rekordów/rok to zero cost.
- **Sarkastyczny shame działa jeśli reszta apki też jest sarkastyczna** — user explicit choice na ostry ton shielda (Phase 4) + ostry broken streak (Phase 6) to coherent brand stance. Celebracyjne notyfikacje sprawiają że shame nie wydaje się zapalczywy — app nagradza ukończenie, karci tylko failure.
- **Pre-scheduling NTF-02 na 14 dni do przodu jako reliability pattern** — iOS gwarantuje delivery `UNCalendarNotificationTrigger(repeats: true)` nawet gdy app killed. Niektóre schedule apps robią tak (np. Streaks).
- **NTF-01 hybrid (main app scheduling przy start, main app cancel przy abort, iOS delivers) to klasyczny iOS pattern** — żadnej BG logic w extension, żadnego Darwin notification subscription, żadnych race warunków.

</specifics>

<deferred>
## Deferred Ideas

- **Paid streak freeze** — jedno-klik "zapauzuj serię na dziś" jako gated premium feature. MON v2.
- **Per-notification granular toggle** (disable NTF-01 osobno od NTF-02) — Apple Settings wystarcza w MVP.
- **In-app daily reminder push** ("hej, nie zrobiłeś jeszcze dziś sesji!") — engagement nudge, post-MVP decyzja po beta data.
- **Widget z current streak na home screen iOS** — post-MVP.
- **Live Activity z countdown sesji** — LAC-01/02 post-MVP.
- **Share streak ("moja 30-dniowa seria DeluluDetox!")** — social feature, post-MVP.
- **Cross-device streak sync przez iCloud** — backend/cloud — out of scope MVP.
- **DeviceActivityReport extension dla usage stats** — STS-01/02 post-MVP.
- **A/B testing copy wariantów notyfikacji** — wymaga analytics backend, post-MVP.
- **Haptic feedback na streak increment** — post-MVP polish.
- **Streak-specific achievements / badges** — dodatkowa warstwa gamification, post-MVP.
- **Stats export (CSV / JSON)** — power user, post-MVP.
- **Aggregated time-in-session wykresy** — nie w GAM-01/02 scope, post-MVP.
- **Per-session detail view** — Phase 3 deferred, utrzymane.
- **stats.json cache file jako snapshot dla widget / Live Activity** — post-MVP razem z widgetem.

</deferred>

---

*Phase: 06-engagement-layer*
*Context gathered: 2026-04-18*
