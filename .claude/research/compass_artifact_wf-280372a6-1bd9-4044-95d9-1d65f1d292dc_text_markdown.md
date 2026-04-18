# Komunikacja main app ↔ extensions w klonie Opala na iOS 26

**Najważniejszy wniosek:** dla on-device klona Opala zbuduj architekturę wokół **pojedynczego źródła prawdy w App Group**, z **main app jako writerem konfiguracji** i **extensionami jako read-mostly konsumentami**, komunikujacymi zmiany przez **atomowy zapis pliku + Darwin notification**. Tokenów (`ApplicationToken` itd.) nie traktuj jako stabilnego klucza — **każdy rekord trzymaj pod własnym UUID**, a token obok jako „best-effort pointer", bo od iOS 17.5 aż po iOS 26.3.1 Apple ma potwierdzony (acknowledged by DTS) bug rotacji tokenów (FB14082790 / FB14237883 / FB18353106). To zmienia wszystko — to nie jest problem brzegowy, to stała architektoniczna. Dodatkowo: DeviceActivityMonitor ma **6 MB RAM** limit (zero third-party SDK), a DeviceActivityReport ma **sandbox uniemożliwiający eksport danych** — jego wyniki nigdy nie wypłyną poza proces raportu (potwierdzone przez Quinn'a „The Eskimo" z Apple DTS, forum thread 728044). WWDC 2023/24/25 **nie miało** sesji poświęconej Screen Time API — API jest zamrożone od iOS 16, a iOS 26 dodaje głównie user-facing rzeczy (Screen Time Lock dla 3rd-party przez iOS 26.4, Declared Age Range) i wprowadza kolejne regresje. Buduj tak, żeby działać *mimo* API, nie *dzięki* niemu.

---

## A. Diagram architektury komunikacji

```
                 ┌─────────────────────────────────────────────────┐
                 │     App Group: group.com.company.opalclone      │
                 │  ┌────────────┐  ┌──────────────┐  ┌─────────┐  │
                 │  │ selection  │  │ profiles.db  │  │ events/ │  │
                 │  │  .json     │  │ (SwiftData)  │  │ *.ndjson│  │
                 │  │ (+coord)   │  │   WAL mode   │  │ append- │  │
                 │  └─────▲──────┘  └──────▲───────┘  │  only   │  │
                 │        │                │          └────▲────┘  │
                 │        │  Darwin notif  │               │       │
                 │   "com.opalclone.selection.changed"     │       │
                 │  "com.opalclone.profile.changed"        │       │
                 │  "com.opalclone.events.appended"        │       │
                 │      + Keychain (TEAMID.group…)         │       │
                 └────────┬──────────────┬──────┬─────────┬┴───────┘
                          │ R/W          │ R    │ R       │ W(append)
                          │              │      │         │
   ┌──────────────────────┴──┐  ┌────────┴──┐  │   ┌──────┴───────────────┐
   │      MAIN APP           │  │ ShieldCfg │  │   │ DeviceActivityMonitor│
   │  (jedyny writer konfigu)│  │ Extension │  │   │      Extension       │
   │  - FamilyActivityPicker │  │ ≤6 MB     │  │   │ 6 MB RAM, <5 s CPU   │
   │  - SessionConfig        │  │ cached    │  │   │ intervalDid{Start,   │
   │  - ManagedSettingsStore │  │ by system │  │   │   End}, event thres. │
   │  - konsumuje events     │  │ RO (read) │  │   │ pisze event+counter  │
   └──────────────┬──────────┘  └───────────┘  │   └──────────────────────┘
                  │ post()                      │
                  │ Darwin notif ──────────────►│         ▲
                  │                             │         │ W(unlock count)
                  │                             │   ┌─────┴─────────────────┐
                  │                             │   │ ShieldAction Extension│
                  │                             │   │ 6 MB, synchronous     │
                  │                             │   │ .close/.defer/.none   │
                  │                             │   │ ❌ NIE może openParent│
                  │                             │   │ ✅ może local notif   │
                  │                             │   └───────────────────────┘
                  │                             │
                  │                      ┌──────┴─────────────────┐
                  │                      │ DeviceActivityReport   │
                  │                      │ Extension (SwiftUI)    │
                  │                      │ ~50–100 MB RAM         │
                  │                      │ ⚠️ SANDBOX: READ-ONLY  │
                  │                      │   NIE pisze do App     │
                  │                      │   Group, NIE posyła    │
                  │                      │   Darwin, NIE do netu. │
                  │                      │ Renderuje tylko view.  │
                  │                      └────────────────────────┘
                  │
                  └─► ManagedSettings.ManagedSettingsStore(named:) ──► iOS system shield
                                                                            │
                                                                            ▼
                                                            User próbuje otworzyć apkę →
                                                            iOS pokazuje Shield (wywołuje
                                                            ShieldCfg ▲ i ShieldAction ▲)
```

**Kluczowe reguły kierunkowości:**

- **Main app → wszystkie extensiony:** przez pliki w App Group + JSON/SwiftData + Darwin signal „re-read". Jedyny kierunek, który Apple w pełni wspiera.
- **DeviceActivityMonitor → main app:** tylko **pośrednio**, przez append-only event log w App Group. Main app konsumuje przy następnym foreground. Darwin notification posyła sygnał „coś doszło", ale main app zobaczy go tylko jeśli akurat żyje.
- **ShieldAction → main app:** **NIE MA** wspieranego sposobu otworzenia aplikacji rodzica (FB15079668, otwarty od 2023). Workaround: `UNUserNotificationCenter` schedule local notification → user tapuje → app się otwiera. Stosuje to one sec, Jomo, AppLocker.
- **DeviceActivityReport → cokolwiek poza sobą:** **niemożliwe.** Sandbox blokuje wszystko (potwierdzone przez Apple DTS, Quinn, forum thread 728044): UserDefaults, pliki, Darwin, sieć. Widok raportu żyje i umiera wewnątrz procesu rozszerzenia.
- **Extension ↔ Extension:** nie istnieje w praktyce. Komunikują się przez dysk w App Group, nigdy bezpośrednio.

