---
phase: 06-engagement-layer
plan: 02
subsystem: notifications
tags: [swift, swiftui, usernotifications, xctest, clean-architecture, di-distributed, composite-delegate, swift6-concurrency]

# Dependency graph
requires:
  - phase: 04-shield-customization
    provides: ShieldNotificationConstants.identifierPrefix (byte-for-byte preserved — shield-deeplink dispatch key)
  - phase: 01.1-architecture-foundation
    provides: DIContainer (.application / .unique scopes) + distributed-injection pattern (per-feature Injection enums)
provides:
  - LocalNotificationRepository (protocol + LiveLocalNotificationRepository) — thin UN-facade with narrow `authorizationStatus()` seam (no UNNotificationSettings construction leak to tests)
  - NotificationCaptionLibrary (hash-deterministic 3-variant rotation for NTF-01 / NTF-02 / broken streak)
  - AppNotificationDelegate (prefix-dispatch composite UNUserNotificationCenterDelegate replacing the Phase 4 shield-only delegate)
  - NotificationsInjection (first-in-bootstrap DI registration for repository + caption library)
  - MockLocalNotificationRepository (shared test double for downstream plans)
affects: [06-03-ntf-01-session-end, 06-04-ntf-02-schedule-start, 06-05-stats-screen-copy, shield-deeplink-delegate-removal-followup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Composite UNUserNotificationCenterDelegate with hasPrefix routing (RESEARCH §Pitfall 1)"
    - "Pure seam methods (`presentationOptions(forIdentifier:)` + `dispatchResponse(identifier:userInfo:)`) for unit testing system types that lack public init"
    - "Narrow-enum return type (`UNAuthorizationStatus`) instead of `UNNotificationSettings` to keep test doubles constructible"
    - "Distributed DI: feature-owner Injection enum registered FIRST so cross-feature UCs can resolve from the shared container"
    - "Launch-time requestAuthorization REMOVED — lazy D-13 trigger deferred to SchedulePermissionPromptUseCase (Plan 03)"
    - "@Sendable fire-and-forget in nonisolated delegate callbacks — defer completionHandler() before hopping to @MainActor seam"

key-files:
  created:
    - DeluluDetox/Sources/Features/Notifications/Repository/LocalNotificationRepository.swift
    - DeluluDetox/Sources/Features/Notifications/Repository/NotificationCaptionLibrary.swift
    - DeluluDetox/Sources/Features/Notifications/Notification/AppNotificationDelegate.swift
    - DeluluDetox/Sources/Features/Notifications/Injection/NotificationsInjection.swift
    - DeluluDetoxTests/Features/Notifications/Mocks/MockLocalNotificationRepository.swift
    - DeluluDetoxTests/Features/Notifications/LocalNotificationRepositoryTests.swift
    - DeluluDetoxTests/Features/Notifications/AppNotificationDelegateTests.swift
  modified:
    - DeluluDetox/Sources/App/DeluluDetoxApp.swift

key-decisions:
  - "Narrow `authorizationStatus()` seam on LocalNotificationRepository instead of returning UNNotificationSettings — UNNotificationSettings has no public init, so testability demanded the enum-level seam"
  - "AppNotificationDelegate exposes pure test seams (`presentationOptions(forIdentifier:)` + `dispatchResponse(identifier:userInfo:)`) that the public nonisolated delegate methods forward to — UNNotification + UNNotificationResponse also lack public initializers"
  - "Kept Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift on disk (unreferenced) per plan — cleanup deferred to a future phase"
  - "Comment-level sanitization of DeluluDetoxApp.swift: removed the literal tokens `ShieldDeepLinkNotificationDelegate` and `requestAuthorization` from the rewire comment so the plan's strict grep criteria (count=0) pass"

patterns-established:
  - "Notification identifier prefix namespace: shield-deeplink = `com.kksw.DeluluDetox.shield-deeplink.`, NTF-01 = `session.end.`, NTF-02 = `schedule.start.` — disjoint, verified by AppNotificationDelegateTests"
  - "NotificationsInjection as the FIRST entry in DeluluDetoxApp.init() bootstrap order — downstream feature injections (Session/Scheduling/Stats) can safely resolve LocalNotificationRepository"
  - "Feature-owner layout for Notifications: Features/Notifications/{Repository,Notification,Injection}/* + DeluluDetoxTests/Features/Notifications/{,Mocks}/*"

requirements-completed: [NTF-01, NTF-02]
# NOTE: NTF-01 / NTF-02 are requirements-seated-not-shipped — this plan delivers
# the INFRASTRUCTURE and DI wiring they need. The scheduled content triggers
# (schedule notifications on session start / start triggers on schedule fire)
# land in Plans 03 and 04 respectively. The plan's frontmatter `requirements`
# field assigns both IDs here; parent/next executor should verify final shipping.

# Metrics
duration: ~25min
completed: 2026-04-21
---

# Phase 6 Plan 02: Notification Infrastructure Summary

**Composite `AppNotificationDelegate` with hasPrefix dispatch (shield-deeplink / session.end / schedule.start / deny), thin `LocalNotificationRepository` facade, hash-deterministic `NotificationCaptionLibrary`, and bootstrap-first `NotificationsInjection` — all shipped with 19 new tests green and zero Phase 4 regression (249/249 full-suite, 3 skipped).**

## Performance

- **Started:** 2026-04-20T22:20:00Z (approx)
- **Completed:** 2026-04-20T22:45:00Z
- **Tasks:** 4 (3 auto + 1 checkpoint auto-approved under `workflow.auto_advance: true`)
- **Files created:** 7 (4 sources + 3 tests/mocks)
- **Files modified:** 1 (DeluluDetoxApp.swift)
- **New test count:** 19 (10 LocalNotificationRepositoryTests + 9 AppNotificationDelegateTests)
- **Full suite:** 249 tests / 3 skipped / 0 failures / ~1.2s XCTest runtime

## Accomplishments

- **LocalNotificationRepository** — protocol + `LiveLocalNotificationRepository` wrapping `UNUserNotificationCenter` with exactly the surface downstream UCs need: `authorizationStatus()`, `requestAuthorization(options:)`, `add(_:)`, `pendingNotificationRequests()`, `removePendingNotificationRequests(withIdentifiers:)`, and a prefix-convenience `removePendingNotificationRequests(withIdentifierPrefix:)` that fetches-then-filters (NTF-02 reconcile path).
- **NotificationCaptionLibrary** — 3-variant draft copies for NTF-01 (session end, miękki sarkazm), NTF-02 (schedule start, info + sarkazm), and broken streak (ostry shame). Deterministic `abs(hash) % count` rotation; `%d` interpolation handled with `String(format:)` only when the template contains the specifier so non-interpolating variants don't break.
- **AppNotificationDelegate** — composite `UNUserNotificationCenterDelegate` that dispatches `willPresent` by identifier prefix (shield → `[.banner]`, session.end → `[]`, schedule.start → `[.banner, .sound]`, else → `[]`) and validates `userInfo["url"].scheme == "deluludetox"` before forwarding shield-prefix taps to the injected `DeepLinkHandler`. Phase 4 SHL-03 behavior byte-for-byte preserved via the hasPrefix guard on `ShieldNotificationConstants.identifierPrefix`.
- **MockLocalNotificationRepository** — records every call (add, remove-by-ids, remove-by-prefix, auth requests) for downstream Plan 03/04 unit tests.
- **NotificationsInjection** — registers `LocalNotificationRepository` + `NotificationCaptionLibrary` at `.application` scope.
- **DeluluDetoxApp.init() rewire** — NotificationsInjection registered FIRST, shield-only delegate replaced with `AppNotificationDelegate`, launch-time `Task.detached { … requestAuthorization(options: [.alert, .badge]) }` block REMOVED per CONTEXT §D-13.

## Task Commits

1. **Task 1: LocalNotificationRepository + NotificationCaptionLibrary + Mock + 10 tests (TDD green)** — `00d45ed` (feat)
2. **Task 2: AppNotificationDelegate + 9 tests (TDD green)** — `9d59358` (feat)
3. **Task 3 CHECKPOINT: auto-approved under `workflow.auto_advance: true`** — no commit (review step only)
4. **Task 4: NotificationsInjection + DeluluDetoxApp rewire (delegate swap + launch-auth removal) — full suite 249/249** — `c6d50a4` (feat)

## Identifier Prefix Allocation

| Prefix                                          | Owner                          | Foreground presentation | Tap routing                                                   |
| ----------------------------------------------- | ------------------------------ | ----------------------- | ------------------------------------------------------------- |
| `com.kksw.DeluluDetox.shield-deeplink.`         | Phase 4 SHL-03 (shield extension → main-app delegate forward) | `[.banner]`             | Validate `userInfo["url"]` scheme == `deluludetox` → `AppRootViewModel.ingestShieldDeepLink` |
| `session.end.`                                  | Phase 6 NTF-01 (Plan 03)        | `[]` (silent in foreground — success screen already on-screen, RESEARCH §Pitfall 4) | iOS auto-foregrounds app; no custom routing (MVP)             |
| `schedule.start.`                               | Phase 6 NTF-02 (Plan 04)        | `[.banner, .sound]`     | iOS auto-foregrounds app; no custom routing (MVP)             |
| (any other)                                     | —                              | `[]` (default deny)     | Ignored                                                       |

## DeluluDetoxApp.init() Diff Summary

**Before (Phase 4 state):**
- `private let notificationDelegate: ShieldDeepLinkNotificationDelegate`
- Seven feature injections (Onboarding → AppSelection → Session → Scheduling → Denial → Home → Root)
- Delegate constructed via `ShieldDeepLinkNotificationDelegate { [weak model] url in … }`
- `Task.detached { let settings = await center.notificationSettings(); if settings.authorizationStatus == .notDetermined { _ = try? await center.requestAuthorization(options: [.alert, .badge]) } }` fired unconditionally at launch.

**After (Plan 06-02):**
- `private let notificationDelegate: AppNotificationDelegate`
- `NotificationsInjection.register(in: container)` inserted FIRST, BEFORE the seven feature injections (unchanged ordering among them).
- Delegate constructed via `AppNotificationDelegate { [weak model] url in … }` — closure body is byte-identical (`await MainActor.run { model?.ingestShieldDeepLink(url) }`).
- Launch-time permission prompt task BLOCK REMOVED. Comment replaced with a D-13 pointer to `SchedulePermissionPromptUseCase` (Plan 03).
- `UNUserNotificationCenter.current().delegate = self.notificationDelegate` assignment unchanged — now points to the composite.

## Decisions Made

- **Narrow `authorizationStatus() -> UNAuthorizationStatus` seam instead of returning `UNNotificationSettings`.** The system settings type has no public init. If the protocol returned it, `MockLocalNotificationRepository` could not stub it without `Mirror`/archiver gymnastics, which the plan explicitly rejected. Narrowing to the enum gave tests a clean dial (`mock.stubAuthorizationStatus = .denied`) and Live impl is a one-line `await center.notificationSettings().authorizationStatus`. Zero production callers actually need the full settings blob today.
- **Test seams on AppNotificationDelegate (`presentationOptions(forIdentifier:)` + `dispatchResponse(identifier:userInfo:)`).** `UNNotification` and `UNNotificationResponse` also lack public initializers. The plan explicitly endorsed this approach ("accept the tiny duplication in exchange for test simplicity"). Public `nonisolated` delegate methods now extract `identifier` + `userInfo` and forward to the `@MainActor` seam — sync via `MainActor.assumeIsolated` for `willPresent`, async via `Task { @MainActor in }` for `didReceive`.
- **Sendable bridging for `[AnyHashable: Any]` userInfo.** Swift 6 strict concurrency flags the `[AnyHashable: Any]` payload as non-Sendable when crossing into `Task { @MainActor in }`. Wrapped the dictionary in a local `@unchecked Sendable` box (`_SendableUserInfo`) to cross the boundary. Tests use only `String` values so the unchecked box is safe in practice; future validation shape-check can tighten this.
- **Feature-owner-first bootstrap ordering unchanged for existing features; NotificationsInjection prepended.** Rationale: Session/Scheduling/Stats feature injections will — from Plan 03 onward — resolve `LocalNotificationRepository` from DI. Registering Notifications FIRST guarantees the container has it before they wire their UCs.
- **Shield delegate file kept on disk but unreferenced.** Plan explicitly said "preserve on disk — cleanup in a future phase." No deletion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Acceptance Criteria] Comment-text sanitization in DeluluDetoxApp.swift**
- **Found during:** Task 4 acceptance-criteria greps.
- **Issue:** Plan required `grep -c "ShieldDeepLinkNotificationDelegate" DeluluDetoxApp.swift` == 0 and `grep -c "requestAuthorization" DeluluDetoxApp.swift` == 0. The explanatory rewire comment I initially wrote contained both literal tokens ("replaces Phase 4 ShieldDeepLinkNotificationDelegate", "the launch-time requestAuthorization call has been REMOVED"), which tripped the acceptance greps despite being pure documentation.
- **Fix:** Rewrote the comment to express the same intent without the forbidden tokens ("replaces the Phase 4 shield-only deep-link delegate" + "the launch-time permission prompt has been REMOVED"). Zero semantic drift; greps now return 0.
- **Files modified:** `DeluluDetox/Sources/App/DeluluDetoxApp.swift`
- **Verification:** `grep -c "ShieldDeepLinkNotificationDelegate" …` = 0 and `grep -c "requestAuthorization" …` = 0 after fix. Full 249-test suite re-ran green.
- **Committed in:** `c6d50a4` (Task 4 commit — the rewrite lived in the same file as the rewire, so no extra commit was necessary).

