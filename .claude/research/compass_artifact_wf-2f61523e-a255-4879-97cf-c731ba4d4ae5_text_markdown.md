# Monetyzacja aplikacji focus na iOS 26 — praktyczny przewodnik dla solo dev

**Bottom line up front:** Dla klona Opala jako MVP w 2026 roku **pure native StoreKit 2 + SubscriptionStoreView + PostHog (free) + Cloudflare R2 JSON dla remote paywall config** to optymalny stack — koszt 0 zł/mies., czas wdrożenia ~2 dni, pokrywa 95% przypadków. Kluczowe ograniczenia (refunds wykrywane z opóźnieniem, brak A/B testów paywalla bez app review, brak cross-platform) są **akceptowalne do ~5 tys. USD MRR**. Po przekroczeniu tego progu dodaj **Superwall Indie (free do 10k USD MAR)** jako warstwę paywalla, a dopiero powyżej 25 tys. USD MRR lub przy wyjściu na Androida/web rozważ RevenueCat/Adapty. Rekomendowana cenówka globalna: **49,99 USD rocznie (≈199 PLN) z 7-dniowym trialem**, default annual z anchoringiem „per week", monthly 8,99 USD jako psychologiczny zły-wybór, bez lifetime w MVP. W Polsce Apple automatycznie dobiera tier — nie ma sensu lokalnie wymyślać ceny, ale należy wybrać tier z ceną kończącą się na „99 PLN/199 PLN/399 PLN".

Poniższy raport szczegółowo rozwija każdą z dziesięciu sekcji, kończąc na sześciu wymaganych deliverables (decision tree, product skeleton, pricing, code skeleton, limitations list, review checklist).

---

## 1. StoreKit 2 — stan w iOS 26 (kwiecień 2026)

### Kontekst wersji
iOS 26 jest wydaniem z września 2025 (Apple zunifikowało numerację z rokiem — **nie ma iOS 19–25**). Aktualna produkcja to **iOS 26.4** (24 marca 2026), beta **26.5** wprowadziła nowy plan „monthly z 12-miesięcznym commitmentem". **WWDC 2026 (8–12 czerwca 2026)** zapowie iOS 27 — na dzień 18 kwietnia 2026 nie ma jeszcze żadnych sesji WWDC26 dot. StoreKit. Wszystko, co nazywane jest „WWDC25 StoreKit", to features, które shipowały w iOS 26.

### Rdzeń API — typy i flow

```swift
// Product: reprezentacja IAP/subskrypcji z App Store Connect
let products = try await Product.products(for: ["pro.monthly", "pro.yearly"])

// SubscriptionInfo zawiera oferty i status grupy
if let sub = product.subscription {
    let groupID = sub.subscriptionGroupID
    let period = sub.subscriptionPeriod
    let intro: Product.SubscriptionOffer? = sub.introductoryOffer
    let winBacks = sub.winBackOffers                       // iOS 18+
    let eligibleWB = try await sub.eligibleWinBackOfferIDs // iOS 18+
}

// Status grupy subskrypcji (wspólny dla wszystkich produktów w grupie)
let statuses: [Product.SubscriptionInfo.Status] = try await sub.status
// .state ∈ {subscribed, expired, inGracePeriod, inBillingRetryPeriod, revoked}

// Transaction: pojedyncze zakupy/odnowienia, jako VerificationResult<Transaction>
for await vr in Transaction.updates {
    if case .verified(let tx) = vr { await tx.finish() }
}
for await vr in Transaction.currentEntitlements { /* ... */ }

// Zakup
let result = try await product.purchase(options: [
    .appAccountToken(userUUID),                      // opaque user linkage
    .promotionalOffer(compactJWS: jws),              // iOS 18.4 — JWS V2
    .winBackOffer(offer)                             // iOS 18+
])
```

### JWS signing = walidacja bez backendu
Każda `Transaction`, `AppTransaction` i `RenewalInfo` jest **JWS (RFC 7515) podpisana ES256** przez App Store. StoreKit 2 automatycznie weryfikuje łańcuch certyfikatów względem Apple Root CA wbudowanego w OS, dodatkowo sprawdzając `bundleId` i `deviceVerification` (chroni przed przenoszeniem transakcji między urządzeniami). `VerificationResult` zwraca `.verified` lub `.unverified(_, VerificationError)`. **Żaden call do własnego serwera nie jest potrzebny** — to główny argument przeciwko legacy receipt file i endpoint `verifyReceipt`.

### Co zmieniło się w iOS 17 / 18 / 26

| API / Feature | iOS 17 | iOS 18 (18.0/18.2/18.4) | iOS 26 (WWDC25) |
|---|---|---|---|
| `SubscriptionStoreView`, `StoreView`, `ProductView` | ✅ wprowadzone | | |
| `subscriptionStoreControlStyle` | `.automatic`, `.buttons`, `.prominentPicker` | + `.compactPicker`, `.pagedPicker` | |
| **Win-back offers** (`SubscriptionOffer.OfferType.winBack`, `.winBackOffer()` purchase option) | | ✅ 18.0 | |
| App Store Server API **v2** + Advanced Commerce API | | ✅ | |
| StoreKit 1 (SKPaymentQueue, verifyReceipt) **oficjalnie deprecated** | | ✅ 18.0 | |
| JWS-signed Promotional Offers V2 (`compactJWS`) | | ✅ 18.4 (back-deploy do iOS 15) | |
| `Transaction.currentEntitlement(for:)` deprecated → `currentEntitlements(for:)` (plural) | | | ✅ 26 |
| **`AppTransaction.appTransactionID`** — globalnie unikalny per Apple Account per app, stabilny przy reinstall/refund/repurchase, unikalny per family member | | ✅ 18.4 | potwierdzone w 26 |
| **`SubscriptionOfferView`** — dedykowany SwiftUI view dla merchandising upgrade/downgrade/crossgrade | | | ✅ 26 |
| Offer codes dla consumables, non-consumables, non-renewing subs (wcześniej tylko auto-ren) + sandbox offer-code testing | | | ✅ 26 |
| Nowe typy notyfikacji: `ONE_TIME_CHARGE`, `EXTERNAL_PURCHASE_TOKEN` | | częściowo | ✅ 26 |
| Liquid Glass wpływa na appearance SubscriptionStoreView | | | ✅ (automatycznie przy kompilacji z Xcode 26) |
| **Brak Apple Intelligence w StoreKit** — żadna integracja nie została zapowiedziana | | | — |

### Advanced Commerce API — kogo dotyczy
**Nie solo deva budującego Opal-clone.** To server-side REST API (+ client types `Transaction.advancedCommerceInfo`) pozwalające generować SKU dynamicznie zamiast rejestrować każdy w ASC. Wymaga aplikacji do Apple i kwalifikuje tylko 4 business models: wielkie katalogi one-time (audiobook/kursy), creator subscriptions (Patreon-style), subskrypcje z add-onami (YouTube TV channels), Mini Apps Partner Program. **Pomiń.**

### Status StoreKit 1 w 2026
- `SKPaymentQueue` + `SKProductsRequest` + `SKPaymentTransactionObserver` → **oficjalnie deprecated w iOS 18**, wciąż działają, brak end-of-life.
- `verifyReceipt` endpoint → **deprecated od WWDC23**, bez nowych features, będzie notice przed wyłączeniem.
- App Store Server Notifications **v1** → deprecated, nowe typy zdarzeń tylko w v2.
- Dla nowego projektu: **StoreKit 2 only, deployment target ≥ iOS 15**. Cały stack StoreKit 2 back-deploy'uje się do iOS 15 — nie ma powodu wymagać iOS 26.

---

## 2. Native StoreKit 2 vs RevenueCat — porównanie dla solo deva w 2026

### Porównanie SDK (ceny zweryfikowane kwiecień 2026)

| Kryterium | Native StoreKit 2 | RevenueCat | Superwall | Adapty | Qonversion |
|---|---|---|---|---|---|
| **Pricing 2026** | Free (tylko cut Apple) | Free ≤ 2,5k USD MTR; **1% MTR** powyżej | Indie: Free ≤ 10k USD **MAR**, 1% powyżej. Startup 49 USD/mies + 1%. Scale 199 USD/mies + 1% | Free ≤ 5k USD/mies; **1%** powyżej | Free ≤ 10k USD MTR; Starter **0,6%**; Growth **0,8%** |
| **Paywall builder** | Tylko SubscriptionStoreView | Paywalls v2 (GA czerwiec 2025), komponentowy edytor, AI-gen, exit offers, remote | No-code klasy premium, A/B/N, Figma-style | Drag-and-drop + AI Paywall Generator, 50+ templates | No-Code Builder 2.0 |
| **A/B testing bez app review** | ❌ | ✅ Experiments + Targeting | ✅ (to rdzeń produktu) | ✅ Autopilot AI | ✅ (Growth) |
| **Analytics** | Tylko ASC (agregowane, ~48h delay) | MRR, churn, LTV, cohorts, funnels | Paywall analytics, free forever | MRR/ARPU/LTV, predictive LTV | MRR, ARR, LTV, cohorts |
| **Webhooks / server events** | Własny backend | ✅ Real-time, 20+ integracji | ✅ Free na wszystkich tierach | ✅ | ✅ Starter+ |
| **Cross-platform** | ❌ iOS only | ✅ | ✅ iOS/Android/Flutter/Web | ✅ pełne | ✅ |
| **Vendor lock-in** | Brak | Średni | Niski | Średni | Średni |

