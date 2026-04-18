# Research

Kurowane notatki badawcze pod projekt (klon Opala + AI on-device na iOS). Każdy plik to samodzielny raport; poniżej szybki indeks.

---

## Screen Time API / klon Opala

- **[iOS 26 vs iOS 18 deployment target](compass_artifact_wf-14f18c53-0c15-46ba-90f6-4e8befe1261a_text_markdown.md)** — Rdzeń Screen Time API (FamilyControls, ManagedSettings, DeviceActivity) w iOS 26 bez nowych funkcji, z regresjami nienaprawionymi 10+ miesięcy. **Rekomendacja: deployment target iOS 18.0** (~90% reach, kompletne API) zamiast iOS 26 (~66% reach).
- **[Najlepsze public repo do Opala](compass_artifact_wf-9f1fb5f8-b639-4ece-808e-76cc0b222990_text_markdown.md)** — **Foqos (awaseem/foqos)** jedyny produkcyjny projekt (iOS 17+, MIT, 431⭐, pełny flow auth→picker→shield→schedule). ScreenBreak/Kairos = demka. Kingstinct RN wrapper = najbogatsze źródło Shield/Action kodu. Apple nie wydało oficjalnego samplu.
- **[Entitlement `family-controls` w 2026](compass_artifact_wf-dee368a6-dad8-4281-9c56-dceec8896003_text_markdown.md)** — Wniosek przez `developer.apple.com/contact/request/family-controls-distribution`, mediana odpowiedzi 2–3 tygodnie. **Pułapka: osobny wniosek na KAŻDY bundle ID** (aplikacja + rozszerzenia). Framing: `.individual`, nie `.child`. Logika on-device, jakikolwiek cloud = reject.
- **[Produkcyjny shield — przewodnik techniczny](compass_artifact_wf-94040b55-09de-47ec-9cd1-64797e3aea07_text_markdown.md)** — `ShieldConfiguration` to 8-polowy struct (UIColor/UIImage/Label), akcje `.none/.defer/.close`, **brak sieci, brak SwiftUI, brak TextField**. API zamrożone od 2022. Liderzy (Opal/one sec/Jomo/Brick) obchodzą to trzema trikami: pre-renderowane UIImage z wypieczoną typografią, lokalne notyfikacje + URL schemes do deep-linku w main app, App Group + Darwin notifications do sync stanu.
- **[Known bugs Screen Time API na iOS 26](compass_artifact_wf-26aecd00-d219-4bf6-9a30-c4499255cad5_text_markdown.md)** — Lista produkcyjnych min z Apple Dev Forums (iOS 26.0–26.4.1, sygnały 26.5 beta). Najgorsze: `eventDidReachThreshold` odpala się natychmiast po zaplanowaniu (FB18061981/FB18927456 i spokrewnione) oraz z 0 min użycia na 26.2 po ładowaniu (FB21450954). Apple DTS twierdzi że fix w 26.5 beta 1 — niepotwierdzone przez userów. Dlatego deployment target iOS 18 to racjonalny wybór.
- **[DeviceActivityReport — przewodnik techniczny](compass_artifact_wf-13fa7075-b78a-413e-a24f-a202bdcb0298_text_markdown.md)** — Report to **jednokierunkowa rura**: extension renderuje SwiftUI/Swift Charts, ale **nie oddaje danych do hosta** (sandbox XPC). Produkcyjny pattern = hybryda: Report dla wykresów + równoległy `DeviceActivityMonitor` z małymi progami eventów (min. 1 min, interwał harmonogramu min. 15 min, max **20 aktywności** łącznie na app+extensiony) tyka licznik w App Group UserDefaults — stąd host czyta "minuty dziś", streaki, XP. iOS 26.4 wprowadził `approvedWithDataAccess` — pierwsza furtka do danych poza extension, ale słabo udokumentowana. Granulacje: `hourly/daily/weekly`.
- **[Komunikacja main app ↔ extensions](compass_artifact_wf-280372a6-1bd9-4044-95d9-1d65f1d292dc_text_markdown.md)** — Architektura: App Group jako single source of truth, main app = writer, extensiony = read-mostly; zmiany przez atomowy zapis pliku + Darwin notification. **Kluczowe:** tokenów (`ApplicationToken` itd.) **nie traktuj jako stabilnego klucza** — bug rotacji tokenów acknowledged by DTS od iOS 17.5 do 26.3.1 (FB14082790/FB14237883/FB18353106). Trzymaj rekordy pod własnym UUID, token obok jako best-effort pointer. Limity: `DeviceActivityMonitor` ma **6 MB RAM** (zero 3rd-party SDK), `DeviceActivityReport` ma sandbox blokujący eksport danych.
- **[Anti-bypass — kompletny katalog](compass_artifact_wf-1862c287-6b03-4a01-a2e4-e53e8d7082b8_text_markdown.md)** — W `.individual` nie zbudujesz niełamliwego blokera — każda obrona ginie przy toggle w `Settings → Screen Time → Apps With Screen Time Access`. Realistyczny Deep Focus = **warstwowa friction** (delay + passphrase typing + accountability + `requireAutomaticDateAndTime` + `denyAppRemoval` + detekcja revocation ze streak-karą). iOS 26.4 wprowadził Lock Screen Time Settings (PIN gate na toggle). Produkcyjne techniki: one sec 10s breath (~36% rezygnuje wg PNAS), Jomo random code typing 250 chars, ScreenZen password copy, AppBlock Strict Mode string.
- **[Live Activities / Dynamic Island dla Opal timera](compass_artifact_wf-719bca2b-9444-49eb-ad10-cbe3c7b6eb88_text_markdown.md)** — Live Activities = idealny primitive dla focus timera, ALE **ActivityKit NIE działa z żadnego Screen Time extension** → wszystkie zmiany state muszą iść przez main app lub backend APNs. `Text(timerInterval:)` = countdown sterowany przez system, zero update budgetu. iOS 18 = interactive buttons, iOS 26 = CarPlay/Watch/Mac inheritance, Liquid Glass, AlarmKit, Relevance Widgets. **Defensive reconciliation on app foreground = obowiązkowe** ze względu na regresje callback reliability i token stability w iOS 26.

