---
phase: 04-shield-customization
plan: 03
subsystem: shield
tags: [managed-settings, shield-action, deep-link, url-scheme, objc-runtime, extension-ram]

# Dependency graph
requires:
  - phase: 04-shield-customization/01
    provides: XCTest scaffolds + 5 XCTSkip stubs asserting the ShieldActionHandler contract (decide(action:hasActiveSession:) -> (response, urlToOpen))
  - phase: 04-shield-customization/02
    provides: SessionPaths + ActiveSessionEnvelope source-share entries on ShieldActionExtension target and Destination.countdown deep-link route
provides:
  - Pure ShieldActionHandler decision struct (main-app target, source-shared) for SHL-03
  - ShieldActionSessionProbe.hasActiveSession() — 1-byte-read active session presence check
  - Production ShieldActionExtension with 3 overrides delegating to shared handle(action:completionHandler:)
  - Best-effort URL open via Objective-C runtime selector (NSClassFromString + openURL:) — TODO/warning marker for local-push fallback
  - 5 SHL-03 unit tests green (previously XCTSkip)
affects: [04-05 device-verification, future local-push-fallback plan]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure-decision struct pattern: extension keeps glue-only; decision logic in XCTest-unit-testable struct source-shared via project.yml"
    - "Objective-C runtime selector workaround for extension URL open (ShieldActionDelegate has no extensionContext property)"
    - "Unconditional completionHandler in switch — fire-and-forget URL open outside the switch so the shield process is always released (T-04-03-02 mitigation)"

key-files:
  created:
    - DeluluDetox/Sources/Features/Shield/ActionHandler/ShieldActionHandler.swift (66 LOC)
  modified:
    - Extensions/ShieldActionExtension/ShieldActionExtension.swift (127 LOC, from 28 LOC stub)
    - DeluluDetoxTests/Features/Shield/ShieldActionHandlerTests.swift (36 LOC — 5 XCTSkip → 5 real assertions)
    - project.yml (source-share entry for ShieldActionHandler.swift on ShieldActionExtension target)

key-decisions:
  - "Wave 0 spike WAIVED by user — treated as NEGATIVE verdict per plan directive; best-effort URL open ships with TODO + #warning"
  - "ShieldActionDelegate does NOT expose extensionContext (plain NSObject subclass, verified via ManagedSettings.swiftinterface) — switched from extensionContext?.open to Objective-C runtime UIApplication+openURL: workaround"
  - "Kept imports at Foundation + ManagedSettings + os only — no UIKit, no FamilyControls, respects 6 MB extension RAM ceiling"
  - "Fire-and-forget URL open pattern: open dispatched outside the switch, completionHandler always fires in switch → no orphaned shield processes"

patterns-established:
  - "Pure-decision extraction + source-share: ShieldActionHandler (main-app target) is compiled into both DeluluDetox and ShieldActionExtension targets via project.yml — single source of truth, zero duplication, XCTest-accessible"
  - "Runtime-selector URL open from extension: NSClassFromString(\"UIApplication\") + NSSelectorFromString(\"sharedApplication\") + NSSelectorFromString(\"openURL:\") — compile-safe alternative to extensionContext?.open when the delegate base class does not provide extensionContext"

requirements-completed: [SHL-03]

# Metrics
duration: 6min
completed: 2026-04-20
---

# Phase 04 Plan 03: Shield Action → Main App Deep Link Summary

**Pure-decision ShieldActionHandler struct wired to ShieldActionExtension via source-share; all 3 delegate overrides route through shared handle() that calls best-effort URL open (Obj-C runtime workaround) then always fires completionHandler(.close). 5 SHL-03 unit tests green.**

## Performance

- **Duration:** ~6 minutes
- **Started:** 2026-04-20T00:26:13Z
- **Completed:** 2026-04-20T00:32:00Z (approx)
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- `ShieldActionHandler` pure struct with `decide(action:hasActiveSession:)` mapping to `Decision(response, urlToOpen)` per CONTEXT §D-05/D-06/D-07/D-13/D-15
- `ShieldActionSessionProbe.hasActiveSession()` — allocation-free 1-byte file-presence probe against App Group `active_session.json` (no JSON decode, Pitfall 6)
- `ShieldActionExtension` production handler: 3 base-class overrides delegate to private `handle(action:completionHandler:)` which calls `decide(...)` → fire-and-forget URL open → unconditional `completionHandler(.close)` in switch
- 5 `ShieldActionHandlerTests` flipped from XCTSkip to real assertions — all pass on iPhone 17 sim
- Full suite: 147 tests, 0 failures, 3 skipped (unrelated pre-existing skips)

## Task Commits

1. **Task 1: ShieldActionHandler pure decision struct + green SHL-03 tests** — `e7e464e` (feat)
2. **Task 2: Wire ShieldActionExtension with best-effort URL open** — `1e2fb8e` (feat)

## Files Created/Modified