**Niuans o pricingu:** RevenueCat 1% liczy od **gross** revenue (przed cutem Apple) — efektywnie ~1,43% po 30% Apple. Superwall 1% liczy tylko od **Monthly Attributed Revenue** (wyłącznie przychód przypisany paywallowi Superwall); renewals i trial-to-paid NIE liczą się jako MAR. To sprawia że **Superwall ma znacznie łagodniejszą krzywą kosztu dla solo deva**.

### Limitations pure native StoreKit 2 (bez backendu, bez SDK) — lista krytyczna

1. **Brak server-side receipt verification** — nie zweryfikujesz subskrypcji poza iOS. *Workaround:* akceptuj; jailbreak fraud dla 10 USD/mies productivity app jest pomijalny.
2. **Brak centralnego entitlement store** — nie odpowiesz z web/support tool „czy user X ma premium". *Workaround:* Cloudflare Worker + KV + App Store Server Notifications v2.
3. **Brak webhook handlingu** — refundy/anulowania poza aplikacją są wykrywane dopiero przy kolejnym foreground `Transaction.currentEntitlements`. Lag: godziny–dni.
4. **Brak A/B testów paywalla bez app review** — bez remote config nie podmienisz copy/ceny/trial length.
5. **Brak wbudowanych analytics** — musisz osobno zaintegrować PostHog/Mixpanel dla `paywall_shown`, `trial_started`, `subscribe_tapped`.
6. **Brak cross-platform subscription sharing** — gdy zrobisz web/Android, musisz budować sync sam.
7. **Brak cohort/LTV/churn analytics out of the box**. ASC Analytics jest agregowane, delay 24–48h.
8. **Brak integracji z attribution (AppsFlyer, Adjust, Branch)** — musisz ręcznie forwardować purchase events.
9. **Trudniejsze edge cases:** billing retry, grace period, family sharing revocation, refund handling — każde wymaga własnego kodu.
10. **Introductory offer eligibility per-Apple-ID-per-subscription-group** — jeden Apple ID, który użył triala, nigdy więcej go nie zobaczy, niezależnie od Twojego accounta. *Workaround:* **win-back offers (iOS 18+)** — fully Apple-managed, żadnego signingu.
11. **Brak promotional offer signingu bez backendu** — JWS sygnatury per user wymagają ES256 klucza. *Workaround:* ogranicz się do intro offers + win-back offers.
12. **Offline / flaky network** — `Transaction.currentEntitlements` łączy się z `mzstorekit.apple.com` i może rzucić NSURLError -1009. *Workaround:* cache last-known-good entitlement w Keychain/UserDefaults z App Group.
13. **`Transaction.updates` może miss transactions jeśli app nie runs** — udokumentowane w Apple Dev Forums. *Workaround:* zawsze re-checkuj `currentEntitlements` na każdy cold start, nie polegaj wyłącznie na `.updates`.
14. **Restore Purchases UX friction** — `AppStore.sync()` wymaga Apple ID prompt. *Workaround:* schowaj przycisk w Settings; `currentEntitlements` na launch restoruje cicho w 95% przypadków.
15. **`CONSUMPTION_REQUEST` (12h window na odpowiedź przy refund dispute dla consumables)** — niemożliwe z clienta. *Workaround:* jeśli nie sprzedajesz consumables, ignoruj; dla Opal-clone nie dotyczy.

### Minimal backend options (gdy jednak warto)

| Platforma | Free tier 2026 | Paid | Gotcha |
|---|---|---|---|
| **Cloudflare Workers + KV** | 100k req/dzień, 1k KV writes/dzień — de facto free na webhooki | 5 USD/mies za 10M | Node `X509Certificate` wymaga WebCrypto; używaj `@apple/app-store-server-library` bundlowanej przez Workerd |
| **Supabase Edge Functions** | 500k invocations/mies free | Pro 25 USD/mies (free pauzuje po 7 dniach nieaktywności — blokujące dla prod webhooks) | Bonus: gotowy Postgres + Auth |
| **AWS Lambda + API Gateway** | 1M req/mies, 400k GB-s free (bez wygaśnięcia) | Grosze | Cold starts 100–500ms, IAM learning curve |
| **Vercel Functions** | Hobby 1M invocations | Pro 20 USD/user/mies | Jeśli nie masz już Vercela, Cloudflare tańsze |

**Werdykt dla Opal-clone:** **Cloudflare Worker + KV** jest bezdyskusyjnym zwycięzcą. Apple ma oficjalną `@apple/app-store-server-library-node`, która zrobi całą weryfikację JWS w ~10 liniach (`SignedDataVerifier.verifyAndDecodeNotification()`). ~2h pracy do wdrożenia. Uruchamiać gdy: zaczniesz się martwić kontaktami od refundowanych userów, sprzedasz consumable, wyjdziesz poza iOS.

### Rekomendacja konkretna dla Opal-clone MVP
- **Stage 1 (0 → 5k USD MRR):** Pure native StoreKit 2 + `SubscriptionStoreView` + PostHog free + hardcoded paywall copy w SwiftUI. Koszt third-party: **0 USD/mies**.
- **Stage 2 (5 → 25k USD MRR):** + Superwall Indie (free do 10k MAR) dla paywall A/B + Cloudflare Worker na webhooki. Koszt: 0–100 USD/mies.
- **Stage 3 (25k+ lub Android/web):** Migracja entitlementów do RevenueCat lub Adapty + Superwall jako warstwa paywalla na górze.

---

## 3. Produktowy teardown Opal / one sec / Jomo / Brick / Forest / Freedom / ScreenZen

### Tabele per app

| App | Free tier | Paid unlocks | Weekly | Monthly | Annual | Lifetime | Trial |
|---|---|---|---|---|---|---|---|
| **Opal** | 1 Recurring Focus Session, on-demand sesje bez limitu, easy bypass, blocklist only, Focus Score tylko dziś | Deep Focus (hard lock), harder bypass, unlimited recurring, whitelist, pełna historia, multi-device sync, Family Sharing | 4,99 / 9,99 USD (obserwowane w Adapty lib) | **19,99** | **99,99** (≈8,29/mies) | **399** | „Free Week" na annual, „Free 3 Days" na monthly — oba z payment method |
| **one sec** | Tylko 1 target app, podstawowe oddychanie | Unlimited apps, zaawansowane interwencje (lustro, 4-7-8, typed text, rotate), Strict Block + harmonogram, delayed interventions, Mac app, widgets, iCloud | — | **2,99** | **19,99** (Family 24,99) | — | 7 dni na annual, z payment method |
| **Jomo** | 1 Sesja, 1 Action/Limit, 1 Budget | Do 10 Sesji/Actions, Strict Mode (emergency passcode), Apple Health, delete-apps-from-ScreenTime, journaling, QR/NFC unlock, multi-device | — | **5,99** | **29,99** (≈2,49/mies) | **99,99** | **3 dni** tylko na annual, z payment method |
| **Brick** | App jest w pełni darmowy | Wszystko w app free; monetyzacja = **fizyczne NFC urządzenie** | — | — | — | **Hardware 59 USD one-time** | 30-dniowy money-back (nie trial w AS sense) |
| **Forest** | iOS: upfront 3,99 USD one-time; brak free tier | Allow-list, advanced stats, friends rooms, więcej drzew. Nowa warstwa **Forest Plus subscription** (enhanced app block, focus pause, live-activities) | — | n/a publicly | n/a publicly | 3,99 USD core (legacy) | Prawdopodobnie 7 dni na Plus |
| **Freedom** | **7 focus sessions total** (bez CC!) — rzadki „soft trial" w kategorii | Unlimited sessions, Locked Mode (niemożliwość ended early), cross-device (iOS/Android/Mac/Win/Chrome), Block Apps + Internet, whitelist, Focus Sounds | — | **8,99** | **39,99** (≈3,33/mies) | **159,99** | 7 sesji bez CC |
| **ScreenZen** | Wszystko free (set pick-up limits, harmonogramy, Global Lock) | Donations + hardware add-on **halo** 49 USD | — | — | — | Halo 49 USD | — |

