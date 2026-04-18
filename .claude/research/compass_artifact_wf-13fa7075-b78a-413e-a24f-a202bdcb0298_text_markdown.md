# DeviceActivityReport — pełny przewodnik techniczny dla klona Opala (iOS 26+)

**Krótka odpowiedź (BLUF).** `DeviceActivityReport` to **jednokierunkowa rura**: ekstension renderuje widok, ale nie oddaje liczbek do hosta — pisanie do App Group / UserDefaults / plików / sieci jest po cichu blokowane przez sandbox XPC. Dla ekranu statystyk w stylu Opala jedyna produkcyjnie sprawdzona architektura to **hybryda**: `DeviceActivityReport` pokazuje prawdziwe wykresy w izolowanym widoku SwiftUI, a równolegle uruchomiony `DeviceActivityMonitor` z licznymi `DeviceActivityEvent` o małych progach (min. 1 min w praktyce, interwał harmonogramu min. **15 min**, max **20 aktywności łącznie** na aplikację+jej extensiony) tyka licznik w App Group UserDefaults — to jest to, z czego host app czyta „minuty dziś vs wczoraj", streaki i XP. W iOS 26.4 (wiosna 2026) pojawił się nowy capability `Family Controls App and Website Usage` + status autoryzacji `approvedWithDataAccess` — pierwsza oficjalna furtka do danych poza extension, ale WWDC nie dostał sesji i szczegóły są słabo udokumentowane. Od WWDC 2022 (sesja 110336 „What's new in Screen Time API") nie było ani jednej dedykowanej sesji WWDC dla tych frameworków; w 2023, 2024 i 2025 — nic. Poniższy raport mapuje każdy element API, co się da, czego nie, i jak omijają to produkcyjne aplikacje (Opal, Jomo, Clearspace, one sec, Brick).

---

## Co się da vs czego się nie da

**Co się da (wewnątrz `DeviceActivityReportExtension`):**

- Odczytać pełny strumień `DeviceActivityResults<DeviceActivityData>` jako `AsyncSequence` — minuty na aplikację, na kategorię, na domenę, `numberOfPickups`, `numberOfNotifications`, `firstPickup`, `lastPickup`, `totalActivityDuration`, `totalPickupsWithoutApplicationActivity`, `isTrusted`, `lastUpdatedDate`.
- Wyrenderować **dowolny SwiftUI**, w tym **Swift Charts** (`import Charts`, `BarMark`, `LineMark`, `SectorMark`), `@State`, `.onAppear`, `.task`, animacje, `ProgressView`, `ForEach` — wszystko działa lokalnie w procesie extension.
- Odczytywać (jednostronnie, do wewnątrz) dane z App Group UserDefaults/kontenera — np. preferencje wyglądu, listę tokenów z hosta.
- Użyć `Application.localizedDisplayName` (zwraca prawdziwą nazwę tylko w tym kontekście i w shield-extension; w głównej aplikacji i w monitorze jest `nil`).
- Dostać trzy granulacje bucketów: **`.hourly(during:)`, `.daily(during:)`, `.weekly(during:)`** — `DeviceActivityFilter.SegmentInterval`. Nic drobniejszego niż godzina.

**Czego się nie da:**

