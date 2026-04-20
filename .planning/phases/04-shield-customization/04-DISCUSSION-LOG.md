# Phase 4: Shield Customization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 04-shield-customization
**Areas discussed:** Shield visual identity, Button configuration, Deep link destination, Unknown-token fallback

---

## Shield Visual Identity

### Tło shielda

| Option | Description | Selected |
|--------|-------------|----------|
| Flat violet #7C3AED | Jednolity electric violet — markowy, czytelny, zero ryzyka dziwnego renderu. Najprostsze do zaimplementowania. | |
| Blur overlay nad app icon | `backgroundBlurStyle` (UIBlurEffect.Style). Rozmyta wersja oryginalnej apki z violet tintem. Apple-native wygląd. | ✓ |
| Violet + subtle pattern | Flat violet + jedna statyczna grafika jako wypełnienie. Wymaga dodatkowego asseta. | |

**User's choice:** Blur overlay nad app icon
**Notes:** Native Apple look + brand tint przez `backgroundColor` z violetem i niskim alpha.

### Ikona

| Option | Description | Selected |
|--------|-------------|----------|
| SF Symbol hand.raised.fill | Native, biele na violet, natychmiastowo rozpoznawalna. Zero custom assetów. | ✓ |
| Custom DeluluDetox logo/mascot | Markowa ikona. Wymaga design pass i assetu. | |
| SF Symbol moon.stars.fill lub nosign | Inne SF Symbole. Bardziej zgodny z sarkastycznym tonem. | |

**User's choice:** SF Symbol `hand.raised.fill`
**Notes:** Recommended option. Wystarczy dla MVP.

### Copy tone (title/subtitle)

| Option | Description | Selected |
|--------|-------------|----------|
| Sarkastyczno-miękki | "Nie teraz, kochanie" / "Jesteś w trakcie sesji — apka może poczekać". Zgodny z Phase 3 D-12. | |
| Sarkastyczno-ostry | "Serio? Dopiero co sam sobie to zablokowałeś" / "Jeszcze X min zanim znowu będziesz mógł scrollować". Mocniejszy ton. | ✓ |
| Neutralny/informacyjny | "Apka zablokowana" / "Sesja kończy się o HH:MM". Bezpieczne, nie wykorzystuje brand voice. | |

**User's choice:** Sarkastyczno-ostry
**Notes:** Dokładne stringi drafty w execute; muszą przejść sanity check vs App Store Guideline 5.5 (Phase 3 research §D).

---

## Button Configuration

### Ile guzików

| Option | Description | Selected |
|--------|-------------|----------|
| Jeden guzik: 'Open app' | Primary: deep link. Brak secondary. Jedna intencja. | |
| Dwa: Close (primary) + Open app (secondary) | Close bardziej dostępny, deep link to opt-in. | |
| Dwa: Open app (primary) + Close (secondary) | Primary violet, pcha do appki gdzie jest countdown i sarkazm. | ✓ |

**User's choice:** Dwa guziki — Open app (primary) + Close (secondary)
**Notes:** Violet accent na primary → wysoka widoczność. Secondary "Zamknij" = Apple default dismiss.

### Copy guzika Open app

| Option | Description | Selected |
|--------|-------------|----------|
| Sarkastyczny: 'Jednak chę Ci się oglądać?' | Buttonowy sarkazm. Zgodny z ostrym tonem. | |
| Funkcjonalny: 'Otwórz DeluluDetox' | Jasny, nudny, jednoznaczny. | |
| Miększy sarkazm: 'Zobacz ile zostało' | Informuje o funkcji (timer w app), z lekką ironią. Zachęca wejść. | ✓ |

**User's choice:** Miększy sarkazm — "Zobacz ile zostało"
**Notes:** Świadomy kontrast: ostry ton na tytule, zachęcający na CTA. Nie odstraszaj usera od kliknięcia.

---

## Deep Link Destination

### Gdzie user ląduje

| Option | Description | Selected |
|--------|-------------|----------|
| Countdown screen z Phase 3 | Reuse `Destination.countdown`. Zero nowych ekranów. | ✓ |
| Interstitial 'tried-to-open' | Nowy ekran. Problem: opaque token, nie wiemy którą apkę próbował otworzyć. | |
| Root home z banerem | Mniej inwazyjny, ale SHL-04 mówi "relevant active session context" — baner za daleko. | |

**User's choice:** Countdown screen z Phase 3
**Notes:** Reuse istniejącego VM i widoku. Jeśli sesja się skończyła w międzyczasie → success screen (też z Phase 3). Brak aktywnej sesji → fallback route opisany w CONTEXT D-10.

### URL scheme vs Universal Link

| Option | Description | Selected |
|--------|-------------|----------|
| Custom URL scheme | `deluludetox://session/active`. Prosta konfiguracja. Foqos też tak robi. | ✓ |
| Universal Link | Wymaga AASA file + hosting. MVP on-device — overkill. | |

