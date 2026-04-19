# Phase 6: Engagement Layer - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 06-engagement-layer
**Areas discussed:** Streak semantics, Stats presentation & placement, Notification delivery design, Broken streak UX

---

## Streak Semantics

### Strefa czasowa

| Option | Description | Selected |
|--------|-------------|----------|
| Local device time | `TimeZone.current`. Intuicyjne. Edge case: travel. | ✓ |
| UTC | Niezmienne przy travel, ale 23:30 pon = wt UTC. | |
| Device time z 4:00 cutoff | "Nocne marki" liczone do poprzedniego dnia. Nietypowe. | |

**User's choice:** Local device time
**Notes:** Consumer app, travel corner case akceptowalne.

### Co liczy jako zakończona sesja

| Option | Description | Selected |
|--------|-------------|----------|
| Tylko outcome == .completed | Spójne z Phase 3 D-08 semantyką | ✓ |
| .completed LUB .broken_by_revoke | Kontrowersyjne, broken to defeat | |
| Jakąkolwiek sesję | Low bar, traci intent | |

**User's choice:** Tylko .completed
**Notes:** .cancelled_by_user i .broken_by_revoke zerowane.

### Grace period

| Option | Description | Selected |
|--------|-------------|----------|
| Bez grace — zero tolerance | Pure, bez manipulacji. Post-MVP streak freeze jako monetization. | ✓ |
| 1 freeze na tydzień | Delikatniej, complexity | |
| Grace do godziny X dnia następnego | UX wyjaśnienia | |

**User's choice:** Zero tolerance
**Notes:** Paid "streak freeze" potencjalny v2 MON feature.

---

## Stats Presentation & Placement

### Gdzie stats żyją

| Option | Description | Selected |
|--------|-------------|----------|
| Home card + dedykowany Stats screen | Dual: glance + drill-down | ✓ |
| Tylko home card | Limitowany space | |
| Tylko Stats screen | Mniej widoczne | |

**User's choice:** Oba
**Notes:** Standard engagement pattern.

### Visual na home card

| Option | Description | Selected |
|--------|-------------|----------|
| Flame emoji + liczby + mini progress | 🔥 streak, count, 7-day dot row | ✓ |
| Tylko duże liczby | Emocjonalnie neutralne | |
| Progress ring + liczby | Apple Fitness style, wymaga milestone'ów | |

**User's choice:** Flame + liczby + mini progress
**Notes:** Motywacyjne, czytelne.

### Stats screen content

| Option | Description | Selected |
|--------|-------------|----------|
| Kalendarz z dniami + streak + total | Visual "gdzie jestem w historii" | ✓ |
| Lista per-session detail | Scope creep (Phase 3 deferred) | |
| Wykres time-in-sessions | Nie w GAM-01/02 | |

**User's choice:** Kalendarz + streak + total
**Notes:** Current/longest streak + Σ total w headerze.

---

## Notification Delivery Design

### Kiedy pytamy o permission

| Option | Description | Selected |
|--------|-------------|----------|
| Lazy — po pierwszej .completed | Natychmiast korzyść, user widzi kontekst | ✓ |
| Onboarding po Screen Time | 2 modale pod rząd, friction | |
| Opt-in w Settings | Nikt nie znajdzie | |

**User's choice:** Lazy przy pierwszej .completed
**Notes:** Prompt przed success screen (Phase 3 D-19).

### NTF-01 delivery (session end)

| Option | Description | Selected |
|--------|-------------|----------|
| Main app w D-08 End Sequence | Nie pokrywa killed-app case | ✓ |
| DAM extension na intervalDidEnd | Narusza marker-only rule Phase 3 D-03 | |
| Scheduled notification przy session start | Reliable dla killed-app | |

**User's choice:** Main app w D-08
**Notes:** Technical reconciliation: honoruję intent "main app owns it" przez hybrid — main app schedule'uje w D-07 Start przez UNCalendarNotificationTrigger(plannedEndAt, repeats:false), cancel w D-08 End gdy outcome != .completed. iOS dostarcza dla .completed nawet gdy app killed. Zapisano w CONTEXT.md D-15/D-16.

