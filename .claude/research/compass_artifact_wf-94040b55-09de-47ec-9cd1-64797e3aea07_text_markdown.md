# Produkcyjny shield w Screen Time API — kompletny przewodnik techniczny

**Shield w iOS jest świadomie ubogim UI — wszystkie bogate doświadczenia (odliczanie, wpisywanie zdań, oddech, gamifikacja) muszą dziać się w main app po deep-linku.** Apple narzuca tu 8-polowy struct `ShieldConfiguration` (UIColor, UIImage, kilka Label-i), trzy odpowiedzi akcji (`.none`/`.defer`/`.close`) i brak wsparcia SwiftUI, TextField, animacji, sieci, czy otwierania parent app. Liderzy rynku (Opal, one sec, Jomo, ScreenZen, Brick) obchodzą te ograniczenia przez trzy główne triki: pre-renderowane UIImage z wypiekaną typografią/brandingiem, lokalne notyfikacje + URL schemes do deep-linku z shield do main app, oraz App Group + Darwin notifications do synchronizacji stanu między procesami. Poniżej pełna anatomia, gotowy kod produkcyjny, architektura „rich shield" i taksonomia trików UX z App Store.

## 1. Dwa extensiony — anatomia, cykl życia, budżety

W Xcode dodaje się **dwa osobne target-y**: `Shield Configuration Extension` (wygląd) i `Shield Action Extension` (obsługa klików). Każdy ma własny bundle ID i **wymaga osobnego zatwierdzenia entitlementu `com.apple.developer.family-controls` w wersji Distribution** przed TestFlight — zatwierdzenia przychodzą 1 dzień–6 tygodni każdy (źródło: Apple Developer Forums thread 717858 oraz `riedel.wtf/state-of-the-screen-time-api-2024`).

**`ShieldConfigurationExtension`** dziedziczy po `ShieldConfigurationDataSource` (framework `ManagedSettingsUI`). Plist: `NSExtensionPointIdentifier = com.apple.ManagedSettingsUI.shield-configuration-service`. System instancjonuje ją **za każdym razem gdy iOS musi wyrenderować shield** (także w trybie app-switchera jako snapshot) i kończy proces wkrótce potem — **nie trzymajcie stanu w instance properties**, bo nie przeżyje między wywołaniami. Extension działa w **bardzo ciasnym sandbox-ie**: **brak sieci** (potwierdzone przez Apple DTS „Eskimo" w thread 772282: *„For privacy reasons you cannot make API calls from your Shield Extension"*), limit pamięci klasyczny dla iOS app extensions (kilka–kilkanaście MB, testować na urządzeniu), a metoda `configuration(shielding:)` powinna wracać **synchronicznie w kilka milisekund** — to nie jest miejsce na dekodowanie dużych obrazów.

**`ShieldActionExtension`** dziedziczy po `ShieldActionDelegate` (framework `ManagedSettings`). Plist: `NSExtensionPointIdentifier = com.apple.ManagedSettingsUI.shield-action-service`. Wywoływana wyłącznie na tap primary/secondary buttona, ma **lekko dłuższy budżet** (completion handler jest async i można zdążyć zapisać do App Group oraz zaplanować `UNNotificationRequest`), ale nadal **brak sieci** i brak oficjalnej drogi otwarcia parent app.

