# Phase 2: App Selection - Research

**Researched:** 2026-04-18
**Domain:** `FamilyControls.FamilyActivityPicker` integration + App Group JSON persistence + UUID-keyed token reconciliation
**Confidence:** HIGH (all API signatures verified against iOS 26.2 SDK .swiftinterface files on disk)

## Summary

Existing `.claude/research/` already covers the architectural hard problems for this phase at depth: the token rotation bug and UUID-keyed record pattern (compass_artifact_wf-280372a6), App Group writer/reader split and atomic write recipe (same artifact), `FamilyActivityPicker` crash-at-scale and entitlement approval (compass_artifact_wf-dee368a6), and iOS 26 regressions justifying defensive `scenePhase` reconciliation (compass_artifact_wf-26aecd00). The locked decisions D-01..D-05 already encode how to handle those.

This research fills the seven gaps the existing corpus does NOT cover: (1) the exact `FamilyControls` SDK API signatures for `Label(token)`, `FamilyActivityPicker(selection:)`, and `FamilyActivitySelection` — verified from the on-disk iOS 26.2 SDK `.swiftinterface`, (2) the canonical `swift-navigation` `@CasePathable` binding pattern for a system-provided sheet that owns a two-way binding, (3) a concrete algorithm for the `scenePhase == .active` reconcile step that D-05 names but does not implement, (4) the actual observed behavior of `Label(token)` for stale/unknown tokens, (5) a clean Repository / UseCase / ViewModel split that respects "VM never imports SwiftUI" while the VM owns a `FamilyActivitySelection`, (6) a Nyquist-shaped validation architecture for SEL-01..SEL-05 that distinguishes what's unit-testable vs. device-only, and (7) a concrete Phase 2 file layout under `DeluluDetox/Sources/`.

**Primary recommendation:** Build one `Blocklist` aggregate with `[TokenRecord]` where each record is `{ id: UUID, kind, token }` — Codable, JSON-serialized atomically to `group.com.kksw.DeluluDetox/blocklists.json`. Persist the full `FamilyActivitySelection` alongside (as `selection.json` or nested) solely to pre-seed the picker on re-open. ViewModel holds both the derived `BlocklistSnapshot` (for `BlockedView` rows) and the seed `FamilyActivitySelection` (for the picker case of `Destination`). Reconcile on `scenePhase == .active` by walking `persistedSelection.applicationTokens ∪ categoryTokens ∪ webDomainTokens` and rewriting each `TokenRecord` under its stable UUID with the token value from the re-read selection — because the only thing iOS guarantees to give you back is "here's the current selection struct, re-hydrate yourself from it."

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Data model supports N named blocklists from day 1 (e.g., `Blocklist` entity with `id: UUID`, optional `name: String`, `[TokenRecord]`). MVP UI exposes only a single implicit blocklist — no list CRUD, no list picker in session flow. Future phase can enable multi-list UI without schema migration.
- **D-02:** `Codable` structs serialized to JSON files in the App Group container (`group.com.kksw.DeluluDetox`). Main app is the sole writer; extensions (DeviceActivityMonitor, ShieldConfiguration, ShieldAction) are read-only. Writes are atomic (`Data.write(to:options: .atomic)`). No SwiftData, no UserDefaults for structured data, no 3rd-party persistence SDKs.
- **D-03:** Split per domain — separate files `blocklists.json`, `sessions.json`, `schedule.json` (latter two arrive in Phase 3/5). DeviceActivityMonitor extension reads only what it needs, keeping parse/RAM cost down within the 6 MB limit.
- **D-04:** Dedicated "Blocked" screen in main app shows a scrollable list with one row per `TokenRecord`, rendered via `Label(token)`. Per-row swipe-to-delete removes a single record. A "Change selection" button opens `FamilyActivityPicker` pre-seeded with the current `FamilyActivitySelection` so the user can add/remove in bulk via Apple's picker. No custom picker UI.
- **D-05:** Reconcile UUID↔token mapping on `scenePhase == .active` only. On foreground, fetch the current `FamilyActivitySelection` from persisted state, diff against Apple's current token set, and refresh `TokenRecord.token` pointers (keyed by UUID). Accepted risk: if a token rotates between foreground and a Phase 3 session start, the session may apply a stale token — revisit in Phase 3 if this becomes a reliability issue.

### Claude's Discretion
- Exact SwiftUI component structure for the "Blocked" screen (cell layout, spacing, header copy).
- Empty-state copy and illustration when the user has picked nothing yet.
- Entry point for the "Blocked" screen in the app navigation (tab vs. root destination) — to be aligned with the navigation graph defined in Phase 1.
- Error / retry copy if `FamilyActivityPicker` presentation fails.
- `FamilyActivitySelection` hydration strategy (whether to cache the full selection alongside individual `TokenRecord`s for picker pre-seeding).