- `DeluluDetox/Sources/Features/Shield/ActionHandler/ShieldActionHandler.swift` (created, 66 LOC) — pure decision struct + session probe
- `Extensions/ShieldActionExtension/ShieldActionExtension.swift` (modified, 28 → 127 LOC) — production handler + runtime URL-open
- `DeluluDetoxTests/Features/Shield/ShieldActionHandlerTests.swift` (modified, 30 → 36 LOC) — 5 XCTSkip stubs replaced with real XCTAssertEqual / XCTAssertNil
- `project.yml` (modified, +1 line) — added `ShieldActionHandler.swift` to `ShieldActionExtension.sources` for source-share

## Test Results

```
Test Suite 'ShieldActionHandlerTests' passed at 2026-04-20 02:28:13.032.
     Executed 5 tests, with 0 failures (0 unexpected) in 0.002 (0.003) seconds

Test Suite 'All tests' passed at 2026-04-20 02:30:57.240.
     Executed 147 tests, with 3 tests skipped and 0 failures (0 unexpected)
```

## Spike Verdict Consulted

Read `04-DISCUSSION-LOG.md` §"Wave 0 Spike — WAIVED (2026-04-20)". Verdict line quoted verbatim:

> **Consequence for Plan 04-03 implementation (treat as NEGATIVE spike verdict):**
> - Follow the **NEGATIVE verdict variant** already documented in `04-03-PLAN.md` Task 2.
> - Ship `extensionContext?.open(...)` as best-effort code, wrapped in TODO + `#warning`.
> - `completionHandler(.close)` is still called unconditionally AFTER the fire-and-forget open.

Implemented per the NEGATIVE variant: TODO(SHL-03 fallback) comment block and `#warning` in place; best-effort URL open still ships; completionHandler(.close) fires unconditionally in switch.

## project.yml Diff

Single-line addition under `ShieldActionExtension.sources`:

```yaml
      - path: DeluluDetox/Sources/Features/Shield/ActionHandler/ShieldActionHandler.swift
```

## Extension Imports (grep-verified)

```
$ grep "^import" Extensions/ShieldActionExtension/ShieldActionExtension.swift
import Foundation
import ManagedSettings
import os
```

Zero FamilyControls / SwiftUI / Combine / UIKit imports — RAM discipline preserved (D-17).

## Decisions Made

- **Runtime-selector workaround replaces `extensionContext?.open`.** Root cause: `ShieldActionDelegate` is a plain `NSObject` subclass in `ManagedSettings.framework` (verified via `arm64-apple-ios-simulator.swiftinterface`) — the `extensionContext` property doesn't exist on this class, so the call didn't compile. Community pattern (Opal, one-sec, AppLocker) uses `NSClassFromString("UIApplication")` + `sharedApplication` selector + `openURL:` selector. Same semantics as `extensionContext?.open`, same Apple-DTS-unsupported status, same waived-spike tracking (TODO + `#warning` still present, unchanged text modulo swapping "extensionContext?.open" for "runtime selector" in the NOTE comment). This keeps the plan's intent (best-effort URL open that we already know may fail on device and will be replaced by local push) while compiling cleanly on iOS 26 SDK.
- **Fire-and-forget open, unconditional close.** URL open dispatched outside the response switch; `completionHandler` fires unconditionally in all three `switch decision.response` arms. Mitigates T-04-03-02 (shield process leak if open hangs).

## Deviations from Plan

### Rule 2 / Rule 3 auto-fix

**1. [Rule 3 - Blocking] Replaced `extensionContext?.open` with Objective-C runtime selector workaround**
- **Found during:** Task 2 (first `xcodebuild build` attempt)
- **Issue:** Plan's `<interfaces>` block asserted `extensionContext: NSExtensionContext? { get }` is "INHERITED from NSObject" — this is factually incorrect. `NSObject` has no `extensionContext` property; it's normally provided by `UIViewController` / `NSExtension`-hosted classes. `ShieldActionDelegate` inherits only from `NSObject` (verified via `ManagedSettings.framework/Modules/ManagedSettings.swiftmodule/arm64-apple-ios-simulator.swiftinterface`), so `extensionContext?.open(...)` failed with `cannot find 'extensionContext' in scope`.
- **Fix:** Replaced the single `extensionContext?.open(url, ...)` line with a private `openURLFromExtension(_:)` helper that uses `NSClassFromString("UIApplication")` + `NSSelectorFromString("sharedApplication")` + `NSSelectorFromString("openURL:")` via `perform(_:)`. Logs at each failure branch via `os.Logger`. Same fire-and-forget semantics; same unsupported-per-Apple-DTS status; same waived-spike risk profile (already tracked by TODO + `#warning`).
- **Files modified:** `Extensions/ShieldActionExtension/ShieldActionExtension.swift`
- **Verification:** `xcodebuild build` → `BUILD SUCCEEDED`; `xcodebuild test` → 147 tests pass; TODO(SHL-03 fallback) grep = 1; `#warning` grep = 1; forbidden-imports grep = 0.
- **Committed in:** `1e2fb8e` (Task 2 commit)