Od **iOS 16** oba extensiony dzielą `ManagedSettingsStore` z main app — można tam czytać i pisać restrykcje (WWDC22 session 110336 „What's new in Screen Time API"). Od iOS 17, 18, 26 **nie pojawiła się żadna dedykowana sesja WWDC o Screen Time API ani żadne nowe pola w `ShieldConfiguration`** — API jest praktycznie zamrożone od 2022 r., potwierdzone brakiem aktualizacji dokumentacji i brakiem sesji WWDC23/24/25.

## 2. `ShieldConfiguration` — co dokładnie da się ustawić

| Element shielda | Czy customizowalne | Limit / uwagi |
|---|---|---|
| `backgroundColor` | Tak (`UIColor?`) | Jeden kolor, bez gradientu. Gradient tylko przez pre-render PNG do `icon`. |
| `backgroundBlurStyle` | Tak (`UIBlurEffect.Style?`) | Wszystkie systemowe: `.systemMaterial`, `.systemThinMaterial`, `.systemThickMaterial`, `.systemUltraThinMaterial` + chrome/dark warianty. `nil` = brak blur. |
| `icon` | Tak (`UIImage?`) | Pojedynczy `UIImage`. **Nie ma oficjalnego limitu w dokumentacji**, praktyka: 512×512–1024×1024 px PNG/JPEG, <200 KB; większe mogą powodować skip-to-default shield. **Nie auto-adaptuje się do dark mode** (Apple Forum thread 720771) — renderować dwa warianty i wybierać przez `UITraitCollection.current.userInterfaceStyle`. |
| `title` | Tak (`ShieldConfiguration.Label?`) | `Label(text: String, color: UIColor)`. **Bez custom font, bez bold/italic, bez multi-style.** System dobiera font i dynamic type. |
| `subtitle` | Tak (`ShieldConfiguration.Label?`) | Jak wyżej. |
| `primaryButtonLabel` | Tak (`ShieldConfiguration.Label?`) | Jeśli `nil` → **system wyświetla domyślny button** (pitfall opisany przez John Baker, Medium 05/2024). |
| `primaryButtonBackgroundColor` | Tak (`UIColor?`) | Tylko kolor, brak ikony w buttonie, brak obramowania. |
| `secondaryButtonLabel` | Tak (`ShieldConfiguration.Label?`) | Jeśli `nil` → **przycisk w ogóle się nie pokazuje** (inne zachowanie niż primary!). |
| SwiftUI view | **Nie** | API przyjmuje wyłącznie UIKit typy. |
| Animacje | **Nie** | Shield to statyczny render. |
| TextField / input | **Nie** | Brak interakcji poza dwoma buttonami. |
| Wiele buttonów (>2) | **Nie** | Max primary + secondary. |
| Obrazy z sieci | **Nie** | Brak API sieciowego w ext. |
| Web view / video / dźwięk / haptics | **Nie** | Żadnych z nich. |
| Dynamic Type / accessibility labels | **Częściowo** | System respektuje Dynamic Type dla Label; `accessibilityLabel` na samym icon nie jest wystawione w API. |
| Dark mode | **Auto dla systemowych kolorów** | `UIColor.label`, `UIColor.systemBackground` adaptują się. Obrazek `icon` — nie. |

Inicjalizator dokładnie: `ShieldConfiguration(backgroundBlurStyle:backgroundColor:icon:title:subtitle:primaryButtonLabel:primaryButtonBackgroundColor:secondaryButtonLabel:)` (źródło: developer.apple.com/documentation/managedsettingsui/shieldconfiguration).

## 3. Czego NIE DA się w shieldzie — potwierdzony budżet

**Potwierdzam każdy punkt z pytania**: brak custom SwiftUI, animacji, TextField, wielokrokowych flow, obrazów z sieci, WKWebView, video, haptics, dźwięku, `Timer`/`NSTimer` (proces jest ubijany, zanim timer zdąży zadziałać), i zadań long-running. „Budżet" customizacji to dokładnie **8 pól struct-u** wymienionych w tabeli wyżej — dwa kolory, jeden blur, jeden UIImage, cztery Label-e — i nic więcej. Nawet „system default button when nil" to niepełna customizacja. Apple Framework Engineer w Apple Developer Forums thread 719905 napisał wprost: *„There's no supported way for your extension to open your main app with the APIs currently available"* — więc z poziomu `ShieldActionDelegate` nie zadziała `UIApplication.shared.open`, `NSExtensionContext.open`, ani `@Environment(\.openURL)`.

## 4. Obejścia ograniczeń stosowane przez Opal, one sec, Jomo, ScreenZen, Brick

**Trick #1 — pre-render UIImage z wypieczoną typografią i brandingiem.** Opal's „Luminaries", „Focus Haiku", „Brutal Insults" i Jomo's „sticker-effect emojis" to niemal na pewno **gotowe pliki PNG w asset catalogu** (albo pobierane z serwera do App Group container), a nie `ShieldConfiguration.Label`. Wzorzec kodu z `UIGraphicsImageRenderer`:

```swift
let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024))
let branded = renderer.image { ctx in
    UIColor(red: 0.96, green: 0.95, blue: 1.0, alpha: 1).setFill()
    ctx.fill(CGRect(origin: .zero, size: CGSize(width: 1024, height: 1024)))
    UIImage(named: "OpalGem")?.draw(at: CGPoint(x: 412, y: 120))
    let para = NSMutableParagraphStyle(); para.alignment = .center
    NSAttributedString(string: "Stay focused\n— Marcus Aurelius",
        attributes: [.font: UIFont(name: "NewYork-Bold", size: 48)!,
                     .foregroundColor: UIColor.label,
                     .paragraphStyle: para])
      .draw(with: CGRect(x: 40, y: 600, width: 944, height: 300),
            options: .usesLineFragmentOrigin, context: nil)
}
try branded.pngData()?.write(to: appGroupURL.appending(path: "shield-icon.png"))
```

Rendering robi się **po stronie main app** (ma pełny font bundle, API sieciowe, SwiftUI `ImageRenderer` z iOS 16+), zapisuje do App Group container, a extension tylko `UIImage(contentsOfFile:)` — żadnego kosztu CPU w ext.

**Trick #2 — deep link do main app przez lokalną notyfikację.** Jedyna zweryfikowana droga otwarcia parent app z shield. Wzorzec stosowany przez one sec (potwierdzony przez Frederika Riedela, twórcę one sec): primary button → z `ShieldActionDelegate` zapisujemy intent do App Group, postujemy Darwin notification, planujemy `UNNotificationRequest` z `userInfo["deeplink"] = "myapp://unlock?token=..."`, zwracamy `.defer`. Użytkownik stuka w notyfikację, main app otwiera się przez custom URL scheme i tam renderuje bogaty SwiftUI.

**Trick #3 — one sec z Shortcuts automation.** Historycznie one sec **w ogóle nie używał ShieldConfiguration** (tylko nowszy „Block" tab używa). Użytkownik ustawiał Personal Automation w Shortcuts: „When app X is opened → Open one sec" → one sec renderuje pełne breathing SwiftUI view (bo to już zwykła aplikacja, nie extension). Minus: gubi się oryginalny deep link notyfikacji.

**Trick #4 — własny tekst wewnątrz `icon: UIImage?` zamiast `title`/`subtitle`.** Pozwala mieć dowolną typografię, wiele stylów, loga, ilustracje — czyli zasadniczo obchodzi limity Label. Opal's quote cards i Jomo's sticker-effect emojis to ten wzorzec.

**Trick #5 — Brick omija problem fizycznie.** NFC puk zamiast przycisku — shield może być minimalny, bo akcja odblokowania dzieje się poza UI (tap telefonem w puk, iOS launch'uje Brick przez background NFC tag reading, Brick czyści `store.shield`).

## 5. `ShieldAction` flow, `.defer` vs `.none` vs `.close`, odliczanie 15s

Semantyka trzech odpowiedzi (developer.apple.com/documentation/managedsettings/shieldactionresponse):

- **`.none`** — „zrób nic, zostaw shield". Używane dla defensywnych `@unknown default` lub gdy chcemy zignorować tap. Shield zostaje w tym samym stanie.
- **`.close`** — „zamknij shielded app, wróć do home screen". Nieodwołalne w tej sesji — użytkownik wychodzi, ale restrykcja dalej działa. Używane dla secondary „Cancel".
- **`.defer`** — **kluczowy trick dla dynamicznego UI**. Apple na WWDC21 session 10123: *„The ability to defer action in the shield is very powerful because it gives the shield the chance to update its appearance while it waits for a signal on how to proceed."* System natychmiast re-woła `configuration(shielding:)` w `ShieldConfigurationDataSource`. Data source czyta zaktualizowany stan z App Group (np. flagę „pending approval" lub timestamp unlock-u) i **zwraca nowy `ShieldConfiguration`**.