- **Porównywać dziś vs wczoraj liczbowo w głównej aplikacji** — host nigdy nie widzi surowych wartości.
- Zapisać minut do UserDefaults / App Group / Core Data / pliku / keychain / iCloud KVS z `DeviceActivityReportExtension` — zapisy są **po cichu porzucane** (Apple traktuje to jako „expected behavior", Case OE1100504480881).
- Zrobić `URLSession`, strzał HTTP, `UNUserNotificationCenter` (zwraca „Couldn't communicate with a helper application"), `UIPasteboard.write`, Darwin notifications, `NSUbiquitousKeyValueStore.synchronize()` (zwraca `false`), `UIApplication.open(_:)`, `@Environment(\.openURL)`, `FoundationModels`.
- Obsłużyć interakcji międzyprocesowej: `Button`, `NavigationLink`, `.onTapGesture` wewnątrz ekstension są albo wprost ignorowane przez remote view proxy, albo wywalają widok z błędem `_UIViewServiceInterfaceErrorDomain Code=3` (forum thread 723491). `DeviceActivityReport` wstawiony w `Button` hosta **połyka tap gesture**.
- Zrenderować wykresu do `UIImage` i zapisać PNG w App Group — zapis pliku też jest blokowany.
- Wyciągnąć `bundleIdentifier` do głównej aplikacji — `Application.bundleIdentifier` jest `nil` poza kontekstem report-extension.
- Próg eventu krótszy niż **1 minuta** w praktyce działa zawodnie; harmonogram krótszy niż **15 minut** jest odrzucany przez `DeviceActivityCenter`. Maksymalny harmonogram: **1 tydzień**. Max **20 równoczesnych aktywności** na aplikację+extensiony (`.excessiveActivities`). Max **50 tokenów** aplikacji w jednej `FamilyActivitySelection`.
- Testować na symulatorze — FamilyControls/DeviceActivity wymagają prawdziwego urządzenia, inaczej autoryzacja zwraca błąd iCloudowy (`cloudd nw_parameters_set_source_application_by_bundle_id_internal` dla `com.apple.FamilyControlsAgent`).

---

## Architektura — diagram przepływu danych słownie

Urządzenie: demon systemowy **`deviceactivityd`** agreguje minuty aplikacji, pickupy i notyfikacje z całego systemu. Gdy twoja aplikacja wywoła `DeviceActivityReport(context:filter:)` w SwiftUI, system:

1. Uruchamia osobny proces **`DeviceActivityReportExtension`** (ExtensionKit/XPC przez `com.apple.DeviceActivityUI.DeviceActivityReportService.viewservice`) z twoim binarnym targetem o `NSExtensionPointIdentifier = com.apple.deviceactivityui.report-extension`.
2. Wstrzykuje ten proces do hierarchii widoków hosta jako **remote view proxy** — host widzi tylko czarny prostokąt/surface, nie ma dostępu do pamięci procesu ekstension.
3. Do `makeConfiguration(representing: DeviceActivityResults<DeviceActivityData>)` w twojej `DeviceActivityReportScene` przekazuje `AsyncSequence` posortowany wg filtra. Struktura: `DeviceActivityResults` → `DeviceActivityData` (per user+device) → `activitySegments` (per bucket wg `segmentInterval`) → `categories` → `applications` / `webDomains`. Każdy poziom jest osobnym `AsyncSequence` — trzeba iterować `for await`.
4. Twój kod redukuje strumień do immutable `Configuration` (np. `String`, struct, tablicę punktów wykresu), a closure `content:` zamienia go w widok SwiftUI.
5. Gdy pojawiają się nowe dane (typowo kilka minut latency, brak formalnego SLA; użyj `DeviceActivityData.lastUpdatedDate` jako jedynego oficjalnego sygnału świeżości), framework **sam** ponownie wywołuje `makeConfiguration` — nic nie trzeba subskrybować.

Równoległa rura bez sandboxu XPC: **`DeviceActivityMonitor`** (`com.apple.deviceactivity.monitor-extension`) żyje w „zwykłym" sandboxie rozszerzenia z entitlementem App Group i **może pisać** do `UserDefaults(suiteName:)` oraz kontenera grupowego. `DeviceActivityCenter.startMonitoring(_:during:events:)` planuje `DeviceActivitySchedule` (min. 15 min) i zestaw `DeviceActivityEvent(applications:categories:webDomains:threshold:)`. Gdy sumaryczny czas dla tokenów w evencie przekroczy `threshold` (jako `DateComponents`), system odpala proces monitora, który dostaje `eventDidReachThreshold(_:activity:)` — **tutaj** inkrementujesz licznik w App Group. Host czyta to UserDefaults bezpośrednio. To jest prawdziwa ścieżka „minuty do UI".

---

## Minimalny działający szablon kodu

Targety w Xcode: (1) główna aplikacja, (2) **Device Activity Report Extension**, (3) **Device Activity Monitor Extension**, (4) App Group `group.com.example.opalclone`, (5) entitlement `com.apple.developer.family-controls` (trzeba poprosić Apple o zgodę na dystrybucję).

**Info.plist dla report-extension** (uwaga: ASC walidacja domaga się `NSExtensionPrincipalClass`, runtime go zabrania — znany bug, forum 812380; praktyka: dodaj przed archive, usuń przed lokalnym buildem, albo zaakceptuj warning ASC):

```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key>
  <string>com.apple.deviceactivityui.report-extension</string>
</dict>
```

**Główna aplikacja — autoryzacja + embedowanie raportu:**

```swift
import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

@main
struct OpalCloneApp: App {
    var body: some Scene {
        WindowGroup {
            RootView().task {
                try? await AuthorizationCenter.shared
                    .requestAuthorization(for: .individual)
            }
        }
    }
}

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let perAppBreakdown = Self("Per-App Breakdown")
}

struct StatsView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false

    var filter: DeviceActivityFilter {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return DeviceActivityFilter(
            segment: .hourly(during: DateInterval(start: today, end: tomorrow)),
            users: .all,
            devices: .init([.iPhone, .iPad]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    var body: some View {
        VStack {
            DeviceActivityReport(.totalActivity, filter: filter)
                .frame(height: 320) // okno XPC — zadbaj o stałe wymiary
            // osobny blok "własne" statystyki z App Group (liczone przez Monitor)
            StreakAndXPView() // patrz niżej
            Button("Wybierz aplikacje") { showPicker = true }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
    }
}
```

**Report extension — SwiftUI Charts wewnątrz:**

```swift
import DeviceActivity
import SwiftUI
import Charts

@main
struct OpalCloneReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityScene()
        PerAppBreakdownScene()
    }
}

struct HourlyPoint: Identifiable { let id = UUID(); let hour: Date; let minutes: Double }
struct AppUsage: Identifiable { let id = UUID(); let name: String; let minutes: Double }
struct TotalActivityConfig {
    let totalMinutes: Double
    let hourly: [HourlyPoint]
    let perApp: [AppUsage]
    let pickups: Int
    let notifications: Int
    let lastUpdated: Date
}

struct TotalActivityScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (TotalActivityConfig) -> TotalActivityView = TotalActivityView.init

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> TotalActivityConfig {
        var hourly: [HourlyPoint] = []
        var perApp: [String: Double] = [:]
        var total: TimeInterval = 0
        var pickups = 0
        var notifs = 0
        var lastUpdated = Date.distantPast

        for await d in data {
            lastUpdated = max(lastUpdated, d.lastUpdatedDate)
            for await seg in d.activitySegments {
                total += seg.totalActivityDuration
                hourly.append(.init(
                    hour: seg.dateInterval.start,
                    minutes: seg.totalActivityDuration / 60
                ))
                for await cat in seg.categories {
                    for await app in cat.applications {
                        pickups += app.numberOfPickups
                        notifs += app.numberOfNotifications
                        let name = app.application.localizedDisplayName
                            ?? app.application.bundleIdentifier
                            ?? "Unknown"
                        perApp[name, default: 0] += app.totalActivityDuration / 60
                    }
                }
            }
        }
        return TotalActivityConfig(
            totalMinutes: total / 60,
            hourly: hourly.sorted { $0.hour < $1.hour },
            perApp: perApp.map { AppUsage(name: $0.key, minutes: $0.value) }
                .sorted { $0.minutes > $1.minutes },
            pickups: pickups,
            notifications: notifs,
            lastUpdated: lastUpdated
        )
    }
}

struct TotalActivityView: View {
    let config: TotalActivityConfig
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(Int(config.totalMinutes)) min dziś")
                .font(.largeTitle.bold())
            Chart(config.hourly) { p in
                BarMark(x: .value("h", p.hour, unit: .hour),
                        y: .value("min", p.minutes))
            }
            .frame(height: 160)
            // UWAGA: żaden Button/NavigationLink tutaj — nie zadziała cross-process.
        }
        .padding()
    }
}
```

**Monitor extension — licznik do App Group:**

```swift
import DeviceActivity
import ManagedSettings
import Foundation

let defaults = UserDefaults(suiteName: "group.com.example.opalclone")!

class OpalMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        let key = "minutes.\(activity.rawValue).\(event.rawValue).\(todayKey())"
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)   // tick = osiągnięto kolejny próg (np. +5 min)
        // Tu można też włączyć shield:
        // ManagedSettingsStore(named: .init("blocked"))
        //   .shield.applications = storedTokens
    }
    override func intervalDidStart(for activity: DeviceActivityName) { /* reset dziennego licznika */ }
    override func intervalDidEnd(for activity: DeviceActivityName) { /* flush */ }
    private func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: .now)
    }
}
```

**Main app — planowanie harmonogramu i odczyt:**

```swift
let center = DeviceActivityCenter()
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd:   DateComponents(hour: 23, minute: 59),
    repeats: true
)
let everyFiveMin = DeviceActivityEvent(
    applications: selection.applicationTokens,
    threshold: DateComponents(minute: 5)
    // includesPastActivity domyślnie false — UWAGA: FB15220094 sprawia, że true bywa jedyną opcją, żeby progi w ogóle odpalały
)
try center.startMonitoring(
    .init("daily"),
    during: schedule,
    events: [.init("fiveMinTick"): everyFiveMin]
)
```

---

## Rekomendowana architektura dla klona Opala — decyzja

**Wybór: hybryda, nie czysty `DeviceActivityReport`, nie czyste progi.** Uzasadnienie:

- **Pure `DeviceActivityReport`** daje piękne wykresy ze świeżymi danymi systemowymi, ale odcina wszystkie funkcje poza renderem widoku: streaki, XP, powiadomienia „dziś zużyłeś 30% mniej niż wczoraj", share sheet, eksport CSV — bez App Group tego nie zrobisz. Opal mimo wszystko trzyma kluczowy wykres „Screen Time" właśnie w report-extension, bo to jedyne źródło dokładnych, godzinowych liczb zgodnych z systemowym Screen Time.
- **Pure progi przez `DeviceActivityMonitor`** dają „własne" liczby do App Group i pełną kontrolę nad gamifikacją, ale są **przybliżone** (tykają co próg, nie są retroaktywne), cierpią regresję iOS 26 (`eventDidReachThreshold` odpala natychmiast po starcie schedule'a — FB13696022/FB18351583/FB21320644/FB18927456/FB18061981 w raporcie Riedel 2024) i mają twarde limity (20 aktywności, 50 tokenów, 6 MB RAM). To model „one sec"/„Brick" — działa, ale wykresy godzinowe odpadają.
- **Hybryda = Opal/Jomo/Clearspace.** Report-extension renderuje wykres oficjalny (bar chart godzinowy + lista aplikacji), a Monitor zapisuje do App Group: (a) `totalMinutesToday` jako sumę ticków, (b) `streakDays` inkrementowany w `intervalDidStart` gdy wczorajsze minuty ≤ budżet, (c) per-appTickCount dla leaderboardu. Ekran „dziś vs wczoraj" bierze dane z App Group (Monitor). Ekran „rozbicie godzinowe" bierze `DeviceActivityReport` (Report-extension). Użytkownik nie widzi granicy, bo oba komponenty siedzą w jednym `ScrollView`. Clearspace poszedł o krok dalej i wysyła agregaty do swojego REST API `thescreentimenetwork.com/api/overview` (syncuje iOS↔web), ale to wymaga Monitor-path, nie Report-path.

Praktyczne wytyczne: `.hourly` dla widoków 1-dniowych (pow. 24 bucketów), `.daily` dla 7–28-dniowych (dłużej niż 7 dni z `.hourly` = crash extension przez mały budżet RAM — community ~80-100 MB dla Report, twarde 6 MB dla Monitor), filter ≤ 28 dni (FamilyActivityPicker i tak indeksuje ~30 dni domen). Używaj **`ManagedSettingsStore(named:)`** z nazwanymi store'ami (do 50 per proces od iOS 16 — WWDC22) — oddziel „planowany blok" od „przekroczony próg".

---

## Bugi produkcyjne i obejścia (stan: kwiecień 2026)

| Bug | Gdzie | Źródło / radar | Obejście |
|---|---|---|---|
| `eventDidReachThreshold` odpala natychmiast po starcie intervalu (iOS 26 regression) | Monitor | forum 727970, 808470, 811305; FB13696022, FB18351583, FB21320644, FB18927456, FB18061981 | Ignoruj pierwsze wywołanie w obrębie pierwszych N sekund od `intervalDidStart`; cofnij i przyznaj autoryzację żeby wyczyścić cache |
| `intervalDidStart`/`End` nigdy nie wywołany | Monitor | forum device-activity 2026, iOS 26.3.1; FB13556935 | Defensywny fallback: Timer w main app wymusza re-scheduling co ileś godzin |
| Random Tokens — shield dostaje tokeny których apka nigdy nie zapisała | Shield + Monitor | FB14082790; riedel.wtf/state-of-the-screen-time-api-2024/; forum 756440, 758325 (Jomo, ScreenZen, Opal) | Porównuj po `hashValue` a nie `==`; cache localizedDisplayName w report-ext |
| Tokeny przechodzą między `ManagedSettingsStore`'ami, shield UI nieświeży | Shield | FB14237883 | Invalidate+rebuild wszystkich stores przy starcie |
| FamilyActivityPicker crash „Connection to plugin invalidated while in use" | Main app | forum 743770, 766506, 750847, 764457 (FB14067691), 773601, 724556 | Timer-driven opacity toggle żeby wymusić redraw i wykryć crash |
| Picker przekracza 50 MB RAM przy Safari domains | Main app | forum 773601 | Wyłącz kategorię web domains, albo ogranicz pre-selection |
| DeviceActivityReport pokazuje czarny ekran / blank | Report-ext | letvar 2024, forum 742109, 750698, 743069 | Użyj `.hourly` zamiast `.daily`; trzymaj extension < ~80 MB RAM; Xcode „Attach to process" dla logów |
| `DeviceActivityReport` w `Button` połyka tap | Main app | forum tag family-controls, iOS 17/Xcode 15 | Nigdy nie otaczaj raportu `Button`em; daj kontrolki obok |
| 3 raporty na jednym ekranie → crash | Report-ext | forum 736770 (iOS 16), 720549, 726474 | Max 2 raporty; switch na `.hourly` |
| Overcounting Safari + in-app browser | Monitor + Report | forum 763542; FB15103784, FB16055453 (iOS 18.1.1) | Wyłącz webDomains w evencie, licz tylko applications |
| Okresowa utrata autoryzacji Screen Time na iOS 26 | Main app | FB18997699; riedel.wtf | `AuthorizationCenter.shared.authorizationStatus` check przy każdym `scenePhase == .active` |
| Brak `.openParentApp` w ShieldAction | Shield | FB15079668 | Local notification z deep linkiem; liczyć się z opóźnieniami Focus/Intelligence |
| Brak otwarcia target-appki z ApplicationToken | Main app | FB15500695 | Użyj localized display name + URL scheme heurystyki |
| 3rd-party Screen Time permission nie lockowany passcode'em | System | FB18794535 | Zdokumentuj ograniczenie w recenzjach App Store |
| `includesPastActivity: false` → próg się nie odpala | Monitor | FB15220094 | Ustaw `true` i deduplikuj sam |
| ASC upload wymaga `NSExtensionPrincipalClass`, runtime zabrania | Report-ext | forum 812380 (2026) | Dodaj klucz tylko na archive, usuń przed lokalnym buildem |
| Symulator — FamilyActivityPicker/autoryzacja nie działają | Dev | folio3.com blog | Testuj wyłącznie na urządzeniu; 15 min min. cykl testowy |
| Brak `print()` w extension console | Dev | letvar 2/3 | `os.Logger(subsystem:category:)` + Console.app, albo Debug → Attach to process |
| `Application.bundleIdentifier` `nil` w main app i Monitor | Main app | forum family-controls 2026 | Cache'uj mapę token→name z wnętrza Report-extension przez App Group UserDefaults *czytane* przez extension (jednokierunkowy write z main app) |

---

## Produkcyjne aplikacje — co i jak pokazują

**Opal** (id1497465230) — bar-chart Screen Time, licznik pickupów, Focus Score /100, kategoryzacja Productive/Distracting, leaderboardy, weekly email. Technika: ciężkie użycie `DeviceActivityReport` extension + Monitor. Peter Schaeffer (Opal) publicznie zgłaszał Random Tokens bug (forum 758325). Na iOS 26 shield czasem pokazuje nieznane tokeny — stąd Opal fallback z lokalnym cache nazw aplikacji.

**Jomo** (id1609960918, jomo.so) — dzienny+tygodniowy total, per-rule summary, „Usefulness" journaling, „Extra Time" odblokowywany spacerami. Zgłosili bug „mismatch between daily and weekly total screen time" — klasyczny objaw hybrydowego liczenia (Report vs Monitor) się rozjechał. Thomas Maht publicznie na forum 758325.

**Clearspace** (id1572515807, getclearspace.com) — „GitHub-style" contribution grid dni trafionych w budżet, pre-open nudge „otwarłeś TikTok 12× dziś", streaki, zaoszczędzone godziny. Wypuścili w 2025 **Screen Time Network REST API** (thescreentimenetwork.com/api/overview — HN item 44194120) — sync iOS↔web agregatów. Oznacza to, że eksfiltrują **zagregowane** liczby przez Monitor-path do swojego backendu; surowa PII nie wychodzi z urządzenia.

**one sec** (riedel.wtf) — minimalne statystyki (block count + streak). Technika: głównie ManagedSettings + ShieldConfiguration/ShieldAction + DeviceActivitySchedule; bazuje na frictionie, nie analizie.

**Brick** (id6448794069, getbrick.com) — lista trybów + streak + session history. Nie ma głębokich statystyk; Shield on/off przez NFC tag. Zero widocznego report-extension.

**Jour** — brak twardych dowodów na deep Screen Time integration; prawdopodobnie tylko shield + basic schedule.

**Wzorzec UX u wszystkich**: `DeviceActivityReport` osadzony jako zwykły widok SwiftUI w środku `ScrollView`, z konkretną wysokością. Obok, w tym samym scrollu, **drugi blok** z danymi czytanymi z App Group (streak, XP, „dziś vs wczoraj"). Granica extension jest niewidoczna, bo style (kolory, font, padding) są identyczne po obu stronach. Użytkownik myśli, że to jeden widok.

---

## Ewolucja iOS — WWDC 23, 24, 25 i co się zmieniło

**WWDC 2021 (session 10123, Christopher Skogen)** — „Meet the Screen Time API". Wprowadzenie FamilyControls/ManagedSettings/DeviceActivity. Filozofia opaque tokens.

**WWDC 2022 (session 110336, MaryAshley Etefia)** — „What's new in Screen Time API". **Wprowadzenie `DeviceActivityReport`, `DeviceActivityReportExtension`, `DeviceActivityReportScene`, `DeviceActivityFilter`, individual authorization, 50 named ManagedSettingsStores.** URL: developer.apple.com/videos/play/wwdc2022/110336/. Kluczowy cytat: *„The framework will invoke makeConfiguration whenever new usage data is fetched so you do not need to invoke it yourself."*

**WWDC 2023 (iOS 17)** — **zero dedykowanych sesji**. Forum thread 730905 potwierdza (deweloper pyta, brak odpowiedzi). Żadnych nowych symboli w headerach. Community raportuje regresję overcounting w iOS 17.4.1/17.6.1 (forum 763542).

**WWDC 2024 (iOS 18)** — **zero dedykowanych sesji**. letvar potwierdza w czerwcu 2024: „not mentioned in the Keynote and Platforms State of the Union, and no sessions or labs are scheduled." iOS 18 dodał **Controls API** (Control Center) — niezwiązane z ManagedSettings. iOS 18.1.1 wprowadził regresję FB16055453 (thresholds double-count).

**WWDC 2025 (iOS 26)** — **zero dedykowanych sesji DeviceActivity**. Keynote-level ogłoszenia (9to5mac 2025-06-11; idownloadblog 2025-06-12): **nowy framework PermissionKit** (parental-approval requests, osobny framework), **Declared Age Range API** (przedział wieku zamiast DOB), rozszerzone App Store age ratings (13+/16+/18+), Communication Safety dla FaceTime video + Shared Albums, SensitiveContentAnalysis framework, Ask-to-Buy exceptions. **iOS 26.0-26.3: brak nowych symboli** w DeviceActivity/FamilyControls/ManagedSettings; za to ciężkie regresje (thresholds firing immediately, deviceactivityd nie budzi extension — FB22304617, FB20526837 i inne).

**iOS 26.4 (wiosna 2026) — jedyna konkretna zmiana API w całym cyklu iOS 17/18/26:**
- Nowy capability **`Family Controls App and Website Usage`** (dodatkowo do starego `com.apple.developer.family-controls`).
- Nowy status `AuthorizationStatus.approvedWithDataAccess` — developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess.
- Efekt UX: po adopcji capability iOS 26.4+ dają userowi wybór „pełna zgoda / odmowa" — starej opcji Screen-Time-bez-danych nie ma (forum 820283, kwiecień 2026, user nemecek_f).
- Sandbox: to **pierwsza oficjalna furtka** dla głównej aplikacji do otrzymywania usage data bez pośrednictwa report-extension. Apple nie opublikowało sesji ani pełnej dokumentacji o kształcie danych; szczegóły dopiero krystalizują się na forum.
- System-level: App Limits dopuszczają `0 min` (twardy block), Screen Time PIN wymagany żeby wyłączyć apkę z „Apps with Screen Time Access" (utwardzenie against bypass), in-app browser blokowany w Downtime.

**Deprecations 2023-2026**: żadnych.

**Dokumentacja diff-endpoint**: `developer.apple.com/documentation/DeviceActivity?changes=latest_minor` — kanoniczny sposób na różnicę między SDK (forum 730905).

---

## Linki (pełna lista z datami)

**Apple dokumentacja:**
- developer.apple.com/documentation/deviceactivity — landing
- developer.apple.com/documentation/deviceactivity/deviceactivityreport
- developer.apple.com/documentation/deviceactivity/deviceactivityreportextension
- developer.apple.com/documentation/deviceactivity/deviceactivityreportscene
- developer.apple.com/documentation/deviceactivity/deviceactivityreport/context
- developer.apple.com/documentation/deviceactivity/deviceactivityfilter
- developer.apple.com/documentation/deviceactivity/deviceactivityfilter/init(segment:users:devices:applications:categories:webdomains:)
- developer.apple.com/documentation/deviceactivity/deviceactivityfilter/segmentinterval-swift.enum/hourly(during:)
- developer.apple.com/documentation/deviceactivity/deviceactivityresults
- developer.apple.com/documentation/deviceactivity/deviceactivitydata
- developer.apple.com/documentation/deviceactivity/deviceactivitydata/lastupdateddate
- developer.apple.com/documentation/deviceactivity/deviceactivitydata/applicationactivity
- developer.apple.com/documentation/deviceactivity/deviceactivitydata/categoryactivity/applications
- developer.apple.com/documentation/deviceactivity/deviceactivitydata/webdomainactivity/webdomain
- developer.apple.com/documentation/deviceactivity/deviceactivitycenter
- developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/excessiveactivities
- developer.apple.com/documentation/deviceactivity/deviceactivityschedule
- developer.apple.com/documentation/deviceactivity/deviceactivityevent
- developer.apple.com/documentation/deviceactivity/deviceactivitymonitor
- developer.apple.com/documentation/familycontrols
- developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess (iOS 26.4)
- developer.apple.com/documentation/managedsettings

**WWDC:**
- developer.apple.com/videos/play/wwdc2021/10123/ (2021-06, „Meet the Screen Time API")
- developer.apple.com/videos/play/wwdc2022/110336/ (2022-06, „What's new in Screen Time API")
- WWDC 2023/2024/2025 — brak dedykowanych sesji.

**Forum Apple Developer (wszystkie zweryfikowane 2026-04-18):**
- developer.apple.com/forums/tags/device-activity (tag)
- developer.apple.com/forums/tags/family-controls (tag)
- forum 742109 (sandbox quote, Opal frustration)
- forum 709692 (ApplicationActivity fields dump)
- forum 736176 (DTS: min granularity = hourly)
- forum 812380 (Info.plist catch-22, 2026)
- forum 721328 (Mac devices wymagają autoryzacji)
- forum 721018 (ActivitySegment no public init)
- forum 730905 (WWDC23 nic o Screen Time)
- forum 735454 (6 MB Monitor RAM limit)
- forum 727970, 808470, 811305 (iOS 26 eventDidReachThreshold regression)
- forum 763542 (overcounting Safari, FB15103784, FB16055453)
- forum 710915 (20 activities cap)
- forum 723491 (NavigationLink crash)
- forum 805859 (Monitor + App Group working code, 2026)
- forum 750698, 743069 (blank DeviceActivityReport)
- forum 743770, 766506, 750847, 764457, 773601, 724556 (FamilyActivityPicker crashes)
- forum 756440, 758325 (Random Tokens — ScreenZen, Jomo, Opal)
- forum 749887 (autoryzacja, cloudd)
- forum 736770, 720549, 726474 (multi-report crashes)
- forum 820283 (iOS 26.4 new capability, 2026-04)

**Blogi deweloperskie:**
- riedel.wtf/state-of-the-screen-time-api-2024/ (Frederik Riedel, one sec, 2024-09-14) — najlepszy skonsolidowany lista bugów i radarów (FB14082790, FB14237883, FB15079668, FB15500695, FB18794535); page rozszerzana w 2026
- letvar.medium.com/time-after-screen-time-part-2-the-device-activity-report-extension-10eeeb595fbd (2024-04-24) — Report extension deep dive
- letvar.medium.com/time-after-screen-time-part-3-the-device-activity-monitor-extension-284da931391b (2024-06-07) — Monitor extension
- crunchybagel.com/monitoring-app-usage-using-the-screen-time-api/ (Streaks by Crunchy Bagel) — 5 MB limit
- medium.com/@yosshi4486/limitations-of-screen-time-related-apis-3ebf7c371962 (Yoshiharu Yamada) — limity ilościowe
- medium.com/@manishdevstudio/mastering-apples-screen-time-api-part-4-visualizing-and-managing-activity-data-a761a8daed55 (Manish Yadav, 2025) — Charts w Report scene
- medium.com/@danisharfin1/creating-an-ios-screen-time-tracking-app-using-swiftui-and-apples-deviceactivity-framework-e999c6f37930 (Muhammad Danish Qureshi)
- medium.com/@juliusbrussee/a-developers-guide-to-apple-s-screen-time-apis-familycontrols-managedsettings-deviceactivity-e660147367d7 (Julius Brussee) — BlockedProfiles + SwiftData
- medium.com/@jc_builds/building-a-powerful-ios-app-blocker-with-screen-time-apis-the-complete-guide-f6272bd00fc4 (JC)
- medium.com/ios-nest/screen-time-api-d1110751d2ce (Ezgi Üstünel) — thresholds
- levelup.gitconnected.com/swiftui-report-device-activity-graphically-visually-73f4d76f5039 (Itsuki)
- kushwaha03.medium.com/the-screen-time-api-and-whats-new-in-screen-time-api-50a1404c130e (Krishna Kushwaha)
- pedroesli.com/2023-11-13-screen-time-api/ (Pedro Esli, 2023-11-13)
- folio3.com/mobile/blog/screentime-api-ios/
- *Uwaga*: brak konkretnych postów Majid Jabrayilov (swiftwithmajid.com nie ma dedicated Screen Time), Jorge Ovalle, Francois Lambert, Chris Sabol, „MoeGlobe" — poszukiwanie nie przyniosło trafień; pytanie użytkownika mogło mieć niepełną listę nazwisk.

**GitHub:**
- github.com/kingstinct/react-native-device-activity (~108★) — najpełniejsza produkcyjna referencja (RN/Expo), dokumentuje known crashes i wzorce App Group persistence; klucze `events_${goalId}`
- github.com/christianp-622/ScreenBreak — iOS 16, SwiftUICharts w DeviceActivityReportScene, individual auth, Rive animations
- github.com/CoffeeNaeriRei/ScreenTime_Barebones — MVVM SwiftUI, `ActivityReport(totalDuration, apps: [AppDeviceActivity])` per app
- github.com/krypted/DeviceActivityExample — minimal experiment repo, entitlements reference

**Apple newsroom / media dla iOS 26:**
- 9to5mac.com/2025/06/11/ios-26-expands-family-tools-with-smarter-child-account-setup/
- idownloadblog.com/2025/06/12/apple-updates-ios26-parental-controls-child-accounts-age-ratings-app-store-apps-permission/
- techlockdown.com/articles/ios-26-screen-time-changes
- news.ycombinator.com/item?id=44194120 (Clearspace Screen Time Network API)

---

## Wnioski

Framework `DeviceActivityReport` dostarcza **dokładnie jedną rzecz**: piękny, prywatny widok SwiftUI z prawdziwymi liczbami Screen Time — i nic więcej. Kropka. Każda inna potrzeba (porównanie dni, streaki, XP, notyfikacje „dziś przekroczyłeś budżet", eksport CSV, leaderboardy, backend sync) musi przejść przez drugą rurę — `DeviceActivityMonitor` z `DeviceActivityEvent.threshold` tykającym licznik w App Group UserDefaults. **To nie jest błąd architektury — to celowa decyzja Apple**, potwierdzona przez zamknięty przez Apple Security radar, gdzie próbę rekonstrukcji danych z widoku extension Apple nazwało „expected behavior". Od WWDC 2022 framework nie dostał żadnej sesji ani materialnego rozszerzenia aż do iOS 26.4, gdzie nowy capability `Family Controls App and Website Usage` i status `approvedWithDataAccess` zwiastują pierwszą oficjalną szczelinę w sandboxie — ale bez WWDC i bez docs to na razie teren eksperymentalny. Dla klona Opala w 2026: **zbuduj hybrydę, zaakceptuj że licznik minut będzie zgrubny (±5 min), obłóż kod defensywnymi fallbackami na iOS 26 regresje thresholdów, i nie próbuj eksfiltrować danych z report-extension — produkcyjnie nikt tego nie robi, bo to się po cichu nie udaje.** Prawdziwy user experience różnicy między tobą a Opalem nie zależy od surowych liczb (wszyscy mają te same progowe tyki), tylko od tego, jak sensownie połączysz to z gamifikacją i frictionem — tu jest pole do popisu, nie w walce z sandboxem.