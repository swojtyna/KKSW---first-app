# Phase 3: Quick Sessions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 03-quick-sessions
**Areas discussed:** Timer enforcement, Anti-cancel friction (QSN-05), Active session UI + countdown (QSN-04), Session record schema
**Language note:** Conducted in Polish at user request; decisions rendered in English for downstream agents in CONTEXT.md.

---

## Timer enforcement

### Q1 — Kto kończy blokadę, gdy timer się wypali?

| Option | Description | Selected |
|--------|-------------|----------|
| Robot w tle + apka asekuruje (rekomendacja) | DAS + DAM intervalDidEnd clears shield; main app self-heals on foreground if endsAt passed. Survives app kill/restart. | ✓ |
| Tylko timer w apce | Pure in-app Timer; shield never auto-clears if app killed. | |
| Tylko robot, bez asekuracji | DAS only; fails on iOS 26 DAM callback regression. | |

**User's choice:** Hybrid (DAS + DAM + main-app self-heal)
**Notes:** Aligns with Opal/Foqos canonical pattern.

### Q2 — Kto zapisuje "sesja skończona" do sessions.json?

| Option | Description | Selected |
|--------|-------------|----------|
| Robot zostawia karteczkę, apka finalizuje (rekomendacja) | DAM writes small finalize marker + Darwin notification; main app finalizes sessions.json on next foreground. Preserves Phase 2 sole-writer rule. | ✓ |
| Robot pisze sam do sessions.json | DAM opens sessions.json directly. Breaks Phase 2 writer/reader split; pressures 6 MB RAM. | |
| Apka odtwarza przy foregroundingu, bez markera | No marker; main app infers from wall clock. Simplest, but history lag if app not opened for days. | |

**User's choice:** DAM marker + main-app finalize
**Notes:** Phase 2 writer/reader split explicitly preserved.

### Q3 — Co robimy, gdy robot w tle NIE odpali (bug iOS 26)?

| Option | Description | Selected |
|--------|-------------|----------|
| Apka sama się ratuje przy otwarciu (rekomendacja) | On scenePhase == .active, if endsAt passed → clear shield + finalize. Zero extra components. | ✓ |
| Podwójny zegar: robot + timer w apce | DAM callback + in-app Timer both attempt clear. Redundant, most reliable, more code. | |
| Ufamy robotowi, udokumentuj ryzyko | Accept the iOS 26 regression. Most fragile. | |

**User's choice:** Main-app self-heal
**Notes:** Mitigates iOS 26 DAM regressions documented in research R5.

### Q4 — Odświeżać mapę tokenów tuż przed startem sesji?

| Option | Description | Selected |
|--------|-------------|----------|
| Tak — odśwież tuż przed shield | Belt-and-suspenders; <10 ms; closes gap when user opened app hours before starting session. | |
| Nie — ufamy reconcile z fazy 2 (rekomendacja przy uproszczeniu) | Accept Phase 2's scenePhase-only reconcile. Stale-token risk acknowledged. | ✓ |

**User's choice:** No pre-start reconcile
**Notes:** User explicitly chose the simpler MVP tradeoff. Revisit in beta if stale-token issues surface.

---

## Anti-cancel friction (QSN-05)

### Q1 — Czy w MVP jest przycisk "zakończ sesję"?

| Option | Description | Selected |
|--------|-------------|----------|
| Brak przycisku — czekasz do końca | Strictest MVP; only escape is Settings revoke. Jomo Strict Mode. | |
| Przycisk + dialog potwierdzający (rekomendacja) | "Are you sure?" Yes/No. Minimal friction, iOS pattern. | ✓ |
| Przycisk + drobna friction (trzymaj/countdown) | 5s press-and-hold or countdown. Touches Deep Focus. | |
| Emergency Pass (1/dzień, wzór Opal) | 1 free exit per day. Requires counter + state. | |

**User's choice:** Early-end button + confirm dialog
**Notes:** Deep Focus explicitly post-MVP (PROJECT.md DFO-01/02/03).

### Q2 — Włączać systemowe utrudnienia na czas aktywnej sesji?

| Option | Description | Selected |
|--------|-------------|----------|
| Oba: requireAutomaticDateAndTime + denyAppRemoval (rekomendacja) | Closes clock-skew + reinstall bypasses. Reverted on session end. | ✓ |
| Tylko requireAutomaticDateAndTime | Only clock defense; user can still manage other apps normally. | |
| Żadne — zostaw na post-MVP | Simplest MVP; accept both bypasses. | |

**User's choice:** Both restrictions active during session
**Notes:** Production pattern (Opal). One-line API each.

### Q3 — Jak zapisywać końcowy status sesji w sessions.json?

| Option | Description | Selected |
|--------|-------------|----------|
| Trzy statusy: completed / cancelled_by_user / broken_by_revoke (rekomendacja) | Max info for Phase 6 streak logic. Revoke detection via polling around $authorizationStatus bug. | ✓ |
| Dwa statusy: completed / not_completed | Simpler but loses intent distinction. | |
| Odkładamy outcome na Fazę 6 | Schema migration later. | |

**User's choice:** Three outcomes
**Notes:** Contract locked for Phase 6 gamification.

### Q4 — Ton copy dla dialogu/komunikatów końca sesji?