**Odliczanie 15s przed odblokowaniem — NIE da się w samym extension** (brak timer-a, proces ubity). Produkcyjny wzorzec:

1. User taps primary „Unlock".
2. `ShieldActionDelegate` zapisuje do App Group: `unlockRequestedAt = Date()`, `unlockTokenID = ...`, fires Darwin notification, schedules `UNNotification` z deeplink-iem `myapp://unlock?token=...`, zwraca `.defer`.
3. User stuka notyfikację → main app otwiera się przez URL scheme → renderuje pełny SwiftUI z 15-sekundowym countdownem, breathing animation, gamifikacją, co chcemy.
4. Po upłynięciu odliczania main app woła `store.shield.applications?.remove(token)` (kluczowe!) i planuje re-lock przez `DeviceActivityCenter.startMonitoring` z `DeviceActivitySchedule` o długości unlock-u.
5. `DeviceActivityMonitorExtension.intervalDidEnd` → `store.shield.applications?.insert(token)` — shield wraca.

**Wymuszenie wpisania zdania** — dokładnie ten sam wzorzec: `TextField` nie istnieje w shield, ale istnieje w main app po deep-linku. Jomo robi to tak dla friction „type a random code". ScreenZen tak samo dla intention.

**API do zwolnienia restrykcji** — `ManagedSettingsStore`:
```swift
let store = ManagedSettingsStore() // lub ManagedSettingsStore(named: .init("unlockSessions"))
store.shield.applications?.remove(token) // pojedynczy token
store.shield.applications = nil          // wszystkie aplikacje
store.clearAllSettings()                 // kompletny reset store-a
```
Od iOS 16 można to wołać z shield action extension — ale czyszczenie przez main app jest pewniejsze (więcej budżetu czasowego).

## 6. Różne shieldy per token i problem „unknown token"

`ShieldConfigurationDataSource` ma **cztery metody do override'u** (Apple doc + John Baker Medium 05/2024):

```swift
override func configuration(shielding application: Application) -> ShieldConfiguration
override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration
override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration
override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration
```

Pitfall: jeśli blokujesz po kategorii, a override'ujesz tylko pierwszy wariant — dostajesz default shield. **Override'uj wszystkie cztery.** Identyfikacja konkretnego tokena: `application.token`, `webDomain.token`, `ActivityCategory.token` — to `Codable` opaque blob-y, stabilne *per ManagedSettingsStore* (z zastrzeżeniem niżej).

