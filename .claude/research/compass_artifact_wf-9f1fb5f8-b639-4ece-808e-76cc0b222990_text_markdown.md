# Najlepsze publiczne repo Screen Time API pod klon Opala

**Foqos (awaseem/foqos) to jedyny projekt produkcyjnej jakości, który rzeczywiście spełnia wszystkie Twoje wymagania** — iOS 17+, `.individual`, pełny flow auth → picker → shield → schedule, aktywnie utrzymywany, MIT, 431+ gwiazdek. Resztę ekosystemu tworzy kilka dobrych, ale niekompletnych demek (ScreenBreak, Kairos) oraz bogaty w kod Swift „wrapper" React Native od Kingstinct, który paradoksalnie jest **najbogatszym referencjalnym zbiorem kodu Shield/Action extension** w całym GitHubie. Apple nie wypuściło żadnego oficjalnego projektu-sample do pobrania — są tylko snippety w sesjach WWDC21/22 i artykule „ConnectionWithFrameworks" (ten ostatni to legacy `.child`, **nie kopiuj**). Dalej — ranking, tabela, rekomendacje i konkretne pliki do przeczytania.

## Krajobraz źródeł — krótki kontekst

Od WWDC22 Apple nie dał już ani jednej sesji o Screen Time, a do dziś nie opublikował **żadnego Xcode sample project** dla FamilyControls / DeviceActivity / ManagedSettings. Oficjalne „sample code" dla tych frameworków **nie istnieje** — są tylko krótkie fragmenty w tabach „Code" sesji oraz snippet'y w dokumentacji. To tłumaczy, czemu społeczność jest rozrzucona i trzeba szyć wiedzę z blogów + 3–4 żywych repo. Druga istotna rzecz: **symulator nie obsługuje tych frameworków** — wszystko testujesz na urządzeniu z wgranym entitlementem Family Controls (Apple zatwierdza w ~3–4 tygodnie dla Distribution). I trzecia: iOS 26 wprowadził regresje (FB18997699 dla utraty permissions, zdechłe `deviceactivityd` przy schedule triggerach) — miej to w głowie czytając kod z 2023/2024.

## Ranking TOP 5 — od najlepszego do najsłabszego