---

## B. Rekomendacja stacka persystencji

Dobór nośnika idzie według trzech osi: **ile danych**, **kto pisze**, **jak często extensiony czytają**.

| Typ danych | Nośnik | Uzasadnienie |
|---|---|---|
| **FamilyActivitySelection (aktywny profil)** | `selection.json` w App Group container + `NSFileCoordinator` + `.atomic` write + `JSONEncoder` | Dane kilka–kilkadziesiąt KB, czyta każdy extension, pisze main app rzadko. **JSON, nie Plist** — `PropertyListEncoder` gubi `includeEntireCategory=true` (forum 721973, richard.dz, sierpień 2024). Plik jest czytelny dla wszystkich 4 extensionów, atomowy rename zapewnia spójność, coordinator blokuje read gdy trwa write. |
| **Lista profili + metadane (nazwy, UUID, szczegóły sesji)** | SwiftData, `ModelConfiguration(groupContainer: .identifier("group.…"), cloudKitDatabase: .none)` (iOS 18+ API) | Ustrukturyzowane, wiele rekordów, relacje. iOS 18 wprowadziło czysty `groupContainer:` API; dziedziczone iOS 17 problemy z CloudKit nie dotyczą on-device (`cloudKitDatabase: .none`). Extension instancjonuje `ModelContainer` per wywołanie i zapisuje przed return. |
| **Konfiguracja sesji (czas, strict mode, snooze)** | `UserDefaults(suiteName: "group.…")` + Codable blob lub osobne klucze | Mała struktura (<1 KB), prostota odczytu w 6 MB extensionie, brak ceremoniału NSFileCoordinator. Pojedynczy klucz UserDefaults jest atomowy (cfprefsd serializuje). |
| **Stan streaków (daily/weekly count, last-broken-date)** | `UserDefaults(suiteName:)` — pojedyncze klucze | Małe scalary, pisane rzadko, czytane często przez ShieldConfiguration do personalizacji komunikatu („8 day streak — don't break it now"). |
| **Licznik odblokowań per sesja / per app** | Append-only NDJSON w `events/YYYY-MM-DD.ndjson` + `JSONEncoder` | ShieldAction pisze event `{"ts": …, "token": <base64>, "profileId": <uuid>, "action": "bypass"}`. Brak race'ów — każdy extension dopisuje do końca pliku przez `FileHandle.write(contentsOf:)` z `O_APPEND` (POSIX atomowe dla <PIPE_BUF bajtów). Main app drenuje przy foreground, agreguje do SwiftData. Wariant „event sourcing" odporny na crash extensionu mid-write. |
| **Branding shielda (title, message, color, custom image)** | `shield-branding.json` w App Group + lokalnie spakowane obrazy w main app bundle (dostępne dla extensionu via `Bundle.main.url` wewnątrz extensionu — ext ma własny bundle, więc ładuj z shared containera) | ShieldConfiguration ładuje przy każdej inwokacji. Zapis dużych `UIImage` jako Data w UserDefaults jest antywzorcem (balonowanie plist, wolny read). Obrazy: `png/jpeg` w container/Library/ShieldAssets/, path przekazany w JSONie. |
| **User preferences (motywacja, theme, onboarding state)** | `UserDefaults(suiteName:)` | Klasyczny use-case — małe klucze, wszystkie extensiony mogą potrzebować themów (tak, shield respektuje dark mode). |
| **Session log / history (archiwum dla UI statystyk)** | SwiftData (ta sama baza co profile, osobny model `SessionRecord`) | Zapytania, agregacje, sortowanie — relacyjna forma, mała baza SQLite w App Group z WAL. Historically-sound. |
| **Wrażliwe tokeny (subskrypcja RC, passcode hash, paired-accountability-partner key)** | Keychain access group `TEAMID.group.com.company.opalclone` z `kSecAttrAccessibleAfterFirstUnlock` | Przetrwa reinstall, szyfrowane hardware'owo, czytelne z extensionów które bywają odpalane pre-unlock. Na iOS App Group automatycznie daje valid keychain access group (Quinn, forum 133677) — nie musisz dodawać osobnego entitlementu `keychain-access-groups` chyba że chcesz osobną grupę. |
| **Debug logs / diagnostyka** | `os.Logger(subsystem: bundleId, category: "<ext-name>")` — tylko unified logging | `print()` nie ssie się z extensionu. OSLog strumień czytasz w Console.app filtrując po subsystem. Do dysku zapisuj tylko **counters**, nie pełne logi (6 MB cap). |
| **Screen Time totals (minuty dziś w wybranych apkach)** | **zostają WEWNĄTRZ DeviceActivityReport extension** | Nie da się ich eksportować. Jeśli chcesz je w main app do dashboardu — renderujesz main-app-side ten sam `DeviceActivityReport` jako osobny view i akceptujesz, że UI main appa nie ma dostępu do surowych liczb, tylko do pixeli. |
| **Flaga „repair needed" (po unknown-token)** | `UserDefaults(suiteName:)` bool + lista niespasowanych tokenów | ShieldConfiguration zapisuje gdy wpadnie token spoza cache'u; main app przy foreground sprawdza flagę i pokazuje banner „Re-select your blocked apps". |

---

## C. Produkcyjny snippet — zapis/odczyt FamilyActivitySelection

Poniższy kod pokrywa: atomowy write, file coordination, dekodowanie z obsługą corruptu, Darwin notification cross-process, integrację z `ManagedSettingsStore`. Gotowe do wklejenia do projektu Xcode 16+ / iOS 26 SDK. Shared target framework dla wszystkich 5 targetów.

```swift
// SharedKit/SelectionStore.swift  (framework/target shared z main app + 4 extensionami)
import Foundation
import FamilyControls
import ManagedSettings
import os

public enum SelectionStoreError: Error {
    case containerUnavailable
    case corrupted(underlying: Error)
    case coordination(NSError)
    case writeFailed(Error)
}

public enum SelectionStore {
    public static let appGroupID = "group.com.company.opalclone"
    public static let fileName   = "selection.v1.json"
    public static let darwinChangeName = "com.opalclone.selection.changed" as CFString

    private static let log = Logger(subsystem: "com.company.opalclone",
                                    category: "SelectionStore")

    private static var fileURL: URL {
        get throws {
            guard let base = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID) else {
                throw SelectionStoreError.containerUnavailable
            }
            return base.appendingPathComponent(fileName, isDirectory: false)
        }
    }

    // MARK: - WRITE (main app only; extensions should not call)

    public static func write(_ selection: FamilyActivitySelection) throws {
        let url  = try fileURL
        // JSONEncoder — NIE PropertyListEncoder (bug z includeEntireCategory, forum 721973).
        let data = try JSONEncoder().encode(selection)

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordErr: NSError?
        var writeErr: Error?

        coordinator.coordinate(writingItemAt: url,
                               options: .forReplacing,
                               error: &coordErr) { coordURL in
            do {
                // .atomic => tempfile + rename(2), POSIX-atomic na APFS.
                try data.write(to: coordURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch { writeErr = error }
        }

        if let e = coordErr { throw SelectionStoreError.coordination(e) }
        if let e = writeErr { throw SelectionStoreError.writeFailed(e) }

        log.info("selection written, bytes=\(data.count, privacy: .public)")
        postChangeNotification()
    }

    // MARK: - READ (any process)

    public static func read() -> FamilyActivitySelection {
        do {
            return try readThrowing()
        } catch {
            log.error("read failed, returning empty: \(String(describing: error), privacy: .public)")
            // Fallback: pusta selekcja. Extension NIGDY nie może crashować
            // bo iOS zabije go i user dostanie default "Restricted" shield.
            return FamilyActivitySelection(includeEntireCategory: true)
        }
    }

    public static func readThrowing() throws -> FamilyActivitySelection {
        let url = try fileURL
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordErr: NSError?
        var result: FamilyActivitySelection?
        var readErr: Error?

        coordinator.coordinate(readingItemAt: url,
                               options: .withoutChanges,
                               error: &coordErr) { coordURL in
            do {
                let data = try Data(contentsOf: coordURL)
                result   = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            } catch let e as DecodingError {
                readErr = SelectionStoreError.corrupted(underlying: e)
                // Opcjonalnie: backup corrupted file dla post-mortem.
                try? FileManager.default.moveItem(
                    at: coordURL,
                    to: coordURL.appendingPathExtension("corrupted-\(Int(Date().timeIntervalSince1970))"))
            } catch { readErr = error }
        }

        if let e = coordErr { throw SelectionStoreError.coordination(e) }
        if let e = readErr  { throw e }
        guard let r = result else {
            return FamilyActivitySelection(includeEntireCategory: true)
        }
        return r
    }

    // MARK: - Darwin notification (cross-process "poke")

    public static func postChangeNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinChangeName),
            nil, nil, true)
    }

    /// Wywołuj z main app. Darwin notif **nie obudzi** usypionych extensionów
    /// — działa tylko jeśli proces już żyje.
    public static func observeChanges(_ handler: @escaping () -> Void) -> AnyObject {
        let observer = DarwinObserver(handler: handler, name: darwinChangeName)
        observer.start()
        return observer
    }
}

// Helper klasa obsługująca C-callback z Darwin center.
final class DarwinObserver {
    private let handler: () -> Void
    private let name: CFString
    init(handler: @escaping () -> Void, name: CFString) {
        self.handler = handler; self.name = name
    }
    func start() {
        let ctx = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            ctx, { (_, obsPtr, _, _, _) in
                guard let p = obsPtr else { return }
                let me = Unmanaged<DarwinObserver>.fromOpaque(p).takeUnretainedValue()
                DispatchQueue.main.async { me.handler() }
            }, name, nil, .deliverImmediately)
    }
    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    }
}
```

**Użycie po stronie main app:**

```swift
// MainApp.swift
import FamilyControls
@MainActor
func saveUserSelection(_ selection: FamilyActivitySelection) {
    do {
        try SelectionStore.write(selection)
        // Zastosuj na store'ach natychmiast.
        let store = ManagedSettingsStore(named: .init("opal.main"))
        store.clearAllSettings()     // ważne: unikaj "token movement bug" FB14237883
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.webDomains   = selection.webDomainTokens.isEmpty
            ? nil : selection.webDomainTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    } catch {
        // Pokaż banner „Nie udało się zapisać, spróbuj ponownie"
        Logger(subsystem: "com.company.opalclone", category: "UI")
            .error("save failed: \(String(describing: error))")
    }
}
```

**Użycie w DeviceActivityMonitor extension:**

```swift
// DeviceActivityMonitorExtension/Monitor.swift
import DeviceActivity
import ManagedSettings
import FamilyControls

final class Monitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: .init("opal.main"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let selection = SelectionStore.read()      // NIGDY nie rzuca
        store.clearAllSettings()
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        // …analogicznie kategorie, webDomains
        EventLog.append(.sessionStarted(activity: activity.rawValue))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.clearAllSettings()
        EventLog.append(.sessionEnded(activity: activity.rawValue))
        // WAŻNE: intervalDidEnd jest często gubione (FB13696022 na iOS 17+).
        // Belt-and-suspenders: dodaj rezerwowy UNCalendarNotificationTrigger
        // w main app który też wyczyści store gdy sesja się skończy.
    }
}
```

**Użycie w ShieldConfiguration extension:**

```swift
// ShieldConfigurationExtension/Config.swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding app: Application) -> ShieldConfiguration {
        let selection = SelectionStore.read()
        let knownTokens = selection.applicationTokens
        if let t = app.token, knownTokens.contains(t) {
            return brandedShield(for: t)
        }
        // UNKNOWN TOKEN — zobacz sekcję F.
        UnknownTokenLog.mark(app.token)
        return genericRepairShield()
    }
    // … analogicznie webDomain, applicationCategory
}
```

---

## D. Checklist setupu App Groups dla 4-targetowego projektu (Xcode 16+ / iOS 26 SDK)

**Krok 1 — Developer Portal: App IDs.** Utwórz 5 identyfikatorów:

- `com.company.opalclone` (main)
- `com.company.opalclone.monitor`, `.shieldconfig`, `.shieldaction`, `.report`

Extension bundle ID **musi być prefix-match** container appa (Apple egzekwuje).

**Krok 2 — App Group identyfikator.** Utwórz `group.com.company.opalclone`. **Nazwa musi zaczynać się literalnym prefiksem `group.`** (Quinn, forum 718126). Na dysku pełne ID to `TEAMID.group.com.company.opalclone`.

**Krok 3 — Capabilities na App ID.** Każdy z 5 App IDs dostaje: **App Groups** (przypisz `group.com.company.opalclone`) + **Family Controls (Development)**. Dodatkowo złóż request o **Family Controls (Distribution)** przez formularz `developer.apple.com/contact/request/family-controls-distribution` — **osobno dla każdego z 5 bundle ID**. Approval nie propaguje się między targetami (Quinn, forum 813073). Timeline wg raportów 2025–2026: **2–8 tygodni per bundle ID**. Złóż wszystkie request w day one — to najczęstszy blocker wysłania na App Store.

**Krok 4 — Provisioning profiles.** Po każdej zmianie capability zregeneruj profile. Typowy błąd: „Profile doesn't support Family Controls (Development)" oznacza że distribution entitlement jeszcze nie został przyznany dla tego bundle ID.

**Krok 5 — Xcode, per-target Signing & Capabilities.** Dla **każdego z 5 targetów**:

1. Select target → tab **Signing & Capabilities**
2. **+ Capability** → **App Groups** → zaznacz `group.com.company.opalclone`
3. **+ Capability** → **Family Controls** (dodaje `com.apple.developer.family-controls = true`)
4. Sprawdź **Build Settings → Code Signing Entitlements** — tylko **jeden** plik `.entitlements` per target (klasyczny bug: Xcode tworzy osobne entitlement pliki dla Debug vs Release i tylko jeden dostaje grupę — forum thread 66752)
5. Zweryfikuj binarkę: `codesign -d --entitlements :- Path.app` i to samo dla każdego `.appex` — wszystkie pięć musi listować **identyczny** string App Group

**Krok 6 — Keychain (opcjonalnie).** Jeśli chcesz osobną keychain access group, dodaj do każdego `.entitlements`:

```xml
<key>keychain-access-groups</key>
<array>
  <string>$(AppIdentifierPrefix)com.company.opalclone.shared</string>
</array>
```

Na iOS App Group ID sam w sobie **też** działa jako keychain access group — nie musisz duplikować (Quinn, forum 133677).

**Krok 7 — Info.plist extensionów.** Template Xcode (File → New → Target → iOS → Device Activity Monitor / Shield Configuration / Shield Action Extension) generuje prawidłowe klucze automatycznie: `NSExtensionPointIdentifier` ustawiony na `com.apple.deviceactivity.monitor-extension` / `com.apple.ManagedSettings.shield-configuration-service` / `com.apple.ManagedSettings.shield-action-service` + `NSExtensionPrincipalClass`.

**Krok 8 — Deployment target.** Wszystkie extensiony muszą mieć deployment target **≥ main app**. Częsta cichy bug (forum 724243): main app jest na iOS 26, extension zostaje domyślnie iOS 17 po File → New Target — callbacks nie odpalają bez żadnego komunikatu.

**Krok 9 — Smoke test kontenera.** Pierwsze wywołanie `containerURL(forSecurityApplicationGroupIdentifier:)` z main app tworzy katalog lazily. Dopiero potem extensiony mają co otwierać.

**Krok 10 — Test na urządzeniu.** Symulator odrzuca Family Controls authorization i nie akumuluje usage — **musi być fizyczne urządzenie + iCloud + Developer Mode w Settings → Privacy & Security**.

---

## E. Katalog typowych bugów i workarounds

Dwanaście najczęstszych pułapek, z konkretnymi źródłami z forów Apple i blogów produkcyjnych.

1. **Token drift po update iOS (FB14082790 / FB14237883 / FB18353106).** Tokeny zapisane przez main app nie `==` tokenom, które dostaje ShieldConfigurationExtension. Zaczęło się iOS 17.5, persystuje w iOS 26.3.1. **Workaround:** trzymaj każdy rekord pod **własnym UUID**, token jako „best-effort pointer"; przy unknown-token zwracaj generyczny shield + flag repair; na najbliższym foreground main appa re-uruchom `FamilyActivityPicker` z pre-załadowaną zapisaną selekcją. Zobacz sekcję F. (źródło: riedel.wtf 2024-09-14; forum threads 732845, 756440, 758325)

2. **DeviceActivityMonitor crash z `EXC_RESOURCE high watermark memory limit (limit=6 MB)`.** Wystarczy Firebase/Sentry/Segment przy init. **Workaround:** zero SDK w extensionie, tylko Foundation. Sprawdzaj `os_proc_available_memory()`. Entitlement `com.apple.developer.kernel.increased-memory-limit` **nie obejmuje** DAM (forum 735454, 745035).

3. **DeviceActivityReport nie eksportuje danych.** Apple DTS (Quinn, forum 728044): „For privacy reasons, device activity extensions are not allowed to pass sensitive user information out of the extension processes, and you can't circumvent this restriction via UserDefaults." **Workaround:** dashboard w main app pokazuj renderując ten sam DARE view; agreguj niezależnie event counters, nie próbuj exportować pixel values.

4. **`intervalDidEnd` / `eventDidReachThreshold` nie są wołane (FB13696022, FB21320644).** Regresja iOS 17.4+, gorsza w iOS 26.0–26.3.1 gdzie `deviceactivityd` bywa kompletnie cichy. **Workaround:** belt-and-suspenders — zawsze rejestruj rezerwowy `UNCalendarNotificationTrigger` w main app na tę samą godzinę, i na foreground re-evaluate stan szielda.

5. **ShieldConfiguration cache'owany zbyt agresywnie (FB14237883).** Gdy przeniesiesz token między `ManagedSettingsStore` instancjami, stary shield UI nadal się renderuje. **Workaround:** zawsze `store.clearAllSettings()` przed add na innym store. Alternatywnie — użyj **jednego** store i dynamicznego shieldu dekodującego kontekst z pliku App Group. Dla wymuszenia reloadu shieldu: ShieldAction zwraca `.defer`, co re-uruchamia `ShieldConfigurationDataSource`.

6. **`includeEntireCategory` gubi się przy PropertyListEncoder (forum 721973).** Zakodowanie `FamilyActivitySelection(includeEntireCategory: true)` przez `PropertyListEncoder` → po decode flaga = `false`. **Workaround:** **używaj `JSONEncoder`**, kropka. Albo trzymaj flagę w osobnym kluczu obok (kingstinct/react-native-device-activity tak robi).

7. **UserDefaults w extension zwraca nil (forum 743175).** `@AppStorage` crashuje w DeviceActivityMonitor z „Using kCFPreferencesAnyUser with a container is only allowed for System Containers". **Workaround:** używaj raw `UserDefaults(suiteName: "group.…")?.object(forKey:)` zamiast `@AppStorage`, zweryfikuj że App Group entitlement jest w każdym targecie. Sam komunikat w logach cfprefsd jest benign (Quinn, forum 775137 z marca 2025) — ignoruj.

8. **FamilyActivityPicker crashuje przy dużej selekcji (FB11400221, FB14067691, FB12270644, FB14451403).** ~50% crash przy 100 items, ~100% przy 200+. **Workaround:** UI kapuj na ≤50 widocznych elementów, wykryj crash przez timer (`@State` flag co dropuje jeśli brak callbacku w 5s) i pokaż overlay „Too many selections, refine your choice". Nie otwieraj pickera z seed-selekcją zawierającą wiele kategorii naraz.

9. **Family Controls authorization silently revoked (FB18794535).** User toggluje Settings → Screen Time → (app) → wszystkie shieldy znikają, zero callbacku. **Workaround:** `AuthorizationCenter.shared.authorizationStatus` check na każdy foreground; jeśli nie `.approved` → re-request + re-apply persisted selection. Od iOS 26.4 dostępny „Screen Time Lock for 3rd parties" (one sec first shipped mid-March 2026), który wymaga passcode'u na toggle — to pierwsza poważna mitigacja Apple w tym obszarze.

10. **Shield pokazuje domyślny „Restricted" system text zamiast brandingu.** Znak że ShieldConfigurationExtension nie jest invocowana. **Workaround:** sprawdź każdy punkt: (a) bundle ID extensionu ma prefix main appa, (b) Info.plist ma `NSExtensionPointIdentifier = com.apple.ManagedSettings.shield-configuration-service`, (c) entitlement Family Controls jest w extension target (nie tylko main), (d) distribution entitlement został przyznany temu konkretnemu bundle ID Extension, (e) `os.Logger` confirm że proces ekstensionu w ogóle startuje.

11. **iCloud restore invalidates tokens i Screen Time passcode.** Tokeny są device-local crypto handles; restore do nowego urządzenia je zeruje. **Workaround:** detect migration (porównaj `identifierForVendor` lub keychain flag) → wymusz full re-pick selection. **Nie syncuj** `FamilyActivitySelection` przez iCloud KV store — zostanie na device.

12. **TestFlight build nie widzi Family Controls.** `com.apple.developer.family-controls` ustawione tylko w Debug.xcconfig, Release go nie ma (forum 806285, 735888). **Workaround:** jeden wspólny `.entitlements` per target, weryfikuj `codesign -d --entitlements :-` na .ipa przed uploadem.

13. **Bonus — nie ma API do otwarcia main app z ShieldAction (FB15079668).** `NSExtensionContext` niedostępny w `ShieldActionDelegate`; `UIApplication.shared.open` niedostępne. **Workaround:** w `handle(action:for:completionHandler:)` scheduluj `UNNotificationRequest` („Want to reflect? Tap to open <YourApp>.") + zwróć `.close` — user tappa notyfikację i otwiera app. Apple Intelligence summary + Focus filters mogą ją opóźnić — akceptuj flakiness.

14. **Bonus — nie ma API do otwarcia *zablokowanej* appki po kliknięciu „Allow anyway" (FB15500695).** Token jest opaque, nie zmapujesz go na URL scheme. **Workaround:** żaden wspierany. Jedyna opcja — `ManagedSettingsStore` cofa shield na X sekund (`store.shield.applications = nil` + scheduled re-apply) — user musi sam wrócić do Home i stapnąć apkę. Riedel zgłasza potrzebę `OpenAppFromApplicationTokenIntent` jako App Intent.

15. **Bonus — tylko jeden 3rd-party blocker działa na raz.** Brick support KB explicit: „Screen Time and other 3rd party blockers may interfere with Brick's ability to block." Dwa `ManagedSettingsStore` z różnych aplikacji mogą się nadpisywać. **Workaround:** poinformuj usera na onboardingu, żeby wyłączył inne blockery; nie próbuj egzekwować — nie masz enumeracji innych aplikacji.

---

## F. Problem „unknown token" — szczegółowa obsługa

**Objaw.** `ShieldConfigurationExtension.configuration(shielding application: Application)` (albo analogicznie `ShieldActionDelegate.handle`) dostaje `application.token`, którego **żaden zapis z main appa nie zawiera**. Ani w `selection.json`, ani w SwiftData, ani w UserDefaults. Nie możesz więc zmapować tokena → profil → branding shieldu, więc nie wiesz co pokazać.

**Kiedy się dzieje (empirycznie, 2024–2026):**

1. Po update iOS (najczęstszy trigger, zaczęło się iOS 17.5)
2. Po dołączeniu/opuszczeniu iCloud Family (thomas_maht, Jomo, forum 732845: *„One situation where this can occur is if you join an iCloud family. Since tokens are intended to be shared among family members, they will be updated at this moment."*)
3. Spontanicznie — pojedyncze wywołania extensionu dostają fresh tokeny podczas gdy persisted tokeny w main appie *nadal działają* do add/remove shields. Quappi na forum 732845: *„Interestingly, the persisted ones still work … but they don't match what's passed into the ShieldConfiguration extension."*
4. Po „Screen Time permission loss" window na iOS 26 (Riedel FB18997699)

**Stanowisko Apple.** Oficjalnego stanowiska brak. DTS (Quinn „The Eskimo") w lipcu 2025 zamknął thread 732845 jako duplicate, kierując do thread 758325 jako kanoniczny — ten z kolei nie ma rozwiązania ani ETA. FB14082790 (one sec), FB14237883 (one sec), FB18353106 (one sec, re-filed for iOS 26), FB14067691 — wszystkie otwarte. **Brak API do re-korelacji nowego tokena ze starym.** Brak API do zapytania „daj mi nowy token dla apki, dla której mam już stary token".

FB17902392 (wspomniane w briefie) **nie zostało zweryfikowane** w publicznych źródłach w czasie research'u — klaster jest realny i acknowledged, ale ten konkretny numer może być Twoim własnym duplikatem lub literówką. Potwierdzone numery: **FB14082790**, **FB14237883**, **FB18353106**, **FB18997699**, **FB13696022** (threshold nie odpala), **FB21320644** (threshold odpala natychmiast, iOS 26).

**Rekomendowany wzorzec obsługi.** Cztery warstwy, wzięte wspólnie z praktyk ScreenZen, Jomo, one sec, Opal:

1. **Nigdy nie crashować na unknown token.** Extension crash → iOS pokazuje default system shield („You cannot use X because it is restricted") → użytkownik traci kontekst co to w ogóle za appka Twoja i dlaczego. Zawsze zwracaj **generyczny** `ShieldConfiguration`.

2. **Cache known-token set w App Group.** Main app po każdym `FamilyActivityPicker` dialogu zapisuje `Set<ApplicationToken>` do App Group UserDefaults (JSON-encoded). ShieldConfigurationExtension czyta raz na wywołanie, sprawdza `contains(token)`.

3. **Breadcrumb „repair needed".** Gdy unknown token, extension zapisuje minimalny rekord (`UnknownTokenLog.append(token:timestamp:)`) + ustawia flag `needsRepair = true` w shared UserDefaults.

4. **Re-pairing flow na najbliższy foreground main appa.** Main app sprawdza flag przy `scenePhase == .active`. Jeśli `true` — pokazuje non-blocking banner „Re-select your blocked apps to restore protection" z przyciskiem otwierającym `FamilyActivityPicker` z pre-załadowaną zapisaną selekcją. User tappa Done → main app zapisuje *nowe* tokeny (które teraz będą `==` tym z extensionów), `store.clearAllSettings()` + re-apply shields, czyści flagę i log.

**Szkielet kodu:**

```swift
// SharedKit/UnknownTokenLog.swift
import Foundation
import ManagedSettings

enum UnknownTokenLog {
    private static let key = "pendingRepair.tokens"
    private static let defaults = UserDefaults(suiteName: SelectionStore.appGroupID)!

    static func append(_ token: ApplicationToken?) {
        guard let token, let data = try? JSONEncoder().encode(token) else { return }
        var existing = (defaults.array(forKey: key) as? [Data]) ?? []
        if !existing.contains(data) { existing.append(data) }
        // Limituj do 50 — w 6 MB budżecie nie ma sensu trzymać więcej.
        if existing.count > 50 { existing = Array(existing.suffix(50)) }
        defaults.set(existing, forKey: key)
        defaults.set(true, forKey: "needsRepair")
    }

    static var needsRepair: Bool { defaults.bool(forKey: "needsRepair") }

    static func clear() {
        defaults.removeObject(forKey: key)
        defaults.set(false, forKey: "needsRepair")
    }
}

// ShieldConfigurationExtension/Config.swift
override func configuration(shielding app: Application) -> ShieldConfiguration {
    let selection = SelectionStore.read()
    if let token = app.token, selection.applicationTokens.contains(token) {
        return brandedConfig(for: token)
    }
    UnknownTokenLog.append(app.token)
    return ShieldConfiguration(
        backgroundColor: .systemBackground,
        icon: UIImage(systemName: "arrow.triangle.2.circlepath"),
        title: .init(text: "App blocked", color: .label),
        subtitle: .init(text: "Open Opal to refresh your block list.",
                        color: .secondaryLabel),
        primaryButtonLabel: .init(text: "OK", color: .white),
        primaryButtonBackgroundColor: .systemBlue)
}

// MainApp/RepairFlow.swift
@MainActor
func handleScenePhaseActive() {
    guard UnknownTokenLog.needsRepair else { return }
    // Pokaż banner z CTA otwierającym FamilyActivityPicker.
    showRepairBanner = true
}

func onPickerFinished(newSelection: FamilyActivitySelection) {
    try? SelectionStore.write(newSelection)
    let store = ManagedSettingsStore(named: .init("opal.main"))
    store.clearAllSettings()
    store.shield.applications = newSelection.applicationTokens.isEmpty
        ? nil : newSelection.applicationTokens
    UnknownTokenLog.clear()
}
```

---

## G. Źródła z datami publikacji

### Apple — oficjalna dokumentacja

- **Configuring app groups** — developer.apple.com/documentation/xcode/configuring-app-groups (current)
- **App Groups entitlement** — developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups (current)
- **Configuring Family Controls** — developer.apple.com/documentation/xcode/configuring-family-controls (current)
- **FamilyControls framework** — developer.apple.com/documentation/familycontrols/ (current)
- **ManagedSettings** — developer.apple.com/documentation/ManagedSettings (current)
- **DeviceActivity** — developer.apple.com/documentation/deviceactivity/ (current)
- **FamilyActivityPicker** — developer.apple.com/documentation/familycontrols/familyactivitypicker (current)
- **ApplicationToken** — developer.apple.com/documentation/managedsettings/applicationtoken (current)
- **NSFileCoordinator** — developer.apple.com/documentation/foundation/nsfilecoordinator (current)
- **ModelConfiguration.GroupContainer** (iOS 18+) — developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct
- **Keychain access groups** — developer.apple.com/documentation/bundleresources/entitlements/keychain-access-groups (current)
- **Sharing keychain access between apps** — developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps (current)
- **App Extension Programming Guide** (archived but still authoritative on NSFileCoordinator in extensions) — developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html
- **Family Controls Distribution request form** — developer.apple.com/contact/request/family-controls-distribution
- **iOS & iPadOS 26 Release Notes** — developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes (2025)
- **Apple Newsroom, Declared Age Range API** — apple.com/newsroom/2025/06/apple-expands-tools-to-help-parents-protect-kids-and-teens-online/ (2025-06-02)

### Apple — WWDC sessions

- **WWDC21 Session 10123 „Meet the Screen Time API"** — developer.apple.com/videos/play/wwdc2021/10123/ (czerwiec 2021)
- **WWDC22 Session 110336 „What's new in Screen Time API"** — developer.apple.com/videos/play/wwdc2022/110336/ (czerwiec 2022)
- **BRAK dedykowanych sesji WWDC 2023/2024/2025 dotyczących Screen Time API** — to jest samo w sobie istotna informacja. API jest zamrożone od WWDC22.
- wwdcnotes.com/documentation/wwdcnotes/wwdc21-10123-meet-the-screen-time-api/
- wwdcnotes.com/documentation/wwdcnotes/wwdc22-110336-whats-new-in-screen-time-api/

### Apple Developer Forums — kluczowe wątki

- **732845** — „ApplicationTokens changing" (_anteloper / Quappi / Quinn DTS), czerwiec 2023 → lipiec 2025 — **kanoniczny thread token drift**
- **758325** — „Tokens change without reason after iOS 17.5.1" (Thomas Maht/Jomo, Peter Schaeffer/Opal), 2024
- **756440** — Scott Harvey / ScreenZen, iOS 17.5.1 issues, 2024
- **728044** — DTS (Quinn): DeviceActivityReport nie może eksportować, UserDefaults.synchronize() jest no-op
- **735454** — 6 MB RAM limit DeviceActivityMonitor (`EXC_RESOURCE`), sierpień 2023 — **kanoniczny**
- **745035** — 6 MB limit potwierdzenie, iOS 17
- **726504** — DeviceActivityReport 100 MB limit (Apple engineer)
- **719905** — „Open parent app from ShieldAction" — Apple Frameworks Engineer potwierdza brak API
- **721973** — `includeEntireCategory` bug z `PropertyListEncoder` (richard.dz, sierpień 2024)
- **762441** — „Creating ApplicationToken with Decoder" — kwiecień 2025
- **743175** — `@AppStorage` crashuje w DAM extension, iOS 17
- **724243** — DAM methods not calling: simulator, deployment target, App Group pitfalls
- **805859** — DeviceActivityMonitor not working iOS 26.2 (2025)
- **764457 / 750847 / 743770 / 724556** — FamilyActivityPicker crashes przy dużych selekcjach (FB14067691 / FB14451403 / FB12270644)
- **735888 / 725036 / 690522** — Family Controls entitlement approval timeline
- **806285** — Family Controls nie działa na TestFlight (Debug-only entitlement bug)
- **807934 / 727058** — ShieldAction `.close`/`.defer`/`.none` semantics, completionHandler ordering
- **718126 / 133677 / 67047** — Quinn: App Group naming iOS vs macOS, keychain access group vs App Group
- **66752** — Debug/Release osobne .entitlements files bug
- **775137** (marzec 2025) / **659448** — „kCFPreferencesAnyUser with a container" benign cfprefsd log
- **813073 / 774455 / 809208** (listopad 2025) — Family Controls distribution approval per-bundle-ID, 2+ tygodnie w kolejce
- **730521** — FamilyActivityPicker 3+ kategorie misbehavior
- **749672** — `.individual` vs `.child` authorization
- **tagi:** developer.apple.com/forums/tags/family-controls, /device-activity, /managed-settings, /screen-time (wszystkie aktywne, kwiecień 2026)

### Blogi — niezastąpione źródła produkcyjne

- **Frederik Riedel (one sec), „Apple's Screen Time API has some major issues"** — riedel.wtf/state-of-the-screen-time-api-2024/ (2024-09-14). Kanoniczny post o bugach z FB numbers (FB14082790, FB14237883, FB15079668, FB15500695).
- **Frederik Riedel, „Making one sec truly bullet-proof with iOS 26.4"** — one-sec.app/blog/lock-screen-time-permission/ (marzec 2026)
- **riedel.wtf tag screen-time** — ongoing
- **Nicola Giancecchi (letvar), „Time After (Screen) Time"** series — letvar.medium.com — część 2 (DeviceActivityReport, 100 MB limit), część 3 (DAM, 6 MB), 2023–2024
- **Pedro Esli, „Using Screen Time API to block apps for a specified time"** — pedroesli.com/2023-11-13-screen-time-api/ (2023-11-13) — konkretna implementacja `ApplicationProfile: Codable, Hashable` w App Group
- **Crunchy Bagel, „Monitoring App Usage using the Screen Time Framework"** (Streaks 9.1) — crunchybagel.com/monitoring-app-usage-using-the-screen-time-api/ (2023) — potwierdza 5–6 MB
- **Julius Brussee, „A Developer's Guide to Apple's Screen Time APIs"** — Medium (2024)
- **John Baker, „Creating a ScreenTime ShieldConfigurationDataSource for iOS FamilyControls API"** — Medium (2024)
- **Itsuki, „Swift/iOS: Take Family Control To Production/Distribution"** — Medium
- **Atomic Bird (Tom Harrington), „Sharing with app extensions"** — atomicbird.com/blog/sharing-with-app-extensions/ (2015-05-18) + file-coordination-fix (2015) — fundamentalne
- **Soroush Khanlou, „File coordination"** — khanlou.com/2019/03/file-coordination/ (2019-03) — empiryczne ~0.5% write loss pod contention
- **Michael Tsai, „IPC via NSFileCoordinator and NSFilePresenter"** — mjtsai.com/blog/2014/11/21/... (2014)
- **Tom Lokhorst (nonstrict.eu), „Darwin Notifications in App Extensions"** — nonstrict.eu/blog/2023/darwin-notifications-app-extensions/ (2023) — cytat Apple engineer o procesie musi żyć
- **Oh My Swift, „Send data between iOS apps and extensions using Darwin Notifications"** — ohmyswift.com/blog/2024/08/27/... (2024)
- **Rambo Codes (Guilherme Rambo), „Common pitfalls when using Keychain Sharing on iOS"** — rambo.codes/posts/2020-01-16-common-pitfalls-when-using-keychain-sharing-on-ios (2020-01-16)
- **Dave DeLong, UserDefaults reference** — dscoder.com/defaults.html
- **Vadim Bulavin, „Advanced Guide to UserDefaults"** — vadimbulavin.com/advanced-guide-to-userdefaults-in-swift/
- **Mike Ash, „Friday Q&A 2017-10-27: locks, thread safety"** — mikeash.com
- **mcky.dev, „Beware os_unfair_lock"** — mcky.dev/blog/beware-os-unfair/
- **Pol Piella, „Core Data migration to App Group"** — polpiella.dev/core-data-migration-app-group
- **Hacking with Swift, „Syncing SwiftData with CloudKit"** + „Access SwiftData container from widgets" — hackingwithswift.com
- **Antoine van der Lee (SwiftLee), „OSLog and Unified logging"** — avanderlee.com/debugging/oslog-unified-logging/
- **TechCrunch, „Opal revamps its screen time app"** — techcrunch.com (2022-09-15)
- **Opal blog „Building Opal's Screen Time Framework"** (Matt Davenport) — opal.so/blog/opals-screen-time-framework
- **Tech Lockdown, „How iOS 26 Changes Parental Controls and Screen Time"** — techlockdown.com/articles/ios-26-screen-time-changes (2025)
- **9to5Mac, „iOS 26 made Live Activities even better on iPhone"** — 9to5mac.com (2025-12-04)
- **Brick KB o store conflict** — brick.frontkb.com/en/articles/6572993

### GitHub / open source

- **kingstinct/react-native-device-activity** — github.com/kingstinct/react-native-device-activity — najlepsze publiczne architecture notes, ~108 stars, aktywnie utrzymywane, producencie pattern `actionsfor${goalId}` / `events_${goalId}` w shared UserDefaults
- **ioridev/flutter_screentime** — github.com/ioridev/flutter_screentime
- **ios_screen_time_tools** — pub.dev/packages/ios_screen_time_tools
- **christianp-622/ScreenBreak** — github.com/christianp-622/ScreenBreak (reference SwiftUI impl)
- „FamilyControlsKit" jako nazwana biblioteka SPM **nie istnieje** publicznie pod tą nazwą — to umbrella term używane w rozmowach, nie konkretny pakiet.

---

## Podsumowanie: co to zmienia dla Twojego klona Opala

Architektura, którą polecam, to **hybryda Pattern A (main-writer) + Pattern B (ext-as-append-only-event-emitter)**, trzymana przez **pojedynczy App Group**, z **JSON-em w plikach** dla dużych struktur (selection, branding) i **UserDefaults** dla małych scalarów. Kluczowa decyzja: **każdy rekord pod własnym UUID**, token jako „best-effort pointer" — bo Apple od trzech głównych wersji iOS (17→26) nie naprawiło rotacji tokenów i żaden producent nie wierzy już że `Token<Application>` jest stable long-term. Extensiony trzymaj **absolutnie bez third-party SDK** (6 MB), bez pracy async która przeżyje callback, bez próby zawrócenia danych z `DeviceActivityReport`. Komunikuj zmiany przez **atomowy write + Darwin notification + polling-on-foreground** — pełny real-time cross-process na iOS dla ekstensionów Screen Time **nie istnieje** i nie pojawił się w iOS 26. Zaplanuj **4–8 tygodni bufora** na per-bundle-ID approval Family Controls Distribution (to najczęstszy powód opóźnienia launchu). Zaimplementuj od dnia zero: **fallback generic shield**, **repair-needed banner**, **re-pairing flow** z `FamilyActivityPicker`, **belt-and-suspenders notifications** na wypadek zgubionego `intervalDidEnd`, **lokalny log diagnostyczny** przez OSLog z konwencją `subsystem = bundleId, category = ext-name`. W iOS 26.4 zyskujesz **Screen Time Lock for 3rd parties** (one sec jest first-shipping) — to pierwsza prawdziwa mitigacja Apple dla „user toggluje permission i znika shield". Zintegruj ją — to feature, który konwertuje na retention. Na koniec: tylko jeden 3rd-party Screen Time blocker może sensownie współistnieć na urządzeniu naraz. Jeśli Twój klon konkuruje z Opalem/one sec/ScreenZen, użytkownik musi jednego z nich odinstalować. Projekt onboardingu — z tym w umyśle.