# Jak zdobyć entitlement `com.apple.developer.family-controls` w 2026 (praktyczny przewodnik dla solo indie dev)

**TL;DR:** Dla dorosłej aplikacji self‑control typu Opal / one sec / Jomo / Brick trzeba złożyć wniosek pod adresem **https://developer.apple.com/contact/request/family-controls-distribution** (wyłącznie z konta Account Holder). Typowy czas odpowiedzi w 2025–2026 to **1 dzień do 4 tygodni**, mediana ~2–3 tygodnie, z długim ogonem sięgającym 2–5 miesięcy przy słabym uzasadnieniu. **Najczęstsza pułapka nie jest merytoryczna, tylko proceduralna**: wniosek trzeba złożyć osobno dla KAŻDEGO bundle ID — aplikacji głównej i każdego rozszerzenia (ShieldConfiguration, ShieldAction, DeviceActivityMonitor, DeviceActivityReport). Kluczowe ramowanie: **"individual use case"** z `requestAuthorization(for: .individual)` (dodane w iOS 16), nie `.child`. Cała logika ma działać on‑device — jakiekolwiek wysyłanie danych Screen Time do chmury = automatyczny odrzut. Poniżej masz pełny workflow „od zera do approved", 3 gotowe szablony uzasadnienia, checklistę aktywów, mapę rejection reasons → fix, oraz opis tego, co można robić BEZ zatwierdzonego entitlementu (spoiler: dużo, ale NIE TestFlight i NIE App Store).

---

## 1. Timeline „od zera do approved" z realistycznymi widełkami czasowymi

Poniższy workflow odzwierciedla to, co robili Itsuki, Baker_build (~1 dzień approval, grudzień 2025), FocusPact, ScreenZen, Opal i inni — uporządkowany według kolejności, w której faktycznie warto działać.

| # | Krok | Czas | Wymagana aktywność |
|---|---|---|---|
| 1 | **Paid Apple Developer Program** ($99/rok). Darmowy „Personal Team" NIE pokazuje w Xcode capability „Family Controls" — to ślepa uliczka, potwierdzone przez Quinn „The Eskimo!" z Apple DTS. | 0–2 dni (weryfikacja) | Zarejestruj się jako Individual lub Organization. Brak publicznych dowodów, że typ konta wpływa na odrzut FamilyControls — solo devowie (Itsuki, alejandror321, Baker_build) i małe firmy (Jomo, one sec) są zatwierdzani na równi. |
| 2 | **Utwórz App IDs w Developer Portal** — osobny dla głównej aplikacji i każdego extension (typowo 4–5 bundle IDs: `com.x.app`, `.ShieldConfiguration`, `.ShieldAction`, `.DeviceActivityMonitor`, `.DeviceActivityReport`). | 1 dzień | Włącz capability „Family Controls" na każdym App ID — dostajesz automatycznie wariant **development** entitlementu bez pytania Apple o cokolwiek. |
| 3 | **Zbuduj prototyp i przetestuj LOKALNIE na fizycznym urządzeniu** z development provisioning profile. Cały łańcuch `AuthorizationCenter` → `FamilyActivityPicker` → `ManagedSettingsStore.shield` → `DeviceActivityCenter` → ShieldConfiguration/ShieldAction działa w debugu bez żadnej zgody Apple. | 2–6 tygodni | Nie używaj symulatora dla flow autoryzacji — `FamilyControlsError Code=2 (invalid account type)` na symulatorze, `FamilyActivityPicker` pokazuje same kategorie bez konkretnych aplikacji (potwierdzone w Apple Forums threads 682257, 708050). |
| 4 | **Przygotuj artefakty do wniosku** (patrz checklista w sekcji 4). Minimalne: prosta strona WWW (nawet GitHub Pages — Itsuki potwierdził że działa), publicznie dostępna privacy policy, 30–90 sek demo video, wypełniony listing w App Store Connect BEZ builda. | 1–2 tygodnie | Itsuki: *„EVERYTHING except for the build are filled in App Store Connect"* — to dostarcza reviewer'owi dowodu, że produkt jest realny. |
| 5 | **Zaloguj się na Account Holder** (NIE Admin — Admin jest cicho blokowany, confirmed thread 721914) i złóż wniosek na **https://developer.apple.com/contact/request/family-controls-distribution** — **osobno dla KAŻDEGO bundle ID**, tego samego dnia, wszystkie naraz. | 15 min × N bundle IDs | Baker_build (grudzień 2025) zatwierdzony na 4 bundle IDs w ~1 dzień gdy złożył je razem. Gdy składasz extensions później osobno — utkniesz na 2–3 tygodnie. |
| 6 | **Czekaj.** Rozkład reportowany w Apple Dev Forums 2024–2026: 1 dzień (best case) → 1–2 tygodnie (fast lane) → 2–4 tygodnie (mediana) → 4,5 tygodnia (thread 725036, ksen17) → 2–5 miesięcy (thread 701874, długi ogon). **System Apple NIE wysyła potwierdzenia, ani numeru case.** Status sprawdzasz w Certificates, Identifiers & Profiles → Identifier → Additional Capabilities → „Family Controls (Distribution)". | 1 dzień – 4 tygodnie realnie, do 5 miesięcy w patologii | Bez automatycznej komunikacji. Approval email od Entitlements team przychodzi z opóźnieniem po tym jak flaga się przestawi. |
| 7 | **Po otrzymaniu zatwierdzenia:** ręcznie przełącz „Family Controls (Distribution)" pod Additional Capabilities każdego Identifier; **regeneruj wszystkie provisioning profile** (debug + release); zrestartuj Xcode kompletnie. Znany bug: Xcode trzyma osobne entitlement files dla Debug i Release — sprawdź oba (thread 806285). | 1–2 godz | Forum thread 712870 (Quinn DTS): po approvalu musisz ręcznie włączyć capability dla distribution. |
| 8 | **Dopiero teraz TestFlight** (internal + external) oraz **App Store submission**. | Standardowy cykl App Review (24–72h typowo w 2026) | Uwaga: ***review App Store*** to osobny, drugi gate — zdarzały się rejections z działu App Review mimo approved entitlementu, bo review'er „didn't even know Family Controls were a thing" (thread 721914). Dodaj szczegółowy App Review Notes z opisem flow i linkiem do approval emaila Entitlements team. |