### Wspólne wzorce (synteza)

**Free tier design:** dominujący wzorzec to **„1-of-everything" gating** — 1 recurring session (Opal), 1 target app (one sec), 1 rule (Jomo). Deep Focus / „can't-end-early" mode to **#1 paywalled feature we wszystkich appkach** — największy willingness-to-pay driver. Whitelist vs blocklist: free users dostają blocklist only. Historia/analytics prawie zawsze paid (Opal: tylko dziś, Jomo: multiple budgets paid).

**Pricing tiers annual:** klaster **29,99–39,99 USD/rok** (Jomo, Freedom, one sec) zgodnie z RevenueCat medianą Health & Fitness (29,65 USD). **Opal to outlier na 99,99 USD/rok** — zakotwiczony przez 399 USD lifetime i 19,99 monthly, pozycjonowany premium. Monthly klaster **5,99–8,99 USD**. Lifetime: 99–159 USD, czyli ~3–4× annual.

**Trials:** **3-dniowy (Jomo annual-only)** to najkrótszy; **7-dniowy** (one sec, Freedom) modalny. Wszyscy z payment method przez Apple EXCEPT **Freedom's 7-session no-CC trial**. Trial tylko na annual to near-universal tactic.

**Paywall placement:** 3–5 onboarding screens → **soft paywall z close button**. Hard paywalls są rzadkie, bo core loop wymaga Screen Time permission grants których nie chcesz zablokować za paywallem. Price anchoring: yearly jako „per week/month", monthly na pełną cenę, lifetime jako kontrast z badge „Save 58%". Social proof: Apple App of the Day, „60k+ 5★", press logos (NYT, Time, Lifehacker), „2M+ users".

**Poland specifics:** **żadna z 7 aplikacji nie ma PLN storefrontu**. Wszyscy polegają na Apple auto-conversion (Opal ~399 PLN/rok, one sec ~79 PLN/rok, Jomo ~119 PLN/rok na kursach Apple 2025). Freedom to web-checkout Stripe/PayPal z card-network FX markupem.

### Benchmarki RevenueCat State of Subscription Apps 2025/2026

| Metric | Wartość |
|---|---|
| Download → trial (Health & Fitness median) | **6,7%**; top 10% 13,5% |
| Download → trial (Business) | 6,9%; top 10% 13,3% |
| Trial → paid (H&F median) | **39,9%**; top 10% 68,3% |
| Trial → paid (>4 dni) | ~45% vs ~30% dla ≤4 dni |
| Annual vs monthly revenue share — **Productivity: 77% monthly** (outlier) | Health & Fitness: 68% annual |
| Annual plan retention po 1 roku | **44,1% median** (spadek YoY z 47,1%); top quartile 60–75% |
| Monthly plan retention po 1 roku | **17,0% median** |
| Weekly plan retention | 3,4% |
| Annual pierwsza miesięczna cancel rate | **~30%** (najbardziej krytyczny moment) |
| Cancellation reason #1 | „Not enough usage" (32–47%) |
| Refund rate hard paywall | 5,8% vs 3,4% freemium; H&F refunds 4,71% |
| Revenue per install (H&F) | 0,44 USD D14, 0,63 USD D60 |
| Median CSS annual price | 29,99 USD; upper quartile ~90 USD |
| Standard annual discount vs monthly×12 | ~17% (głębsze discountyczą rewolucję) |

---

## 4. Paywall UX i implementacja