### Waived-spike documentation

**2. [Spike WAIVED] Wave 0 Plan 04-01 Task 1 physical-device verification waived by user**
- **Source:** `04-DISCUSSION-LOG.md` §"Wave 0 Spike — WAIVED (2026-04-20)"
- **Treatment:** Followed NEGATIVE verdict variant as instructed. TODO(SHL-03 fallback) + `#warning` placed above the runtime-selector URL open call site. Full local-push-notification fallback deferred to a follow-up plan (TBD; orchestrator to schedule after Plan 04-05 device verification).
- **Artifact:** The waiver also reshaped how the #warning text reads vs the strict plan (the plan said "spike negative" — waiver says "spike waived"; I used the waiver's phrasing since it is the most recent source of truth).

---

**Total deviations:** 2 — 1 auto-fix (Rule 3, blocking compile error on incorrect plan interface) + 1 user-directed spike waiver faithfully followed
**Impact on plan:** No scope creep. The runtime-selector workaround preserves the plan's intent (ship best-effort URL open with waived spike) while compiling cleanly. All acceptance criteria met modulo the specific grep pattern `extensionContext?.open` (which was the root cause of the compile error; waived-spike follow-up plan still applies).

## Acceptance Criteria Check

- [x] `xcodegen generate` exits 0
- [x] `ShieldActionHandler.swift` created, `struct ShieldActionHandler` = 1, `func decide(action: ActionKind, hasActiveSession: Bool)` = 1
- [x] URL strings: `deluludetox://session/active` = 1, `deluludetox://` appears twice (once in session/active prefix, once as root URL)
- [x] `enum ShieldActionSessionProbe` = 1
- [x] `ShieldActionHandler.swift` source-shared in project.yml under `ShieldActionExtension.sources`
- [x] `XCTSkipIf` count in `ShieldActionHandlerTests.swift` = 0
- [x] `xcodebuild test -only-testing:DeluluDetoxTests/ShieldActionHandlerTests` → 5 passed, 0 failed
- [x] Full suite: 147 passed, 0 failed, 3 skipped (pre-existing skips, not SHL-03)
- [x] `xcodebuild build` on DeluluDetox scheme → BUILD SUCCEEDED
- [x] 3 overrides in `ShieldActionExtension.swift` (application, webDomain, category — the iOS 26 SDK does NOT require a 4th `(webDomain, in: category)` override)
- [x] `ShieldActionHandler().decide` = 1 (single delegation point)
- [x] `ShieldActionSessionProbe.hasActiveSession` = 1
- [x] `completionHandler(.close)` = 1 real code-path call (plus 1 mention inside a doc comment — behaviorally correct)
- [x] Forbidden imports (FamilyControls / SwiftUI / Combine / UIKit) = 0
- [x] `TODO(SHL-03 fallback)` = 1
- [x] `#warning` for waived spike = 1
- [ ] **Deviation:** `extensionContext?.open` literal grep = 0 (replaced by `openURLFromExtension` runtime-selector helper — see Deviation #1 above)

## Issues Encountered

- Simulator UUID in `./CLAUDE.md` (`C958163F-49E1-4B46-8A6D-C2056CD25A37`) is stale on this host — not present in Xcode 26.3. Used iPhone 17 by name via `6D73311F-3541-4B74-92E8-8014FABC3329` for this session. Recommendation: a separate follow-up may refresh `CLAUDE.md` simulator UUID, but this is out of scope for Plan 04-03.
- The plan's `<interfaces>` block incorrectly listed `extensionContext` as inherited from `NSObject`. Handled via deviation Rule 3 (see above). Plan-side: consider updating Plan 04-05 (device verification) to note that the runtime-selector path should be tested end-to-end on device, not the non-existent `extensionContext?.open`.

## Next Phase Readiness

- `ShieldActionHandler` + extension wiring complete — SHL-03 unit-testable contract is green.
- Device-level verification of the URL-open path is deferred to Plan 04-05 (per plan's `done` criterion). Expectation per the waiver: device verification will confirm the best-effort open is unreliable and will trigger the scheduled local-push-fallback plan.
- No blockers for subsequent Phase 04 plans (Plan 04-04 onwards).

## Self-Check: PASSED

- [x] `DeluluDetox/Sources/Features/Shield/ActionHandler/ShieldActionHandler.swift` exists (verified via `ls`)
- [x] `Extensions/ShieldActionExtension/ShieldActionExtension.swift` modified (verified via `git log --oneline`)
- [x] `DeluluDetoxTests/Features/Shield/ShieldActionHandlerTests.swift` modified
- [x] Commit `e7e464e` present (`git log --oneline | grep e7e464e`)
- [x] Commit `1e2fb8e` present (`git log --oneline | grep 1e2fb8e`)
- [x] All acceptance criteria verified via grep / xcodebuild above

---
*Phase: 04-shield-customization*
*Completed: 2026-04-20*