### Deferred Ideas (OUT OF SCOPE)
- Multi-list CRUD UI (data model supports it, UI ships later).
- Session-start reconciliation (second reconcile point before `StartSessionUseCase` — Phase 3).
- On-demand / background reconciliation (scenePhase is sufficient for MVP).
- Empty-state app suggestions (Apple doesn't expose names; non-trivial).
- Import / export blocklist JSON.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEL-01 | User can select apps to block using FamilyActivityPicker | `FamilyActivityPicker(selection: Binding<FamilyActivitySelection>)` exposes an Apps tab. Verified SDK signature below. |
| SEL-02 | User can select app categories to block using FamilyActivityPicker | Same picker; categories tab is the default in the sheet UI. `FamilyActivitySelection.categoryTokens` surfaces chosen categories. |
| SEL-03 | User can select websites to block using FamilyActivityPicker | Same picker; Web tab. `FamilyActivitySelection.webDomainTokens`. |
| SEL-04 | Selected tokens persist across app launches via App Group | Atomic JSON write + `NSFileCoordinator` to `group.com.kksw.DeluluDetox/blocklists.json`. Recipe in compass_artifact_wf-280372a6 §C is directly applicable. |
| SEL-05 | Token rotation is handled gracefully — records keyed by own UUID, token as best-effort pointer | UUID-keyed `TokenRecord` + scenePhase reconcile algorithm (see Gap 3 below). Persist full `FamilyActivitySelection` alongside to re-seed the picker and to drive reconcile. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Presenting the picker sheet | Presentation (SwiftUI View) | — | System-provided view; only SwiftUI layer holds the `Binding` it requires |
| Picker selection state held across the sheet lifecycle | Presentation (ViewModel) | — | VM owns a `Destination?` case carrying the in-flight `FamilyActivitySelection`. No SwiftUI import needed — `FamilyControls.FamilyActivitySelection` is a plain Codable struct. |
| Blocklist domain logic (add/remove/reconcile) | Domain (UseCases) | — | Pure business rules; no SwiftUI, no Foundation persistence detail |
| JSON persistence & App Group file I/O | Data (Repository) | — | Hides `NSFileCoordinator` / `FileManager` / App Group path resolution |
| Atomic write + Darwin notification | Data (Repository) | — | Same artifact that D-02 locks in; extensions will be readers later |
| Rendering `Label(token)` row | Presentation (SwiftUI View) | — | `SwiftUI.Label` extension constructor lives in `FamilyControls` — this is a View concern, never a VM concern |
| `scenePhase == .active` reconcile trigger | Presentation (SwiftUI scenePhase) | Domain (UseCase runs the logic) | View watches scenePhase, ViewModel fires the UseCase, Repository does the write |
| Token rendering failure fallback (stale token) | Presentation (SwiftUI View) | — | Apple's `Label(token)` decides how to render; our only lever is to swallow rendering errors, not to replace them |

## Existing Research Summary

Cite, don't re-derive. Each file is the authoritative source for its domain for this phase.

| Research artifact | What it already covers that Phase 2 needs | Where Phase 2 applies it |
|-------------------|-------------------------------------------|--------------------------|
| `compass_artifact_wf-280372a6-...` (Main app ↔ extensions) | App Group file layout, `NSFileCoordinator` + `.atomic` write recipe with full Swift source, token rotation bug (FB14082790 / FB14237883 / FB18353106), UUID-as-key pattern, Darwin notification, `@AppStorage` gotcha in extensions, unknown-token repair flow | D-02, D-03, D-05, SEL-04, SEL-05 — copy the `SelectionStore` skeleton from §C, adapt filename to `blocklists.json`, keep `JSONEncoder` (not Plist) per forum 721973 |
| `compass_artifact_wf-dee368a6-...` (family-controls entitlement) | Per-bundle-ID approval, 2–8 week timeline, `.individual` framing, development entitlement works in sandbox | Blocker awareness — planner notes that physical device testing requires entitlement already granted from Phase 1 |
| `compass_artifact_wf-9f1fb5f8-...` (Foqos / reference repos) | `awaseem/foqos` architecture, `Inakitajes/kairos` 4-extension structure, Pedro Esli's `ApplicationProfile: Codable, Hashable` with `{ id: UUID, applicationToken: ApplicationToken }` is the de-facto pattern | The `TokenRecord` struct in the Architecture section below is a direct adaptation of Pedro's pattern, generalized to three token kinds |
| `compass_artifact_wf-26aecd00-...` (iOS 26 known bugs) | `deviceactivityd` regressions, callback loss, user-revoke path, justifies defensive reconciliation | D-05's reconcile-on-foreground decision is the correct mitigation |
| `compass_artifact_wf-14f18c53-...` (deployment target) | Existing research argues iOS 18.0 for stability; PROJECT.md locks iOS 26.0 | Phase 2 defers to PROJECT.md — iOS 26.0 is the target. Note the tension for the planner. |
| `compass_artifact_wf-94040b55-...` (production shield) | 8-field `ShieldConfiguration`, no SwiftUI / no network / no `TextField` | Not Phase 2 — Phase 4 problem. Cite only if a question crosses over. |

## Gap Research

### Gap 1: `FamilyActivitySelection` + Token serialization specifics [VERIFIED: iOS 26.2 SDK .swiftinterface]

Source of truth: `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/{FamilyControls,ManagedSettings}.framework/Modules/*.swiftinterface` — read directly on 2026-04-18.

**`FamilyActivitySelection` definitive signature:**

```swift
// VERIFIED from FamilyControls.swiftinterface lines 142-163
public struct FamilyActivitySelection : Swift.Codable, Swift.Equatable {
    @available(iOS 15.2, *) public let includeEntireCategory: Swift.Bool
    public var applicationTokens: Set<ApplicationToken>
    public var categoryTokens: Set<ActivityCategoryToken>
    public var webDomainTokens: Set<WebDomainToken>
    public var applications: Set<Application> { get }  // derived
    public var categories:   Set<ActivityCategory> { get }  // derived
    public var webDomains:   Set<WebDomain> { get }  // derived
    public init(includeEntireCategory: Swift.Bool)
    public init()
    public func encode(to encoder: any Encoder) throws
    public init(from decoder: any Decoder) throws
}
```

**`Token<T>` (the underlying type of all three tokens) definitive signature:**

```swift
// VERIFIED from ManagedSettings.swiftinterface line 87
public struct Token<T> : Codable, Equatable, Hashable { /* opaque body */ }

public typealias ApplicationToken      = Token<Application>       // line 54
public typealias ActivityCategoryToken = Token<ActivityCategory>  // line 225
public typealias WebDomainToken        = Token<WebDomain>         // line 535
```

**Implications for Phase 2:**

1. **`FamilyActivitySelection` is natively `Codable`** — can be persisted whole via `JSONEncoder`. This answers Claude's Discretion "hydration strategy" question in favor of **persist the full selection alongside `[TokenRecord]`** — it's free (both JSON), reusable for picker pre-seeding, and necessary for the reconcile algorithm (Gap 3). Store selection as a nested field in `blocklists.json`, not a separate file, to keep D-03's "one file per domain" rule intact.

2. **Each `Token<T>` is `Codable + Hashable + Equatable`** — safe to use as a struct field, in Sets, and as a JSON value. This is what makes the Pedro Esli / kingstinct pattern work.

3. **The binary content of a token is opaque to the app** — you encode/decode it as a black box. You **cannot** inspect it, map it to an app name, or compare it to any stable identity beyond structural `==`. This is the whole reason D-05 exists.

4. **Caveat (compass_artifact_wf-280372a6 §E.6, forum 721973, VERIFIED):** `PropertyListEncoder` loses `includeEntireCategory`. **Always use `JSONEncoder` for `FamilyActivitySelection`.** This is non-negotiable. D-02 already locks JSON.

5. **Caveat (training knowledge, [ASSUMED]):** The opaque binary blob inside a `Token<T>` is **not** guaranteed stable across iOS updates or iCloud Family changes. This is the FB14082790 / FB14237883 / FB18353106 cluster. A token serialized today may not `==` the token iOS hands back tomorrow — which is precisely why SEL-05 exists. A round-trip within the same OS install is reliable.

**Net:** `FamilyActivitySelection` round-trips cleanly via JSON on a single device/OS version. The risk is *long-term* identity across OS updates, not *short-term* encode/decode correctness.

[VERIFIED: iOS 26.2 SDK .swiftinterface on local Xcode] — structural Codable conformance
[CITED: `.claude/research/compass_artifact_wf-280372a6-...` §E.1, §E.6] — token rotation, Plist encoder bug
[ASSUMED] — exact semantics of "stable across OS updates"; the research cites DTS acknowledgement but no published spec

### Gap 2: `swift-navigation` `@CasePathable` binding for a system sheet [VERIFIED: Context7 swift-navigation docs + SDK signatures]

**The canonical pattern** (from Context7 `/pointfreeco/swift-navigation` docs, retrieved 2026-04-18):

```swift
@CasePathable
enum Destination {
    case picker(FamilyActivitySelection)     // ← associated value IS the in-flight selection
    case errorAlert(ErrorAlertState)
}

// Presentation — case-path binding. When user dismisses the sheet,
// swift-navigation sets destination = nil automatically.
.sheet(item: $model.destination.picker) { $selection in
    // $selection is a Binding<FamilyActivitySelection>, exactly what FamilyActivityPicker wants.
    FamilyActivityPicker(selection: $selection)
}
```

**Why this works:** swift-navigation's `.sheet(item: Binding<T?>)` variant (case-path form) returns **a bound associated value** — the closure receives `Binding<T>` (via `$` projection) so you can two-way bind straight into `FamilyActivityPicker(selection:)`. The picker mutates the `FamilyActivitySelection` in place; swift-navigation propagates the mutation back into the enum case's associated value on the ViewModel; when the user dismisses, swift-navigation sets `destination = nil`.

**Verified SDK signature of the consumer:**

```swift
// VERIFIED from FamilyControls.swiftinterface line 171
@MainActor public init(selection: Binding<FamilyActivitySelection>)
```

So the types line up: `$model.destination.picker` produces `Binding<FamilyActivitySelection>` when the case is active, and `FamilyActivityPicker` takes exactly that.

**Critical rule (from Navigation GUIDE.md anti-patterns):** the associated value lives **inside** the enum case, NOT as a sibling `@State var selection: FamilyActivitySelection` on the View. If you declare the selection outside the case, you get two sources of truth and the VM can't tell whether the sheet is "live" or not.

**Dismissing = committing:** when swift-navigation clears `destination`, the VM observes the transition `.picker(let s) → nil` and fires `UpdateBlocklistFromSelectionUseCase(s)`. Implementation option: watch the transition via a `didSet` on `destination`, or expose an explicit `pickerDismissed(final: FamilyActivitySelection)` intent and wire the `onChange(of:)` observer in the View — the UI-SPEC calls for "Apple sheet dismiss IS the commit trigger" so the `didSet` path is cleaner.

[VERIFIED: Context7 /pointfreeco/swift-navigation docs + iOS 26.2 SDK .swiftinterface]
[CITED: `.claude/guides/navigation/GUIDE.md`] — @CasePathable rules

### Gap 3: `scenePhase == .active` reconciliation algorithm (D-05 concrete)

D-05 says "diff against Apple's current token set" but doesn't specify *how*. The honest answer: **Apple does not expose a current token set** separate from the selection you persisted. There is no `TokenRegistry.shared.currentTokens(for: oldToken)` API. What you actually do is narrower:

**The reconcile contract:**

1. The user's "current choice" on the device is a `FamilyActivitySelection` — you know this only because you persisted it last time the picker committed. Apple gives you no independent enumeration.
2. On each cold start / foreground, `FamilyActivitySelection.applicationTokens` / `.categoryTokens` / `.webDomainTokens` may equal the set you wrote, or may differ if iOS rotated tokens underneath you (FB14082790 cluster).
3. The only way to detect rotation is to **apply** the persisted tokens — either by rendering them in `Label(token)` or by pushing them into `ManagedSettingsStore.shield.applications` — and observe downstream failure. There is no predicate API.
4. Therefore "reconcile" in our MVP means: **re-read the persisted `FamilyActivitySelection` from disk, walk its token sets, and rewrite each `TokenRecord.token` under its stable UUID from the re-read value.** If a token rotated between writes, the re-read picks up the new binary; the UUID stays identical; downstream consumers see the fresh token next time.

**Pseudocode (the concrete algorithm for `ReconcileBlocklistUseCase`):**

```
input:  persisted Blocklist (UUID-keyed records with possibly-stale token bytes)
        persisted FamilyActivitySelection (the "snapshot that iOS hands back")
output: Blocklist with each record's token field refreshed

1. let freshSelection = BlocklistRepository.load().selection      // disk re-read; iOS may have rewritten tokens
2. build three lookup maps:
     appIndex[ApplicationToken]      = token
     catIndex[ActivityCategoryToken] = token
     webIndex[WebDomainToken]        = token
   (every token in freshSelection is in exactly one map)
3. For each record in blocklist.records:
     match record.token (== by value) against the appropriate index
     if found:   rewrite record.token to the found value (no-op if unchanged; stable if rotated but still recognized)
     if missing: the token was removed by the user in an out-of-band way (unlikely since only the picker writes) OR rotated beyond recognition — either way, mark record as "orphaned" (do not delete; Phase 3 / Phase 4 decides shielding behavior)
4. Also reconcile the reverse direction:
     For each fresh token NOT already in blocklist.records → append a new TokenRecord (new UUID, kind inferred from the index it came from)
     This catches the edge case where two picker commits raced or a prior reconcile crashed mid-write.
5. Atomically write the reconciled Blocklist back to disk. Post Darwin notification so any live extensions see the new version.
```

**Important scoping:** Step 3's "orphaned" case is rare in practice — the *only* writer is the main app's picker commit, and the user cannot edit the persisted JSON directly. In practice step 3 is a no-op on non-rotation launches and silently updates bytes on rotation launches. Step 4 exists as a belt-and-suspenders recovery for crash-mid-write.

**Where this lives in code:**
- View: `.onChange(of: scenePhase) { if $0 == .active { Task { await model.onForeground() } } }`
- VM: `func onForeground() async { await reconcileBlocklist() }` where `reconcileBlocklist` calls the UseCase
- UseCase: `ReconcileBlocklistUseCaseImpl` does the 5 steps above, calls Repository `load()`, `save(_:)`
- Repository: already does atomic JSON R/W + Darwin post (per compass_artifact_wf-280372a6 §C)

**What "stale token detected by `Label`" looks like:** see Gap 4.

[CITED: `.claude/research/compass_artifact_wf-280372a6-...` §F] — unknown-token handling pattern mirrors this
[ASSUMED] — step 4 reverse-reconcile as belt-and-suspenders; not documented by Apple, but follows from "write path is idempotent"

### Gap 4: `Label(token)` rendering behavior [VERIFIED: iOS 26.2 SDK + MEDIUM-confidence forum reports]

**The exact constructors** (from `FamilyControls.swiftinterface` lines 95-98):

```swift
// VERIFIED: iOS 26.2 SDK
extension SwiftUI.Label where Title == FamilyControls.FamilyActivityTitleView,
                              Icon  == FamilyControls.FamilyActivityIconView {
    public init(_ applicationToken: ApplicationToken)
    public init(_ categoryToken:    ActivityCategoryToken)
    public init(_ webDomainToken:   WebDomainToken)
}
```

So `Label(token)` returns a `Label<FamilyActivityTitleView, FamilyActivityIconView>` — Apple-rendered title + icon. You cannot peek inside. You can wrap it in a `List` row, a `HStack`, etc., but you cannot swap its typography.

**Observed behaviors (MEDIUM confidence, aggregated from Apple Developer Forums):**

1. **Icons are ~25×25pt and cannot be scaled up without blur** [CITED: forum 731387]. This is a UI-SPEC concern — row height should follow the system default, do not force `.scaleEffect()`.

2. **Dark/light mode rendering has a bug on iOS 26** where newly added tokens may render with black titles in a dark-mode-forced light UI until the view re-appears [CITED: forum tag family-controls page 4]. Mitigation: rely on system semantic colors; do not force a specific color scheme on the `Label`.

3. **For unknown/stale tokens, `Label(token)` does NOT crash** — it renders Apple's fallback (typically a generic icon and either blank text or a placeholder). The compass_artifact_wf-280372a6 §F case study describes this: "Extension crash → iOS pokazuje default system shield → użytkownik traci kontekst." The same forgiving behavior applies to `Label(token)` in-app. [CITED: `.claude/research/compass_artifact_wf-280372a6-...` §F.1]

4. **There is no API to query "is this token renderable"** before putting it in a view. You cannot pre-validate. The only signal is visual ("this row is blank") and the only mitigation is the scenePhase reconcile in Gap 3.

**Net for `BlockedView`:**
- Do not override typography, font, or icon on `Label(token)` rows (UI-SPEC already locks this).
- Accept that a stale-token row will render as Apple's generic fallback (blank name / generic icon) rather than an error. The reconcile in Gap 3 will replace it with a fresh token on next foreground.
- Do not add `.accessibilityLabel` overrides — Apple's `Label` provides accurate VoiceOver strings that we can't otherwise obtain.

[VERIFIED: iOS 26.2 SDK — constructor signatures]
[CITED: Apple Developer Forums 731387, family-controls tag page 4 — rendering quirks]

### Gap 5: Repository layering for Screen Time data (project-architecture fit)

**Confirmed split** (consistent with CLAUDE.md "VMs never import SwiftUI"):

| Layer | Imports allowed | Imports forbidden |
|-------|-----------------|-------------------|
| View (SwiftUI) | SwiftUI, FamilyControls, SwiftUINavigation, Observation | — |
| ViewModel (`@Observable`) | FamilyControls, Observation, SwiftUINavigation (for `@CasePathable`) | **SwiftUI** (no `Color`, `Binding`, `View`, etc.) |
| UseCase (Domain) | FamilyControls, Foundation, Observation | SwiftUI, ManagedSettings (ManagedSettings is an application-layer concern for Phase 3) |
| Repository (Data) | FamilyControls, Foundation, os | SwiftUI, Observation |

**Key resolution:** the VM *can* import `FamilyControls` because `FamilyActivitySelection` / `ApplicationToken` etc. are plain value types, not SwiftUI types. `Label(token)` IS SwiftUI, so it lives only in the View. This is a clean split.

**Recommended `BlocklistRepository` protocol (Domain):**

```swift
// Domain/Repositories/BlocklistRepository.swift
import Foundation
import FamilyControls

protocol BlocklistRepository {
    func load() async throws -> Blocklist
    func save(_ blocklist: Blocklist) async throws
    /// Convenience: observe cross-process changes via Darwin notification.
    /// Phase 2 may not wire this; extensions in Phase 3+ will.
    func changes() -> AsyncStream<Void>
}
```

**Recommended entities (Domain):**

```swift
// Domain/Entities/Blocklist.swift
import FamilyControls

struct Blocklist: Codable, Equatable {
    var id: UUID                       // stable identity across renames (supports D-01 N-lists)
    var name: String?                   // nil = "the implicit MVP list"
    var records: [TokenRecord]
    /// Persisted snapshot of the last picker commit. Used to (a) pre-seed the
    /// picker on re-open (SEL-04 survival), (b) drive reconcile (SEL-05).
    var selection: FamilyActivitySelection
}

struct TokenRecord: Codable, Equatable, Identifiable {
    var id: UUID                        // ALWAYS the record's own ID, not derived from token
    var kind: Kind
    var token: TokenPayload             // sum type; opaque bytes inside

    enum Kind: String, Codable { case application, category, webDomain }

    enum TokenPayload: Codable, Equatable {
        case application(ApplicationToken)
        case category(ActivityCategoryToken)
        case webDomain(WebDomainToken)
    }
}
```

**Repository implementation (Data):** directly adapts `SelectionStore` from compass_artifact_wf-280372a6 §C. Rename `selection.v1.json` → `blocklists.v1.json`. Keep `NSFileCoordinator`, `.atomic`, `.completeFileProtectionUntilFirstUserAuthentication`, JSONEncoder, Darwin notification.

### Gap 6: UseCase granularity for Phase 2

Minimal set that maps 1:1 to the UI actions in UI-SPEC + D-05:

| UseCase | Trigger | Responsibility |
|---------|---------|----------------|
| `LoadBlocklistUseCase` | `HomeViewModel.onAppear` / `BlockedView.task` | Read from Repository; return `Blocklist`. If file missing, return an empty `Blocklist(id: UUID(), records: [], selection: .init())`. |
| `UpdateBlocklistFromSelectionUseCase` | Picker sheet dismissed | Diff new `FamilyActivitySelection` vs current `Blocklist`. Add a `TokenRecord` (new UUID) for each token present in new selection but not existing; drop records whose token is no longer in new selection. Write atomically. |
| `RemoveTokenFromBlocklistUseCase` | Swipe-to-delete row | Remove the `TokenRecord` by `id`. Rebuild `Blocklist.selection` by removing the deleted token from the appropriate token set. Write atomically. |
| `ReconcileBlocklistUseCase` | `scenePhase == .active` | Algorithm in Gap 3. Pure function over `(Blocklist) → Blocklist`; writes back iff anything changed. |

**Why four and not two:** `UpdateBlocklistFromSelectionUseCase` and `RemoveTokenFromBlocklistUseCase` operate on different *inputs* (bulk `FamilyActivitySelection` vs single record ID) and mean different things to the user ("I redid my picks" vs "I yanked one"). Folding them would require the caller to construct the sentinel "selection minus one token" — leaky. Keep them separate per the Architecture Guide's Single Responsibility rule.

**`LoadBlocklistUseCase` is arguably trivial** (pure pass-through). The Architecture Guide says "Delete it if it just forwards one Repository call, have the ViewModel call Repository directly." For Phase 2, **keep it** — the VM should not import the Data layer even to fetch the aggregate, and having an explicit `Load...UseCase` keeps the DI shape uniform. Small cost, clean contract.

### Gap 7: Testing strategy — what's unit-testable vs device-only

**Unit-testable (green CI on simulator, no entitlement):**

- `UpdateBlocklistFromSelectionUseCase` — pure function over `(Blocklist, FamilyActivitySelection) → Blocklist`. Construct `FamilyActivitySelection()` (public init), populate sets, assert outputs. [VERIFIED: `FamilyActivitySelection.init()` is public]
- `RemoveTokenFromBlocklistUseCase` — pure function.
- `ReconcileBlocklistUseCase` — pure function; test all four Gap 3 branches (no-op, rotation, orphan, reverse-reconcile).
- `BlocklistRepositoryImpl` — integration test against a temp directory (inject the container URL or the `FileManager`). Test: write → read → identical; concurrent read during write via `NSFileCoordinator` blocks appropriately; corrupt file → backup taken → empty returned.
- `HomeViewModel` routing — mock all four UseCases; assert `Destination` transitions on intent calls.
- `BlockedViewModel` (or the blocked-branch of HomeViewModel) — same pattern.

**NOT unit-testable (requires physical device with entitlement):**

- `FamilyActivityPicker` actually showing (simulator renders nothing useful — existing Phase 1 research already notes this).
- `AuthorizationCenter.shared.authorizationStatus` returning `.approved`.
- Cross-process Darwin notification round-trip (requires extension running; Phase 3 problem).
- Token rotation itself (requires an OS update event — you cannot trigger it).

**Can `FamilyActivitySelection` be constructed in tests?** YES. `init()` and `init(includeEntireCategory:)` are both public [VERIFIED: SDK]. The `Set<ApplicationToken>` fields are `var` and mutable — but you cannot **synthesize** a fresh `ApplicationToken` in test (its init is not public and the bytes are opaque). **Workaround:** to exercise UseCase diff logic, seed `applicationTokens` by round-tripping a `FamilyActivitySelection` from a recorded JSON fixture captured on-device. Alternatively, design the UseCase interface so the diff operates on a protocol'd `TokenIdentity` that you can fake; that's overkill for Phase 2 — JSON fixtures are sufficient.

**Canonical Nyquist test map for SEL-01..SEL-05** — see the Validation Architecture section below.

### Gap 8: Concrete Phase 2 file layout

Incremental on top of the Phase 1 scaffold (which already has `DeluluDetox/Sources/App/`, `Features/{Root,Onboarding,Denial,Home}/`, `Domain/{UseCases,Entities,Repositories}/`, `Data/Repositories/`, `DesignSystem/`).

```
DeluluDetox/Sources/
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift                   # Phase 1 — amended to switch empty/blocked branches
│   │   └── HomeViewModel.swift              # Phase 1 — amended: Destination enum gains .picker / .errorAlert cases; gains BlocklistSnapshot; intents for picker + swipe-delete
│   └── Blocked/                             # NEW in Phase 2
│       └── BlockedView.swift                # Sub-view shown when blocklist.records.isEmpty == false (UI-SPEC §Screen 3)
├── Domain/
│   ├── Entities/
│   │   ├── Blocklist.swift                  # NEW — Blocklist + TokenRecord + TokenPayload
│   │   └── BlocklistSnapshot.swift          # NEW — VM-facing derived view (grouped by kind, sorted stably by UUID)
│   ├── Repositories/
│   │   └── BlocklistRepository.swift        # NEW — protocol only
│   └── UseCases/
│       ├── LoadBlocklistUseCase.swift
│       ├── UpdateBlocklistFromSelectionUseCase.swift
│       ├── RemoveTokenFromBlocklistUseCase.swift
│       └── ReconcileBlocklistUseCase.swift
├── Data/
│   └── Repositories/
│       └── BlocklistRepositoryImpl.swift    # NEW — adapts SelectionStore pattern from research
└── App/
    └── DependencyContainer.swift            # AMENDED — adds Blocklist factory methods

DeluluDetoxTests/
├── Blocklist/
│   ├── BlocklistTests.swift                 # Codable round-trip, Equatable
│   ├── UpdateBlocklistFromSelectionUseCaseTests.swift
│   ├── RemoveTokenFromBlocklistUseCaseTests.swift
│   ├── ReconcileBlocklistUseCaseTests.swift
│   └── BlocklistRepositoryImplTests.swift   # Integration against temp dir
├── Fixtures/
│   └── SampleFamilyActivitySelection.json   # Captured on-device; checked into repo
└── HomeViewModelTests.swift                 # AMENDED — destination transitions for picker
```

**Rationale:**
- `BlockedView.swift` sits under `Features/Blocked/` as its own folder for Phase 4+ growth (shield customization likely spawns a sibling view), even though MVP renders it inside `HomeView`'s body.
- No separate `BlockedViewModel` at MVP — UI-SPEC explicitly allows extending `HomeViewModel`. A split can be made in Phase 3 if session-start logic bloats Home.
- `Domain/Entities/BlocklistSnapshot.swift` is a UI-facing projection (grouped sections, stable sort) — the VM reads `Blocklist` from the UseCase and maps to `BlocklistSnapshot` for the View. Keeps the View dumb.
- `Fixtures/SampleFamilyActivitySelection.json` — the only viable way to test diff logic without a real picker. Captured on-device in Phase 1 human-verification, committed.

## Recommended Architecture for Phase 2

### System Architecture Diagram

```
   ┌─────────────────────────────────────────────────────────────────┐
   │  main app process                                                │
   │                                                                  │
   │   HomeView                                                       │
   │   ├─ scenePhase observer ───► HomeViewModel.onForeground()       │
   │   │                                 │                             │
   │   │                                 ▼                             │
   │   │                   ReconcileBlocklistUseCase()                 │
   │   │                                 │                             │
   │   │                                 ▼                             │
   │   ├─ if records.isEmpty ─► empty hero (Phase 1)                  │
   │   └─ else ───────────► BlockedView                                │
   │                          │                                        │
   │                          ├─ List rows = Label(token) × records    │
   │                          ├─ swipeActions → RemoveTokenUseCase     │
   │                          └─ "Zmień wybór" tap → VM sets           │
   │                               destination = .picker(selection)    │
   │                                      │                            │
   │   HomeView (same view)                                            │
   │   .sheet(item: $model.destination.picker) { $sel in               │
   │       FamilyActivityPicker(selection: $sel)   ← Apple-owned sheet │
   │   }                                                                │
   │   .onChange of destination nil edge:                               │
   │       UpdateBlocklistFromSelectionUseCase(lastSel)                 │
   │                                                                    │
   │   All UseCases talk to ──► BlocklistRepository (protocol)          │
   │                                  │                                  │
   │                                  ▼                                  │
   │                     BlocklistRepositoryImpl                         │
   │                     ├─ NSFileCoordinator                            │
   │                     ├─ JSONEncoder / JSONDecoder                    │
   │                     └─ atomic write + .complete…UntilFirstAuth     │
   │                                  │                                  │
   └──────────────────────────────────┼──────────────────────────────────┘
                                      ▼
                  ┌─────────────────────────────────────────┐
                  │  App Group: group.com.kksw.DeluluDetox  │
                  │                                           │
                  │   blocklists.json  (ONE file for now)    │
                  │   ┌──────────────────────────────────┐   │
                  │   │ { id, name?, records: [...],     │   │
                  │   │   selection: FamilyActivity-     │   │
                  │   │              Selection }         │   │
                  │   └──────────────────────────────────┘   │
                  │                                           │
                  │   Darwin: com.kksw.DeluluDetox.blocklists.changed │
                  │   (Phase 3+ consumers will listen)        │
                  └─────────────────────────────────────────┘
```

### `HomeViewModel` Destination shape (augmented from Phase 1)

```swift
import Observation
import SwiftUINavigation
import FamilyControls

@Observable
final class HomeViewModel {
    @CasePathable
    enum Destination {
        case picker(FamilyActivitySelection)
        case errorAlert(ErrorAlertState)
    }

    private(set) var snapshot: BlocklistSnapshot = .empty
    var destination: Destination?

    private let loadBlocklist:    LoadBlocklistUseCase
    private let updateBlocklist:  UpdateBlocklistFromSelectionUseCase
    private let removeToken:      RemoveTokenFromBlocklistUseCase
    private let reconcile:        ReconcileBlocklistUseCase

    init(
        loadBlocklist: LoadBlocklistUseCase,
        updateBlocklist: UpdateBlocklistFromSelectionUseCase,
        removeToken: RemoveTokenFromBlocklistUseCase,
        reconcile: ReconcileBlocklistUseCase
    ) {
        self.loadBlocklist = loadBlocklist
        self.updateBlocklist = updateBlocklist
        self.removeToken = removeToken
        self.reconcile = reconcile
    }

    func onAppear()        async { await refresh() }
    func onForeground()    async { try? await reconcile(); await refresh() }

    func chooseAppsTapped() {
        // Pre-seed picker with CURRENT selection so the user sees their
        // existing picks (UI-SPEC Screen 2 "pre-seed" requirement).
        destination = .picker(snapshot.selection)
    }

    func removeTapped(recordId: UUID) async {
        try? await removeToken(recordId: recordId)
        await refresh()
    }

    // Called when the sheet dismisses (destination transitions .picker(s) → nil).
    // The associated value `s` is the final selection the user committed.
    func pickerDismissed(_ selection: FamilyActivitySelection) async {
        try? await updateBlocklist(selection: selection)
        await refresh()
    }

    private func refresh() async {
        let blocklist = (try? await loadBlocklist()) ?? .empty
        self.snapshot = BlocklistSnapshot(from: blocklist)
    }
}
```

**Binding the dismissal-commit** — the neatest way is to wrap the destination setter:

```swift
var destination: Destination? {
    didSet {
        // Detect the picker → nil transition = user dismissed
        if case .picker(let finalSelection) = oldValue, destination == nil {
            Task { await pickerDismissed(finalSelection) }
        }
    }
}
```

### View wiring

```swift
struct HomeView: View {
    @Bindable var model: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.snapshot.isEmpty {
                HomeEmptyHero(onTap: { model.chooseAppsTapped() })
            } else {
                BlockedView(snapshot: model.snapshot,
                            onRemove: { id in Task { await model.removeTapped(recordId: id) } },
                            onChangeSelection: { model.chooseAppsTapped() })
            }
        }
        .task { await model.onAppear() }
        .onChange(of: scenePhase) { _, new in
            if new == .active { Task { await model.onForeground() } }
        }
        .sheet(item: $model.destination.picker) { $selection in
            FamilyActivityPicker(selection: $selection)
        }
    }
}
```

This is the full Phase 2 wiring in ~15 lines of View. Everything else lives in the ViewModel + UseCases.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| App / category / website selection UI | Custom list of toggles, custom search, custom category tree | `FamilyActivityPicker(selection:)` | Apple-owned, entitlement-gated, no other supported way — user cannot select via any alternative API |
| Rendering app name + icon from a token | `Text(resolveName(token))` + `Image(appIcon:)` | `SwiftUI.Label(_ token:)` | Names and icons are **not** exposed as strings/images. The Label initializer is the **only** way to render them. [VERIFIED: iOS 26.2 SDK] |
| Persistence format | SwiftData, Core Data, Realm, SQLite | JSON via `Codable` + `NSFileCoordinator` | D-02 locks JSON. Also: extensions have 6 MB RAM cap; SwiftData/Core Data overhead is risky in DeviceActivityMonitor [CITED: compass_artifact_wf-280372a6 §B] |
| App Group write primitive | `Data.write(to:options: .atomic)` alone | `NSFileCoordinator.coordinate(writingItemAt:…)` wrapping the atomic write | Extensions will be concurrent readers in Phase 3; the coordinator is how you avoid torn reads [CITED: compass_artifact_wf-280372a6 §C] |
| Token identity strategy | Using `ApplicationToken` as the primary key of a record | App-generated `UUID` as primary key, token as a *value* field | SEL-05; tokens rotate across OS updates [CITED: FB14082790 / FB14237883 / FB18353106] |
| Navigation state for picker sheet | `@State var showPicker = false` + `@State var selection = …` on the View | `@CasePathable` `Destination?` enum case carrying the `FamilyActivitySelection` | Single source of truth, testable, matches project Navigation GUIDE |
| Selection encoder | `PropertyListEncoder` | `JSONEncoder` | `includeEntireCategory` flag lost on Plist round-trip [CITED: forum 721973, compass_artifact_wf-280372a6 §E.6] |

**Key insight:** Phase 2 is 80% wiring. The hard problems are already solved by Apple (the picker) or by prior research (the persistence recipe). The *only* net-new work is (a) the Blocklist aggregate + UseCase surface, (b) reconcile algorithm (Gap 3), and (c) the `BlockedView` UI. Getting tempted to add custom selection UI, a token-name lookup, or a bespoke ORM is how this phase goes sideways.

## Common Pitfalls

### Pitfall 1: Using the persisted `FamilyActivitySelection` instead of re-building it from `[TokenRecord]`
**What goes wrong:** After swipe-to-delete on row N, the UI updates but the next picker open still shows the deleted token pre-selected.
**Why:** `Blocklist.selection` is stored *alongside* `Blocklist.records` — if you only remove from `records`, `selection` drifts.
**How to avoid:** Every mutation to `records` must also update `selection` in the same UseCase (remove the token from the appropriate `Set` in `selection`). Write both to disk in one atomic call.
**Warning signs:** Picker "remembers" deleted items on re-open.

### Pitfall 2: ViewModel importing SwiftUI to hold `Binding` for the picker
**What goes wrong:** Compile error or worse — VM becomes un-unit-testable because XCTest doesn't run a SwiftUI environment.
**Why:** Natural impulse is "the picker needs a `Binding`, so the VM owns a `Binding`."
**How to avoid:** The VM owns the **value** (`FamilyActivitySelection`) inside the `Destination.picker(_)` case. The View, via swift-navigation case-path binding, projects that into a `Binding<FamilyActivitySelection>` at the call site. No `Binding` type ever crosses the VM boundary.
**Warning signs:** `import SwiftUI` in `HomeViewModel.swift`.

### Pitfall 3: Forgetting to call `NSFileCoordinator` around atomic writes
**What goes wrong:** Works fine in the simulator; randomly returns empty or corrupted data under load on device when an extension is reading concurrently.
**Why:** `.atomic` on `Data.write` gives you single-writer atomicity but NOT multi-process coordination. Coordinator is the XPC-backed glue that blocks readers during writes.
**How to avoid:** Use the exact `SelectionStore` pattern from compass_artifact_wf-280372a6 §C verbatim. Never bypass the coordinator even for "simple" writes.
**Warning signs:** `Data(contentsOf:)` in an extension sometimes decodes to garbage. [CITED: compass_artifact_wf-280372a6 §C]

### Pitfall 4: `FamilyActivityPicker` crash on large selections
**What goes wrong:** User picks ~100+ items (e.g., "All Social" category auto-expands) → picker crashes, sometimes with no callback.
**Why:** Apple bug (FB11400221, FB14067691, FB12270644, FB14451403). Crashes at ~50% rate around 100 items, ~100% at 200+.
**How to avoid:** In MVP we do nothing — the UI-SPEC does not cap selection count. Accept the risk. Consider adding a safety timer later per the research workaround.
**Warning signs:** Picker sheet appears and immediately dismisses; no `pickerDismissed` fires. [CITED: compass_artifact_wf-280372a6 §E.8]

### Pitfall 5: Treating the reconcile as cosmetic (skipping or making it async-fire-and-forget)
**What goes wrong:** Phase 3 session-start reads a stale token, applies it to `ManagedSettingsStore`, and the shield silently doesn't block.
**Why:** The reconcile is the **only** thing keeping `TokenRecord.token` fresh. If it's debounced out of a foreground, the next Phase 3 read sees stale data.
**How to avoid:** `onForeground()` runs `await reconcile()` before anything else reads the blocklist. Make it a hard `await`, not a `Task {}`.
**Warning signs:** Intermittent "shield didn't apply" reports after user takes a long break between sessions. [CITED: `.claude/research/compass_artifact_wf-280372a6-...` §F, §E.1]

### Pitfall 6: Extensions reading `blocklists.json` during Phase 2
**What goes wrong:** Phase 2 ships without the extension-reader path working, then Phase 3 bolts it on and discovers the file schema is wrong for extension RAM budget.
**Why:** D-03 already anticipates this (split per domain file), but extensions aren't actually instantiated against the file until Phase 3.
**How to avoid:** Phase 2 should include a smoke test — in the `DeluluDetoxTests` bundle, decode `blocklists.json` using only `Foundation` (no `FamilyControls`) to confirm the schema is parseable from an extension-like process. Fail the build if the struct somehow depends on an import not available in 6 MB extension context. [ASSUMED safety check]
**Warning signs:** Phase 3 reports "extension crashes on boot."

### Pitfall 7: Swift 6.2 `Sendable` boundaries around `FamilyActivitySelection`
**What goes wrong:** Moving a `FamilyActivitySelection` from MainActor to a background task for a repository write trips strict concurrency warnings.
**Why:** `FamilyActivitySelection` is a struct; `Set<Token<T>>` fields should be `Sendable` transitively. But Apple has not annotated it `@Sendable`.
**How to avoid:** Keep all reads/writes on `@MainActor` in Phase 2 (the files are small, I/O is fast, no benefit to going off-main). If a Phase 3 consumer needs background access, they'll add `@unchecked Sendable` conformance or a wrapper at that point.
**Warning signs:** Warnings like "Passing argument of non-Sendable type…" on build. [ASSUMED based on Phase 1 Pitfall 7 pattern]

## Code Examples

### Blocklist entity (Domain)

```swift
// Source: derived from Pedro Esli's ApplicationProfile pattern +
// compass_artifact_wf-280372a6 §E.1 UUID-keyed record guidance
import Foundation
import FamilyControls
import ManagedSettings

struct Blocklist: Codable, Equatable {
    var id: UUID
    var name: String?                    // nil for the implicit MVP list
    var records: [TokenRecord]
    var selection: FamilyActivitySelection

    static let empty = Blocklist(id: UUID(), name: nil, records: [], selection: FamilyActivitySelection())
}

struct TokenRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: Kind
    var token: TokenPayload

    enum Kind: String, Codable { case application, category, webDomain }

    enum TokenPayload: Codable, Equatable {
        case application(ApplicationToken)
        case category(ActivityCategoryToken)
        case webDomain(WebDomainToken)
    }
}
```

### Repository implementation (Data) — adapted from compass_artifact_wf-280372a6 §C

```swift
// Source: compass_artifact_wf-280372a6-...  §C "SelectionStore" adapted for Blocklist
import Foundation
import FamilyControls
import os

final class BlocklistRepositoryImpl: BlocklistRepository {
    private static let log = Logger(subsystem: "com.kksw.DeluluDetox",
                                    category: "BlocklistRepository")
    private static let appGroupID = "group.com.kksw.DeluluDetox"
    private static let fileName = "blocklists.v1.json"
    private static let darwinChangeName = "com.kksw.DeluluDetox.blocklists.changed" as CFString

    private var fileURL: URL {
        get throws {
            guard let base = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupID) else {
                throw BlocklistRepositoryError.containerUnavailable
            }
            return base.appendingPathComponent(Self.fileName, isDirectory: false)
        }
    }

    func load() async throws -> Blocklist {
        let url = try fileURL
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordErr: NSError?
        var result: Blocklist = .empty
        var readErr: Error?

        coordinator.coordinate(readingItemAt: url,
                               options: .withoutChanges,
                               error: &coordErr) { coordURL in
            guard FileManager.default.fileExists(atPath: coordURL.path) else { return }
            do {
                let data = try Data(contentsOf: coordURL)
                result = try JSONDecoder().decode(Blocklist.self, from: data)
            } catch {
                readErr = error
                Self.log.error("Blocklist decode failed: \(String(describing: error), privacy: .public)")
            }
        }
        if let e = coordErr { throw BlocklistRepositoryError.coordination(e) }
        if let e = readErr  { throw BlocklistRepositoryError.corrupted(e) }
        return result
    }

    func save(_ blocklist: Blocklist) async throws {
        let url = try fileURL
        let data = try JSONEncoder().encode(blocklist)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordErr: NSError?
        var writeErr: Error?

        coordinator.coordinate(writingItemAt: url,
                               options: .forReplacing,
                               error: &coordErr) { coordURL in
            do {
                try data.write(to: coordURL,
                               options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch { writeErr = error }
        }
        if let e = coordErr { throw BlocklistRepositoryError.coordination(e) }
        if let e = writeErr { throw BlocklistRepositoryError.writeFailed(e) }

        Self.log.info("Blocklist saved, records=\(blocklist.records.count)")
        postChangeNotification()
    }

    func changes() -> AsyncStream<Void> { /* Darwin observer stream; Phase 3 wires consumers */ }

    private func postChangeNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(Self.darwinChangeName),
            nil, nil, true)
    }
}

enum BlocklistRepositoryError: Error {
    case containerUnavailable
    case corrupted(Error)
    case coordination(NSError)
    case writeFailed(Error)
}
```

### `UpdateBlocklistFromSelectionUseCase`

```swift
// Source: Phase 2 gap research (Gap 6) — pure diff
import Foundation
import FamilyControls

protocol UpdateBlocklistFromSelectionUseCase {
    func callAsFunction(selection: FamilyActivitySelection) async throws
}

final class UpdateBlocklistFromSelectionUseCaseImpl: UpdateBlocklistFromSelectionUseCase {
    private let repo: BlocklistRepository
    init(repo: BlocklistRepository) { self.repo = repo }

    func callAsFunction(selection newSelection: FamilyActivitySelection) async throws {
        var blocklist = (try? await repo.load()) ?? .empty

        // Build existing-token lookup so we can preserve UUIDs.
        var existingByToken: [TokenRecord.TokenPayload: TokenRecord] = [:]
        for r in blocklist.records { existingByToken[r.token] = r }

        var next: [TokenRecord] = []
        for t in newSelection.applicationTokens {
            let key: TokenRecord.TokenPayload = .application(t)
            next.append(existingByToken[key] ?? TokenRecord(id: UUID(), kind: .application, token: key))
        }
        for t in newSelection.categoryTokens {
            let key: TokenRecord.TokenPayload = .category(t)
            next.append(existingByToken[key] ?? TokenRecord(id: UUID(), kind: .category, token: key))
        }
        for t in newSelection.webDomainTokens {
            let key: TokenRecord.TokenPayload = .webDomain(t)
            next.append(existingByToken[key] ?? TokenRecord(id: UUID(), kind: .webDomain, token: key))
        }

        blocklist.records = next
        blocklist.selection = newSelection
        try await repo.save(blocklist)
    }
}
```

### `ReconcileBlocklistUseCase`

```swift
// Source: Gap 3 pseudocode
import Foundation

protocol ReconcileBlocklistUseCase {
    func callAsFunction() async throws
}

final class ReconcileBlocklistUseCaseImpl: ReconcileBlocklistUseCase {
    private let repo: BlocklistRepository
    init(repo: BlocklistRepository) { self.repo = repo }

    func callAsFunction() async throws {
        var blocklist = try await repo.load()
        let fresh = blocklist.selection

        // Forward: rewrite token bytes under the stable UUID
        for idx in blocklist.records.indices {
            let rec = blocklist.records[idx]
            switch rec.token {
            case .application(let t):
                if let match = fresh.applicationTokens.first(where: { $0 == t }) {
                    blocklist.records[idx].token = .application(match)
                }
            case .category(let t):
                if let match = fresh.categoryTokens.first(where: { $0 == t }) {
                    blocklist.records[idx].token = .category(match)
                }
            case .webDomain(let t):
                if let match = fresh.webDomainTokens.first(where: { $0 == t }) {
                    blocklist.records[idx].token = .webDomain(match)
                }
            }
        }

        // Reverse: pick up any tokens in `fresh` we don't already have (crash-mid-write recovery)
        let haveAppTokens = Set(blocklist.records.compactMap { if case .application(let t) = $0.token { return t } else { return nil } })
        for t in fresh.applicationTokens where !haveAppTokens.contains(t) {
            blocklist.records.append(TokenRecord(id: UUID(), kind: .application, token: .application(t)))
        }
        // (same for category and webDomain — omitted for brevity)

        try await repo.save(blocklist)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Color`-via-UIColor in Shield config | `Theme.*` + `Label(token)` for app rows | Phase 1 Theme + SDK discipline | Keeps brand + legal safety (no name leaks) |
| `ObservableObject` + `@Published` | `@Observable` | iOS 17 / Swift 5.9 | Matches project mandate |
| Multiple `@State` flags | `@CasePathable` `Destination?` | swift-navigation 2.x | Single source of truth |
| `ApplicationToken` as primary key | UUID-keyed record with token as value field | 2024 (FB cluster acknowledged) | Survives token rotation |
| `PropertyListEncoder` for `FamilyActivitySelection` | `JSONEncoder` | forum 721973 disclosure | Preserves `includeEntireCategory` |

**Deprecated / outdated:**
- Treating opaque token bytes as stable long-term identifier — do not.
- `.child` authorization — not relevant here (project is `.individual`), just flagging it's not the pattern to copy from old tutorials.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Reverse-reconcile in Gap 3 step 4 (reconstruct orphan records from `selection` that are missing in `records`) is sound | Gap 3, Reconcile UseCase | Low — if unnecessary it's a no-op; if wrong it would add duplicate records, observable in tests |
| A2 | `FamilyActivitySelection` Codable round-trips cleanly on a single device/OS — bytes survive one launch cycle | Gap 1 | High if wrong: persistence fails. Mitigation: covered by `BlocklistRepositoryImplTests` round-trip assertion |
| A3 | Phase 2 can defer extension-reader testing of the schema to Phase 3 without introducing binary-incompat risk | Pitfall 6 | Medium — if the schema has extension-unsafe imports, Phase 3 boot fails. Mitigation: smoke-decode test in Phase 2 |
| A4 | `Sendable` strict-mode warnings for `FamilyActivitySelection` can be sidestepped by keeping everything on `@MainActor` in Phase 2 | Pitfall 7 | Low — if Apple has annotated it `@Sendable` already the code works; if not, `@MainActor` isolation is always safe |
| A5 | The picker-dismiss commit pattern (VM `didSet` on `destination`) reliably fires exactly once per dismissal | HomeViewModel Destination shape | Medium — if it fires twice, duplicate UUID assignment is possible; guard by idempotency on the UseCase |

Empty on: token rendering behavior (verified via SDK + forums), Codable conformance (verified via SDK), FamilyActivityPicker signature (verified), swift-navigation pattern (verified via Context7 + Nav GUIDE).

## Open Questions for Planner

1. **Picker-dismiss commit semantics across iOS versions.** The `didSet` transition on `destination` is what turns "sheet dismissed" into "save selection". Does iOS 26 fire the `item` binding nil-set atomically, or can there be an in-flight mutation of the selection that arrives *after* `destination = nil`?
   - What we know: swift-navigation's docs treat the transition as atomic from the binding's perspective.
   - What's unclear: whether a last-keystroke update from the picker can race the dismiss.
   - Recommendation: test on device with the planner's verification task; if racing, wrap the last-write via an explicit `doneButtonTapped` intent path instead of `didSet`. This is Claude's Discretion territory.

2. **`Blocklist.id` — durable identity even in MVP single-list mode?** D-01 mandates N-list schema from day one; MVP shows one implicit list. Does the MVP create exactly one `Blocklist` on first launch and reuse that UUID forever, or does it create a new UUID each time `records.isEmpty` becomes true again?
   - What we know: D-01 explicitly says "Future phase can enable multi-list UI without schema migration."
   - What's unclear: whether persisting a zero-record blocklist (just keeping the ID) is acceptable or whether we delete the file when empty.
   - Recommendation: **keep the `Blocklist` with its UUID forever once created, even when records are empty.** Delete only if user explicitly "resets" (a post-MVP feature). This minimizes Phase 3/Phase 5 "where did the id go" bugs.

3. **Testing without a physical device.** The plan should clarify whether the Phase 2 human-verification wave requires:
   - (a) physical iOS device with Family Controls entitlement approved (blocked on Apple approval, possibly 2-8 weeks),
   - (b) development entitlement + physical device (works now, already used in Phase 1),
   - (c) simulator only (UI-level tests plus fixture-driven UseCase tests; no picker integration test).
   - Recommendation: (b) for Phase 2 functional verification; (c) for CI. Submit the distribution entitlement in parallel so Phase 3 isn't blocked.

4. **Empty-state copy and hero illustration.** D-01 decided and UI-SPEC Screen 3 covers this — but empty-state-after-deletion is a different beast (user just saw their list, now it's gone). Does the transition back to the empty hero need an extra beat or is the 0.35s crossfade per UI-SPEC sufficient? Claude's Discretion per CONTEXT.md; flag for UI checker.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Xcode 26.x with iOS 26.2 SDK | All Swift code | Yes | 26.3 (17C529) / iOS 26.2 SDK | — |
| Swift 6.2 | All Swift code | Yes | 6.2.4 | — |
| XcodeGen | project.yml regen | Yes | 2.45.3 | — |
| `FamilyControls` / `ManagedSettings` frameworks | Phase 2 runtime | Yes (SDK on disk, verified) | iOS 26.2 SDK | — |
| `pointfreeco/swift-navigation` 2.8.0 | Destination binding | Yes (Phase 1 already declared as SPM dep) | 2.8.0 | — |
| Physical iOS device with `com.apple.developer.family-controls` (Development) | Picker integration + `scenePhase` testing on real hardware | Unknown (was "TBD" in Phase 1) | — | Simulator for UI + VM tests; device only for SEL-01/02/03 functional verification |
| Physical iOS device with `com.apple.developer.family-controls` (**Distribution**) | App Store / TestFlight launch | Requires Apple approval per bundle ID (~2-8 weeks) | — | Dev build on device; defer distribution until approved |

**Missing dependencies with no fallback:**
- Physical device for picker integration — simulator does not meaningfully render `FamilyActivityPicker` contents.

**Missing dependencies with fallback:**
- Distribution entitlement (not needed to ship Phase 2 code; only blocks external testing).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode 26.3) |
| Config file | None — test target declared in `project.yml` |
| Quick run command | `mcp__XcodeBuildMCP__test_sim` scoped to `DeluluDetoxTests/Blocklist` |
| Full suite command | `mcp__XcodeBuildMCP__test_sim` (all tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test type | Automated command | File exists? |
|--------|----------|-----------|-------------------|--------------|
| SEL-01 | User can select **apps** via FamilyActivityPicker | manual-only (device) | N/A | N/A |
| SEL-01 | `UpdateBlocklistFromSelectionUseCase` creates an `application`-kind `TokenRecord` for each new applicationToken | unit | `xcodebuild test -only-testing:DeluluDetoxTests/UpdateBlocklistFromSelectionUseCaseTests/testAddApplicationTokens` | ❌ Wave 0 |
| SEL-02 | User can select **categories** | manual-only (device) | N/A | N/A |
| SEL-02 | UseCase creates `category`-kind records | unit | `...testAddCategoryTokens` | ❌ Wave 0 |
| SEL-03 | User can select **websites** | manual-only (device) | N/A | N/A |
| SEL-03 | UseCase creates `webDomain`-kind records | unit | `...testAddWebDomainTokens` | ❌ Wave 0 |
| SEL-04 | Selections persist across app launches | unit (Repository round-trip against temp dir) | `...BlocklistRepositoryImplTests/testWriteThenReadYieldsEqualBlocklist` | ❌ Wave 0 |
| SEL-04 | Selections persist across app launches (real App Group) | manual (device + relaunch) | N/A | N/A |
| SEL-05 | UUID preserved when same token re-selected | unit (pure function) | `...testReselectingSameTokenPreservesUUID` | ❌ Wave 0 |
| SEL-05 | Reconcile refreshes token bytes on foreground | unit (pure function over fixture) | `...ReconcileBlocklistUseCaseTests/testReconcileReplacesTokenBytesWhileKeepingUUID` | ❌ Wave 0 |
| SEL-05 | Reconcile handles orphan record (token no longer in selection) | unit | `...testReconcileFlagsOrphanRecord` | ❌ Wave 0 |
| SEL-05 | Reconcile handles reverse-orphan (token in selection, not in records) | unit | `...testReconcileReinsertsReverseOrphan` | ❌ Wave 0 |
| Cross-cutting | Atomic write doesn't leave partial files | unit (Repository + injected FileManager) | `...BlocklistRepositoryImplTests/testInterruptedWriteLeavesPriorFileIntact` | ❌ Wave 0 |
| Cross-cutting | `HomeViewModel.chooseAppsTapped()` transitions `destination` to `.picker(currentSelection)` | unit (VM) | `HomeViewModelTests/testChooseAppsTappedOpensPicker` | ❌ Wave 0 (HomeViewModelTests exists from Phase 1; amend) |
| Cross-cutting | `HomeViewModel` dismissal of picker fires `UpdateBlocklistFromSelectionUseCase` exactly once | unit (VM + mock UseCase) | `...testPickerDismissalCommits` | ❌ Wave 0 |
| Cross-cutting | Row swipe-delete fires `RemoveTokenFromBlocklistUseCase` with correct UUID | unit (VM + mock) | `...testSwipeDeleteFiresRemoveWithCorrectId` | ❌ Wave 0 |

**Manual-only justifications:**
- SEL-01/02/03 picker UI: the system sheet renders opaque content from iOS; there is no UI-level API to enumerate its rows. Simulator does not load app catalog data. Only a physical device with a granted entitlement can show the real picker.
- SEL-04 cross-launch on real App Group: simulator's container is distinct from device; cross-process behavior is only meaningful on device.

### Sampling Rate

- **Per task commit:** Targeted run — `xcodebuild test -only-testing:DeluluDetoxTests/Blocklist` (all Blocklist unit tests) plus `HomeViewModelTests`. Should complete in well under 30 seconds.
- **Per wave merge:** Full `mcp__XcodeBuildMCP__test_sim` suite on the simulator.
- **Phase gate:** Full suite green on simulator + manual SEL-01 through SEL-04 verified on physical device; SEL-05 reconcile verified via device scenario "select apps, backup iCloud, restore, re-launch" (or equivalent token-rotation repro if available).

### Wave 0 Gaps

- [ ] `DeluluDetoxTests/Blocklist/BlocklistTests.swift` — Codable round-trip + Equatable
- [ ] `DeluluDetoxTests/Blocklist/UpdateBlocklistFromSelectionUseCaseTests.swift`
- [ ] `DeluluDetoxTests/Blocklist/RemoveTokenFromBlocklistUseCaseTests.swift`
- [ ] `DeluluDetoxTests/Blocklist/ReconcileBlocklistUseCaseTests.swift`
- [ ] `DeluluDetoxTests/Blocklist/BlocklistRepositoryImplTests.swift` — integration against temp dir (inject container URL via a protocol'd path provider)
- [ ] `DeluluDetoxTests/Fixtures/SampleFamilyActivitySelection.json` — captured on-device during Phase 1 or Phase 2 human verification, committed
- [ ] `DeluluDetoxTests/Fixtures/FixtureLoader.swift` — helper to decode fixtures
- [ ] Mock implementations: `MockBlocklistRepository`, `MockLoadBlocklistUseCase`, `MockUpdate…`, `MockRemove…`, `MockReconcile…`
- [ ] Amendment to `HomeViewModelTests.swift` — picker destination transitions, dismissal commit
- [ ] `project.yml` — add `DeluluDetoxTests` target dependencies on new UseCase/Repository files (if not already globbed in)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No | No user auth layer — Phase 2 has no user accounts |
| V3 Session Management | No | No app-level sessions in Phase 2 |
| V4 Access Control | Limited | App Group container is process-scoped; only our app + its extensions access it. OS enforces. |
| V5 Input Validation | Yes | JSON decode of `Blocklist` from disk — must handle corruption gracefully (backup corrupt file, return empty). Covered by repository tests. |
| V6 Cryptography | No | No crypto in Phase 2. Tokens are opaque Apple-owned blobs, not secrets. |
| V8 Data Protection | Partial | File protection level `.completeFileProtectionUntilFirstUserAuthentication` on blocklist file — matches research recipe. Locks file until first device unlock. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Corrupted JSON on disk (bit flip, crash-mid-write) | DoS (to UX) | Backup the corrupted file, return empty `Blocklist`; log via OSLog. [CITED: compass_artifact_wf-280372a6 §C pattern] |
| Partial-write window where reader sees half-written file | DoS / data integrity | `NSFileCoordinator` + `.atomic` (temp + rename). [CITED: research] |
| User revokes Screen Time auth between picker and commit | Elevation of Privilege (against our guarantees) | On foreground, `AppRootViewModel` (Phase 1) already re-checks `AuthorizationCenter`; if denied → route to Denial. Phase 2 inherits. |
| Token rotation causing silent shield bypass (downstream, Phase 3 problem) | Spoofing of identity | UUID-keyed record + reconcile on foreground. [CITED: SEL-05] |
| Extension reading blocklists.json while main app writes | Information disclosure / torn read | `NSFileCoordinator` blocks readers during write. [CITED: research] |

**No user-provided input beyond token taps.** There is no free-form text input in Phase 2, so no V5-classical injection surface. The one validation concern is file decode, handled above.

## Project Constraints (from CLAUDE.md)

- **SwiftUI-first**; UIKit only via `UIViewControllerRepresentable` bridges (not needed in Phase 2).
- **Clean Architecture** — MVVM + UseCase + Repository. Enforced by the file layout above.
- **ViewModels never import SwiftUI** — Phase 2 respects this by holding `FamilyActivitySelection` (FamilyControls type, not SwiftUI) inside `Destination.picker` associated value.
- **swift-navigation** — single `Destination?` enum, `@CasePathable`, case-path bindings. Verified pattern in Gap 2.
- **XcodeGen** — edit `project.yml`, run `xcodegen generate`; never touch `.xcodeproj` directly. Phase 2 adds test target dependencies on new files — if sources are globbed, no project.yml changes needed beyond the new test files being picked up.
- **XcodeBuildMCP for build/test** — all build/run/test actions go through MCP tools, never raw `xcodebuild`.
- **Project skills:** scanned `.claude/skills/` and `.agents/skills/` — none found. No SKILL.md to load.
- **Repo name has triple hyphen** (`KKSW---first-app`) — preserve verbatim.
- **No backend, on-device only.** Phase 2 has zero network I/O.
- **iOS 26.0+ target locked by PROJECT.md** despite the Phase 1 research arguing for iOS 18.0 as a reach/stability win. Phase 2 defers — research notes this tension but does not reopen the debate.

## Sources

### Primary (HIGH confidence)
- **iOS 26.2 SDK `.swiftinterface` files** (on-disk at `/Applications/Xcode.app/.../iPhoneOS26.2.sdk/System/Library/Frameworks/{FamilyControls,ManagedSettings}.framework/Modules/*.swiftinterface`) — verified API signatures for `FamilyActivitySelection`, `FamilyActivityPicker`, `Token<T>`, `Label(token)` initializers.
- `.claude/research/compass_artifact_wf-280372a6-...` — definitive source for App Group persistence recipe, token rotation, unknown-token handling.
- `.claude/research/compass_artifact_wf-9f1fb5f8-...` — Pedro Esli's `ApplicationProfile` pattern used as the basis for `TokenRecord`.
- `.claude/research/compass_artifact_wf-dee368a6-...` — entitlement timelines.
- Context7 `/pointfreeco/swift-navigation` — canonical `@CasePathable` + `.sheet(item:)` binding pattern.
- `.claude/guides/architecture/GUIDE.md` — Clean Architecture rules.
- `.claude/guides/navigation/GUIDE.md` — swift-navigation rules.

### Secondary (MEDIUM confidence)
- Apple Developer Forum thread 731387 — `Label(token)` icon size quirks.
- Apple Developer Forum family-controls tag — `Label(token)` dark-mode bug.
- pedroesli.com/2023-11-13-screen-time-api/ — `ApplicationProfile: Codable, Hashable` reference implementation.
- riedel.wtf/state-of-the-screen-time-api-2024/ — token rotation field-report context.

### Tertiary (LOW confidence)
- General WebSearch hits on FamilyActivityPicker pre-seeding — superseded by direct SDK verification; retained for cross-check only.

## Metadata

**Confidence breakdown:**
- API signatures (picker, Label, selection, tokens): HIGH — verified against on-disk iOS 26.2 SDK
- swift-navigation pattern: HIGH — verified via Context7 docs + project Navigation GUIDE
- Persistence recipe: HIGH — copied from compass_artifact_wf-280372a6 §C, which is itself sourced from published Apple DTS forum guidance
- Reconcile algorithm (Gap 3): MEDIUM — logic derives from the research's guidance but the exact step-4 reverse reconcile is my reasoning, marked [ASSUMED] in the log
- `Label(token)` stale-token rendering: MEDIUM — forum-reported, not Apple-documented
- Test strategy: HIGH for unit tests; manual paths are inherent to Screen Time API (not a confidence issue)

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (API signatures should hold for the Xcode 26.x cycle; reconcile algorithm is architectural and won't age)
