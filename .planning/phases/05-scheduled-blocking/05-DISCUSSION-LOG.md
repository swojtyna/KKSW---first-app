# Phase 5: Scheduled Blocking - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 05-scheduled-blocking
**Areas discussed:** Schedule scope & data model, Conflict schedule vs quick session, Create/edit UX, DAM & notifications boundary

---

## Schedule Scope & Data Model

### Ile schedule'ów w data model

| Option | Description | Selected |
|--------|-------------|----------|
| Schema supports N, UI shows 1 | Analogicznie do Phase 2 blocklist. Schema ready for v2 multi-schedule bez migracji. | ✓ |
| Strictly singular | Jeden rekord, prostsze. Migracja wymagana w v2. | |
| N in UI too | Multi-schedule w MVP. Scope creep. | |

**User's choice:** Schema supports N, UI shows 1
**Notes:** Spójne z Phase 2 D-01 pattern.

### Cross-midnight support

Najpierw user nie rozumiał problemu — wyjaśnione: DAS używa `DateComponents` (H/M) bez daty. Dla okna 22:00-06:00 albo Apple wrapuje (undocumented), albo splittujemy na dwa intervały (22:00-23:59 + 00:00-06:00), zjadając 2 z 20 activity slotów.

| Option | Description | Selected |
|--------|-------------|----------|
| Tak, wspieramy cross-midnight | User widzi jedno okno, pod maską split na 2 DAS. "Sleep block" = top use case. Koszt: 2/20 aktywności. | ✓ |
| Nie w MVP | UI waliduje, user robi dwa schedule'e. Ale MVP = 1 UI schedule, więc efektywnie brak sleep blocka. | |
| Nie, ale edukacja + roadmap | UI blokuje, wyjaśnia. Uczciwe ale ogranicza feature. | |

**User's choice:** Tak, wspieramy
**Notes:** Sleep block to flagship use case. 2/20 budget acceptable.

---

## Conflict: Schedule × Quick Session

### Schedule start podczas aktywnej sesji

| Option | Description | Selected |
|--------|-------------|----------|
| Schedule rozszerza, przejmuje po sesji | Quick session trwa do końca, schedule coexistuje via osobny ManagedSettingsStore. Naturalny merge. | ✓ |
| Quick session cancellowana przez schedule | Schedule przejmuje kontrolę. User traci success sesji. | |
| Brak interakcji (equipoise) | Dwie warstwy MS, complicated clearing. | |

**User's choice:** Schedule rozszerza
**Notes:** Osobne named ManagedSettingsStore, iOS auto-merge.

### Quick session start podczas aktywnego okna schedule

| Option | Description | Selected |
|--------|-------------|----------|
| Pozwalamy — druga warstwa | Session działa Phase 3 flow. MS merge = ta sama lista. End-of-session wraca do samego schedule. | ✓ |
| Blokujemy — schedule już blokuje | Start button disabled. User traci hard-focus na wierzchu. | |
| Pozwalamy i rozszerzamy schedule | Session kończy schedule od daty-końca sesji. Ryzykowne semantycznie. | |

**User's choice:** Pozwalamy — druga warstwa
**Notes:** Mentalny model "schedule = baseline, session = hard-focus". Zgodny z poprzednią decyzją.

---

## Create/Edit UX

### Days picker

| Option | Description | Selected |
|--------|-------------|----------|
| 7 toggle chips + presety | Pn Wt Śr Cz Pt Sb Nd jako chips. Przyciski "Dni robocze/Weekend/Codziennie". Pattern Apple Clock. | ✓ |
| Multi-select List z checkboxami | Klasyczne, więcej miejsca, bez presetów. | |
| Segmented control x7 | Custom, iOS segmented = single-select zazwyczaj. Nie warto. | |

**User's choice:** 7 toggle chips + presety
**Notes:** Familiar z iOS Clock app.

### Time picker

| Option | Description | Selected |
|--------|-------------|----------|
| Dwa DatePicker(.hourAndMinute) wheel | Spójne z Phase 3 D-18 custom duration. Apple standard. | ✓ |
| Dwa compact DatePicker | Mniej miejsca, mniej tactile. | |
| Single range slider na osi 24h | Trendy, nieznany pattern, trudne trafianie w minuty. | |

**User's choice:** Dwa wheel DatePicker
**Notes:** Konsystencja z Phase 3.

### Enable toggle semantyka

| Option | Description | Selected |
|--------|-------------|----------|
| Efekt od następnego okna | Prostsze semantyki, mniej edge case'ów. Toggle wpływa na harmonogram, nie na stan. | ✓ |
| Immediate effect | Natychmiast apply/clear MS przy toggle. Więcej edge case'ów. | |
| Prompt przy konflikcie | Dialog "od razu czy od następnego?" — friction. | |

**User's choice:** Efekt od następnego okna
**Notes:** Emergency "disable NOW" deferred do post-MVP.

---

## DAM Integration & Notifications

### DeviceActivity activity count

| Option | Description | Selected |
|--------|-------------|----------|
| 1 DAS z repeats=true per dzień | Apple powtarza codziennie, filter weekday w DAM callback. 1 slot (2 cross-midnight). | ✓ |
| Osobna DAS per dzień tygodnia | Czyste semantycznie, ale 5-7 slotów per schedule = wyczerpuje 20 limit. | |
| 1 DAS z Set<DateInterval> | Apple doc nie gwarantuje dla recurring — fragile. | |