## Rynek / inspiracje

- **[Apki 2025 — co wygrało](compass_artifact_wf-bd5f38aa-9a38-421d-9b1c-4a08d9bbb0c0_text_markdown.md)** — ChatGPT pobił TikToka (770M pobrań), zwycięzca Google Play Best of 2025 = **Focus Friend** (detoks od telefonu). Dualizm roku: AI w kieszeni + aktywna obrona uwagi.

## Monetyzacja

- **[Monetyzacja focus app na iOS 26 (solo dev)](compass_artifact_wf-2f61523e-a255-4879-97cf-c731ba4d4ae5_text_markdown.md)** — MVP stack: **StoreKit 2 + SubscriptionStoreView + PostHog (free) + Cloudflare R2 JSON dla remote paywall** (koszt 0 zł/mies, ~2 dni wdrożenia, pokrywa 95% przypadków do ~5k USD MRR). Po przekroczeniu dodaj Superwall Indie (free do 10k USD MAR); RevenueCat/Adapty dopiero przy 25k+ MRR albo wyjściu na Android/web. Cenówka globalna: **49,99 USD/rok z 7-dniowym trialem**, monthly 8,99 USD jako anchor, bez lifetime w MVP. Ograniczenia StoreKit 2: refundy z opóźnieniem, brak A/B testów paywalla bez app review.

## AI on-device

- **[21 modeli AI z HuggingFace pod iOS 2026](compass_artifact_wf-fe71c4e7-c492-45a1-9606-997897ecd4c6_text_markdown.md)** — LLM: `mlx-community` (Qwen3, Llama 3.2, SmolLM3, LFM2, Gemma 3, Phi-4-mini) ładowane jednym ID w `mlx-swift-examples`. Speech: Argmax WhisperKit/TTSKit, FluidAudio, Kokoro, Parakeet. Braki community portów: Depth Anything V2, SAM 2, Real-ESRGAN.

---

**Last Updated**: 2026-04-18