**User's choice:** Custom URL scheme `deluludetox://session/active`
**Notes:** Rejestracja przez `project.yml` (XcodeGen). Handler przez SwiftUI `.onOpenURL`.

---

## Unknown-Token Fallback

### Co pokazać gdy brak kontekstu sesji

| Option | Description | Selected |
|--------|-------------|----------|
| Branded shield z generic copy | Ten sam wizual, generic copy ("Zablokowane" / "Zamknij i zrób coś mądrzejszego"). | ✓ |
| Apple default shield | Zwróć nil. Najprostsze, ale user widzi nie-markowy shield. | |
| Branded minimal: tylko logo + neutralny tekst | Violet blur, logo, "Zablokowane", ZERO guzików. | |

**User's choice:** Branded shield z generic copy
**Notes:** Brand consistency nawet w edge case'ie. Deep link w fallbacku idzie na root home zamiast countdown (bo countdown może nie istnieć).

### Jak decydować że token jest 'nieznany'

| Option | Description | Selected |
|--------|-------------|----------|
| Brak active_session.json w App Group | Extension czyta active_session.json. Brak/pusty plik → fallback. Przykrywa race + usuniętą sesję. | ✓ |
| Token nie jest w blocklists.json | Dodatkowy parsing. Pełniejsze pokrycie, ale więcej I/O i pamięci. | |
| Wyłącznie gdy extension rzuci error | Try/catch na całym kodzie. Mniejsze wyczucie edge case'u. | |

**User's choice:** Brak `active_session.json` w App Group
**Notes:** Świadomy tradeoff: prostota i niższa pamięć kosztem potencjalnych false positives w rzadkich race'ach (token valid, ale sesja jeszcze nie zapisana). Akceptowalne w MVP.

---

## Claude's Discretion

Następujące obszary zostawione do decyzji podczas execute:
- Dokładny styl `UIBlurEffect.Style` (thick material dark, regular, etc.)
- Alpha violet tintu nałożonego na blur (0.6 vs 0.8)
- Point size / weight SF Symbola `hand.raised.fill`
- Dokładne stringi (title, subtitle, button copy) — draft z wariantami
- Mechanizm odczytu `plannedEndAt` dla dynamicznego subtitle (inline read vs cache)
- Copy/forma fallback UI w main app przy deep linku bez aktywnej sesji
- Color secondary buttona (Apple default system blue vs neutral gray)
- Strategia lokalizacji (hard-coded PL vs `.strings` + en fallback) — aligned z Phase 1-3

## Deferred Ideas

Wszystkie odnotowane w CONTEXT.md `<deferred>` sekcji:
- Shield behavior po końcu sesji (Phase 3 territory)
- Per-source shield różnicowanie (Phase 5 może dodać subtle markup)
- Analityka / logi z Shield extension (post-MVP)
- Custom logo / maskotka (post-MVP design pass)
- Universal Links (post-MVP)
- Pełna lokalizacja (future)
- Haptic / sound (Shield API limitation + post-MVP)
- Emergency pass (post-MVP gamification)
- Dynamic copy history-based (post-MVP)

---

## Wave 0 Spike — WAIVED (2026-04-20)

**Decision:** Waive Plan 04-01 Task 1 (physical-device verification of `extensionContext?.open(_:)` from `ShieldActionDelegate`). Plan 04-03 commits unconditionally to the local-push-notification fallback.

**Rationale:**
- RESEARCH.md Pitfall 4 establishes `extensionContext?.open(_:)` is unreliable from Shield extensions — Apple has not documented it as supported for `ShieldActionDelegate`, and community reports show inconsistent behavior across iOS versions.
- No physical iOS 26 device readily available for this session; spike ROI is low when the fallback is already well-understood and the Shield API contract has been frozen since 2022.
- Choosing the fallback a priori removes a blocking dependency on Wave 2 (Plan 04-03) without compromising SHL-03 behavior — the user still gets a tappable primary button that routes to the main app via `UNNotificationRequest` delivery + `UNUserNotificationCenterDelegate` → deep-link path.

**Consequence for Plan 04-03 implementation:**
- Do NOT attempt `extensionContext?.open(URL(string: "deluludetox://..."))` in `ShieldActionHandler.handle(action:for:completionHandler:)`.
- Instead: schedule an immediate local notification (`UNNotificationRequest` with `trigger: nil`) whose `userInfo` carries the deep-link URL; user taps notification banner → `UNUserNotificationCenterDelegate.didReceive(_:withCompletionHandler:)` in the main app's `AppDelegate` / `SceneDelegate` bridge routes to `HomeViewModel.handleDeepLink(_:)`.
- URL scheme registration in `project.yml` (Plan 04-02 Task N) is still required — the local-notification handler uses the same `deluludetox://` scheme.

**Task 1 status:** `WAIVED` (not `blocked`). Plan 04-01 is now complete.

