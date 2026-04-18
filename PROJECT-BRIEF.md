# Projekt: Klon Opala — iOS App Blocker (self-control)

## Co buduję
Natywną aplikację iOS, która jest klonem funkcjonalnym aplikacji 
Opal (https://apps.apple.com/us/app/opal-screen-time-control/id1497465230). 
To self-control tool dla DOROSŁYCH — user sam sobie blokuje 
dostęp do rozpraszających apek (social media, gry) i stron WWW 
na wybrany czas albo według harmonogramu.

NIE jest to parental control. Nie wymaga Family Sharing ani 
dziecięcego konta.

## Stack techniczny
- Swift 6.2
- SwiftUI
- Minimum iOS: 26.0 *(do rewizji — research R1 rekomenduje iOS 18 
  ze względu na ~90% reach vs ~66% na iOS 26 i nienaprawione 
  regresje Screen Time API; decyzja produktowa otwarta)*
- Xcode 26+
- Native Apple frameworks (FamilyControls, ManagedSettings, 
  DeviceActivity, ManagedSettingsUI, ActivityKit, StoreKit 2).
- **Committed third-party dependencies:**
  - `pointfreeco/swift-navigation` (`SwiftUINavigation`) — 
    state-driven navigation (Destination enum na ViewModelu, 
    `@CasePathable`, case-path bindings). Szczegóły: 
    `.claude/guides/navigation/GUIDE.md`.
- Inne third-party dependencies podejmujemy ad-hoc przy 
  konkretnych featureach, na bazie researchy, jawnie jako ADR.
- Brak backendu w MVP (wszystko on-device + App Group).

## Architektura kodu
**Clean Architecture** z MVVM (Presentation) + UseCase (Domain) + 
Repository (Data). SOLID / KISS / DRY — żadnej warstwy ani 
abstrakcji bez konkretnego powodu. ViewModele używają `@Observable` 
i NIE importują SwiftUI (testowalność). Navigation state-driven 
przez `Destination` enum na ViewModelu.

Szczegóły: `.claude/guides/architecture/GUIDE.md` oraz 
`.claude/guides/navigation/GUIDE.md`.

## Architektura Xcode — targety
Projekt wieloTargetowy:

1. **Main App** (SwiftUI) — onboarding, picker, sesje, 
   statystyki, ustawienia.
2. **DeviceActivityMonitor extension** — reakcja na start/
   koniec harmonogramu, progi eventów.
3. **ShieldConfigurationExtension** — wygląd shielda.
4. **ShieldActionExtension** — obsługa kliknięć na shieldzie 
   (deep link do main app dla bogatszego UX).
5. **DeviceActivityReport extension** (opcjonalnie, decyzja 
   po R4) — statystyki użycia.

Wszystkie targety w App Group `group.com.<mojadomena>.<nazwaapki>` 
do dzielenia danych.

**Placeholdery do uzupełnienia przed setupem**: nazwa apki, 
bundle ID, App Group identifier, Team ID.

## Feature'y MVP
1. Onboarding + autoryzacja Screen Time (individual 
   authorization).
2. Wybór apek/kategorii/stron WWW przez FamilyActivityPicker.
3. "Quick session" — natychmiastowa blokada na wybrany czas 
   (15 / 30 / 60 / 90 min).
4. Harmonogramy — cykliczne blokady (np. 9–17 w dni robocze).
5. Własny shield z brandingiem i podstawowymi przyciskami.
6. Podstawowa gamifikacja — liczenie ukończonych sesji, streak.
7. Lokalne powiadomienia o końcu sesji.

## Feature'y post-MVP
- Deep Focus — opóźnienia, wpisywanie zdania, utrudnione 
  odblokowanie (techniki z R6).
- Statystyki użycia (DeviceActivityReport — po R4).
- Live Activity z timerem sesji (po R9).
- Subskrypcja, free vs paid tier (po R10).
- Accountability partner (backend, daleka przyszłość).

## Twarde ograniczenia, o których Claude MUSI pamiętać
1. **Opaque tokens** — `ApplicationToken`, `WebDomainToken`, 
   `ActivityCategoryToken` są nieprzezroczyste. Apple NIE 
   ujawnia nazw ani ikon apek wybranych przez usera. Do 
   wyświetlenia służy SwiftUI `Label(token)`. Nie próbuj 
   ich deserializować ani mapować do stringów.
2. **Entitlement wymagany** — `com.apple.developer.family-controls` 
   musi być złożony i zatwierdzony przez Apple. Bez niego 
   API nie działa na realnym device. Development bez 
   entitlementu tylko w ograniczonym zakresie.
3. **Extensions to osobne procesy** — main app i extensions 
   komunikują się przez App Group. Bez App Group persystencja 
   tokenów NIE przetrwa.
4. **Problem "unknown token"** — iOS czasem podaje extensionowi 
   token, którego nigdy wcześniej nie widział. Kod shield 
   extensionów MUSI mieć fallback (domyślny shield, log błędu).
5. **Brak dostępu do surowych statystyk** — DeviceActivityReport 
   renderuje dane w sandboxowanym extension, dane NIE MOGĄ 
   go opuścić. Logika "zapisz minuty użycia do UserDefaults" 
   NIE zadziała bezpośrednio.
6. **Shield ma ograniczenia** — ShieldConfiguration NIE obsługuje 
   custom SwiftUI views, animacji, pól tekstowych, obrazków 
   z sieci. Bogaty UX (wpisywanie zdania, odliczanie) robi 
   się przez deep link do main app.

## Dokumentacja projektu
Wiedza projektowa jest podzielona na kilka miejsc i Claude 
ma OBOWIĄZEK z nich korzystać:

### `.claude/guides/` — guidy wewnętrzne
Katalog `.claude/guides/README.md` zawiera indeks guidów. 
MUSZĄ być konsultowane za każdym razem gdy piszesz kod, 
podejmujesz decyzje architektoniczne lub strukturyzujesz 
projekt. Na starcie każdej sesji / nowego zadania otwórz 
`.claude/guides/README.md` i zapoznaj się z odpowiednimi 
guidami przed rozpoczęciem pracy.

Obecnie:
- `architecture/GUIDE.md` — Clean Architecture, MVVM, 
  UseCase, Repository, DI, SOLID
- `navigation/GUIDE.md` — swift-navigation, Destination 
  enum, sheets / alerts / NavigationStack
- `xcodegen/GUIDE.md` — modyfikacja `project.yml`
- `xcodebuild-mcp/GUIDE.md` — build / test przez 
  XcodeBuildMCP
- `create-new-guide/GUIDE.md` — jak pisać kolejne guide'y

**Plugin skills** (uzupełniają guide'y):
- `swift-concurrency:swift-concurrency` — async/await, 
  actors, Sendable, data races
- `swiftui-expert:swiftui-expert-skill` — best practices 
  SwiftUI, state management, iOS 26 Liquid Glass

### `.claude/research/` — researche R1–R10 (+ dodatkowe)
Głębokie researche pokrywające kluczowe obszary. Autorytatywny 
indeks z TL;DR każdego: `.claude/research/README.md`.

Mapowanie R1–R10:
- R1: Stan Screen Time API w iOS 26 (+ min. target)
- R2: FamilyControls entitlement w 2026
- R3: Open-source klony i repo referencyjne (Foqos i reszta)
- R4: DeviceActivityReport — statystyki, ograniczenia
- R5: Shield UI — customizacja, deep linki, rich UX
- R6: Anti-bypass / Deep Focus techniques
- R7: App Groups, komunikacja main ↔ extensions, persystencja
- R8: Znane bugi Screen Time API i workaroundy (2026)
- R9: Live Activities i powiadomienia dla sesji focus
- R10: Monetyzacja (StoreKit 2, paywall, tiery)

Dodatkowe (poza R1–R10): modele AI z HuggingFace pod iOS, 
apki 2025 / rynek — pełne TL;DR w `.claude/research/README.md`.

Gdy pracujesz nad czymś co pokrywa research, przeczytaj 
odpowiedni plik ZANIM zaczniesz pisać kod. Nie zgaduj API 
Screen Time i nie wymyślaj rozwiązań które badania już 
wyjaśniły.

## Jak pracujemy (kolejność)
1. Setup projektu Xcode z targetami + App Group.
2. Autoryzacja Screen Time + FamilyActivityPicker.
3. "Quick session" end-to-end (shield się nakłada i zdejmuje).
4. Harmonogramy.
5. Shield UI + deep linki.
6. MVP done → iteracje post-MVP.

## Zasady dla Claude
- **Zawsze konsultuj `.claude/guides/` i `.claude/research/`** 
  przed pisaniem kodu. To nie jest opcjonalne.
- Pisz Swift 6.2 idiomatycznie, SwiftUI first, async/await 
  i actors jako domyślny model współbieżności.
- W kodzie extensionów defensywnie: guard'y, fallbacki, 
  obsługa unknown tokens, brak assertów, logi przez os.Logger.
- Każdy plik ma nagłówek wyjaśniający rolę w architekturze.
- Struktura folderów zgodna z guidami z `.claude/guides/`.
- Pytaj zanim zaczniesz kodować jeśli coś jest niejasne — 
  zwłaszcza decyzje architektoniczne (persystencja, struktura 
  modeli, nazewnictwo App Group, min. target).
- Nie zgaduj API Screen Time. Jeśli nie jesteś pewien szczegółu 
  (np. cykl życia DeviceActivityMonitor), poproś o odpowiedni 
  fragment researchu zamiast zmyślać.
- Decyzje o third-party dependencies podejmuj jawnie — zapisz 
  jako decision/ADR z uzasadnieniem, nie dorzucaj ich po cichu.