**Problem „unknown token" — krytyczny dla produkcji.** Apple czasem podaje token, którego twoja extension nigdy nie widziała. Przyczyny udokumentowane przez Frederika Riedela (one sec) w FB14082790: token pochodzi z innego `ManagedSettingsStore(named:)`, proces extension-a właśnie wstał z czystą pamięcią, albo iOS zrotował tokeny po update-cie (zgłoszone niezależnie przez developerów Opal, ScreenZen, Jomo). Riedel: *„If a fresh, unknown token is provided to the Shield Configuration Delegate there's no way the code can determine the appropriate user interface."*

**Strategia obsługi** (z `kingstinct/react-native-device-activity`, 141⭐):
1. Trzymaj w App Group mapę `familyActivitySelectionId -> [token -> configId]` — każda selekcja ma własne ID, token referencowany pośrednio.
2. Przy lookup: znajdź selekcję która zawiera ten token; prioritetyzuj mniejsze selekcje nad większymi, apps nad kategoriami.
3. **Zawsze miej fallback „unknown token" shield** — generyczny branded shield z napisem „Blocked" + primary „Open [app name]" deep-linkującym do main app gdzie user zarządza (źródło: wszystkie produkcyjne apki mają ten fallback wedle Riedela).

```swift
private func lookupConfig(for token: ApplicationToken) -> ShieldBrand? {
    guard let data = defaults?.data(forKey: "tokenMap"),
          let map = try? JSONDecoder().decode([ApplicationToken: String].self, from: data),
          let brandId = map[token],
          let brandData = defaults?.data(forKey: "brand.\(brandId)") else { return nil }
    return try? JSONDecoder().decode(ShieldBrand.self, from: brandData)
}
```

## 7. Przekazywanie main app → shield przez App Group

**Nazewnictwo App Group jest sztywne**: `group.<bundle-id-main-app>.<suffix>`, np. `group.so.yourapp.shared`. Musi być **dodane do Signing & Capabilities WSZYSTKICH targetów** (main + Config + Action + ActivityMonitor + Widget) i dodatkowo zadeklarowane w Info.plist każdego extension-a w kluczu `AppGroup` dla niektórych SDK (Wellspent).

**Trzy kanały danych** (wzorzec używany łącznie, nie alternatywnie):

**(a) UserDefaults(suiteName:)** — dla małych, gorących danych (flagi, timestamps, mapy token→ID):
```swift
let defaults = UserDefaults(suiteName: "group.so.yourapp.shared")
defaults?.set(try? JSONEncoder().encode(brand), forKey: "brand.default")
```
Limit praktyczny: ~kilka MB total, inaczej start-up extension-a się ciągnie.

**(b) Plik JSON / PNG w `containerURL(forSecurityApplicationGroupIdentifier:)`** — dla cięższych payload-ów (pre-renderowane obrazy shielda, lokalizowane pakiety stringów):
```swift
let url = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.so.yourapp.shared")!
    .appendingPathComponent("shields/\(brandId).png")
```

**(c) Darwin notifications** — sygnał zmiany między procesami (bez payload-u):
```swift
CFNotificationCenterPostNotification(
    CFNotificationCenterGetDarwinNotifyCenter(),
    CFNotificationName("so.yourapp.config.updated" as CFString),
    nil, nil, true)
```
Wzorzec (nonstrict.eu blog, 2023): **App Group jako source of truth, Darwin jako change signal**. Extension re-reads UserDefaults po otrzymaniu powiadomienia. Uwaga z community (MMWormhole, Rizwan Ahmed blog): Darwin bywa flaky od iOS 13 — zawsze duplikować stan w UserDefaults, nie polegać wyłącznie na notyfikacji.