### NTF-02 delivery (schedule start)

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-schedule 2 tyg do przodu | Reliable bez względu na app state | ✓ |
| Reaktywnie z Darwin notification | Zawodne gdy app killed | |
| DAM sam fire'uje | Scope creep odrzucony w Phase 5 | |

**User's choice:** Pre-schedule
**Notes:** UNCalendarNotificationTrigger(dateMatching: weekday+hour+minute, repeats: true) w SyncScheduleUseCase z Phase 5 D-14. iOS auto-repeat. Cross-midnight = notification tylko dla evening segmentu.

### Copy ton

| Option | Description | Selected |
|--------|-------------|----------|
| Miękki sarkazm + celebracja | Nie agresywne, w brand voice | ✓ |
| Czysto celebracyjny | Traci brand voice | |
| Ostry sarkazm | Ryzyko attacku w notification context | |

**User's choice:** Miękki sarkazm + celebracja
**Notes:** Notification context (lock screen) jest inny niż shield context (aktualny moment pokusy). Miękki ton lepszy.

---

## Broken Streak UX

### Copy przy złamanej serii

| Option | Description | Selected |
|--------|-------------|----------|
| Miekko-sarkastyczna zachęta | Kontrapunkt do shielda, brand "ironic not malicious" | |
| Ostry shame | Konsystentny z shield tonem, mocny, ryzyko deinstal | ✓ |
| Celebratory | Traci brand voice | |

**User's choice:** Ostry shame
**Notes:** Świadome ryzyko. Konsystent z Phase 4 D-03 ostrym shield tonem. Brand voice over safe engagement. Monitorować w beta — jeśli signal "too harsh" można złagodzić w dot-release.

### Longest streak display

| Option | Description | Selected |
|--------|-------------|----------|
| Widoczne na Stats + subtelnie na home | Motywacja bez overwhelming | ✓ |
| Tylko na Stats | Clean home, lost motivation | |
| Nigdzie | Sympathy dla tych którzy stracili | |

**User's choice:** Stats zawsze + home tylko w broken streak context
**Notes:** Home card w broken streak pokazuje "Straciłeś X-dniową serię" — longest wpleciony w shame copy.

### Moment wygasania serii

| Option | Description | Selected |
|--------|-------------|----------|
| Eagerly o północy | Compute on-demand z sessions.json + Calendar. Zero "state ghost". | ✓ |
| Lazy — do próby sprawdzenia | Cached w stats.json, nieaktualne po 2 dniach | |

**User's choice:** Eagerly
**Notes:** Stats pure compute from source, zero cache, zero migration concerns.

---

## Claude's Discretion

- Dokładne warianty copy (NTF-01, NTF-02, broken streak) — library 3-5 wariantów, rotation strategy
- Home card visual (shadow, radius, padding, placement)
- Kalendarz layout detail (dots size, today highlight)
- Monday-first vs Sunday-first (PL convention: Monday-first)
- Last 7 dni dot row order (dziś prawy vs lewy)
- `.willPresent` behavior gdy app foreground (banner vs nothing)
- Success screen + permission prompt sequencing
- Szary flame visual (opacity/outline)
- Empty state dla Stats screen gdy 0 sesji
- Granice nawigacji kalendarza (scroll w przyszłość?)

## Deferred Ideas

Wszystkie w CONTEXT.md `<deferred>`:
- Paid streak freeze (v2 MON)
- Per-notification granular toggles
- In-app daily reminder push
- Widget, Live Activity
- Share streak
- Cross-device iCloud sync
- DeviceActivityReport usage stats (STS)
- A/B testing
- Haptics, achievements/badges
- Stats export
- Aggregated wykresy
- Per-session detail view
- stats.json cache (razem z widget post-MVP)