**Realistyczny total od zera do live w App Store:** **6–12 tygodni** dla solo dev z gotowym prototypem i dobrym uzasadnieniem; **4 miesiące+** w patologicznym scenariuszu z rejection + resubmission.

---

## 2. Struktura formularza wniosku (krok po kroku)

Adres: **https://developer.apple.com/contact/request/family-controls-distribution** (wymaga logowania jako Account Holder). Formularz nie ma publicznie indeksowanej wersji HTML, poniższa struktura pochodzi z walkthroughu Itsuki (Medium), kilkunastu threadów Apple Dev Forums oraz oficjalnego ogłoszenia Matt Eaton (Apple DTS) w wątku 690522.

**Sekcja A — kontakt / firma:** imię, nazwisko, email, nazwa firmy / osoby fizycznej zgodnie z enrollmentem, Team ID (10 znaków, np. `BH752TBX9L`), kraj, telefon.

**Sekcja B — aplikacja:** nazwa aplikacji, **App Apple ID** (numeryczny, z App Store Connect → My Apps → App Information → „Apple ID" — musisz najpierw utworzyć rekord App Store Connect), **Bundle ID** (dokładnie ten, który ma dostać entitlement — **jedno zgłoszenie na jeden bundle ID**), URL produktu/marketingu (landing page, GitHub Pages — wystarczy).

**Sekcja C — uzasadnienie (pola tekstowe, tu jest cały bój):**
1. Jak aplikacja używa FamilyControls / ManagedSettings / DeviceActivity — wymień konkretne API i flow.
2. Grupa docelowa / use case — **individual (self, adult, iOS 16+)** vs parent/guardian (child via Family Sharing).
3. Jakie dane zbiera aplikacja i jak są używane.
4. Potwierdzenie braku sprzedaży/udostępniania danych Screen Time stronom trzecim (odpowiednik Guideline 5.5 — ta sama litera dla MDM).
5. Dlaczego Screen Time API jest niezbędne do działania aplikacji.
6. URL polityki prywatności (obowiązkowy, publicznie dostępny).

**Sekcja D:** Submit. **Brak confirmation email, brak case ID** — typowa skarga w Dev Forums 2024–2026. Status tylko przez portal.

---

## 3. Trzy gotowe szablony uzasadnienia (wersje do wyboru)

### Szablon A — Solo dev, aplikacja przed launchem, brak innych apek w App Store (~210 słów)

> [App Name] is a digital wellness app designed for adults who want to build healthier relationships with their own iPhone. Users self‑authorize Family Controls on their personal device using `AuthorizationCenter.shared.requestAuthorization(for: .individual)` — this is NOT a parental‑control scenario and does not involve Family Sharing or a child Apple ID. It is the individual use case supported in iOS 16+.
>
> **How we use the entitlement:** FamilyControls to let the user pick their own distracting apps and websites via `FamilyActivityPicker`; `ManagedSettingsStore.shield` to restrict the selected apps during focus sessions the user schedules; DeviceActivity (Monitor + Report extensions) to start/stop shields at scheduled times and surface on‑device usage insights. Users can end or pause sessions themselves at any time.
>
> **Privacy:** Screen Time API only exposes opaque `ApplicationToken` / `WebDomainToken` / `ActivityCategoryToken` values — we never read app names, URLs, content, messages, or passwords. All selection data stays on‑device; nothing is transmitted to our servers. We do not sell, share, or disclose Screen Time‑derived data to any third party, consistent with App Store Review Guideline 5.5 principles.
>
> **Target users:** Adults seeking to reduce mindless scrolling, improve focus, manage ADHD symptoms, or support digital‑minimalism goals — same category as Opal, one sec, Jomo, ScreenZen, Clearspace, Roots.
>
> **Assets:** Website [URL]. Demo video [URL]. Privacy policy [URL]. App Store Connect App Apple ID [######]. Bundle IDs requested: `com.x.app`, `com.x.app.ShieldConfiguration`, `com.x.app.ShieldAction`, `com.x.app.DeviceActivityMonitor`.

### Szablon B — Dev mający już aplikacje w App Store (~220 słów)

> I am [Name], developer of [Existing App 1] and [Existing App 2] (links: […]), both live on the App Store in good standing. [New App Name] is my next product: a digital wellness / focus app for adults who want to take back control of their own iPhone use.
>
> **Use case — individual, not parental:** Users authorize Family Controls for themselves via `requestAuthorization(for: .individual)`. The entitlement is used exclusively to let the user voluntarily limit their own access to apps and websites they choose. We do not target child accounts and do not rely on Family Sharing guardian approval.
>
> **APIs used:** `FamilyActivityPicker` (user‑selected apps/websites); `ManagedSettings.shield.applications` / `.webDomainCategories` for the blocking layer; `DeviceActivitySchedule` + `DeviceActivityMonitorExtension` for recurring focus sessions; `DeviceActivityReportExtension` for on‑device usage stats. Shield UI is customized via `ShieldConfigurationDataSource` and `ShieldActionDelegate`.
>
> **Privacy model:** Apple's API returns opaque tokens, never app names, URLs, or content. All data is on‑device; no Screen Time data leaves the user's phone. This mirrors the published policies of Opal, Jomo, one sec, and other approved peers.
>
> **Supporting materials:** Product website [URL], onboarding video [URL], privacy policy [URL], App Store Connect draft listing Apple ID [######]. Bundle IDs: [main + each extension, listed]. Submitting one form per bundle ID as documented. TestFlight invitation available on request.

### Szablon C — Aplikacja z dodatkowymi funkcjami (NFC, accountability partners, AI coach, Pomodoro) (~240 słów)

> [App Name] is a digital wellness app for adults that combines Apple's Screen Time API with [additional feature: accountability partners / habit‑unlock actions like walking or meditating / NFC‑triggered blocks / AI coaching / Pomodoro]. It is built exclusively for the individual adult use case — each user authorizes Family Controls on their own device using `AuthorizationCenter.shared.requestAuthorization(for: .individual)`. No Family Sharing, no child account, no guardian flow.
>
> **Core entitlement usage (minimum necessary):**
> - **FamilyControls / FamilyActivitySelection** — user picks which apps and web categories they want to restrict.
> - **ManagedSettings** — apply the user's chosen shield during sessions they initiate or schedule.
> - **DeviceActivityMonitor extension** — start/stop shields on the schedule the user created.
> - **ShieldConfiguration / ShieldAction extensions** — show our branded block screen and handle the user's own unlock flow (breathing exercise, waiting period, accountability check) — all initiated by the user.
> - **DeviceActivityReport extension** — render the user's on‑device usage data inside our analytics view.
>
> Additional features ([e.g., NFC tag, HealthKit integration, accountability list]) layer on top of Screen Time API; none expose private data — only aggregated, on‑device stats the user opts to display.
>
> **Privacy:** Screen Time tokens are opaque; app/website names never leave the device. No selling, sharing, or transmitting of activity data. Policy: [URL].
>
> **Assets:** Website [URL], 60‑sec demo video [URL], screenshots [URL], privacy policy [URL], competitor comparison [URL]. Bundle IDs: [list].

**Uwagi do wszystkich szablonów.** (a) **Słowa‑klucze które są zielonym światłem:** „individual", „on‑device", „opaque tokens", „user‑initiated", „digital wellness", „focus". (b) **Słowa‑pułapki które warto unikać:** „monitor", „track", „collect usage", „server analytics", „leaderboard" (Apple Engineer potwierdził na forum 769247: *„A leaderboard of such is not supported today"*), „hide apps" (rejection precedent — thread 749466 — odrzucone jako „uses ScreenTime API to hide apps… unapproved uses of public APIs"). (c) **Wspominanie konkurentów (Opal, Jomo, one sec)** działa — pozycjonuje aplikację w znanej, Apple‑sanctioned kategorii.

---

## 4. Checklista „co musi być gotowe przed złożeniem wniosku"

Synteza z Medium Itsuki, wątków Apple Dev Forums 725036 / 735888 / 806301, oraz praktyk indie devów 2024–2026:

- [ ] **Paid Apple Developer Program** aktywny; login na **Account Holder** (Admin nie może submitować).
- [ ] **Wszystkie bundle IDs utworzone** (main + 4 extensions) z włączoną capability Family Controls na każdym.
- [ ] **Prototyp działający na fizycznym urządzeniu** w debug build — pełny flow: authorization → picker → shield → schedule → custom shield UI → unlock.
- [ ] **Strona WWW** dostępna publicznie (GitHub Pages wystarczy — Itsuki potwierdził). Screenshoty, opis produktu, FAQ.
- [ ] **Polityka prywatności pod publicznym URL** zawierająca język: Screen Time API returns opaque tokens, dane nie opuszczają urządzenia, no sale/share/disclose to third parties (literalnie zapożyczone z Guideline 5.5).
- [ ] **App Store Connect listing wypełniony BEZ builda**: nazwa, opis, keywords, kategoria, age rating (12+ lub 17+, NIE Kids Category), screenshoty, preview video, privacy policy URL, app privacy details (nutrition labels).
- [ ] **Demo video 30–90 sek** pokazujące: onboarding, permission prompt, `FamilyActivityPicker`, zablokowana aplikacja z custom shield, unblock. Hostowane na YouTube unlisted lub Vimeo.
- [ ] **Lista bundle IDs do zgłoszenia** gotowa — zamierz się submitować formularz N razy tego samego dnia (jeden na każdy bundle ID).
- [ ] **Template uzasadnienia** dopasowany (A, B lub C z sekcji 3) — **pisz szczegółowo**, wymieniając konkretne framework'i i flow; krótkie generyczne opisy korelują z declines (lateef, thread 818977).
- [ ] **Odpowiedź „No"** na pytanie formularza *„Will your app share device or usage data beyond the individual… including through means such as screenshots, screen recordings, or server logging?"* — „Yes" = automatyczny odrzut (thread 769247, ajy: *„I originally answered Yes and was rejected, then later answered No and was accepted"*).
- [ ] **Kontakt email** monitorowany codziennie — Apple czasem prosi o doprecyzowanie bez numeru case.