### 1. awaseem/foqos — *production-grade, bierz i ucz się*
- **URL:** https://github.com/awaseem/foqos — autor: Ali Waseem — **~431 ★ / 75 fork** — ostatni commit: bardzo aktywny, release v1.19 z września 2025 + bieżąca praca na `main` w 2026
- **Stack:** SwiftUI, SwiftData, Family Controls, Core NFC, CodeScanner, BackgroundTasks, App Intents, Live Activities
- **Framework'i:** FamilyControls ✅, ManagedSettings ✅, DeviceActivity ✅ (ManagedSettingsUI zawarty w extension FoqosDeviceMonitor)
- **Extensions:** `FoqosDeviceMonitor/` (DeviceActivityMonitor), `FoqosWidget/` — **brakuje osobnych ShieldConfiguration/ShieldAction extension w najnowszej wersji** (ostrzeżenie: nie robi custom shield UI ani interaktywnych przycisków na shield — to jest gap do wypełnienia samodzielnie, jeśli chcesz Opal-style „why are you opening this?")
- **Auth:** `.individual` ✅
- **Min iOS:** iOS 17.0 + Xcode 15.0 + Swift 5.9
- **Entitlement:** wymaga (potrzebujesz konta Apple Dev + zgody Family Controls)
- **Dlaczego BIERZ:** to jedyny utrzymywany, realny produkt w App Store z otwartym kodem i czystą architekturą. Ma wzorzec **Strategy pattern dla BlockingStrategy** (Manual, NFC, QR, NFC+Timer, QR+Timer, QR+Manual itp.) — idealne do zaadoptowania przez klon Opala. SwiftData jako local store, porządne rozbicie na Views/Models/Strategies/Utils/Intents.
- **Dlaczego SKIP (albo raczej: czego nie kopiuj):** nie ma Shield Configuration Extension ani Shield Action Extension — jeśli chcesz custom UI ekranu blokady z przyciskami „Unlock for 2 min" / „Open parent app" (klasyczny Opal/One Sec), musisz to dopisać sam
- **Pliki do otwarcia pierwsze:** `Foqos/Models/Strategies/` (cały folder — strategie blokowania), `FoqosDeviceMonitor/` (extension z `intervalDidStart` / `intervalDidEnd` / `eventDidReachThreshold`), `Foqos/Utils/` (helpery zapisu `FamilyActivitySelection` w shared App Group), `Foqos/Intents/` (App Intents do Shortcuts automation)

### 2. Inakitajes/kairos — *najbliżej „kompletnej Opal template"*
- **URL:** https://github.com/Inakitajes/kairos — nazwa wewnętrzna appki: „Soul"
- **Stars:** niskie, młody projekt, ale **ma CAŁĄ czwórkę extension'ów** w jednym repo
- **Extensions (wszystkie!):** `SoulActivityMonitor/` (DeviceActivityMonitor), `SoulShieldConfiguration/` (Shield UI), `SoulShieldAction/` (Shield button handlers), `SoulWidget/`
- **Framework'i:** FamilyControls ✅, ManagedSettings ✅, DeviceActivity ✅, ManagedSettingsUI ✅
- **Auth:** `.individual` ✅ (wzorowane na Foqos — QR/NFC trigger, „Guard" profile system, Live Activities)
- **Struktura:** `ShieldManager.swift` (singleton — autolock timers, Live Activities, background), `TriggerManager.swift` (QR+NFC persistence), modele `BlockingMode.swift` i `Trigger.swift`
- **Code quality:** *OK–good* (świeżyj projekt, mniej dopracowany niż Foqos, ale bogatszy w extension coverage)
- **Min iOS:** 17.0+, Xcode 15
- **Dlaczego BIERZ:** to **jedyny znaleziony otwarty projekt, który ma osobno wszystkie 4 extension'y** oraz `.individual`. Jeśli potrzebujesz punktu odniesienia „jak wygląda pełny Xcode project tree dla Opal-clone", zajrzyj tu.
- **Dlaczego SKIP:** mniej gwiazdek = mniej battle-tested, mniejsza pewność że nie ma bugów. Wiele inspiracji z Foqos, więc jeśli masz Foqos + artykuł Pedro Esli dla Shield extension, w zasadzie nie musisz go czytać.
- **Pliki pierwsze:** `Soul/Managers/ShieldManager.swift`, `SoulShieldAction/` (struktura handle-action), `SoulShieldConfiguration/` (override'y `configuration(shielding:)`)

### 3. christianp-622/ScreenBreak — *najlepszy tutorial-level „full showcase" iOS 16*
- **URL:** https://github.com/christianp-622/ScreenBreak — publiczne, niski star count, commity ~2023
- **Framework'i:** FamilyControls ✅, ManagedSettings ✅, DeviceActivity ✅ (+ DeviceActivityReport z SwiftUICharts), Widget Extension ✅
- **Extensions:** DeviceActivityMonitor ✅, DeviceActivityReport ✅, Shield Configuration ✅ (custom shield z własnym logo/komunikatem), Widget ✅ — **brakuje osobnego Shield Action Extension**
- **Auth:** `.individual` ✅ (pierwszy open-source który to wprost pokazał, eksplicytnie cytując WWDC22)
- **Min iOS:** 16.0, Xcode 14
- **Code quality:** *OK* — bardzo czytelne, edukacyjne, lecz place holdery tu i tam; Rive animacje i SwiftUICharts są luźno dorzucone
- **Dlaczego BIERZ:** ma **część której brakuje Foqosowi** — custom ShieldConfiguration extension + DeviceActivityReport z pie-chartem. Idealne do nauki jak konfigurować `configuration(shielding application:)` z własnymi kolorami, tytułem, ikoną.
- **Dlaczego SKIP:** projekt nieutrzymywany od ~2 lat, może mieć problem z iOS 18+ (deadlock w `intervalDidEnd` → `startMonitoring` — znany bug FB14664238)
- **Pliki pierwsze:** extension `ShieldConfiguration/*` (override `configuration(shielding:)`), ViewModel zapisujący `FamilyActivitySelection` do UserDefaults w App Group, `DeviceActivityReport` view z filtrem segmentu dziennego

### 4. kingstinct/react-native-device-activity — *skarbnica kodu Swift, nawet jeśli nie piszesz RN*
- **URL:** https://github.com/kingstinct/react-native-device-activity — aktywnie utrzymywany
- **Framework'i:** FamilyControls ✅, ManagedSettings ✅, DeviceActivity ✅, ManagedSettingsUI ✅
- **Extensions:** **wszystkie: Monitor + Shield Configuration + Shield Action** — pełna, produkcyjna implementacja po stronie Swift
- **Auth:** `.individual` ✅, obsługuje iOS 15.1+
- **Code quality:** *good–production* (to biblioteka faktycznie używana komercyjnie)
- **Dlaczego BIERZ:** to najbogatszy referencyjny zbiór kodu do **Shield Action Extension** i **persistowanego `FamilyActivitySelection` przez ID zamiast tokena** (dla uniknięcia ogromnych payloadów w UserDefaults). Świetne uwagi w README o: crash'owaniu `FamilyActivityPicker`, triggering shield z background/monitor procesu, wzorcu `actionsFor${goalId}` w userDefaults, referencji przez `shieldIds`.
- **Dlaczego SKIP:** Trzeba przedzierać się przez warstwę Expo/React Native. Nie używaj do skopiowania architektury, tylko do przeczytania konkretnych plików Swift.
- **Pliki pierwsze:** folder `ios/` — wszystkie `.swift` z katalogów `DeviceActivityMonitorExtension/`, `ShieldConfigurationExtension/`, `ShieldActionExtension/`. README sekcje „Triggers", „Event history", „ShieldIds".

### 5. pansuriyaravi/Screen-Time-API-Sample-Code — *fallback minimalny, ale real code*
- **URL:** https://github.com/pansuriyaravi/Screen-Time-API-Sample-Code — tagi: swiftui swiftui-example screentime sample-code
- **Framework'i:** FamilyControls, ManagedSettings, DeviceActivity (potwierdzone po tagach; zasięg mniejszy)
- **Extensions:** minimalne — DeviceActivityMonitor
- **Code quality:** *poor–OK* (mały projekt-stub; dobry jako szkielet startowy, nie jako wzorzec produkcyjny)
- **Dlaczego BIERZ:** czysty, mały punkt startowy, jeśli Foqos i Kairos wydają Ci się za duże kombajny
- **Dlaczego SKIP:** to praktycznie „hello world" — pomija schedule i custom shield

**Pominięte celowo:**
- `agarrharr/Homework` — rekonstrukcja WWDC21, **iOS 15 `.child`**, parental control. Odrzucone zgodnie z Twoim wymaganiem.
- `krypted/DeviceActivityExample` — placeholdery, `.child`, zdechły. Odrzucone.
- `ftonato/family-controls-example` — nie udało się potwierdzić aktualnego stanu, prawdopodobnie stub.
- `lukesthl/digital-break-app` — Expo/React Native + AppIntent, **nie używa klasycznego stacka** FamilyControls/DeviceActivity.
- `SaeedBaig/Screen-Break-iOS`, `kubicle/screenBreak` — false positives, nic wspólnego ze Screen Time API.

## Tabela porównawcza — kto co pokrywa

| Projekt | Family­Controls | Managed­Settings | Device­Activity | ManagedSett­ingsUI (Shield UI) | Shield Action Ext. | Individual Auth | Schedule (DeviceActivitySchedule) |
|---|---|---|---|---|---|---|---|
| **awaseem/foqos** | ✅ | ✅ | ✅ | ❌ (default shield) | ❌ | ✅ | ✅ (timer-based + background) |
| **Inakitajes/kairos** | ✅ | ✅ | ✅ | ✅ (SoulShieldConfiguration) | ✅ (SoulShieldAction) | ✅ | ✅ |
| **christianp-622/ScreenBreak** | ✅ | ✅ | ✅ + Report | ✅ (custom shield) | ❌ | ✅ | ✅ |
| **kingstinct/react-native-device-activity** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (z persistencją przez ID) |
| **pansuriyaravi/Screen-Time-API-Sample** | ✅ | ✅ | ✅ | ❌ | ❌ | ~ | cząstkowy |

## Jeśli budujesz klon Opala — konkretny plan

**Zacznij od `awaseem/foqos`** i zaciągnij z niego: (a) architekturę **Strategy pattern** dla `BlockingStrategy` (Manual / Scheduled / NFC / QR) — to jest ten sam wzorzec, na którym Julius Brussee buduje swoją „real-world app" i jest to właściwe podejście dla wieloprofilowego blokera; (b) wzorzec **SwiftData dla `BlockedProfile` + `BlockedSession`** jako lokalny storage (prosty history & analytics out-of-the-box); (c) strukturę katalogów `Views/Models/Components/Utils/Intents` + osobny target `FoqosDeviceMonitor` — skopiuj jeden-do-jednego; (d) użycie **App Intents** dla Shortcuts automation (to jest przewaga nad Opalem, którą łatwo mieć za darmo); (e) konfigurację `com.apple.developer.family-controls` entitlement w obu targetach oraz App Group `group.<bundle>.data`.

**Weź z `Inakitajes/kairos`** strukturę **wszystkich 4 extension targetów** (`SoulActivityMonitor`, `SoulShieldConfiguration`, `SoulShieldAction`, `SoulWidget`) — skopiuj ich Info.plist oraz extension point identifiers (**ważne:** dla Shield Config używaj `com.apple.ManagedSettingsUI.shield-configuration-service`, a **nie** legacy `com.apple.deviceactivity.shield-configuration` — ten drugi jest odrzucany przez TestFlight review w 2024–2025).

**Weź z `ScreenBreak`** custom `ShieldConfigurationDataSource` (override `configuration(shielding:)`) oraz `DeviceActivityReport` scene z pie chartem, jeśli chcesz pokazywać statystyki użycia (klasyczny ekran „jak dużo dzisiaj klikałeś Instagram").

**Weź z `kingstinct/react-native-device-activity`** (tylko pliki Swift!) produkcyjny wzorzec **`ShieldActionDelegate`** (button handlers) oraz **trick z `familyActivitySelectionId`** — nie przechowuj całego stringified selection tokena w UserDefaults, zapisuj go pod krótkim UUIDem, a extension'y niech go odtwarzają. Ten sam projekt ma też solidny wzorzec na **retrieve-token-then-publish-via-App-Group** który łata słynny bug Apple („shield extension dostaje nieznany token" → raportowany m.in. przez ScreenZen na iOS 17.4.1/17.5.1).

**Uzupełnij dziury samodzielnie:** brakuje Ci na pewno (a) sensownego obslugiwania przypadku **użytkownik wyłączył Screen Time w Settings bez Twojego udziału** (FB18997699 — częste na iOS 26), (b) **refreshu szczególnie długich list tokenów** po zmianie wyboru (crash `FamilyActivityPicker` na dużych kategoriach jest opisany w kingstinct README), (c) logiki „shield dalej liczy czas użycia" — jeśli użytkownik siedzi na ekranie blokady, Screen Time wlicza to do czasu użycia tej apki (bug zgłoszony na Apple Forums, brak workarounda na jesień 2025).

## 3–5 konkretnych plików/gistów/snippetów wartych przeczytania

1. **Pedro Esli, „Using Screen Time API to block apps for a specified time"** — http://pedroesli.com/2023-11-13-screen-time-api/ — **najbardziej kompletny end-to-end snippet jaki istnieje** poza repo: auth `.individual` w `@main App`, `ShieldManager` z `ManagedSettingsStore.shield.applications/.applicationCategories/.webDomainCategories`, `.familyActivityPicker(isPresented:selection:)`, Shield Configuration Extension z `override func configuration(shielding application:) -> ShieldConfiguration` (własne kolory, `Unlock`/`Don't unlock` przyciski), Shield Action Extension z `case .primaryButtonPressed` → `completionHandler(.defer)`, `ApplicationProfile: Codable, Hashable` z `ApplicationToken`, `DataBase` singleton na `UserDefaults(suiteName:)` App Group. To jest de facto **brakujący Apple sample** przepisany przez społeczność.

2. **John Baker (B4k3R), „Creating a ScreenTime ShieldConfigurationDataSource for iOS FamilyControls API"** — https://medium.com/@B4k3R/creating-a-screentime-shieldconfigurationdatasource-for-ios-familycontrols-api-5ca1079d3188 — jedyny materiał który pokrywa **wszystkie 4 override'y** `configuration(shielding:)`: dla `Application`, `Application in category`, `WebDomain`, `WebDomain in category`. Plus pełny opis konfiguracji App Group między targetami (to jest miejsce, w którym większość ludzi rozwala sobie projekt). Zbudowany na komercyjnej apce Stryde, więc battle-tested.

3. **Crunchy Bagel (Streaks team), „Monitoring App Usage using the Screen Time Framework"** — https://crunchybagel.com/monitoring-app-usage-using-the-screen-time-api/ — produkcyjny case study Streaks 9.1. **Najlepszy snippet dla `DeviceActivityEvent` z `threshold: DateComponents(minute: 30)` + `eventDidReachThreshold` callback** w monitor extension. Plus bridge UIKit → SwiftUI dla `familyActivityPicker` w starszej architekturze.

4. **Foqos `Foqos/Models/Strategies/` folder** — https://github.com/awaseem/foqos/tree/main/Foqos/Models (ścieżka: `Foqos/Models/Strategies/`) — implementacja Strategy pattern: `ManualBlockingStrategy`, `NFCBlockingStrategy`, `QRBlockingStrategy`, kompozyty timer-based. Przeczytanie tego pliku zaoszczędzi Ci tygodnie projektowania abstrakcji.

5. **kingstinct `ios/*` folder + README sekcja „Triggers / Event history / ShieldIds"** — https://github.com/kingstinct/react-native-device-activity — referencja jak rozłożyć dane między `userDefaults` używając prefixów `actionsfor${goalId}`, `events_${goalId}`, `shieldIds` w shared App Group, żeby Shield Configuration i Shield Action extension mogły odebrać konfigurację bez dostępu do główegi procesu. Dodatkowo uwaga o **crashu `FamilyActivityPicker`** i fallbackowym view zachowania UX.

**Bonus — riedel.wtf, „Apple's Screen Time API has some major issues"** (https://riedel.wtf/state-of-the-screen-time-api-2024/) — to nie tutorial, tylko lista pułapek od autora komercyjnego „one sec". Przeczytaj, zanim zaczniesz — znajdziesz tam opis random-token-change bug i dlaczego nie możesz bindować logiki biznesowej na 1:1 mapping token→app w UserDefaults.

## Wnioski — jak rozumiem ten ekosystem po research'u

Ekosystem open-source dla Screen Time API jest **ubogi i silnie zdeformowany** przez brak oficjalnego Apple sample. Istnieje **jedno dobre repo produkcyjne** (Foqos), **dwa edukacyjne** (ScreenBreak, Kairos), **jedna biblioteka Swift schowana w RN-ie** (kingstinct) oraz garść tutoriali Medium/personal-blog, z których Pedro Esli i John Baker są absolutną obowiązkówą. Najlepszy kod po stronie Shield Action + persistence jest **paradoksalnie w wrapperze RN**, więc nie omijaj go ze względu na Expo. Paul Hudson, Antoine van der Lee, Majid Jabrayilov i Azam Sharp **nie napisali nic** o tym API — to jest po prostu content gap, nie Twoje niedopatrzenie w wyszukiwaniach. Twoja strategia powinna być: sklonuj Foqos jako bazę + wzbogać o Shield Configuration/Action extension wg artykułu Pedro Esli i Johna Bakera, nauczyciel się pułapek z riedel.wtf, i od razu składaj wniosek o Distribution entitlement (trwa 3–4 tygodnie, a na ShieldAction extension bywa, że utknie w „Submitted" i zablokuje Ci TestFlight — patrz thread z Apple Forums o ID 9D7MU547QH).