**User's choice:** 1 DAS z repeats=true per dzień
**Notes:** Filter `Calendar.weekday` w DAM intervalDidStart.

### ManagedSettingsStore strategia

| Option | Description | Selected |
|--------|-------------|----------|
| Osobny store "deluludetox.schedule" | Niezależny od "deluludetox.session" (Phase 3). iOS auto-merge. Clearing nie wpływa na drugi. | ✓ |
| Wspólny store | End-of-session musiałby sprawdzać "czy schedule aktywny". Bug-prone. | |

**User's choice:** Osobny store `deluludetox.schedule`
**Notes:** Enabler dla decyzji o warstwach z Area 2.

### Shield copy per-source

| Option | Description | Selected |
|--------|-------------|----------|
| Ten sam copy | Phase 4 D-14 obowiązuje. Prostsze, ten sam helper w extension. | ✓ |
| Subtle różnicowanie | Shield czyta source, inny prefix. Marginal gain, więcej RAM. | |

**User's choice:** Ten sam copy
**Notes:** Phase 4 decyzje obowiązują bez modyfikacji w Phase 5.

### NTF-02 ownership

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 5 marker, Phase 6 notification | Event source z DAM, konsumpcja w Phase 6. Clean separation. | ✓ |
| Phase 5 wysyła sama | DAM → UNUserNotificationCenter direct. Scope creep na NTF-02. | |
| Nic w Phase 5, Phase 6 retroactive | Phase 6 musi dorabiać DAM marker. Niepraktyczne. | |

**User's choice:** Phase 5 marker, Phase 6 notification
**Notes:** Kontrakt: `schedule_event_marker.json` + Darwin notification; Phase 6 reconciliates i wysyła notyfikacje.

---

## Claude's Discretion

- Cross-midnight marker copy + styl w edytorze
- Kolor/styl chipów dni (filled vs outline)
- Wizualne enabled/disabled (grey out vs badge)
- Empty state copy w liście harmonogramu
- Error toast copy dla DeviceActivityCenter throws
- Struktura marker files (single overwrite vs append-only)
- Kolejność chipów (Pn-Nd vs Nd-Sb)
- Opcjonalne `name` field w edytorze (schema wspiera, funkcjonalnie zbędne w MVP)
- Indicator "drugiej warstwy" (session + schedule jednocześnie) w countdown screen

## Deferred Ideas

Wszystkie w CONTEXT.md `<deferred>`:
- Multi-schedule UI (MSC-01/02 v2)
- Per-schedule blocklist
- Emergency "disable NOW" toggle
- Warning przy usuwaniu tokenów podczas aktywnego okna
- NTF-02 delivery (Phase 6)
- Schedule templates
- Multi-schedule DAS budget scaling
- Widget / Live Activity
- Cross-device iCloud sync

---

## Wave 0 Spike — DEFERRED

Date: 2026-04-20
Status: deferred — no physical iOS 26+ device available at execution time.

Consequence:
- Plan 05-02 MUST NOT pick happy-path (repeats=true) vs daily-re-register-at-midnight fallback until this spike runs and a verdict section is appended below (heading: Wave-0-Spike-Verdict).
- Tasks 2 and 3 of Plan 05-01 were executed (scaffolds + XCTSkipIf test stubs). No spike instrumentation was added. No spike revert was needed.
- Downstream: run Plan 05-01 Task 1 on device before starting Plan 05-02.

## Wave 0 Spike Verdict — CONFIRMED Outcome A (2026-04-20 on device)

Retroactively verified via Plan 05-08 physical-device UAT. Scenarios 1, 3 and 4 from `05-HUMAN-UAT.md` all PASS:
- Scenario 1 — basic `intervalDidStart` fires on scheduled day.
- Scenario 3 — weekday filter works on `repeats: true` DAS.
- Scenario 4 — cross-midnight segment handoff (22:00–06:00): `.evening` intervalDidStart at 22:00, intervalDidEnd at 23:59:59, `.morning` intervalDidStart at 00:00, intervalDidEnd at 06:00. Markers consumed on next foreground.

Conclusion: `DeviceActivitySchedule(repeats: true)` with `DateComponents(hour:minute:)` fires reliably day after day without main-app-side re-registration. No daily-re-register-at-midnight fallback needed. Plans 05-02 / 05-04 / 05-05 happy-path implementations stand.

## Wave 0 Spike Verdict — ASSUMED Outcome A (original conditional entry, kept for audit)

Date: 2026-04-20
Decided by: user (override of spike gate in D-17) — proceed with happy-path implementation without on-device verification.

Assumed outcome: **A — `DeviceActivitySchedule(repeats: true)` with `DateComponents(hour:minute:)` fires `intervalDidStart` reliably day after day without re-registration.**

Implications for Plan 05-02+:
- Plan 05-02 `SyncScheduleWithSystemUseCase` implements ONLY the happy-path registration (single `startMonitoring` call per segment, `repeats: true`). No daily re-register-at-midnight scaffold.
- Plan 05-04 / 05-05 proceed against the same assumption.
- Plan 05-08 (on-device UAT) is the deferred verification gate. If SCH-03 UAT case ("schedule fires on day N+1 without app relaunch") fails there, we create a decimal fix phase (e.g. 05.1) to add daily re-register fallback.

Risk log: if Outcome A is wrong, Plans 05-02 / 05-04 / 05-05 require rework — not wasted code, but added cost. User accepted this risk to unblock Wave 1.