---

## 5. Najczęstsze przyczyny rejection + kontrargumenty / fixy

| # | Rejection pattern | Dlaczego się dzieje | Jak naprawić / argument |
|---|---|---|---|
| 1 | **„Yes" na pytanie o data sharing** | Screen Time data jest traktowana jak super‑sensitive (CSAM lineage, COPPA, GDPR). Każdy ślad off‑device = auto‑reject, nawet opt‑in leaderboard. | Zaprojektuj architekturę on‑device‑only (App Groups, nie serwer). Brak analytics na tokenach. Odpowiedz „No" zgodnie z prawdą po refaktorze. Przykład: ajy (thread 769247) — „Yes" → reject → „No" po zmianie → approved. |
| 2 | **Vague / generic opis use case** | Entitlements team dostaje tysiące wniosków; „I want to block apps" = spam‑tier. | Wymień konkretne framework'i (FamilyControls, ManagedSettings, DeviceActivity), konkretne feature'y (user‑defined schedules, custom shields), konkretny typ usera (dorosły self‑manager). Dodaj link do website + App Store Connect listing. lateef (thread 818977) resubmitował „a much more detailed explanation" po declining. |
| 3 | **Brak zgłoszenia dla extensions** (najczęstsza pułapka w 2025–2026) | Approval jest attached do konkretnego bundle ID. Extensions mają inne bundle IDs. | Submituj formularz osobno dla **każdego** bundle ID tego samego dnia. Quinn DTS (thread 813073): *„See Requesting the Family Controls entitlement"* — extensions wymagają osobnej rundy. Baker_build (thread 809190) zrobił to i miał approval w 1 dzień; baker2795 zapomniał i utknął na 10+ dni. |
| 4 | **Mismatch między `.individual` a `.child`** w opisie | Form i runtime API muszą być zgodne. Opisujesz app dla dorosłego, a używasz `.child` (lub odwrotnie) = reject. | Dla Opal‑like adult app → **zawsze** `requestAuthorization(for: .individual)` i zawsze w opisie pisz „individual, iOS 16+, no Family Sharing, no child account". Quinn DTS (thread 712870): *„with iOS 16, Screen Time API can be used for individual devices."* |
| 5 | **Scope creep / próba użycia API do niestandardowych celów** | Ukrywanie aplikacji, enterprise monitoring, monetyzacja samego API. | Stick to schedules + thresholds + user‑initiated shields. **Nie próbuj monetyzować samego Screen Time** — Guideline 4.10 wprost nazywa „Screen Time APIs" jako zabronione do direct monetization (sub za feature'y aplikacji OK; sub za sam fakt blokowania — NIE). Thread 749466: rejection za „uses ScreenTime API to hide apps… unapproved uses of public APIs." |
| 6 | **Silence / brak odpowiedzi przez tygodnie** (technicznie nie rejection, ale blokuje tak samo) | Brak confirmation number; kolejka opaque; sezonowe peaks. | (a) NIE submituj duplikatów — lando77 (thread 812332) zrobił drugi wniosek z więcej contextu, total czekanie wzrosło z „few days" do 3+ tygodni. (b) Czekaj 2–3 tygodnie. (c) Złóż **Code‑Level Support Request** przez Developer Account → Support z Team ID + Bundle ID + request ID (standardowa odpowiedź Apple DTS: *„Please file a code‑level support request including your Team ID for assistance"* — thread 818977). (d) Napisz w Apple Dev Forums pod tagiem `family-controls` — Quinn Eskimo czasem eskaluje stuck requests. |
| 7 | **Aplikacja próbuje czytać konkretne nazwy apek / URL‑e** | Zwracane są opaque `ApplicationToken`/`WebDomainToken` — są nieczytelne poza rodziną usera, to celowy design Apple. | Nie próbuj deanonimizować tokenów. Logikę raportową trzymaj w `DeviceActivityReportExtension` (sandbox), który RENDERUJE agregaty w SwiftUI bez eksponowania surowych danych do host app. |
| 8 | **App Review (osobny gate!) odrzuca mimo approved entitlementu** | Reviewer App Review może być niezaznajomiony z Family Controls (thread 721914: *„read like the person on the other side didn't even know that Family Controls were a thing"*). | W App Review Notes dodaj: (a) wyraźną wzmiankę „This app uses Apple's Family Controls / Screen Time API (individual use case, iOS 16+)"; (b) kopię maila approval od Entitlements team; (c) demo account lub demo flow; (d) krok‑po‑kroku jak sprawdzić shield. Jeśli odrzucą — użyj App Review Board z referencą do approvalu entitlementu. |

---

## 6. Workflow deweloperski BEZ zatwierdzonego entitlementu (co faktycznie działa)

Kluczowy fakt, który nie jest oczywisty z dokumentacji: **istnieją DWA entitlementy**, nie jeden. `com.apple.developer.family-controls.development` jest **automatycznie dostępny dla każdego paid member** gdy włączysz capability na Bundle ID — bez żadnego wniosku. Dopiero `com.apple.developer.family-controls` (distribution, bez sufiksu) wymaga aprobaty Apple. Ta asymetria pozwala zbudować i przetestować 95% aplikacji przed uzyskaniem distribution. Oto macierz co działa na jakim etapie:

| Scenariusz | Działa bez distribution? | Szczegóły |
|---|---|---|
| **Personal Team / darmowe konto** | ❌ Nie | Capability „Family Controls" nie pojawia się w Xcode w ogóle. Quinn Eskimo (thread 764682): *„That capability should show up if you're a member of a paid team… Personal Team feature has significant limitations and this is one of them."* |
| **Paid $99 dev account — kompilacja** | ✅ Tak | `import FamilyControls`, `import ManagedSettings`, `import DeviceActivity` — wszystko się kompiluje. Kod piszesz normalnie. |
| **Xcode Signing & Capabilities → toggle Family Controls** | ✅ Tak (paid team) | Toggle dodaje `com.apple.developer.family-controls` do `.entitlements` i aktywuje capability na App ID w portalu. **Bez kontaktu z Apple.** |
| **Debug build na własne fizyczne urządzenie** | ✅ Tak — w pełni | Development provisioning profile automatycznie zawiera entitlement dev‑wariant. `AuthorizationCenter`, `FamilyActivityPicker`, `ManagedSettingsStore`, `DeviceActivityCenter`, ShieldConfiguration + ShieldAction + DeviceActivityMonitor + DeviceActivityReport extensions — **wszystko działa end‑to‑end**. Można robić kompletne user testing. |
| **iOS Simulator** | ⚠️ Tylko częściowo | `requestAuthorization(for: .individual)` wywala `FamilyControlsError Code=2 (invalid account type)`. `FamilyActivityPicker` pokazuje kategorie ale NIE konkretne apki (brak realnego inventory). **W praktyce: testuj na urządzeniu, symulator tylko do UI layout.** (Apple Engineer, thread 682257.) |
| **Ad‑hoc distribution / TestFlight internal testing** | ❌ Nie | Używają distribution provisioning profile, który wymaga zatwierdzonego distribution entitlementu. Archive fails: *„Provisioning profile doesn't include the com.apple.developer.family-controls entitlement."* |
| **TestFlight (internal LUB external)** | ❌ Nie | Quinn Eskimo (thread 735888): *„Is there a way to distribute to testflight without getting approved for the family controls entitlement? **No.** TestFlight uses a distribution provisioning profile, just like the App Store. If you only have access to an entitlement for development, you can't use it in any channel that requires a distribution provisioning profile."* |
| **App Store Connect submit builda** | ❌ Nie | Upload fails. „Family Controls (Distribution)" nie pojawi się pod Additional Capabilities dopóki nie ma approvalu. |
| **Wypełnienie App Store Connect listing bez builda** | ✅ Tak | Itsuki rekomenduje: *„EVERYTHING except for the build are filled in App Store Connect"* przed wysłaniem wniosku — reviewer dostaje dowód realności produktu. |

**Praktyczny wniosek:** możesz zbudować pełny, w pełni działający produkt, zrobić closed beta na swoim telefonie + telefonach znajomych (każdy ich kabel‑podpina i Xcode installuje debug build), zebrać feedback — i **dopiero potem** złożyć wniosek z kompletnymi artefaktami. To prawdopodobnie najbezpieczniejsza ścieżka: minimalizuje ryzyko, że będziesz przerabiał architekturę po rejection.

### Plan B gdy entitlement nigdy nie zostanie zatwierdzony

Dla aplikacji typu „adult self‑control" alternatywy są słabe, ale istnieją: **Focus Filters API** (iOS 16+, bez entitlementu — ale to tylko filtr, nie blokuje otwarcia apki; one sec używa go *dodatkowo*, patrz https://one-sec.app/blog/focus-filters-ios-16/); **Shortcuts Automation** (user‑driven, łatwy do obejścia, nie nadaje się jako standalone produkt); **Network Extension / DNS filter** (osobny managed entitlement, blokuje web nie apki); **sparowanie z hardware** (Brick, Unpluq, Foqos — ale sama logika blokowania i tak używa FamilyControls pod spodem). **Bottom line:** dla prawdziwego blokowania apek jak Opal/one sec/Brick — **musisz** dostać entitlement; alternatywy tylko uzupełniają, nie zastępują.

---

## 7. Kluczowe wymagania App Store Review specyficzne dla tej kategorii

**Guideline 5.5 (MDM)** — technicznie dotyczy MDM nie Screen Time API, ale jego język jest wzorcem commitmentu który Apple oczekuje i w uzasadnieniu i w privacy policy: *„Apps offering MDM services may not sell, use, or disclose to third parties any data for any purpose, and must commit to this in their privacy policy."* (App Store Review Guidelines, last updated February 6, 2026, https://developer.apple.com/app-store/review/guidelines/)

**Guideline 4.10 (Monetizing Built‑In Capabilities)** — literalnie wymienia Screen Time APIs: *„You may not monetize built‑in capabilities provided by the hardware or operating system… or Apple services and technologies, such as Apple Music access, iCloud storage, or Screen Time APIs."* Możesz pobierać subskrypcję za feature'y swojej aplikacji, nie możesz pobierać za sam fakt blokowania.

**Guideline 2.5.1 (Software Requirements)** — *„Apps should use APIs and frameworks for their intended purposes and indicate that integration in their app description."* Obowiązkowo wymień w opisie App Store że aplikacja używa Screen Time API / Family Controls framework.

**Screenshots App Store (2.3.3):** muszą pokazywać aplikację w użyciu — `FamilyActivityPicker`, custom shield, schedule configuration, usage report, a nie sam splash screen. Rejections za „tylko login/marketing screen" są regularne.

**App Privacy details w App Store Connect:** muszą zadeklarować wszystko co app dotyka, łącznie z danymi ze Screen Time API (nawet jeśli zostają on‑device, kategorie typu „App Activity" mogą być istotne — skonsultuj z aktualnym Apple Data Collection guidebook).

**App Review Notes (2.3.1(a)):** dodaj kopię approval emaila od Entitlements team, demo credentials jeśli dotyczy, krok‑po‑kroku przejście flow, wyjaśnienie że to „individual use case iOS 16+".

---

## Wnioski

**Prawdziwą barierą nie jest „czy Apple mnie zatwierdzi" — tylko dyscyplina proceduralna.** W danych publicznych z 2024–2026 brakuje dowodów że solo indie developers są systematycznie odrzucani z powodu braku LLC; Itsuki, Baker_build, alejandror321 i setki innych solo devów dostali approvals. **Realne powody delays** to: (1) niewysłanie wniosków dla extension bundle IDs, (2) „Yes" w pytaniu o data sharing, (3) zbyt ogólne uzasadnienie, (4) duplikaty submissions, (5) zapomnienie że tylko Account Holder może submitować. Każdy z nich jest trywialny do uniknięcia jeśli znasz z góry.

**Model mentalny który działa:** traktuj zatwierdzenie entitlementu jak „privacy audit przez Apple w formie dokumentów". Im bardziej twoja architektura i uzasadnienie wygląda na on‑device, user‑initiated, individual‑authorization, opaque‑tokens, no‑server — tym szybszy approval. Im więcej w języku jest słów „track", „collect", „analytics", „leaderboard", „hide", „monitor employees" — tym pewniejszy reject. Skopiuj ramowanie Opal/Jomo/one sec/ScreenZen z ich App Store listingów i privacy policies — one przeszły zarówno entitlement approval jak i App Review, więc są de facto Apple‑approved templatem językowym.

**Jedna dodatkowa rada dla Polaka składającego wniosek:** wypełnij formularz po angielsku, ale **nie musisz** mieć zarejestrowanej firmy w USA ani rzecznika patentowego ani LLC. Apple honoruje enrollmenty Individual z Polski. Adres URL strony produktu może być na dowolnym hostingu (Framer, Cloudflare Pages, GitHub Pages). Privacy policy może być wygenerowana z generatora (np. TermsFeed z dedykowaną sekcją Screen Time API) — Apple czyta język, nie pedigree kancelarii prawnej.