**Co konkretnie zapisać**: branding (primary/secondary colors jako hex strings, background blur style jako raw Int, logo as PNG in container), per-token konfiguracja (custom title/subtitle user-zdefiniowany, motivational message pool z rotacją, aktualne statystyki „saved time today" jako pre-renderowany PNG), pending-unlock state (timestamp żądania, token ID, dla `.defer` flow).

## 8. Lokalizacja shielda

**Extension ma własny bundle** — `NSLocalizedString(key, comment:)` w kodzie extension-a **rezolwuje się do `Bundle.main` extension-a**, nie main app. Dwie opcje:

**Opcja A (zalecana przez John Baker):** Dodaj `Localizable.strings` do membership-u zarówno main app target jak i shield extension target — Xcode skopiuje plik do obu bundle-i. Używaj zwykłego `NSLocalizedString("shield.title", comment: "")`.

**Opcja B (elastyczniejsza):** Main app wybiera lokalizowane stringi (z pełnym dostępem do wszystkich bundle-i i logiki `Locale.current`) i zapisuje do App Group UserDefaults pod kluczem np. `shield.strings.\(Locale.current.identifier)`. Extension odczytuje gotowe stringi. Pozwala na server-sourced copy, A/B testy, dynamiczną aktualizację bez app update-u — preferowane przez większe apki.

Extension widzi `Locale.current` identycznie jak main app (dzielą user locale). `application.localizedDisplayName` dla `Application` parametru jest **zwracane już po lokalizacji systemowej** — nie tłumacz go ręcznie.

## 9. Zmiany w iOS 17 / 18 / 26 — brak zmian w ShieldConfiguration

**To najważniejszy i potencjalnie rozczarowujący fakt tego researchu.** Po sprawdzeniu WWDC21 (10123), WWDC22 (110336), wszystkich sesji 2023/2024/2025 w `developer.apple.com/videos/all-videos/?q=Screen+Time` oraz `q=Family+Controls`, a także release notes iOS 17/18/26:

- **WWDC23, WWDC24, WWDC25 — żadnej dedykowanej sesji o Screen Time API.** Tylko user-facing zmiany w Screen Time (np. iOS 26: App Limits można ustawić na 0 minut, Screen Time passcode chroni third-party permissions).
- **Brak nowych pól w `ShieldConfiguration`.** Wciąż 8 pól, UIKit-only.
- **Brak SwiftUI support w shieldach.** Brak nowych typów buttonów.
- **Brak nowych case'ów w `ShieldActionResponse`** — developerzy zgłosili enhancement request (FB17261679) o `.openParentApp`, Apple nie dodało.
- **Regresje w iOS 26 zgłaszane społecznie**: DeviceActivity thresholds odpalają natychmiast zamiast w interwałach, zwiększona niestabilność tokenów. Nie wpływają bezpośrednio na `ShieldConfiguration`, ale ważne dla architektury unlock/re-lock.
- **iOS 16 (WWDC22) pozostaje ostatnim istotnym update-m** — wtedy indywidualna autoryzacja (bez konta rodzica), współdzielenie `ManagedSettingsStore` między host a extension, wiele named stores.

**Implikacja dla Opal clone'a**: nie czekaj na Apple, architektura z App Group + deep-link + pre-render obrazów jest oficjalnie trwała. Będzie tak samo w iOS 27.

## Anatomia produkcyjnych shieldów — rekonstrukcja z App Store

**Opal** (opalapp.com/help/what-are-block-screens): białe/kremowe tło, centralny „quote card" jako pre-renderowany PNG (zawierający ilustrację + tekst z custom fontem — co jest niemożliwe w Label). Motywy Pop Culture / Focus Haiku / Luminaries / Offline Ideas / AI Personalities (Brutal Insults, Jane Austen) = **biblioteka bitmap shipowana w bundle lub pobierana z serwera do App Group container**. Primary „Use [app]" → `.defer` + notyfikacja → main app decrementuje Open Limit quota i czyści shield. Secondary dismiss = `.close`. Deep Focus mode = primary button jako system default (nieaktywny) albo returnuje `.none`.

**one sec**: historycznie omija shield przez Shortcuts Personal Automation — tap app X otwiera one sec, gdzie breathing animation jest **zwykłym SwiftUI View w main app**. Nowszy „Block" tab używa prawdziwego shielda, minimalnego, który deep-linkuje z powrotem do one sec. Potwierdzone przez founderowskie tweety Frederika Riedela.

**Jomo** (help.jomo.so): duża „sticker-effect emoji" wyraźnie pre-renderowana (Jomo help explicitnie opisuje „sticker-like effect on the emoji" jako recognition feature), title „Jomo-Ing", subtitle „Blocked by [rule] on Jomo". Primary „Unlock" → deep link → friction tasks w main app (wait timer, copy random code, reason, QR/NFC scan, photo with AI, math problem, mirror, HealthKit actions). 150+ block screens = library PNG.