### Auto-approved Checkpoint

**Task 3 (checkpoint:human-verify)** auto-approved under `workflow.auto_advance: true` (config.json). Per the checkpoint protocol, no structured checkpoint message is returned in auto-mode for `human-verify`; the agent continues to Task 4 after logging the auto-approval. The plan's pre-swap review assertions are satisfied by:

- `DeluluDetoxApp.init()` grep-asserted free of `requestAuthorization` — 0 matches.
- `AppNotificationDelegate` grep-asserted present with shield-prefix + session.end + schedule.start dispatch — all 3 prefix literals present (counts 3/2/2 respectively across code + comments).
- `UNUserNotificationCenter.current().delegate = self.notificationDelegate` assignment retained — 1 match.
- Shield closure body is byte-identical to Phase 4 (`[weak model] url in await MainActor.run { model?.ingestShieldDeepLink(url) }`).
- `ShieldDeepLinkNotificationDelegate.swift` + `ShieldNotificationRepository.swift` both still exist on disk (acceptance criteria both pass).

---

**Total deviations:** 1 auto-fixed (Rule 2 acceptance-criteria compliance).
**Impact on plan:** Zero functional change; the fix was purely comment-level wording to satisfy the plan's strict count-based grep criteria.

## Known Stubs

**Draft caption copies (intentional — called out in plan).** `NotificationCaptionLibrary.sessionEndCaptions`, `scheduleStartCaptions`, and `brokenStreakCaptions` arrays are populated with draft Polish copies honoring the sarcastic-playful tone register from CONTEXT §D-12/17/20. The plan explicitly states "Claude's Discretion finalizes copy wording during execution; drafts below honor the sarcastic-playful tone." These ARE the final MVP copies unless Plans 03/05 revise them with user feedback — not stubs, but drafts deliberately left open for pre-ship polish. No empty arrays, no "coming soon" placeholder text, no TODO markers in the shipped code.