| Option | Description | Selected |
|--------|-------------|----------|
| Neutralny / współczujący (rekomendacja) | "Timer ma jeszcze 23 min. Na pewno?" Safe, no dark patterns. | |
| Motywująco-stanowczy | Light push to continue. | |
| Claude decyduje — dopracujemy w fazie UI | Tone deferred to UI phase. | |
| Other: sarkastyczno-zabawny | User free-text override. | ✓ |

**User's choice:** Sarcastic-playful (user override)
**Notes:** Applies to ALL user-facing strings in this phase. No emotional guilt-tripping (App Store 5.5 safe).

---

## Active session UI + countdown (QSN-04)

### Q1 — Gdzie mieszka ekran startu sesji i ekran aktywnej sesji?

| Option | Description | Selected |
|--------|-------------|----------|
| Jeden Home, dwa stany (rekomendacja) | Same screen, VM switches state. One destination case. | |
| Dwa osobne ekrany (push) | Push from start screen to dedicated countdown screen. | ✓ |
| Sheet / modal dla aktywnej sesji | .sheet with countdown. Swipe-down dismiss conflicts with QSN-05. | |

**User's choice:** Two screens with push navigation

### Q2 — Kształt countdownu podczas aktywnej sesji?

| Option | Description | Selected |
|--------|-------------|----------|
| Progress ring + duże cyfry (rekomendacja) | Ring draining + digits + caption. Opal/Foqos pattern. | ✓ |
| Tylko duże cyfry | Minimal; no ring. | |
| Horizontal progress bar + cyfry | Utility-style; less satisfying. | |

**User's choice:** Progress ring + digits + sarcastic caption

### Q3 — Jak user ustawia custom duration (QSN-02)?

| Option | Description | Selected |
|--------|-------------|----------|
| Natywny DatePicker(.hourAndMinute) wheel (rekomendacja) | iOS-native, 5 min – 8 h range. | ✓ |
| Dwa steppery (godziny / minuty) | More compact in Form. | |
| Slider 5 min – 8 h | Hard to hit "37 min" precisely. | |

**User's choice:** Native wheel picker, 5 min – 8 h range

### Q4 — Co user widzi zaraz po wygaśnięciu sesji (przy otwarciu apki)?

| Option | Description | Selected |
|--------|-------------|----------|
| Krótki ekran sukcesu + sarkastyczny tekst (rekomendacja) | "Survived 30 min"-style screen, tap to dismiss. | ✓ |
| Toast / banner, bez dedykowanego ekranu | Dismissible banner at top of home. | |
| Nic — po prostu home idle | No celebration. | |

**User's choice:** Dedicated success screen with sarcastic copy, tap-to-dismiss

---

## Session record schema

### Q1 — Osobny plik na aktywną sesję, czy jeden wspólny?

| Option | Description | Selected |
|--------|-------------|----------|
| active_session.json + sessions.json (rekomendacja) | DAM reads small singleton; main app reads history. Cleaner RAM profile. | ✓ |
| Jeden sessions.json z isActive flag | Single file; DAM must parse growing file. Worse RAM. | |

**User's choice:** Two-file split

### Q2 — Zestaw pól w SessionRecord?

| Option | Description | Selected |
|--------|-------------|----------|
| Pełny od dnia 1 (rekomendacja) | Full schema including appVersion, plannedEndAt, etc. No Phase 6 migration. | ✓ |
| Minimalny MVP, dorobimy w Fazie 6 | Migration burden in Phase 6. | |
| Tylko DAM minimum | Too spartan; requires recompute. | |

**User's choice:** Full schema from day 1

### Q3 — Kiedy zapisujemy do pliku?

| Option | Description | Selected |
|--------|-------------|----------|
| Trzy momenty: start + koniec + anulu (rekomendacja) | Create at start, finalize at end / cancel / revoke. Deterministic, crash-recoverable. | ✓ |
| Tylko na końcu | Crash in-session loses the record. | |
| Tylko na początku + update outcome | Collides with two-file split from Q1. | |

**User's choice:** Three write moments

### Q4 — Retencja historii sesji?

| Option | Description | Selected |
|--------|-------------|----------|
| Wszystkie sesje, bez limitu (rekomendacja) | ~200 B/record; non-issue for years. | ✓ |
| Rollover po 365 dniach | Long streaks need separate counter. | |
| Limit 1000 ostatnich | Arbitrary cap with no driver. | |

**User's choice:** No retention cap in MVP

---

## Claude's Discretion

- Exact SwiftUI structure of the start screen (Form vs VStack layout; chips arrangement vs picker placement).
- Exact sarcastic copy strings — draft during execution, align with the sarcastic-playful tone.
- Progress ring animation curve and easing.
- Success screen exact visual design.
- Entry point for the session flow in the main-app navigation graph.
- "Pick apps first" empty-state visual.
- Handling of the `DeviceActivityCenter` "max 20 activities" limit (unlikely to hit in MVP).
- Mechanism for tracking whether the success screen has been shown once per completed session.

## Deferred Ideas

- Deep Focus (passphrase typing, unlock delay, hold-to-end, Emergency Pass) — post-MVP DFO-01/02/03.
- Live Activity / Dynamic Island countdown — post-MVP LAC-01/02.
- Local notifications on session end — Phase 6 NTF-01.
- Multi-session concurrency / session queue.
- Streak penalty for `cancelled_by_user` / `broken_by_revoke` — Phase 6 decides.
- Per-session history UI.
- Custom sound / haptic on session end.
- Emergency Pass gamification lever.
- Pre-start token reconciliation — revisit in beta if stale-token issues surface.