### Kiedy pokazać paywall
Dla focus apps **dominuje hard paywall (albo quasi-hard z małym „X") po spersonalizowanym onboardingu** — tak robi Opal, one sec, Jomo. Dane: **~50% trial starts happens during onboarding** (Mojo via RevenueCat), **>80% trial starts na Day 0** (SOSA 2025). Rosie Hoggmascall case: przeniesienie paywalla z głęboko-w-app do early-flow wyciągnęło trial opt-in z 2% → 8% → 15%. Rootd 5×owało revenue przez paywall na start onboardingu (dismissible).

### Kanoniczny flow onboarding → paywall (9 kroków)
1. Welcome/hook z one headline („Take back your focus").
2. Problem framing (1–2 screens: „avg person unlocks phone 96×/day").
3. Goal selection („Reduce social media / Study deeper / Sleep better").
4. Profile questions (experience, które apki blokować).
5. Social proof (rating, user count, press).
6. **Value recap / „personalized plan"** — pattern Noom/Fastic, najsilniejszy konwersyjnie.
7. Commitment pledge („I'll limit Instagram to 30min/day").
8. Notification permission prime.
9. Paywall framed as „Start your plan".

Superwall: personalizowane paywalle **+15%** conv. Adapty: USP-focused copy **do +40%** revenue.

### Elementy, które konwertują

| Element | Best practice 2025/2026 |
|---|---|
| **Social proof** | User count, star rating, 1–2 review cards, press logos |
| **Price anchoring** | Annual jako **per-week**: „1,50 USD/tydz, rozliczane rocznie 77,99 USD" obok przekreślonej tygodniowej |
| **Plan selection** | 2–3 opcje max, annual default, radio/card style |
| **„Most popular" badge** | Na annual, z savings % („SAVE 60%") |
| **Trial CTA** | „Start 7-day free trial" gdy eligible, inaczej „Continue". **Unikaj** samego „Continue" gdy trial implicit — rejection 3.1.2 |
| **Urgency** | Używaj rzadko; legitimate intro-offer countdown OK, fake — Apple reject |
| **Restore Purchases** | **Wymagane na paywallu** (Apple checklist) |
| **Terms of Use / Privacy Policy** | **Wymagane jako tappable links wewnątrz aplikacji**, nie tylko w ASC metadata. Użyj „Terms of Use" (nie „Terms of Service") |
| **Trial timeline** | Visual: „Dziś: unlock → Day 5: reminder → Day 7: sub starts" — redukuje refundy |

### ⚠️ Toggle paywalls = dead w 2026
**Od połowy stycznia 2026 Apple mass-rejectuje paywalle z togglem free-trial/no-trial** pod 3.1.2 jako „confusing and misleading". Toggle był #1 conversion pattern 2022–2025, teraz **auto-reject**. Zgodne zamienniki: dwa jawnie labelowane plan cards, ewentualnie eligibility-based paywall swapping.

### SubscriptionStoreView vs custom SwiftUI

**SubscriptionStoreView** (iOS 17+) wygrywa dla MVP: 50 LOC vs 500+ dla custom, Apple sam utrzymuje zgodność z guidelines, auto-handles intro offers, upgrade/downgrade, Ask to Buy, accessibility, localization. **Ograniczenia**: marketing content tylko powyżej plan listy (nie pomiędzy), nie da się zrobić Duolingo-style multi-page narrative paywalla, nie można remote A/B testować bez app update.

Minimalny compliant paywall:
```swift
SubscriptionStoreView(groupID: "21234567") {
    MarketingContent()
        .containerBackground(
            LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom),
            for: .subscriptionStoreFullHeight
        )
}
.subscriptionStoreControlStyle(.prominentPicker)
.subscriptionStoreButtonLabel(.multiline)
.storeButton(.visible, for: .restorePurchases, .policies)
.subscriptionStorePolicyDestination(url: termsURL, for: .termsOfService)
.subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
```

**Rule of thumb:** marketing-heavy storytelling paywall z dużym scroll → **custom SwiftUI** (używając `Product.purchase()` pod spodem). Prosty 2–3 planów z hero image → **SubscriptionStoreView**.

### A/B testing paywalli bez RevenueCat/Superwall
**Product Page Optimization (PPO):** do 3 treatments vs baseline, max 90 dni, jeden test naraz, testuje **icon/screenshots/previews — nie in-app paywall**. **Custom Product Pages (CPP):** do **70 CPPs per app** (double'owało się 29 października 2025), każda z unikalnym URLem, keyword-taggable (od połowy 2025) — świetne pod płatne kampanie z dopasowanym landingiem.

**In-app A/B bez vendora (pure native recipe):**
```
1. JSON feature flags na Cloudflare R2/Pages (free).
2. Stabilny deviceID w Keychain (UUID).
3. Hash(deviceID + experimentName) % 100 → variant bucket.
4. Fetch config na launch, z cache fallback.
5. Render PaywallA vs PaywallB.
6. Loguj paywall_view, trial_start, purchase z variant tag do TelemetryDeck/PostHog.
```
Limitacje: brak server-side significance engine, zmiana designu wymaga app update chyba że budujesz JSON-driven renderer.

---

## 5. App Store Server Notifications v2 — czy potrzebujesz?

### Pełna lista typów eventów v2
`SUBSCRIBED`, `DID_RENEW` (+ subtype `BILLING_RECOVERY`), `DID_FAIL_TO_RENEW` (+ `GRACE_PERIOD`), `EXPIRED` (+ `VOLUNTARY`/`BILLING_RETRY`/`PRICE_INCREASE`/`PRODUCT_NOT_FOR_SALE`), `GRACE_PERIOD_EXPIRED`, `DID_CHANGE_RENEWAL_PREF` (+ `UPGRADE`/`DOWNGRADE`), `DID_CHANGE_RENEWAL_STATUS` (+ `AUTO_RENEW_ENABLED`/`DISABLED`), `OFFER_REDEEMED`, `PRICE_INCREASE` (+ `PENDING`/`ACCEPTED`), `REFUND`, `REFUND_DECLINED`, `REFUND_REVERSED`, `CONSUMPTION_REQUEST` (12h window), `RENEWAL_EXTENDED`, `RENEWAL_EXTENSION`, `REVOKE` (Family Sharing revoke), `TEST`, `EXTERNAL_PURCHASE_TOKEN`, `ONE_TIME_CHARGE` (nowy iOS 26), `RESCIND_CONSENT` (iOS 26.x sandbox).

### Co CANNOT be detected z pure client + `Transaction.updates`
1. **Refund gdy app nie runs** — `Transaction.updates` fire'uje tylko gdy proces żyje. Refund wczoraj → user pozostaje entitled aż do następnego otwarcia aplikacji. Lag: godziny–dni.
2. **Family Sharing revocation** w real time.
3. **Cancellation outside app** — user w Settings „Cancel Subscription" tylko zmienia `willAutoRenew=false` w RenewalInfo; żadnego immediate eventu.
4. **Billing retry / grace period** transitions w real time.
5. **Price increase consent pending** — tylko przez `PRICE_INCREASE` server notification.
6. **Consumption requests** (12h window) — **niemożliwe z clienta**.
7. **Cross-device/cross-platform analytics** — `Transaction.updates` runs tylko na instalującym device.
8. **Refund Reversed** — prawie niewidoczny on-device.
9. **External purchase tokens** (EU DMA) — pure server.
10. **Full audit trail dla disputes** — client-side `Transaction.all` truncate'uje historię.

### Workaround dla client-only
```swift
@main
struct MyApp: App {
    @StateObject var store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .task {
                    for await vr in Transaction.updates {
                        if case .verified(let tx) = vr {
                            await store.updateEntitlement(tx)
                            await tx.finish()
                        }
                    }
                }
                .task { await store.refreshEntitlements() }
                .onChange(of: scenePhase) { _, new in
                    if new == .active { Task { await store.refreshEntitlements() } }
                }
        }
    }
}
```
Plus: manual `AppStore.sync()` tylko na explicit „Restore Purchases" tap. Sprawdzaj `Product.SubscriptionInfo.Status.state` dla grace/billing retry.

### Kiedy warto postawić lightweight backend
- Sprzedajesz **consumables** i chcesz wygrywać refund disputes (musisz odpowiedzieć na `CONSUMPTION_REQUEST`).
- Multi-device / multi-platform (web, Android, Mac) — entitlement sync.
- Analytics (accurate MRR, churn, cohorts).
- Automatic „save" emails na `AUTO_RENEW_DISABLED` zanim sub wygaśnie.
- Anti-fraud cross-check z App Store Server API.

Dla Opal-clone MVP **żadne z tych nie stosuje się**. Pomiń aż do Stage 2.

---

## 6. Receipt validation w 2026

### On-device (default)
`VerificationResult<Transaction>.verified` znaczy: JWS signature checkuje do Apple root CA, `bundleId` matches, `deviceVerification` nonce matches. **Wystarczające dla większości aplikacji.** `AppTransaction.shared` (iOS 16+) zastępuje legacy receipt file — JWS signed, auto-verified.

### Kiedy warto server-side via App Store Server API v2
1. **Anti-fraud na jailbreak** — atakujący może hookować StoreKit i zwracać fake `.verified`. Server-side `GET /inApps/v1/transactions/{id}` jest niepodważalne.
2. **Cross-device entitlement sync** (web/Android source of truth).
3. **Non-iOS clients**.
4. **Business analytics** (MRR, LTV, cohorts).
5. **Long-term history** (`/inApps/v1/history/{id}`) — client-side może missować stare refundy.
6. **`CONSUMPTION_REQUEST` response** — niemożliwe bez serwera.

**Realistic risk dla Opal-clone solo deva: niski.** 5–10 USD/mies productivity z małym TAMem jailbreakerów nie potrzebuje server-side validation. Dodaj gdy wyjdziesz na web lub wejdziesz na premium price bands.

---

## 7. Family Sharing dla subscriptions

### Konfiguracja
Per product w App Store Connect, toggle `isFamilyShareable`. **Nieodwracalny po włączeniu** (userzy mogli kupić na podstawie tej funkcji). W Swift: `product.isFamilyShareable` (Bool).

### Revenue impact
Jeden zakup = do **5 dodatkowych family members** (6 total włącznie z purchaser). Revenue per purchase bez zmian; tradeoff: per-seat revenue za lepszą **conversion i retention** (shared subs churn znacząco mniej). Dla Opal-clone focus app: **włącz** — focus apps są często używane przez pary/rodziny („wspólne odcinanie się od telefonów wieczorem"), a pojedynczy user płacący 49,99 USD/rok z wiarą, że to też dla partnera, to lepszy deal niż dwóch nie-subskrybentów.

### Implementacja
```swift
switch tx.ownershipType {
case .purchased:    // user kupił sam
case .familyShared: // dostał przez Family Sharing
@unknown default: break
}
```
**Nie lockuj entitlement na `.purchased`** — po prostu grantuj dostęp niezależnie od ownershipType. Z iOS 18.4 `appTransactionID` każdy family member ma unikalny ID (nawet ze współdzielonym `originalTransactionID`), co daje czyste per-user analytics.

### UX implications dla focus apps
Jeśli twoje sesje/profile synchronizują się przez iCloud (CloudKit), musisz rozgraniczyć per-user data vs per-account data — family member nie powinien widzieć sesji purchasera. Rozwiązanie: CloudKit private database per Apple ID (dzieje się automatycznie), a entitlement checkuj przez StoreKit osobno.

---

## 8. Trial abuse prevention

### Jak działa `isEligibleForIntroOffer(for:)`
```swift
let eligible = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
```
Eligibility jest określana **przez Apple server-side na bazie signed-in Apple ID + subscription group ID** — nie per device. Zasada: **jeden intro offer per subscription group per Apple ID, lifetime**. Value cache'owana on-device ale refresh'owana przy sync.

### Czy user bypassa delete/reinstall?
**Nie.** Eligibility jest przypisana do Apple ID, nie device ani installation. Reinstall, reset device, switch device — żadne nie resetują eligibility. **Jedyny real bypass: nowy Apple ID.** Apple nie udostępnia sposobu detekcji tego.

### Edge cases

| Sytuacja | Eligibility |
|---|---|
| Nowy Apple ID sign-in | Fresh eligibility (jedyny bypass) |
| User zrefundował trial | Nadal nie-eligible (Apple track'uje redemption) |
| Different subscription group w tej samej apce | Per-group → fresh eligibility |
| Family-shared recipient | Jeśli sam nie użył intro — pozostaje eligible gdy kupi direct |
| Stary sub wygasł lata temu | Nie-eligible dla intro, ale **eligible dla win-back offers (iOS 18+)** — to sanctioned way Apple na second-chance trials |

### Praktyczne podejście dla Opal-clone
- Zawsze surface intro offer eligibility przed renderem paywalla (`SubscriptionStoreView` robi to auto).
- Nie hardcode'uj „free trial" copy — renderuj conditionally na bazie `product.subscription?.introductoryOffer` + eligibility.
- **Akceptuj straty z repeat-trial abuse** (new Apple IDs). Mitigation przez twój własny account system (`appAccountToken` + server heuristics, device fingerprint, IP) jest non-trivial i rzadko warty dla solo deva.
- **Win-back offers (iOS 18+)** to Apple-sanctioned way na re-engagement — skonfiguruj w ASC (Minimum Paid Duration, Time Since Last Subscribed, Wait Between Offers), Apple automatycznie merchandise'uje w Settings → Subscriptions, in-app sheet (StoreKit Message API), App Store product page.

---

## 9. App Store Review — specifics dla focus apps

### Family Controls entitlement — wciąż gated w 2026
**Tak**, osobny approval flow poza normalnym App Review.

**Proces:**
1. W Apple Developer → Certificates, IDs & Profiles → twój App ID → add **Family Controls (Development)** capability (auto-approved).
2. Dla shipowania: osobno request **Family Controls (Distribution)** przez form developer.apple.com/contact — **per bundle ID, włącznie z każdym extensionem** (Shield Configuration, Device Activity Monitor, Device Activity Report extensions każde wymagają osobnej approval).
3. Uzasadnienie: dlaczego potrzebujesz, jak app pomaga **userowi zarządzać własnym czasem**, privacy stance na `FamilyActivitySelection`.

**Timelines 2025/2026 z Apple Dev Forums:**
- Main app bundle: 1–7 dni typowo, czasem tygodnie.
- **Extension bundles: 2 tygodnie do kilku miesięcy** (liczne posty z listopad 2025–marzec 2026 zgłaszają „stuck in Submitted" 2–4 tygodnie). Developer Support tickets często bez odpowiedzi.
- Rejekcje zwykle cite insufficient justification → resubmit z więcej szczegółów o user-management intent i privacy.

**⚠️ Action item dla user:** Złóż request **zanim dokończysz build**. To krytyczna ścieżka.

**Frameworki:**
- **FamilyControls** — `AuthorizationCenter.shared.requestAuthorization(for: .individual)` (`.individual` dla self-control, `.child` dla parental control).
- **ManagedSettings** — `ShieldSettings`, `ManagedSettingsStore`.
- **DeviceActivity** — `DeviceActivityMonitor` extension (scheduled events), `DeviceActivityReport` extension (SwiftUI usage reports, **dane opaque — nie można ich odczytać w host app**).
- **Opaque tokens**: `ApplicationToken`, `WebDomainToken`, `ActivityCategoryToken` — persist OK, dekodowanie nie, **żadnego wysłania na serwer**. To #1 compliance tripwire.

### Guideline 3.2.2 / 5.1.1 — „nie możesz monetyzować samego API"
Cytat: *„You may not monetize built-in capabilities provided by the hardware or operating system, such as (...) Screen Time APIs."*

**Znaczenie:** Nie możesz brać kasy *wyłącznie* za dostęp do Screen Time APIs. Musisz oferować wartość na wierzchu — multiple profiles, scheduling, gamification, analytics, nudges — i to subskrypcja odblokowuje. Opal/Jomo/one sec spełniają to przez whitelist + scheduling + Strict Mode + history + breathing interventions jako paid features.

### Guideline 5.5 nie dotyczy
5.5 (MDM) dotyczy enterprise mobile device management, nie Screen Time API. Self-control apps rely on **Family Controls entitlement pod 5.1 (Privacy)**. Nie próbuj aplikować jako MDM.

### Guideline 3.1.2 — wymagania paywalla (inside app UI, nie tylko ASC metadata)

| Wymagane | Realizacja |
|---|---|
| Title subskrypcji | „Focus Pro — Yearly" |
| Length okresu | „1 year" / „1 month" — spell out |
| Price per period | „59,99 USD/year" — duże, czytelne |
| Auto-renewal disclosure | „Subscription automatically renews unless canceled at least 24 hours before the end of the current period." |
| Terms of Use (EULA) link | Tappable w paywallu + w ASC metadata. Użyj „Terms of Use", nie „Terms of Service" |
| Privacy Policy link | Tappable w paywallu + w ASC |
| Restore Purchases button | Wymagany na paywallu (+ w Settings) |
| Free trial disclosure | „7 days free, then 59,99 USD/year. Cancel anytime." **Nie rób trial bardziej prominent niż billed amount** — konkretny rejection reason |

Apple w 2025/2026 **rozluźnił** wymaganie długiego „Payment will be charged..." paragrafu w paywallu — nie jest już strictly required, ale większość devs dodaje jako fine print dla safety.

**Metadata w ASC:** Privacy Policy URL ma dedykowane pole; **Terms of Use nie** → dodaj na końcu App Description: `Terms of Use: https://...`.

### Typowe rejection reasons

| Rejection | Frekwencja | Fix |
|---|---|---|
| 3.1.2 missing disclosures | Bardzo wysoka | Dodaj wszystkie linki + button |
| 3.1.2 „free trial promoted more than billed" | Wysoka (od 2024) | Bold billed price, ≥ prominence „free" |
| **3.1.2 toggle paywall** | Auto-rejection od stycznia 2026 | Dwa jawne plan cards |
| Family Controls misuse (tokens na serwer, analytics) | Instant rejection + entitlement risk | Tokens local only |
| 4.3 Spam/duplicate (dużo Opal-clonów) | Średnia | Silne differentiation: unikalna UX, unique feature (AI, accountability partner, bedtime wind-down), oryginalne copy i screenshots. **Nie kopiuj Opala 1:1.** |
| 2.3.1 Misleading claims | Średnia | Nie claim „scientifically proven" bez citation |
| 5.1.1 Privacy | Średnia | Privacy Policy URL, App Privacy nutrition label, purpose strings |
| 4.2 Minimum Functionality | Średnia | Pre-populate sample blocking profile na first launch dla reviewera |
| 2.1 Reviewer can't test | Wysoka operacyjnie | **Note to Reviewer** wyjaśniający Family Controls auth flow + screen recording |

### EU DMA / CTF / CTC w 2026
- Od iOS 17.4 (marzec 2024): EU devs mogą link out do external payments lub dystrybuować przez alternative marketplaces/web distribution.
- **Core Technology Fee (CTF) jest phaseowany out**. Apple zobowiązało się przejść do **Core Technology Commission (CTC)** — 5% na digital goods sold via external payment links — z unified business model **od 1 stycznia 2026**. W kwietniu 2026 unified model się rolluje, specifics wciąż finalizowane z EC.
- **Rekomendacja dla solo deva: zostaw standard App Store IAP.** CTF/CTC math tylko favours you at bardzo dużej skali. RevenueCat's własny test web checkout = **-6% takehome revenue per user** (niższa konwersja mimo 0% Apple cutu + Stripe fees).

---

## 10. Analytics i optymalizacja

### Metryki

| Metryka | Formuła |
|---|---|
| Paywall impression → trial | trials / paywall views (split by placement) |
| Trial → paid | converted / trials started (>80% decyzji w pierwszym tygodniu) |
| Download → paid D35 | paid subs / installs w 35 dni |
| D1/D7/D30 retention | % active na day N |
| Monthly / annual churn | cancellations / active |
| First-renewal rate | renewed / first-term-ends (biggest single churn event) |
| ARPU / ARPPU | revenue / (all users / paying users) |
| LTV | ARPPU × avg sub months × margin |
| LTV:CAC | target >3:1 steady state |
| Refund rate | refunds / gross (trial-to-annual może być 4× monthly) |

### Tools comparison

| Tool | Free tier | Paid 2026 | Verdict solo dev |
|---|---|---|---|
| **App Store Connect Analytics** | Free | — | Baseline. WWDC25 dodało dedicated Subscriptions section + Download-to-Paid cohorts, Avg Proceeds per Download. Delay 1–3 dni, agregowane. Authoritative. |
| **TelemetryDeck** | 10k signals/mies free | ~12–20 EUR/mies starter | **Pierwszy wybór dla iOS-native solo deva.** GDPR by design (double-hashed IDs), Swift-first, SPM, tanio, proste dashboardy |
| **PostHog** | 1M events/mies + 5k replays free | ~0,00005 USD/event; self-host free | **Drugi wybór.** All-in-one: analytics + feature flags + session replay + A/B. Feature flags świetne pod paywall A/B |
| **Mixpanel** | 1M events/mies free | Szybko drogie powyżej free | Polished funnels, non-technical friendly; expensive at scale |
| **Amplitude** | 50k MTUs free (Starter) | Custom | Strong cohorts; enterprise-oriented |
| **Aptabase** | Free tier + ~20 USD/mies | 20+ USD cloud | **Disqualifying: cannot compute MAU/retention/funnels** (brak user IDs) |
| **RevenueCat** (gdy zmienisz zdanie) | Free ≤ 2,5k MTR | 1% MTR | Best-in-class subscription data; vendor lock-in |

**Rekomendowany stack bez RevenueCat:** ASC Analytics (truth-of-record acquisition + subscription) + **TelemetryDeck** (in-app behavior, onboarding funnel, paywall events) + **Cloudflare JSON** (remote flags / A/B assignment). Pull ASC subscription CSV monthly do arkusza dla LTV/retention math. Jeśli chcesz feature flags w jednym: **PostHog free**.

### Benchmarki Productivity / Health & Fitness 2025/2026
(Powtórzone z sekcji 3, teraz jako optimizacyjny target.)
- Download → trial median: **H&F 6,7%, Business 6,9%**. Target top 10% = 13,5%.
- Trial → paid: **H&F 39,9% median, top 10% 68,3%**. Longer trials (17–32 dni) konwertują 45,7% median.
- Annual/monthly split dla Opal-clone: **mierz się z Health & Fitness (68% annual)** — twoja cechą jest habit building, nie productivity.
- Annual po 1 roku retencja: **44,1% median**. Pierwsza miesięczna cancel rate dla annual: **~30%** (krytyczny moment).
- Monthly po 1 roku: 17% median; weekly 3,4%.
- Median annual price: **29,99 USD** (upper quartile ~90 USD).

---

## A. Decision tree — native StoreKit 2 vs dodatki

```
Solo dev, MVP, no backend — Opal-clone focus app 2026
│
├── STAGE 1 (0 → 5k USD MRR)
│   → PURE NATIVE StoreKit 2 + SubscriptionStoreView
│   → + TelemetryDeck (free 10k signals) lub PostHog free
│   → + Cloudflare R2 JSON dla paywall copy remote config (opcja)
│   → Koszt: 0 USD/mies. Czas wdrożenia: 2 dni.
│   → Akceptuj limitations 1–15 (sekcja 2).
│
├── STAGE 2 (5 → 25k USD MRR, albo chcesz A/B paywall)
│   → Dodaj Superwall Indie (free ≤ 10k USD MAR, potem 1%)
│   │   — używaj własnych paywall views lub ich no-code editor
│   │   — purchase SDK Superwall LUB zostaw Product.purchase() (oba działają)
│   → Dodaj Cloudflare Worker + KV dla App Store Server Notifications v2
│   │   — Apple's @apple/app-store-server-library do JWS verify w 10 LOC
│   │   — KV trzyma „is_premium" + expiresAt per appTransactionID
│   → Koszt: 0–100 USD/mies przy 10k MAR.
│
└── STAGE 3 (25k+ USD MRR, albo Android/web)
    → Migruj entitlementy do RevenueCat (1% MTR) lub Adapty (1% ≥ 5k)
    │   — cheapest przy skali: Qonversion Starter 0,6%
    │   — dla najszerszego ekosystemu + integracji: RevenueCat
    │   — dla najlepszego paywall buildera + indie-friendly: Adapty
    → Zostaw Superwall jako paywall layer na górze (oficjalna integracja z RC)
```

**Dlaczego NIE RevenueCat w Stage 1:** próg 2,5k USD MTR (obniżony z 10k), 1% efektywnie ~1,43% po Apple cut — bijesz się o to od pierwszych kwot. Killer feature RC (cross-platform entitlements) nie ma znaczenia dopóki nie ma Android/web.

**Dlaczego NIE full backend w Stage 1:** focus app nie ma high-stakes fraud, consumption requests, ani volume CS. `Transaction.currentEntitlements` on foreground pokrywa 95%. ASC refund notifications na email wystarczą dla <100 subs/mies.

---

## B. Product skeleton — Free vs Paid dla Opal-clone

Na podstawie benchmarków z sekcji 3 (dominant pattern = „1-of-everything" gating + Deep Focus paywalled + Whitelist paid + History paid).

### Free tier
- **1 recurring focus session** (1 schedule, np. „weekdays 9–17") — jak Opal
- **Unlimited on-demand sessions**, ale z easy bypass — jak Opal
- **1 blocking profile** (np. „Social media") — jak Jomo (1 rule)
- **Blocklist only**, brak whitelist — uniwersalne
- **Focus Score / stats tylko dzisiaj**, bez historii — jak Opal
- Domyślny sample profile na onboardingu (compliance z Guideline 4.2 Minimum Functionality)
- Podstawowe widgets (tylko status „active session") — jak Forest

### Paid tier (Focus Pro)
- **Deep Focus mode** — hard lock, nie można end early (#1 willingness-to-pay — Opal/Jomo Strict Mode/Freedom Locked) 
- **Unlimited recurring sessions** + **unlimited blocking profiles** — jak Opal/Jomo
- **Whitelist mode** (allow-list blocking) — jak Opal
- **Pełna historia Focus Score + Focus Report** z trendami 30d/90d/1y — jak Opal
- **Harder bypass difficulties** (typed commitment text, 4-7-8 breathing, phone rotation) — jak one sec
- **Schedules z geofencingiem i automatyzacją** (Shortcuts integration) — differentiator
- **Emergency unlock passcode / QR-code unlock** — jak Jomo
- **Multi-device sync** (CloudKit) — jak Opal
- **Apple Health integration** (screen time vs sleep correlation) — jak Jomo
- **Custom themes / app icon** — jak Jomo/Opal
- **Family Sharing** — enabled, revenue tradeoff za retention
- **Siri Shortcuts + Live Activities** — native iOS 26 features jako differentiator

### Jak NIE robić Guideline 3.2.2 rejection
Subskrypcja musi odblokować **własną wartość poza samym Screen Time API**. Powyższy set to robi: custom scheduling engine, emergency UX, breathing interventions, Health correlation, themes, cross-device sync. Nie sprzedajesz „dostępu do blokowania", sprzedajesz system wokół blokowania.

---

## C. Rekomendowany pricing PLN / USD / EUR

**Uzasadnienie:** median H&F annual = 29,99 USD, ale Opal na 99,99 USD, Jomo 29,99, Freedom 39,99. Dla nowego wejścia **pozycjonuj się między Jomo a Opal — oferuj premium wartość za średnią cenę**. Cel: 60–70% annual revenue share (jak Health & Fitness, nie 77% monthly jak Productivity).

### Cenówka USD (primary market)
- **Weekly: NIE oferuj** — retencja weekly 3,4% po roku, wysokie refund rates, postrzegany jako dark pattern. Dla focus app to sprzeczność wartościowa („help me quit addictions" via slot-machine-style weekly billing).
- **Monthly: 8,99 USD** — między Jomo (5,99) a Freedom (8,99), jako „świadomie zły wybór" pokazany obok annual.
- **Annual: 49,99 USD** (≈4,17/mies, ≈0,96/tydz). Price anchoring: „0,96 USD/tydz, billed annually at 49,99 USD" vs „8,99 USD/mies". Implied discount: **53% off monthly×12**. W środku między Jomo (29,99) a Opal (99,99), oferujesz premium value za fair price.
- **Lifetime: NIE w MVP** — RevenueCat generalnie odradza. Rozważ dopiero gdy masz walidację retencji + chcesz cashflow boost. Jeśli dodasz: **129,99 USD** (≈2,6× annual, anchor dla annual).

### Cenówka PLN (Polska)
Apple Pricing Tier matrix auto-mapuje USD→PLN. **Wybierz tiery z PLN kończącymi się na „99"** — psychologicznie mocne po polsku jak po angielsku.
- **Monthly: 39,99 PLN** (Apple Tier dla ~8,99 USD) — lub 34,99 jeśli chcesz aggressive PLN pricing
- **Annual: 199,99 PLN** (Apple Tier dla ~49,99 USD)
- Nie rób dedykowanego PLN storefrontu ani osobnych translacji marketingowych na Stage 1 — żaden z 7 teardownowanych konkurentów tego nie robi. Polskie App Store automatycznie przetłumaczy localization keys. Ty zadbaj tylko o:
  - Polską lokalizację paywalla (pl.lproj)
  - Poprawne deklinacje („7 dni za darmo", „potem 199,99 zł/rok")
  - Terms/Privacy w wersji PL na landing page

### Cenówka EUR (strefa euro)
- **Monthly: 9,99 EUR** (Apple Tier)
- **Annual: 54,99 EUR** (slight euro premium jak większość apek)

### Trial model
**7-dniowy free trial z payment method, tylko na annual plan.** Rationale:
- SOSA 2025: trials >4 dni konwertują 45% vs 30% dla ≤4 dni.
- 7d to modal length w kategorii (one sec, Freedom).
- Trial only-on-annual pushuje ku długoterminowemu planowi (Jomo, Freedom robią to).
- Card-required trial = standard App Store trial = Apple handles abuse prevention via `isEligibleForIntroOffer`.
- **Nie rób 3-dniowego** — najwyższa Day-0/Day-1 cancel rate.
- Nie rób 14/30-dniowego w MVP — pokusa retencyjna ale ryzyko ARR lag i zwiększony CAC payback.

### Regional considerations
- **Apple auto-FX** działa dobrze dla PLN, CZK, HUF — nie ręczne ceny.
- **Poland specifics:** App Store Polska używa PLN, VAT 23% wliczony w cenę (Apple handle), wypłata do twojego konta w USD/EUR/PLN zależnie od banku.
- **Rozważ „local pricing" na Opal-style premium tier w USA/UK (69,99 USD) + lower w PL (149,99 PLN)** tylko jeśli osiągniesz Stage 2 i PostHog pokaże silną PL cohort z niższym ARPU. W MVP: jeden pricing tier globalnie.

---

## D. Minimum code skeleton — StoreKit 2 full flow

Pełny szkielet: product load → purchase → observe → unlock → propagate do extension przez App Group UserDefaults.

```swift
// MARK: - Store.swift (shared module, dostępny dla main app + extensions)
import Foundation
import StoreKit

@MainActor
@Observable
final class Store {
    // Produkty z App Store Connect subscription group
    static let productIDs = ["focuspro.monthly", "focuspro.yearly"]
    static let subscriptionGroupID = "21234567"
    static let appGroupID = "group.com.yourco.focuspro"
    static let entitlementKey = "isPremium"
    static let entitlementExpiresKey = "premiumExpiresAt"
    
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isPremium: Bool = false
    private(set) var introOfferEligible: Bool = true
    
    private var updateListenerTask: Task<Void, Never>?
    private let appGroupDefaults = UserDefaults(suiteName: Store.appGroupID)
    
    init() {
        // 1. Start listener PRZED jakimkolwiek innym action (inaczej zgubisz tx)
        updateListenerTask = listenForTransactions()
        
        // 2. Restore z App Group cache dla instant startup
        isPremium = appGroupDefaults?.bool(forKey: Store.entitlementKey) ?? false
    }
    
    deinit { updateListenerTask?.cancel() }
    
    // MARK: Product loading
    func loadProducts() async {
        do {
            products = try await Product.products(for: Store.productIDs)
            await checkIntroOfferEligibility()
        } catch {
            print("Product load failed: \(error)")
        }
    }
    
    // MARK: Intro offer eligibility (per-group, authoritative)
    func checkIntroOfferEligibility() async {
        introOfferEligible = await Product.SubscriptionInfo
            .isEligibleForIntroOffer(for: Store.subscriptionGroupID)
    }
    
    // MARK: Purchase
    func purchase(_ product: Product, appAccountToken: UUID? = nil) async throws -> Transaction? {
        var options: Set<Product.PurchaseOption> = []
        if let token = appAccountToken {
            options.insert(.appAccountToken(token))
        }
        let result = try await product.purchase(options: options)
        
        switch result {
        case .success(let verification):
            let tx = try checkVerified(verification)
            await updateEntitlement(from: tx)
            await tx.finish()
            return tx
        case .pending:
            return nil // Ask-to-Buy / SCA — czekaj na .updates
        case .userCancelled:
            return nil
        @unknown default:
            return nil
        }
    }
    
    // MARK: Transaction.updates listener
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let tx = try await self.checkVerified(result)
                    await self.updateEntitlement(from: tx)
                    await tx.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: Current entitlements refresh (na każdy launch + foreground)
    func refreshEntitlements() async {
        var active: Set<String> = []
        var latestExpiry: Date = .distantPast
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            guard tx.revocationDate == nil else { continue }
            if let exp = tx.expirationDate, exp < Date() { continue }
            active.insert(tx.productID)
            if let exp = tx.expirationDate, exp > latestExpiry {
                latestExpiry = exp
            }
        }
        
        purchasedProductIDs = active
        isPremium = !active.isEmpty
        
        // Propagacja do App Group (sekcja kluczowa dla extensionów)
        appGroupDefaults?.set(isPremium, forKey: Store.entitlementKey)
        if latestExpiry != .distantPast {
            appGroupDefaults?.set(latestExpiry, forKey: Store.entitlementExpiresKey)
        }
    }
    
    private func updateEntitlement(from tx: Transaction) async {
        await refreshEntitlements() // pełny recompute zamiast per-tx diff
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }
    
    // MARK: Restore purchases (explicit user action)
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
}

// MARK: - App entry
@main
struct FocusProApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task {
                    await store.loadProducts()
                    await store.refreshEntitlements()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refreshEntitlements() }
                    }
                }
        }
    }
}

// MARK: - Paywall (SubscriptionStoreView — recommended dla MVP)
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SubscriptionStoreView(groupID: Store.subscriptionGroupID) {
            VStack(spacing: 20) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                Text("Take back your focus")
                    .font(.largeTitle.bold())
                FeatureBullets()
                SocialProofCard()
            }
            .padding()
            .containerBackground(
                LinearGradient(colors: [.indigo, .purple],
                               startPoint: .top, endPoint: .bottom),
                for: .subscriptionStoreFullHeight
            )
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases, .policies)
        .subscriptionStorePolicyDestination(
            url: URL(string: "https://yourapp.com/terms")!,
            for: .termsOfService)
        .subscriptionStorePolicyDestination(
            url: URL(string: "https://yourapp.com/privacy")!,
            for: .privacyPolicy)
        .onInAppPurchaseCompletion { product, result in
            if case .success(.success) = result {
                dismiss()
            }
        }
    }
}

// MARK: - Shield Configuration Extension
// Extension czyta App Group UserDefaults, BEZ bezpośredniego dostępu do StoreKit
import ManagedSettings
import ManagedSettingsUI

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let defaults = UserDefaults(suiteName: Store.appGroupID)
        let isPremium = defaults?.bool(forKey: Store.entitlementKey) ?? false
        
        // Premium users dostają custom branded shield, free podstawowy
        if isPremium {
            return ShieldConfiguration(
                backgroundBlurStyle: .dark,
                backgroundColor: UIColor(named: "BrandPurple"),
                icon: UIImage(named: "PremiumShieldIcon"),
                title: ShieldConfiguration.Label(
                    text: "🌿 Your focus time is active",
                    color: .white),
                subtitle: ShieldConfiguration.Label(
                    text: "Keep going — you chose this.",
                    color: .white),
                primaryButtonLabel: ShieldConfiguration.Label(
                    text: "I'll wait",
                    color: .white)
            )
        } else {
            return ShieldConfiguration(
                title: ShieldConfiguration.Label(
                    text: "Focus active",
                    color: .label)
            )
        }
    }
}

// MARK: - DeviceActivity Monitor Extension
import DeviceActivity
import ManagedSettings

class FocusActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let defaults = UserDefaults(suiteName: Store.appGroupID)
        let isPremium = defaults?.bool(forKey: Store.entitlementKey) ?? false
        
        // Premium: multiple profiles, advanced blocking
        // Free: tylko default profile
        applyBlocking(premium: isPremium)
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
        store.shield.webDomainCategories = nil
    }
    
    private func applyBlocking(premium: Bool) {
        // ... implementation
    }
}
```

**Kluczowe punkty:**
1. **App Group UserDefaults jest jedyną drogą propagacji entitlement do extension.** Shield Configuration Extension i Device Activity Monitor Extension nie mogą bezpośrednio wołać StoreKit (izolowane procesy, brak Apple ID context).
2. **Cache isPremium w App Group** przetrwa app kill — shield nadal będzie się renderować premium wariantem.
3. **Nie ufaj wartości w extension dla krytycznych decyzji** (user mógł anulować sub między launches). Dla security-critical: re-checkuj na każdym foreground main app'a. Dla UX-polish (custom shield): cache OK.
4. **`isEligibleForIntroOffer(for:)`** używaj per-group, nie per-product — authoritative.
5. **`Transaction.updates` start PRZED pierwszym `loadProducts()`/`refreshEntitlements()`** — inaczej race condition gdy transaction fire'uje przed listener startuje.
6. **`AppStore.sync()` tylko na user-initiated restore** — nie periodic, pokazuje Apple ID prompt.

### Custom paywall (Stage 2, gdy potrzebujesz kontroli)
```swift
struct CustomPaywall: View {
    @Environment(Store.self) private var store
    @State private var selected: Product?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Hero()
                SocialProofCards()      // „2M+ users", rating, reviews
                TrialTimeline()         // dziś → dzień 5 reminder → dzień 7 charge
                ForEach(store.products) { p in
                    PlanCard(product: p,
                             isSelected: selected?.id == p.id,
                             introEligible: store.introOfferEligible)
                        .onTapGesture { selected = p }
                }
                TrialCTA(product: selected, eligible: store.introOfferEligible)
                HStack {
                    Link("Terms of Use", destination: URL(string: "...")!)
                    Link("Privacy Policy", destination: URL(string: "...")!)
                    Button("Restore") {
                        Task { try? await store.restore() }
                    }
                }.font(.caption)
            }
        }
    }
}
```

---

## E. Konkretne limitations „native only, no backend" — z workaroundem per każda

| # | Limitation | Workaround / akceptowalne ryzyko |
|---|---|---|
| 1 | Refund gdy app nie runs — lag godziny–dni | Akceptuj. Dla 10 USD/mies ryzyko minimalne; ASC refund emails jako manual fallback |
| 2 | Family Sharing revocation lag | Akceptuj; refresh na foreground łapie w <24h |
| 3 | Cancellation poza app nie fire'uje eventu (tylko `willAutoRenew=false` w RenewalInfo) | Inspectuj `Product.SubscriptionInfo.status` + `renewalInfo.willAutoRenew` na foreground; pokaż in-app reactivation flow |
| 4 | Billing retry / grace period state lag | Na foreground checkuj `status.state == .inBillingRetryPeriod`, pokaż update payment CTA |
| 5 | Price increase consent pending nie visible | Akceptuj — Apple w Settings pokaże user; minimalny impact bez własnej communication |
| 6 | Consumption requests (12h window) | N/A — Opal-clone nie sprzedaje consumables |
| 7 | Brak cross-device/cross-platform analytics | Akceptuj na MVP. Przy Stage 2 dodaj Cloudflare Worker + KV. `appTransactionID` (iOS 18.4+) daje stabilny per-user ID |
| 8 | Refund Reversed niewidoczny | Akceptuj; rzadki case |
| 9 | External purchase tokens (EU) | Nie wchodź w external payments dla MVP |
| 10 | Truncated Transaction.all history | Akceptuj; App Store Server API v2 dla full history dopiero przy Stage 2 |
| 11 | Brak server-side receipt verification (jailbreak risk) | Akceptuj — ryzyko niskie dla 5–10 USD/mies productivity |
| 12 | Brak centralnego entitlement store dla web/support tool | Akceptuj w Stage 1; na Stage 2 Cloudflare Worker |
| 13 | Brak webhook handlingu | Akceptuj; `currentEntitlements` na foreground 95% cases |
| 14 | **Brak A/B paywall bez app review** | Cloudflare R2 JSON + hash(deviceID) bucketing + dwa SwiftUI views. Nie policz significance server-side, eyeballuj w TelemetryDeck. Alternative: Superwall Indie (free) ≤ 10k MAR |
| 15 | Brak wbudowanych analytics | TelemetryDeck (free 10k signals) lub PostHog free. Eventy: `paywall_shown`, `trial_started`, `subscribe_tapped`, `subscribe_succeeded`, `subscribe_failed`, `restore_tapped` |
| 16 | Brak cohort/LTV/churn z pudełka | ASC Analytics subscription CSV monthly do arkusza; pull via ASC Connect API jeśli chcesz auto |
| 17 | Brak integracji MMP (AppsFlyer, Adjust, Branch) | Ręczne forwardowanie purchase events w Store.swift; albo Stage 2 Superwall (forwarduje do 20+ MMPs free) |
| 18 | Promotional offer signing niemożliwe bez backendu | Ogranicz się do intro offers + win-back offers (Apple-managed, no signing) |
| 19 | Offline/flaky network `currentEntitlements` error | Cache last-known-good w App Group UserDefaults; fallback na cache z 24h TTL |
| 20 | `Transaction.updates` może missować tx gdy app nie runs | Zawsze re-checkuj `currentEntitlements` na cold start i foreground (w code skeleton powyżej) |
| 21 | Restore UX friction (AppStore.sync prompt) | Schowaj w Settings; `currentEntitlements` na launch robi silent restore |
| 22 | Intro offer per-Apple-ID-per-group — user bypassuje przez nowy Apple ID | Akceptuj; win-back offers dla prawdziwych lapsed. Server-side fingerprinting nie warty dla solo deva |

---

## F. App Store Review checklist dla focus app z subskrypcją

### Pre-submission (zanim submit na review)
- [ ] **Family Controls (Distribution) entitlement request wysłany dla main app bundle ID** — co najmniej 2 tygodnie przed planowanym submit
- [ ] **Family Controls entitlement request wysłany dla każdego extension bundle ID** osobno (Shield Configuration, Device Activity Monitor, Device Activity Report) — timeline 2–6 tygodni
- [ ] Privacy Policy URL aktywny, dostępny publicznie
- [ ] Terms of Use URL aktywny
- [ ] App Privacy „nutrition label" wypełniony w ASC (dane collectowane, purpose, linking to identity)
- [ ] Subscription group utworzony w ASC z produktami (monthly + yearly)
- [ ] Intro offer (7-day trial na annual) skonfigurowany w ASC
- [ ] `isFamilyShareable` skonfigurowany na produktach (uwaga: nieodwracalne)
- [ ] App Store screenshots: jeśli pokazują paid features, w description dodaj „Some features require a subscription"

### Paywall (Guideline 3.1.2)
- [ ] Title subskrypcji widoczny („Focus Pro — Yearly")
- [ ] Length okresu spelled out („1 year", nie „1y")
- [ ] Price per period w czytelnym rozmiarze ≥16pt
- [ ] Auto-renewal disclosure text widoczny
- [ ] Tappable „Terms of Use" link
- [ ] Tappable „Privacy Policy" link
- [ ] „Restore Purchases" button widoczny (nie schowany w menu) na paywallu
- [ ] Free trial disclosure: „7 days free, then 49.99 USD/year. Cancel anytime."
- [ ] **Billed price NIE mniej prominent niż „free trial"**
- [ ] **Żadnego toggle free-trial/no-trial** (auto-reject od stycznia 2026)
- [ ] CTA clear („Start 7-day free trial" albo „Continue" — match actual action)
- [ ] Terms of Use URL dodany w App Description (w ASC) — bo ASC nie ma dedykowanego pola

### Family Controls / Screen Time usage (5.1, 3.2.2)
- [ ] `AuthorizationCenter.shared.requestAuthorization(for: .individual)` (nie `.child` chyba że robisz parental control)
- [ ] `FamilyActivitySelection` nigdy NIE wysyłane na serwer, nie hash'owane dla analytics, nie logowane
- [ ] `ApplicationToken`/`WebDomainToken`/`ActivityCategoryToken` tylko local storage
- [ ] Subskrypcja odblokowuje **genuine app value beyond raw Screen Time API** (multiple profiles, scheduling engine, Strict Mode UX, history, themes, Health integration, Shortcuts)
- [ ] Nie claim „parental control" jeśli `.individual` — pozycjonuj jako self-management

### Code & UX
- [ ] Sample blocking profile pre-populated na pierwszym launch (compliance z 4.2 Minimum Functionality — reviewer nie widzi pustej aplikacji)
- [ ] `Transaction.updates` listener startuje przed jakimkolwiek innym StoreKit call
- [ ] `Transaction.currentEntitlements` refresh na każdy `scenePhase == .active`
- [ ] App Group UserDefaults propagacja do extensions działa (test na TestFlight)
- [ ] Verification: `VerificationResult.unverified` NIE grantuje entitlement

### Metadata & submission
- [ ] Differentiation od innych Opal-clonów (własne copy, własne screenshots, unikalna feature — np. breathing intervention, AI coach, accountability partner, bedtime wind-down)
- [ ] **Note to Reviewer** z krokami: „1. Grant Screen Time permission when prompted. 2. Tap 'Add Profile' → pick any app from picker. 3. Tap 'Start Focus Session'."
- [ ] Opcjonalny screen recording testu dla reviewera
- [ ] Purpose strings dla Screen Time permission jasne i user-facing
- [ ] App Icon nie skopiowany 1:1 z Opala/Jomo (4.3 spam risk)

### Post-approval monitoring
- [ ] Ustaw App Store Server Notifications v2 URL w ASC (nawet na stub Cloudflare Worker — Apple wymaga valid endpoint)
- [ ] Monitor first-day rejections/crash reports w ASC
- [ ] PostHog/TelemetryDeck dashboardy dla: paywall_view, trial_start, purchase, restore_tapped
- [ ] Refund watch: ASC refund emails + monthly CSV pull

---

## Conclusion — synteza decyzyjna

Native StoreKit 2 w 2026 roku jest **dojrzałe, cryptograficznie bezpieczne przez JWS bez potrzeby backendu**, i pokrywa większość przypadków single-platform solo deva. Krytyczne luki dotyczą nie kryptografii, ale **operacyjnej widoczności** — refundy, analytics, A/B testów paywalla — i wszystkie mają workaroundy za 0 USD/mies (TelemetryDeck/PostHog, Cloudflare R2 remote config, opcjonalny Worker dla webhooks na Stage 2).

Opal-clone w Polsce/globalnie powinien **pozycjonować się jako H&F-style habit app**, nie jako Productivity — category data pokazuje, że 68% annual revenue share jest osiągalne, a 77% monthly (który rządzi Productivity) zostawia pieniądze na stole. Wygraj przez **personalizowany onboarding → soft paywall z widocznym close**, **49,99 USD / 199,99 PLN annual jako default**, 7-dniowym trialem tylko na annual, monthly 8,99 USD / 39,99 PLN jako świadomie gorszy wybór, bez lifetime w MVP.

Trzy największe ryzyka execution: **(1) Family Controls entitlement approval (złóż 2–4 tygodnie wcześniej, osobno per extension)**, (2) **toggle paywall auto-reject od stycznia 2026** (pamiętaj, nie używaj), (3) **Guideline 3.2.2 risk** (subskrypcja musi odblokować wartość poza samym Screen Time API — sprzedaj Strict Mode UX, history, themes, Health integration, nie „dostęp do blokowania"). Ominięcie tych trzech minefieldów + powyższy code skeleton = ship możliwy w ~2 tygodnie od pierwszego commita.