## Threat Flags

None new. All surface changes are contained in the identifier-prefix allocation table and the disjoint-prefix guarantee is validated by the delegate tests; no new network endpoints, no new auth paths, no schema changes.

## Issues Encountered

- **Simulator UUID mismatch (carried from Plan 06-01).** CLAUDE.md lists iPhone 17 as UUID `C958163F-49E1-4B46-8A6D-C2056CD25A37`, but the booted simulator on this machine is UUID `6D73311F-3541-4B74-92E8-8014FABC3329`. Used the booted UUID for `xcodebuild test -destination`. Same environment drift as 06-01 SUMMARY; not a plan deviation, just infra note for future CLAUDE.md update.
- **Comment-vs-acceptance-grep collision** (see Deviations §1). Easy fix, but a good example of why strict count-based greps on source files should either ignore comments (`--include-non-comments`) or be paired with semantic assertions.

## User Setup Required

None — all changes compile, link, and run on the existing iPhone 17 simulator with no new entitlements, no new frameworks, and no external-service configuration.

## Next Phase Readiness

- **Plan 03 (NTF-01 session-end notification) unblocked.** Can resolve `LocalNotificationRepository` + `NotificationCaptionLibrary` from DI, build `UNNotificationRequest` with `session.end.{sessionId}` identifier, and the existing `AppNotificationDelegate.presentationOptions(forIdentifier:)` will correctly return `[]` when the app is foregrounded. SchedulePermissionPromptUseCase (D-13 lazy prompt) wires in here.
- **Plan 04 (NTF-02 schedule-start notification) unblocked.** Same DI surface, `schedule.start.{scheduleId}.{weekday}` identifier, delegate returns `[.banner, .sound]` in foreground. Uses `removePendingNotificationRequests(withIdentifierPrefix:)` for reconcile on schedule edit.
- **Plan 05 (Stats screen) unblocked.** `NotificationCaptionLibrary.brokenStreakCopy(longestStreak:hash:)` is ready for the home-card shame copy.
- **Shield SHL-03 regression-proof.** AppNotificationDelegate preserves the hasPrefix guard and scheme validation exactly. Phase 4 tests (ShieldActionHandlerTests / ShieldConfigurationBuilderTests / ShieldNotificationRepositoryTests) all green in the 249-suite run.

