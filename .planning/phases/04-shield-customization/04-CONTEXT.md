# Phase 4: Shield Customization - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Zablokowane aplikacje (via quick session z Phase 3 lub przyszły schedule z Phase 5) wyświetlają markowy shield DeluluDetox w miejsce oryginalnej apki. Shield ma brand (violet blur, SF Symbol), sarkastyczny copy w tonie projektu, oraz dwa guziki: primary deep link do main app → istniejącego countdown screen z Phase 3, secondary "Zamknij" = Apple default dismiss. Gdy extension dostanie token bez aktywnego kontekstu sesji — branded fallback shield z generic copy (bez specjalnego deep linku do countdown). ShieldActionExtension obsługuje primary action i otwiera main app przez custom URL scheme `deluludetox://session/active`.

**In scope:**
- `ShieldConfigurationExtension` produkujący `ShieldConfiguration` dla apps / webDomains / categories / activities
- Branded visual: blur background + violet tint (`#7C3AED`) + `hand.raised.fill` SF Symbol
- Sarkastyczno-ostry title/subtitle copy (aligned z Phase 3 D-12)
- Dwa guziki: primary "Zobacz ile zostało" + secondary Apple default dismiss
- Unknown-token fallback branch (sam wizual, generic copy, deep link → root home)
- `ShieldActionExtension` obsługa primary action → `openApp(URL)` z custom URL scheme
- Main app URL scheme rejestracja + handler na root routerze → `Destination.countdown` (z Phase 3)
- Fallback UX w main app gdy deep link przychodzi bez aktywnej sesji (success screen jeśli właśnie zakończona, inaczej root home)

**Out of scope (inne fazy lub post-MVP):**
- Shield dla Phase 5 schedules — ten sam design się nakłada automatycznie (ManagedSettings agnostic wrt source), decyzje per-schedule zostaną w Phase 5 (zgodnie z "Claude's Discretion")
- Custom logo / maskotka DeluluDetox — SF Symbol wystarcza MVP, custom asset to późniejszy design pass
- Universal links / AASA file — custom URL scheme wystarcza on-device MVP
- Shield animacje / custom SwiftUI views — zablokowane przez Shield API
- Analityka / logi z extension — post-MVP (deferred)
- Live Activity / Dynamic Island — post-MVP LAC-01/02
- Emergency Pass / "1 free break" — post-MVP gamification
- Per-app różne shieldy (opaque tokens i tak nie pozwalają)

</domain>

<decisions>
## Implementation Decisions

