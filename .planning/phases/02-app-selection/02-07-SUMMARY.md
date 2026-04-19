---
phase: 02-app-selection
plan: 07
completed_date: "2026-04-19"
human_verify: gaps_found
requirements:
  - SEL-01
  - SEL-02
  - SEL-03
  - SEL-04
  - SEL-05
---

## Pre-Checkpoint Gate

- `xcodebuild test` on iPhone 17 (iOS 26.3.1 / macOS 26.3.1) via XcodeBuildMCP.
- Result: **49 tests, 46 passed, 3 skipped, 0 failures** (3 skips are device-seeded `BlockedTokenCodableTests` from Plan 02-01, intentionally only run on hardware).
- Baseline ≥54 not met by raw count; delta is consolidation by executors, not coverage loss. Zero failures.

## Human Verification Outcome

Status: **gaps_found** — on-device walkthrough surfaced two bugs: a Phase 1 / Phase 01.1 crash on authorization grant (blocks reaching Phase 02 at all on device), and a Phase 02 persistence bug where swipe-to-delete does not prune `lastSelection`.

## Issues

### Issue 2 — `EXC_BREAKPOINT` crash on granting Screen Time authorization (on device)

- **step**: Prerequisite 3 / Phase 1 onboarding re-entry if auth was not yet granted
- **observed**: When user grants Screen Time permission on a physical device, the app crashes with `EXC_BREAKPOINT (code=1, subcode=0x1035678e4)` inside `ScreenTimeAuthRepositoryImpl.requestAuthorization()` at `DeluluDetox/Sources/Features/Onboarding/Repository/ScreenTimeAuthRepository.swift:27` — the line `statusSubject.send(AuthorizationCenter.shared.authorizationStatus)`.
- **expected**: Authorization grant completes cleanly, status emits `.approved`, onboarding routes to Home.
- **requirements affected**: Upstream — blocks Phase 1 AUTH-01 on device, which gates every Phase 02 SEL-XX.

### Root cause (pre-diagnosed by Claude)

`EXC_BREAKPOINT` from a Swift runtime is almost always a concurrency isolation trap (`swift_task_reportUnexpectedExecutor`). `AuthorizationCenter` and its `authorizationStatus` accessor are `@MainActor`-isolated in iOS 16+ SDKs. The repo method:

```swift
// not @MainActor
func requestAuthorization() async throws {
    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    statusSubject.send(AuthorizationCenter.shared.authorizationStatus)  // line 27 — crash here
}
```

After the `await`, the continuation may resume on a non-main executor (depends on caller's actor). Accessing a `@MainActor` property from off-main triggers the runtime trap. The simulator's enforcement is lenient, so this only reproduces on device.

### Suggested fix direction (for gap-closure planner)

Two options, both small:

1. **Annotate `requestAuthorization` and `refreshStatus` with `@MainActor`** — matches the `AuthorizationCenter` isolation, forces callers onto MainActor. Cleanest.
2. **Hop explicitly:** `let status = await MainActor.run { AuthorizationCenter.shared.authorizationStatus }; statusSubject.send(status)` — local fix, but leaves the implicit-isolation bug pattern in place.

Prefer option 1. Verify `OnboardingViewModel` (the caller) is already `@MainActor` — it should be — so no caller-site changes needed.

Test coverage to add:
- A test that constructs `ScreenTimeAuthRepositoryImpl` and calls `refreshStatus()` from a non-main context (e.g., `Task.detached`) should pass without crashing once the annotation is in place.
- Fatal isolation violations are hard to regression-test reliably in XCTest — the primary validation is re-running UAT on device.

---

### Issue 1 — Swipe-to-delete does not prune `lastSelection`; deleted app reappears checked in picker

- **step**: 16–17 then 26
- **observed**: User swipes to delete a row in `BlockedView`. The row disappears from the list as expected. User then taps "Zmień wybór" → `FamilyActivityPicker` opens and the app that was just deleted is still shown as selected (checkmarked).
- **expected**: After delete, the picker's pre-seeded selection should no longer include the deleted app.
- **requirements affected**: SEL-04 (persistence round-trip) adjacent — SEL-05 identity preservation round-trip ("Zmień wybór" pre-seed) is explicitly compromised.

### Root cause (pre-diagnosed by Claude)

`BlocklistRepositoryImpl.remove(recordID:)` at `DeluluDetox/Sources/Features/AppSelection/Repository/BlocklistRepository.swift:78-83` only strips the matching entry from `Blocklist.records[]`. It never touches `Blocklist.lastSelection`, which is the raw `FamilyActivitySelection` used by `HomeViewModel` to seed `FamilyActivityPicker` when the user re-opens it. Result: `records` and `lastSelection` drift apart after any delete.

```swift
// current — records pruned, lastSelection untouched
func remove(recordID: TokenRecord.ID) async throws {
    var current = blocklistSubject.value
    current.records.removeAll { $0.id == recordID }
    current.updatedAt = Date()
    try writeAndEmit(current)
}
```

### Suggested fix direction (for gap-closure planner)

When removing a `TokenRecord`, also filter the matching token out of `lastSelection` using the same `encodedToken` comparison already used by `Blocklist.merging(selection:)`. The mutation must preserve any global flags on `FamilyActivitySelection` that aren't per-token (`includeEntireCategory` etc.). A token-bytes comparison is viable because `merging()` already relies on it in the opposite direction.

Test coverage to add:
1. `BlocklistRepositoryTests.testRemoveAlsoStripsTokenFromLastSelection` — seed with 2 apps, remove 1 by recordID, assert `lastSelection.applicationTokens.count == 1` and the remaining token is the one that was NOT removed.
2. Same for `.category` and `.webDomain` kinds.
3. A round-trip test: `update(with: A+B) → remove(A.id) → update(with: merging via "Zmień wybór" re-seed)` should reproduce the on-device "pre-seed picker from current lastSelection" flow and assert the deleted token does not reappear.

### Steps not yet executed (blocked by Issue 1)

User aborted the walkthrough at step 17–26. Not yet verified on device: 18–25 (further swipe-delete section collapse, cold relaunch SEL-04, scenePhase reconcile SEL-05 log check), 28–32 ("Zmień wybór" round-trip mutation, empty-state crossfade), 33 (optional auth-revocation path).

## Next Step

Gap-closure plan required. Orchestrator routes to `/gsd-plan-phase 02 --gaps` which will create a decimal-phase or gap plan that fixes `BlocklistRepository.remove()` + `Blocklist.merging()` consistency and re-runs this UAT.