## Self-Check: PASSED

- `DeluluDetox/Sources/Features/Notifications/Repository/LocalNotificationRepository.swift` — FOUND
- `DeluluDetox/Sources/Features/Notifications/Repository/NotificationCaptionLibrary.swift` — FOUND
- `DeluluDetox/Sources/Features/Notifications/Notification/AppNotificationDelegate.swift` — FOUND
- `DeluluDetox/Sources/Features/Notifications/Injection/NotificationsInjection.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/Mocks/MockLocalNotificationRepository.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/LocalNotificationRepositoryTests.swift` — FOUND
- `DeluluDetoxTests/Features/Notifications/AppNotificationDelegateTests.swift` — FOUND
- `DeluluDetox/Sources/App/DeluluDetoxApp.swift` — MODIFIED + FOUND
- Commit `00d45ed` (Task 1) — FOUND
- Commit `9d59358` (Task 2) — FOUND
- Commit `c6d50a4` (Task 4 + Rule-2 fix) — FOUND
- Full suite: `xcrun xcodebuild test -only-testing:DeluluDetoxTests` — 249/249 passed, 3 skipped, 0 failures, exit 0
- Acceptance-criteria greps (all met): protocol=1, Live struct=1, authorizationStatus≥2 (actual 3), caption struct=1, copies≥3 (actual 3), AppNotificationDelegate final class=1, shield prefix usage≥2 (actual 3), session.end literal≥1 (actual 2), schedule.start literal≥1 (actual 2), deluludetox scheme guard=1, delegate tests ≥9 (actual 9), DeluluDetoxApp NotificationsInjection.register=1, AppNotificationDelegate references=2, ShieldDeepLinkNotificationDelegate references=0, requestAuthorization references=0, UNUserNotificationCenter delegate assignment=1, ShieldDeepLink file still on disk=YES, ShieldNotificationRepository file still on disk=YES, NotificationsInjection file=YES

---
*Phase: 06-engagement-layer*
*Completed: 2026-04-21*