**ScreenZen** (changelog 2025: „Shield Enhancements - Launch interventions directly from the shield screen with an improved unlock flow"): dark non-stimulating background, customizable prompt text („Is this important?", „What are you seeking?"), countdown 5s–60s+ → niemożliwy w shield, więc **tap primary → deep link → countdown w main app**. Odds-that-app-unlocks (random refuse) — logika w main app przed `store.shield.applications?.remove`.

**Brick**: minimalny shield z tekstem „Your phone is currently Bricked", **bez primary button do bypass** (no way to unlock bez fizycznego tapa NFC). Secondary = home screen. Cała interakcja fizyczna, shield serves as information panel.

## Minimalny działający kod Swift

**ShieldConfigurationExtension.swift** (target: Shield Configuration Extension):

```swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let defaults = UserDefaults(suiteName: "group.so.yourapp.shared")
    private let containerURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.so.yourapp.shared")!

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let brand = loadBrand(for: application.token)
        return makeConfig(title: brand?.title ?? "Time to focus",
                         subtitle: "\(application.localizedDisplayName ?? "This app") is blocked",
                         brand: brand)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        let brand = loadBrand(for: category.token)
        return makeConfig(title: brand?.title ?? "Category blocked",
                         subtitle: "\(category.localizedDisplayName ?? "Apps") paused",
                         brand: brand)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfig(title: "Website blocked",
                   subtitle: webDomain.domain ?? "This site is paused",
                   brand: loadBrand(for: webDomain.token))
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfig(title: "Website blocked",
                   subtitle: webDomain.domain ?? "This site is paused",
                   brand: loadBrand(for: category.token))
    }

    // MARK: - Helpers

    private func makeConfig(title: String, subtitle: String, brand: ShieldBrand?) -> ShieldConfiguration {
        let primary = brand?.primaryColor ?? UIColor.label
        let bg = brand?.backgroundColor ?? UIColor.systemBackground

        let iconURL = containerURL.appendingPathComponent("shields/\(brand?.id ?? "default").png")
        let icon = UIImage(contentsOfFile: iconURL.path)
              ?? UIImage(systemName: "lock.shield.fill")

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: bg,
            icon: icon,
            title: .init(text: title, color: primary),
            subtitle: .init(text: subtitle, color: primary.withAlphaComponent(0.7)),
            primaryButtonLabel: .init(text: "Unlock for 60s", color: .white),
            primaryButtonBackgroundColor: primary,
            secondaryButtonLabel: .init(text: "Close", color: primary)
        )
    }

    private func loadBrand<T: Codable & Hashable>(for token: T) -> ShieldBrand? {
        guard let mapData = defaults?.data(forKey: "tokenMap"),
              let map = try? JSONDecoder().decode([T: String].self, from: mapData),
              let brandId = map[token],
              let brandData = defaults?.data(forKey: "brand.\(brandId)") else {
            return try? defaults?.data(forKey: "brand.default")
                .flatMap { try JSONDecoder().decode(ShieldBrand.self, from: $0) }
        }
        return try? JSONDecoder().decode(ShieldBrand.self, from: brandData)
    }
}

struct ShieldBrand: Codable {
    let id: String
    let title: String
    let primaryColorHex: String
    let backgroundColorHex: String
    var primaryColor: UIColor { UIColor(hex: primaryColorHex) }
    var backgroundColor: UIColor { UIColor(hex: backgroundColorHex) }
}
```

**ShieldActionExtension.swift** (target: Shield Action Extension):

```swift
import ManagedSettings
import UIKit
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {

    private let defaults = UserDefaults(suiteName: "group.so.yourapp.shared")
    private let store = ManagedSettingsStore()

    override func handle(action: ShieldAction,
                        for application: ApplicationToken,
                        completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            requestUnlock(tokenData: (try? JSONEncoder().encode(application)) ?? Data(),
                          displayName: "app",
                          completion: completionHandler)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.none)
        }
    }

    override func handle(action: ShieldAction,
                        for webDomain: WebDomainToken,
                        completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            requestUnlock(tokenData: (try? JSONEncoder().encode(webDomain)) ?? Data(),
                          displayName: "site", completion: completionHandler)
        case .secondaryButtonPressed: completionHandler(.close)
        @unknown default: completionHandler(.none)
        }
    }

    override func handle(action: ShieldAction,
                        for category: ActivityCategoryToken,
                        completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            requestUnlock(tokenData: (try? JSONEncoder().encode(category)) ?? Data(),
                          displayName: "category", completion: completionHandler)
        case .secondaryButtonPressed: completionHandler(.close)
        @unknown default: completionHandler(.none)
        }
    }

    // MARK: - Rich unlock flow via deep link

    private func requestUnlock(tokenData: Data, displayName: String,
                               completion: @escaping (ShieldActionResponse) -> Void) {
        let requestId = UUID().uuidString
        defaults?.set(tokenData, forKey: "pendingUnlock.\(requestId).token")
        defaults?.set(Date(), forKey: "pendingUnlock.\(requestId).date")

        // Darwin notification — budzimy main app jeśli w tle
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("so.yourapp.unlockRequested" as CFString),
            nil, nil, true)

        // Local notification — user stuka, main app się otwiera
        let content = UNMutableNotificationContent()
        content.title = "Complete unlock"
        content.body = "Tap to finish unlocking \(displayName)"
        content.userInfo = ["deeplink": "yourapp://unlock?requestId=\(requestId)"]
        content.sound = nil
        let req = UNNotificationRequest(identifier: requestId, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { _ in
            completion(.defer) // shield zostaje; data source może re-render „pending unlock"
        }
    }

    // Opcjonalny direct unlock bez main app (dla quick 60s feature):
    private func directUnlock(token: ApplicationToken,
                              completion: @escaping (ShieldActionResponse) -> Void) {
        store.shield.applications?.remove(token)
        // Zaplanuj re-lock: przez DeviceActivityCenter w main app (tu brak dostępu)
        // więc zapisujemy marker, main app przy najbliższym uruchomieniu zaplanuje monitor
        defaults?.set(Date(), forKey: "needsRelockScheduling")
        completion(.close)
    }
}
```

## Wzorzec „rich shield" — architektura krok po kroku

1. **Xcode setup**: Main app + 3 extension targets (`ShieldConfigurationExtension`, `ShieldActionExtension`, `DeviceActivityMonitorExtension`). W każdym: App Group `group.so.yourapp.shared` w Signing & Capabilities + entitlement `com.apple.developer.family-controls`. URL scheme `yourapp://` w `CFBundleURLTypes` main app.
2. **Shared Swift Package** z modelami (`ShieldBrand`, `UnlockRequest`, `TokenIndex`), wrapperem `SharedStore` na UserDefaults(suiteName:), `DarwinNotificationManager`.
3. **User konfiguruje block**: main app pokazuje `FamilyActivityPicker`, dostaje `FamilyActivitySelection`, zapisuje selekcję + mapę token→brandId do App Group, wywołuje `store.shield.applications = selection.applicationTokens`.
4. **Main app pre-renderuje shield icon**: `UIGraphicsImageRenderer` lub SwiftUI `ImageRenderer` (iOS 16+) → PNG do `containerURL/shields/<brandId>.png`. Render może być wykonywany przy każdej zmianie brandingu lub raz na dzień z ze świeżymi statystykami („saved time today: 2h 14m" baked into image).
5. **User otwiera blocked app** → iOS budzi `ShieldConfigurationExtension` → czyta brand z App Group → zwraca `ShieldConfiguration` z pre-renderowanym icon i labelami „Unlock for 60s" / „Close".
6. **User taps primary „Unlock"** → `ShieldActionExtension` zapisuje `pendingUnlock.<uuid>` do App Group, posts Darwin notification, planuje `UNNotification` z deep-linkiem `yourapp://unlock?requestId=<uuid>`, zwraca `.defer`.
7. **User taps notyfikację** → iOS otwiera main app przez URL scheme → `.onOpenURL` w SwiftUI rozpoznaje `requestId`, ładuje pendingUnlock z App Group.
8. **Main app renderuje rich UI**: SwiftUI View z 15-sekundowym countdownem (`TimelineView`), pytaniem „czy na pewno?", wymaganym TextField-em „Type: I will use this mindfully", breathing animation, gamifikacją (streak counter), AI-generated motivational message z serwera.
9. **User kończy friction** → main app woła `store.shield.applications?.remove(token)` i `DeviceActivityCenter().startMonitoring(.quickUnlock, during: DeviceActivitySchedule(intervalStart: now, intervalEnd: now+60s, repeats: false))`.
10. **Po 60s**: `DeviceActivityMonitorExtension.intervalDidEnd` → `store.shield.applications?.insert(token)` → shield wraca.
11. **Anty-abuse**: zlicz unlock-i per dzień w App Group, blokuj primary button przy przekroczeniu limitu (returning `.none` z shield action albo pokazuj shield bez primary label-a).

## Taksonomia trików UX z produkcyjnych apek

- **Opal — AI Personalities**: Brutal Insults / Dad jokes / Jane Austen — tekst generowany server-side, zaciągany do main app, **pre-renderowany do PNG** z unikalną typografią per personality, podstawiany jako `ShieldConfiguration.icon`. Każdego dnia inny quote → visual freshness bez zmiany kodu extension-a.
- **Opal — Emergency Pass (1/week)**: licznik w App Group, primary button staje się nieaktywny (system default / `.none` response) poza tym jednym tygodniowym oknem.
- **Opal — App Uninstall Protection**: `ManagedSettingsStore.application.denyAppRemoval = true` na czas aktywnej sesji, żeby user nie skasował Opala.
- **one sec — Shortcuts redirect**: Personal Automation w iOS Shortcuts, „when X opens → Open one sec". Omija shield API całkowicie.
- **one sec — Mirror intervention**: AVFoundation w main app, front camera, 10s look-at-self → dopiero wtedy unlock button się aktywuje.
- **one sec — Follow the dot**: SwiftUI animation + DragGesture w main app.
- **Jomo — Sticker emoji**: każde emoji renderowane z puffy-sticker effect przez `UIGraphicsImageRenderer` po stronie main app, zapisane do App Group. 150+ assets w library.
- **Jomo — AI photo validation**: user robi foto (np. „touched grass"), main app wysyła do LLM vision API, po weryfikacji `store.shield.applications?.remove`.
- **Jomo — HealthKit actions**: „walk 500 steps to earn unlock" — main app query-uje `HKStatisticsQuery` dla `HKQuantityTypeIdentifier.stepCount`, po spełnieniu warunku zwalnia restrykcję.
- **ScreenZen — progressive countdown**: każdy kolejny unlock tego dnia wydłuża wait timer o +30s. Licznik w App Group, UI w main app po deep-linku.
- **ScreenZen — random refusal**: `Bool.random(probability: 0.2)` w main app — 20% szans że „dice" zabroni unlock-u nawet po całej friction, re-lock natychmiast.
- **ScreenZen — Replacement Apps**: primary button w shieldzie Instagrama deep-linkuje do main app, który otwiera Duolingo i uruchamia `DeviceActivityMonitor` na 5 min — dopiero wtedy Instagram się odblokowuje.
- **Brick — NFC puk**: fizyczne oddzielenie klucza. `CoreNFC` w main app, `store.shield.applications = nil` po skanie. Pełna immunizacja na shield UI limity.
- **Brick — Strict Mode przeciw Settings-toggle**: Shortcuts automation „when Settings opens → Open Brick" — zamyka lukę wyłączania Screen Time.
- **Uniwersalny trick — baked stats**: pre-renderuj „You saved 2h 14m today" do PNG po stronie main app raz dziennie, podstawiaj jako `icon`. Shield wygląda live, nawet gdy data source jest statyczna.
- **Uniwersalny trick — dark/light dual render**: pre-renderuj dwa PNG-i, w `configuration(shielding:)` wybieraj przez `UITraitCollection.current.userInterfaceStyle` bo `icon` sam z siebie nie adaptuje się do trybu.

## Źródła

**Apple docs**: developer.apple.com/documentation/managedsettingsui (ShieldConfiguration, ShieldConfigurationDataSource), developer.apple.com/documentation/managedsettings (ShieldActionDelegate, ShieldAction, ShieldActionResponse, ManagedSettingsStore), developer.apple.com/documentation/familycontrols (FamilyActivityPicker, AuthorizationCenter), developer.apple.com/documentation/deviceactivity (DeviceActivityMonitor, DeviceActivitySchedule).

**WWDC**: session 10123 „Meet the Screen Time API" (WWDC21) — definiuje architekturę; session 110336 „What's new in Screen Time API" (WWDC22) — iOS 16 shared store, individual authorization; **brak dedykowanych sesji WWDC23/24/25**.

**Apple Developer Forums**: thread 719905 (no way to open parent app — potwierdzone przez Apple DTS), thread 772282 (no network calls in shield extension — „Eskimo"), thread 720771 (icon dark-mode issue), thread 725168 (customizacja nie aplikowana), thread 707144 (`.defer` re-queries data source), thread 717858 (Xcode templates).

**GitHub**: github.com/kingstinct/react-native-device-activity (141⭐ — najpełniejsza produkcyjna implementacja), github.com/Inakitajes/kairos (kompletna iOS 26 app „Soul" na App Store), github.com/CoffeeNaeriRei/ScreenTime_Barebones (czyste przykłady ShieldConfiguration), github.com/christianp-622/ScreenBreak, github.com/ioridev/flutter_screentime, github.com/nlbb/wellspent-sdk-docs (architektura komercyjnego SDK), github.com/mutualmobile/MMWormhole (IPC reference).

**Blogi**: riedel.wtf/state-of-the-screen-time-au-2024 (Frederik Riedel, twórca one sec — **must-read, najautorytatywniejsze** źródło o bugach i obejściach), medium.com/@B4k3R (John Baker, Stryde — ShieldConfigurationDataSource walkthrough + App Group setup), pedroesli.com/2023-11-13-screen-time-api/ (Pedro Esli — pełny unlock-for-N-minutes pattern z DeviceActivity), medium.com/@jc_builds (JC — SwiftUI blocker tutorial), medium.com/@juliusbrussee (architektura BlockingStrategy protocol), nonstrict.eu/blog/2023/darwin-notifications-app-extensions/ (Darwin IPC), oboe.com/learn/building-an-ios-content-filter-app-1n329rm/managedsettings-and-shielding-4, tutorials.one-sec.app/screen-time-api-issues, donnywals.com/handling-deeplinks-in-your-app (deeplink handling).

**App Store / marketing**: opalapp.com/help/what-are-block-screens, community.opal.so, help.jomo.so, jomo.so/blog, one-sec.app, screenzen.co, getbrick.app. ProductHunt / Cybernews / NBC Select reviews dla screenshotów shieldów Brick.

## Konkluzja — co musisz zapamiętać budując Opal clone

**Shield jest gate-em, nie doświadczeniem** — każda animacja, każdy `TextField`, każde countdown musi dziać się w main app po deep-linku przez `.defer` + local notification + URL scheme. Akceptuj to od dnia pierwszego, zaprojektuj architekturę na ten wzorzec. **Pre-renderowanie bitmap to killer feature** — wszystko czego Label nie obsłuży (custom fonty, multi-style text, loga, ilustracje, statystyki) baked-uj do PNG po stronie main app i serwuj jako `icon`. **Unknown token fallback jest obowiązkowy** — produkcyjne apki zgłaszały to niezależnie, Apple rotuje/re-wystawia tokeny w niedeterministycznych przypadkach; bez fallback-u user zobaczy default iOS shield zamiast twojego. **App Group + Darwin notification to jedyny kanał IPC** — trzymaj stan jako source of truth w UserDefaults(suiteName:), używaj Darwin jako change-signal, nigdy odwrotnie. **API jest zamrożone od iOS 16** — nie czekaj na WWDC26 z nadzieją na SwiftUI w shieldach; architektura deep-linkowa jest docelowa, nie tymczasowa. I ostatnie, często pomijane: **zabudżetuj 4–6 tygodni na Apple approval** każdego z trzech bundle ID-ów extension-ów zanim wyślesz na TestFlight — to nie jest instant enable.