### Visual Identity (SHL-01)
- **D-01:** Tło = blur overlay nad oryginalną apką. `ShieldConfiguration.backgroundBlurStyle` ustawione na native UIBlurEffect.Style (dokładny styl — `.systemThickMaterialDark` lub analogiczny — to Claude's Discretion), z `backgroundColor` jako violet `#7C3AED` z niskim alpha (~0.6–0.8) nałożonym na blur. Apple-native wygląd + brand tint.
- **D-02:** Ikona = SF Symbol `hand.raised.fill` w kolorze białym, wyrenderowana do `UIImage` i przekazana jako `ShieldConfiguration.icon`. Zero custom assetów w MVP.
- **D-03:** Title copy = sarkastyczno-ostry ton. Draft kierunku: `"Serio?"` / `"Dopiero co sam sobie to zablokowałeś"`. Subtitle w podobnym tonie, np. `"Jeszcze X min zanim znowu będziesz mógł scrollować"`. Dokładne stringi drafty w execute phase, muszą przejść sanity check przeciw App Store Guideline 5.5 (research §D — sarkastyczny, ale nie manipulacyjny / guilt-tripping).
- **D-04:** Dynamiczny remaining time w subtitle — PREFEROWANY jeśli Shield extension może w rozsądny sposób odczytać `plannedEndAt` z `active_session.json` w czasie renderowania. Jeśli race/cold-start go nie wykona — subtitle degraduje do statycznego sarkazmu bez liczby minut. Claude decyduje o szczegółach w plan/execute; fallback musi być wbudowany.

### Button Configuration (SHL-03)
- **D-05:** Dwa guziki: **primary** `ShieldConfiguration.primaryButtonLabel` = "Zobacz ile zostało" (miększy sarkazm — zachęca do kliknięcia, sam ostry ton jest na title/subtitle). Primary background = violet `#7C3AED` (brand accent, highly visible). **Secondary** = standard Apple dismiss (`secondaryButtonLabel` nil lub Apple default "Zamknij") — returnuje do home screen bez deep linku.
- **D-06:** Primary button triggeruje `ShieldActionExtension.handle(action:for:completionHandler:)` z `.primaryButtonPressed`. Extension wywołuje `context.openApp(URL)` z custom URL scheme (D-08), po czym `completionHandler(.close)`.
- **D-07:** Secondary (dismiss) close handler — `completionHandler(.close)` bez otwierania apki. Apple automatycznie wraca userowi na home screen.

### Deep Link (SHL-04)
- **D-08:** Custom URL scheme zarejestrowany w `project.yml` (XcodeGen) dla main app target: `deluludetox://` z path `session/active`. Pełny URL: `deluludetox://session/active`. Zero konfiguracji AASA / universal links w MVP.
- **D-09:** Main app handler na root `AppRootViewModel` (z Phase 1): odbiera deep link przez SwiftUI `.onOpenURL(perform:)` na root View, parsuje host/path, dispatchuje intent do root VM. Dla `session/active` root VM ustawia `Destination.countdown(CountdownViewModel(...))` (swift-navigation, push navigation) — reuses ekran z Phase 3.
- **D-10:** Fallback routing (deep link bez aktywnej sesji):
  - Jeśli `active_session.json` istnieje i `plannedEndAt > now` → Destination.countdown (normalny case).
  - Jeśli aktywna sesja właśnie się zakończyła (outcome = .completed, success screen z Phase 3 jeszcze nie pokazany) → pokaż success screen.
  - Inaczej (brak sesji, broken_by_revoke, cancelled_by_user już widziany) → root home bez push, opcjonalny toast "Nic aktualnie nie blokujesz" (Claude's Discretion na copy/forma).

### Unknown-Token Fallback (SHL-02)
- **D-11:** Detection: ShieldConfigurationExtension na każdym renderze czyta `active_session.json` z App Group `group.com.kksw.DeluluDetox`. Jeśli plik nie istnieje, jest pusty, lub jego parse się sypie → branch fallback. Nie parsuje `blocklists.json` — mniejsze zużycie pamięci (6 MB limit), wystarczająca detekcja race'ów z zimnym startem i resztkowych tokenów po usunięciu sesji.
- **D-12:** Fallback visual = TEN SAM co normalny shield (blur + violet tint + `hand.raised.fill` + dwa guziki). Zachowanie brand consistency. Różnica wyłącznie w copy: title = `"Zablokowane"` (neutralny), subtitle = `"Zamknij i zrób coś mądrzejszego"` (sarkazm utrzymany ale bez referencji do sesji).
- **D-13:** Fallback primary button copy = `"Otwórz DeluluDetox"` (nie "Zobacz ile zostało" bo nie ma co pokazywać). Deep link URL = `deluludetox://` (root) zamiast `deluludetox://session/active`. Main app URL handler odkrywa że nie ma path → root home (spójne z D-10 branch "brak sesji").

### Extension Integration
- **D-14:** ShieldConfigurationExtension pokrywa wszystkie cztery `configuration(shielding:)` overrides: applications, webDomains, activityCategories, activities. Każdy zwraca ten sam `ShieldConfiguration` (MVP: nie różnicujemy source — ten sam design dla apps, websites i categories). Kod dzielony przez prywatną `buildShieldConfiguration(context:)` helperkę.
- **D-15:** ShieldActionExtension pokrywa wszystkie cztery odpowiadające overrides (action dla apps/webDomains/categories/activities), wszystkie delegują do wspólnej `handleAction(_:for:completionHandler:)`. Primary action → open URL. Secondary → close. Unknown action → close (bezpieczny default).
- **D-16:** Obie extensions respektują zasadę Phase 3 D-03: **read-only** wobec App Group plików. Shield extensions NIE modyfikują `active_session.json`, `sessions.json`, ani `blocklists.json`. Czysto czytają.
- **D-17:** RAM budget dla Shield extensions = ten sam co DAM (zakładany 6 MB ceiling — PROJECT.md Hard Constraints). Zero third-party SDKs. Imports tylko Foundation + UIKit (dla `UIImage` z SF Symbol) + ManagedSettings + ManagedSettingsUI.

### Claude's Discretion
- Dokładny styl blur (`.systemThickMaterialDark` vs `.regular` vs inny) — dobrać w execute po wizualnym teście.
- Alpha violet tintu (0.6 vs 0.8) — do wyczucia w execute.
- Point size / weight SF Symbola `hand.raised.fill` — dobrać tak żeby był czytelny na średnim device size.
- Dokładne sarkastyczne stringi (title, subtitle, primary button copy) — draft w execute, multiple warianty do review, finalny wybór po "czy to brzmi jak DeluluDetox, nie jak Twitter burn".
- Mechanism wyboru czy `plannedEndAt` nadaje się do subtitle (D-04) — np. in-memory cache z koroną poza 1 s, lub simple try/catch na każdym renderze.
- Dokładna forma toastu / UI gdy deep link ląduje bez aktywnej sesji (D-10) — toast vs inline baner vs silent route.
- Color dla secondary button (primary violet jest jasny; secondary może być Apple default system blue lub neutral gray — do wyboru po visual test).
- Czy `ShieldConfiguration` secondary button jest explicit (z naszym "Zamknij" copy) czy zostawiamy jako Apple default (nil) — Apple default jest niezawodny, nasze copy daje spójność brandu. Default: explicit "Zamknij" w PL lokalizacji.
- Strategia lokalizacji copy (hard-coded PL w MVP vs `.strings` file + en fallback) — consistent z Phase 1-3 podejściem.

### Folded Todos
- None — no pending todos matched Phase 4.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project constraints
- `.planning/PROJECT.md` §Hard Constraints from Research — Shield API limits (8-field struct, no SwiftUI/animations/network images), unknown token problem (must have fallback), DAM-class RAM limit, no third-party SDKs in extensions
- `.planning/PROJECT.md` §Multi-Target Structure — `ShieldConfigurationExtension` i `ShieldActionExtension` jako separate targets dzielące `group.com.kksw.DeluluDetox` App Group
- `.planning/REQUIREMENTS.md` §Shield — SHL-01/02/03/04 acceptance criteria
- `.planning/ROADMAP.md` §Phase 4 — goal + success criteria

### Shield API / Screen Time
- `.claude/research/compass_artifact_wf-280372a6-1bd9-4044-95d9-1d65f1d292dc_text_markdown.md` — main-app ↔ extensions communication przez App Group, atomic writes, żelazna zasada sole-writer (main app), extension read-only; token instability; 6 MB RAM w extension
- `.claude/research/compass_artifact_wf-dee368a6-dad8-4281-9c56-dceec8896003_text_markdown.md` — `family-controls` entitlement, `.individual`, per-bundle-ID approval (wpływa na możliwość testowania shield extension na device)
- `.claude/research/compass_artifact_wf-9f1fb5f8-b639-4ece-808e-76cc0b222990_text_markdown.md` — Foqos jako production-grade reference implementation ShieldConfiguration + ShieldAction; konkretne wzorce kodu

### Anti-bypass / ethics
- `.claude/research/compass_artifact_wf-1862c287-6b03-4a01-a2e4-e53e8d7082b8_text_markdown.md` §D — App Store Guideline 5.5, sarkastyczny vs manipulacyjny ton, co jest OK a co blokuje aprobatę

### Project architecture
- `.claude/guides/architecture/GUIDE.md` — MVVM + UseCase + Repository, `@Observable` VMs bez SwiftUI, SOLID/KISS/DRY
- `.claude/guides/navigation/GUIDE.md` — `swift-navigation`, `Destination?` enum, `@CasePathable`, case-path bindings, handling `.onOpenURL` na root view
- `.claude/guides/xcodegen/GUIDE.md` — dodanie URL scheme do Info.plist via `project.yml`, konfiguracja extension targets, App Group entitlement
- `.claude/guides/xcodebuild-mcp/GUIDE.md` — build/run/test tooling

### Prior phase context
- `.planning/phases/01-foundation-onboarding/01-CONTEXT.md` — electric violet `#7C3AED` accent color, scaffolding extensions (ShieldConfigurationExtension + ShieldActionExtension exist as empty targets)
- `.planning/phases/02-app-selection/02-CONTEXT.md` — App Group file bus, atomic writes, sole-writer rule; extensions są read-only
- `.planning/phases/03-quick-sessions/03-CONTEXT.md` — `active_session.json` schema (D-13/D-14), `CountdownViewModel` + countdown screen via `Destination.countdown` (D-16), success screen lifecycle (D-08/D-19), sarkastyczno-playful tone rule (D-12) — Phase 4 D-03 escaluje ten sam ton do "ostry" tylko na shieldzie

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Greenfield dla Phase 4** — scaffolding extensions z Phase 1 (`ShieldConfigurationExtension`, `ShieldActionExtension`) istnieje jako pusty target z XcodeGen, ale bez logiki. Phase 4 dopisuje ciało. Main app ma już `AppRootViewModel` i swift-navigation routing z Phase 1.
- **Electric violet `#7C3AED`** — zdefiniowany bezpośrednio przez RGB init w shared code z Phase 1 (Phase 01 decision: direct RGB zamiast asset catalog, fix 56b3b42). Shield extension może wywołać ten sam RGB init inline (ShieldConfiguration używa `UIColor`, nie SwiftUI `Color`) — zero nowej konfiguracji.
- **`CountdownViewModel` + Countdown screen** z Phase 3 (D-16) — deep link w Phase 4 podłącza się do istniejącego `Destination.countdown` case na root VM. Zero nowych ekranów w Phase 4.
- **`active_session.json`** z Phase 3 (D-13) — Shield extension czyta ten plik; wystarczy ścieżka i `SessionRecord` Codable struct (znana z Phase 3).

### Established Patterns (from prior phases + project guides)
- Clean Architecture: Shield extension *nie* ma UseCase layer (cienka warstwa renderująca), ale helpery do czytania `active_session.json` mogą iść przez wspólny `SessionReaderProtocol` w SPM module współdzielonym między main app a extensions. Konsystentne z Phase 2 D-02 (Repository per domain).
- `@Observable` VMs bez SwiftUI — dotyczy main app; extension code jest klasowy (`ShieldConfigurationDataSource`, `ShieldActionDelegate`).
- `swift-navigation` push flow — deep link wchodzi przez `.onOpenURL`, root VM ustawia `Destination?` (ścieżka Phase 1 navigation graph rozbudowana o `.countdown` case z Phase 3).
- App Group file bus, atomic writes, main app sole writer — zasada z Phase 2/3 jest utrzymana (D-16 tutaj).

### Integration Points
- **`ShieldConfiguration` API** — klasa `ShieldConfigurationDataSource` dziedziczy z `ShieldConfigurationDataSource` (ManagedSettingsUI framework). Override cztery `configuration(shielding:)` metody. Każda zwraca `ShieldConfiguration(backgroundBlurStyle:backgroundColor:icon:title:subtitle:primaryButtonLabel:primaryButtonBackgroundColor:secondaryButtonLabel:)`.
- **`ShieldActionDelegate` API** — klasa `ShieldActionHandler` dziedziczy z `ShieldActionDelegate` (ManagedSettingsUI). Override cztery `handle(action:for:completionHandler:)` metody. Primary action → `completionHandler(.defer)` lub `.close` po wywołaniu `context.openApp(URL)` (Apple doc clarification do research'u — w nowym iOS extension wywołuje `openApp` bezpośrednio).
- **URL scheme** — rejestracja w `project.yml` (XcodeGen) pod main app target: `CFBundleURLTypes` z `CFBundleURLSchemes: [deluludetox]`. Handler na `App` struct: `.onOpenURL { url in rootVM.handleDeepLink(url) }`.
- **App Group file bus** — Shield extensions czytają `active_session.json` przez wspólny helper (preferowany SPM `SessionPersistence` module z Phase 3, re-used as dependency extensions' targets).
- **`ShieldConfiguration.icon`** — wymaga `UIImage`. SF Symbol `hand.raised.fill` renderowany przez `UIImage(systemName: "hand.raised.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold))`.

</code_context>

<specifics>
## Specific Ideas

- **Foqos** jako code reference dla ShieldConfiguration + ShieldAction patterns — MIT-licensed, production-grade iOS Screen Time app (research R-Foqos).
- **Sarkastyczny ton na shieldzie jest celowo ostrzejszy niż w reszcie appki** (user explicit choice) — shield to moment pokusy, wymaga mocniejszego sygnału. CTA na guziku i copy w samej appce (po kliknięciu deep linku) wracają do łagodniejszego sarkazmu — żeby user nie poczuł się atakowany jak już posłuchał i otworzył DeluluDetox.
- **Brand consistency nawet w fallbacku** — wybrana opcja "branded shield z generic copy" ponad Apple default. User chce żeby DeluluDetox zawsze wyglądał jak DeluluDetox, nawet w edge case'ie.
- **Cost-benefit tradeoff na detekcji unknown tokenów**: prostsza ścieżka (tylko check `active_session.json`) zamiast parsowania `blocklists.json`. Świadoma zgoda na false positives w rzadkich race'ach kosztem niższej złożoności extension kodu i RAM.

</specifics>

<deferred>
## Deferred Ideas

- **Shield behavior po końcu sesji** — zachowanie dokładnego momentu gdy sesja się kończy a shield wciąż jest widoczny; należy do Phase 3 end sequence (D-08: clear ManagedSettings shield) i nie wymaga osobnej decyzji Phase 4.
- **Per-source shield różnicowanie (quick session vs schedule)** — ten sam design dla wszystkich sources w MVP; Phase 5 może opcjonalnie dodać subtle różnicę (np. `[Schedule]` prefix w subtitle) w ramach swojej "Claude's Discretion".
- **Analityka / logi z Shield extension** — deep link klikany, fallback hit, unknown token — post-MVP. Żadnej persistence z extension poza głównym flow. Jeśli w przyszłości potrzebne — osobny App Group file, namespace'd marker pattern analogiczny do Phase 3 D-03.
- **Custom logo / maskotka** zamiast SF Symbol — przyszły design pass. SF Symbol wystarcza MVP.
- **Universal Links (AASA file)** — post-MVP. Custom URL scheme działa fully on-device.
- **Lokalizacja copy (en fallback + inne języki)** — aligned z Phase 1-3 decyzją; MVP PL hard-coded lub PL-only `.strings` (zgodnie z tym co wybrano w Phase 1).
- **Haptic feedback / sound na shield actions** — Shield API raczej nie wspiera, plus nie w MVP scope.
- **"Emergency pass" / "1 free break per day"** — post-MVP gamification, aligned z Phase 3 deferred list.
- **Dynamic adjustments copy na podstawie outcome history** ("to już trzeci raz dziś próbujesz otworzyć Instagrama") — post-MVP, wymaga persistentego stanu w extension.

</deferred>

---

*Phase: 04-shield-customization*
*Context gathered: 2026-04-18*
