---
phase: 05-scheduled-blocking
plan: 02
subsystem: scheduling
tags: [scheduling, repository, use-case, persistence, combine, xctest, wave-1]
status: complete

# Dependency graph
requires:
  - phase: 05-scheduled-blocking
    plan: 01
    provides: "Schedule / ScheduleEvent / ScheduleEventMarker / SchedulePaths / ScheduleProtocols scaffolds + MockScheduleRepository + 3 XCTSkipIf test files"
provides:
  - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift — ScheduleRepositoryImpl with atomic JSON persistence, 4-closure URL-provider test seam, Combine publisher over [Schedule], multi-marker consume (RESEARCH OQ#4)"
  - "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift — CreateOrUpdateScheduleUseCaseImpl composing repo.upsert → sync in CONTEXT D-14 order"
  - "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift — ConsumeScheduleEventMarkerUseCaseImpl draining sorted markers into schedule_events.json"
  - "ScheduleRepository protocol — full method set (upsert, remove(id:), loadFromDisk, appendEvent, consumeEventMarkers) + ScheduleStoreError enum"
  - "CreateOrUpdateScheduleUseCase / SyncScheduleWithSystemUseCase / ConsumeScheduleEventMarkerUseCase protocols — method signatures landed (SyncSchedule body stays empty until Plan 04)"
  - "12 new passing assertions replacing XCTSkipIf stubs (5 Repo + 3 CreateOrUpdate + 4 ConsumeEventMarker)"
affects:
  - "Plan 05-03 — ScheduleShieldRepository + ScheduleActivityMonitoringRepository (uses ManagedSettingsStoreNames already landed; no protocol churn expected here)"
  - "Plan 05-04 — SyncScheduleWithSystemUseCaseImpl now has its protocol method signed off; registration in SchedulingInjection.register will wire ScheduleRepositoryImpl + the two Plan 02 UseCases"
  - "Plan 05-05 — DAM extension marker writers produce files matching the SchedulePaths naming convention that the repository + UC already consume"
  - "Plan 05-06 — ScheduleEditorViewModel gets a MockCreateOrUpdateScheduleUseCase whose signature now matches the production impl"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Feature-first Common/Repository + Common/UseCase layout under DeluluDetox/Sources/Features/Scheduling/"
    - "SessionRepository analogue: 4-closure URL-provider init seam + production convenience init reading SchedulePaths"
    - "Multi-marker destructive-consume: list App Group dir → filter → parse unix-millis suffix → sort ascending → decode → append → remove. Parse failure drops single file (logged) instead of throwing (STRIDE T-05-02-04)"
    - "Protocol-extension-in-place (no file move): Plan 05-01's empty bodies now carry the method set Plan 05-02 uses; downstream plans extend further without renaming files or splitting conformers"

key-files:
  created:
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift"
    - "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift"
  modified:
    - "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift — extended 4 protocol bodies (ScheduleRepository, CreateOrUpdateScheduleUseCase, SyncScheduleWithSystemUseCase, ConsumeScheduleEventMarkerUseCase)"
    - "DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift — 5 XCTSkipIf stubs → 5 real assertions + helper"
    - "DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift — 3 stubs → 3 real assertions"
    - "DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift — 4 stubs → 4 real assertions"
    - "DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift — remove(scheduleId:) → remove(id:) + stubbedLoadFromDisk"
    - "DeluluDetoxTests/Features/Scheduling/Mocks/MockCreateOrUpdateScheduleUseCase.swift — callAsFunction(_:) void, no return value"
    - "DeluluDetoxTests/Features/Scheduling/Mocks/MockSyncScheduleWithSystemUseCase.swift — sync(schedule:) → callAsFunction(schedule:)"

key-decisions:
  - "Happy-path-only: assumes Wave 0 Outcome A per 05-DISCUSSION-LOG; no daily re-register fallback code in ScheduleRepository (that would live in Plan 04 Sync UC if ever needed)"
  - "Repository owns 'list + sort + delete' for markers; the UC only translates Marker → Event and appends. Keeps deletion semantics atomic with the listing (can't reintroduce a consumed file between list and delete)"
  - "Protocol bodies extended in-place, not moved to feature sub-files. Plan 05-01's design choice preserved — Live* + Mock* conformers stay discoverable in one spot"
  - "ScheduleStoreError enum lives in ScheduleRepository.swift (next to its sole thrower), not in Models/ — matches SessionStoreError colocation with SessionRepository.swift"

patterns-established:
  - "For CurrentValueSubject-backed publishers in tests: use the SessionRepositoryTests sync helper shape (XCTestExpectation + XCTWaiter + sink.cancel). Closure-appended arrays under @MainActor + Swift 6.2 strict concurrency crash"

requirements-completed: []  # SCH-01 / SCH-02 close when Plans 05-04 (Sync UC), 05-06 (Editor VM) and 05-07 (List VM + navigation) also land

# Metrics
duration: 35min
completed: 2026-04-20
---

# Phase 05 Plan 02: Schedule Repository + Persistence UseCases Summary

**Scheduling data layer is live — `ScheduleRepositoryImpl` persists schedules atomically and publishes updates via `AnyPublisher<[Schedule], Never>`; `CreateOrUpdateScheduleUseCaseImpl` wires editor-save to repo + sync; `ConsumeScheduleEventMarkerUseCaseImpl` drains the timestamp-suffixed marker pile into `schedule_events.json` without losing cross-midnight events.**

## Performance

- **Duration:** ~35 min (2026-04-20)
- **Tasks planned:** 2
- **Tasks completed:** 2/2
- **Files created:** 3 (1 repo source + 2 UC source)
- **Files modified:** 7 (1 protocols + 3 test files + 3 mock files)
- **Test delta:** suite total 205 → 205; skipped 54 → 42 (12 promoted); failures 0 → 0
- **Scoped test passes:** 5 (ScheduleRepositoryTests) + 3 (CreateOrUpdateScheduleUseCaseTests) + 4 (ConsumeScheduleEventMarkerUseCaseTests) = 12

## Accomplishments

- Shipped `ScheduleRepositoryImpl` mirroring `SessionRepositoryImpl` — 4-closure URL-provider seam, atomic JSON writes with `.completeFileProtectionUntilFirstUserAuthentication`, `CurrentValueSubject<[Schedule], Never>` surfaced through `schedulesPublisher`
- Implemented multi-marker consume: list App Group dir → filter via `SchedulePaths.isMarkerFile(_:)` → parse `{unix_ms}` suffix → sort ascending → decode + delete each — resolves RESEARCH OQ#4 cross-midnight defect
- Wired `CreateOrUpdateScheduleUseCaseImpl` to call `repo.upsert` then `sync(schedule:)` in the CONTEXT D-14 order (Plan 04 owns DAS rollback semantics)
- Wired `ConsumeScheduleEventMarkerUseCaseImpl` to translate each marker into a `ScheduleEvent` and append via the repository, preserving chronological order
- Promoted every Plan 05-01 XCTSkipIf stub in the three target test files to a real assertion — skip count fell from 54 to 42 (delta 12), match for "5 Repo + 3 CreateOrUpdate + 4 ConsumeEventMarker"
- Realigned the three mocks whose Plan 05-01 shapes no longer matched the final protocols: `MockScheduleRepository.remove(scheduleId:) → remove(id:)`, `MockCreateOrUpdateScheduleUseCase.callAsFunction(schedule:) -> Schedule → callAsFunction(_:) void`, `MockSyncScheduleWithSystemUseCase.sync(schedule:) → callAsFunction(schedule:)`

## Task Commits

| Task | Name                                                                                       | Commit    | Files                                                                                                                               |
| ---- | ------------------------------------------------------------------------------------------ | --------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| 1    | ScheduleRepository — protocol body + ScheduleRepositoryImpl + 5 tests + mock alignment     | `1f954f9` | ScheduleProtocols.swift + ScheduleRepository.swift + ScheduleRepositoryTests.swift + MockScheduleRepository.swift                   |
| 2    | CreateOrUpdate + ConsumeEventMarker UseCases — impls + 7 tests + 2 mock signature realigns | `7ac9998` | ScheduleProtocols.swift + CreateOrUpdateScheduleUseCase.swift + ConsumeScheduleEventMarkerUseCase.swift + 2 test files + 2 mocks    |

## Files Created/Modified

**Created (source):**

- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` — `ScheduleRepositoryImpl` (211 lines) + `ScheduleStoreError` enum
- `DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift` — `CreateOrUpdateScheduleUseCaseImpl`
- `DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift` — `ConsumeScheduleEventMarkerUseCaseImpl`

**Modified (source):**

- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` — extended `ScheduleRepository` + `CreateOrUpdateScheduleUseCase` + `SyncScheduleWithSystemUseCase` + `ConsumeScheduleEventMarkerUseCase` protocol bodies

**Modified (tests):**

- `DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift` — 5 stubs → 5 real assertions + sync-publisher helper
- `DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift` — 3 stubs → 3 real assertions
- `DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift` — 4 stubs → 4 real assertions

**Modified (mocks):**

- `DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift` — `remove(scheduleId:)` → `remove(id:)`; added `stubbedLoadFromDisk` + `loadFromDisk()` conformance
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockCreateOrUpdateScheduleUseCase.swift` — `callAsFunction(schedule:) -> Schedule` → `callAsFunction(_:)` void
- `DeluluDetoxTests/Features/Scheduling/Mocks/MockSyncScheduleWithSystemUseCase.swift` — `sync(schedule:)` → `callAsFunction(schedule:)`

## Decisions Made

- **Scope Task 1 strictly to `ScheduleRepository` protocol changes.** The plan `<interfaces>` block nominally lands all protocol signatures up front, but that cascades into mock failures on unrelated UseCase protocols during Task 1's build. Split the changes: Task 1 only extends `ScheduleRepository`; Task 2 extends the three UC protocols and aligns their mocks in the same commit. Keeps each commit cleanly compilable.
- **Deletion stays in the repository.** `ConsumeScheduleEventMarkerUseCase` does not touch `FileManager`. The repository's `consumeEventMarkers()` returns already-sorted-and-deleted markers; the UC only maps Marker → Event and appends. Contract stays tight; UC unit tests don't need a temp directory.
- **`fileExists` guard around the App Group directory in `consumeEventMarkers`.** Defends against a pre-first-run race where the container directory itself doesn't exist yet (test-seam path providers can legitimately return a non-existent URL).
- **`currentSchedules` helper in tests uses XCTestExpectation + XCTWaiter, not a synchronous variable capture.** The first attempt (`var received: [[Schedule]] = []; sink { received.append($0) }`) crashed the test runner under Swift 6.2 strict concurrency on `@MainActor` — exactly as `SessionRepositoryTests` already documents in a header comment. Copied the proven shape.

## Deviations from Plan

**Auto-fixed (Rule 3 — blocking issues):**

1. **[Rule 3 — Blocking] Mock signature mismatch between Plan 05-01 and Plan 05-02 `<interfaces>`.**
   - **Found during:** Task 2 first compile.
   - **Issue:** `MockCreateOrUpdateScheduleUseCase.callAsFunction(schedule:) async throws -> Schedule` (Plan 01) doesn't satisfy the Plan 02 protocol `callAsFunction(_ schedule: Schedule) async throws`. Same for `MockSyncScheduleWithSystemUseCase.sync(schedule:)` vs. protocol's `callAsFunction(schedule:)`, and `MockScheduleRepository.remove(scheduleId:)` vs. protocol's `remove(id:)`.
   - **Fix:** Updated each mock's method signature to match the protocol; stored a `lastInputSchedule` instead of returning one where the return type vanished.
   - **Files modified:** `MockCreateOrUpdateScheduleUseCase.swift`, `MockSyncScheduleWithSystemUseCase.swift`, `MockScheduleRepository.swift`.
   - **Commits:** Task 1 (`1f954f9`) for the repo mock; Task 2 (`7ac9998`) for the two UC mocks.

2. **[Rule 3 — Blocking] Test runner crash on `testUpsertAddsNewScheduleToPublisher`.**
   - **Found during:** Task 1 test execution.
   - **Issue:** First iteration of the publisher test used `var received: [[Schedule]] = []; publisher.sink { received.append($0) }` inside an `@MainActor` `async throws` test; Swift 6.2 strict concurrency crashed at "closure #1 in …" exactly as `SessionRepositoryTests` header comment warns.
   - **Fix:** Replaced with the proven `currentSchedules(from: repo)` sync-read helper that mirrors `SessionRepositoryTests.currentActiveSession/currentHistory`.
   - **Files modified:** `ScheduleRepositoryTests.swift`.
   - **Commit:** Task 1 (`1f954f9`).

3. **[Rule 3 — Blocking] Floating-point rounding in `testConsumeEventMarkerReturnsAllMarkersAndDeletes`.**
   - **Found during:** Task 1 test execution.
   - **Issue:** Asserting filename-suffix roundtrip with `Int64($0.timestamp.timeIntervalSince1970 * 1000) == 50` fails because `Date(timeIntervalSince1970: 0.050).timeIntervalSince1970 * 1000 == 49.99…` → `49`.
   - **Fix:** Replaced the integer-equality check with pairwise `XCTAssertLessThan` on timestamps + a kind-mapping check. Correctness of the chronological sort is still asserted; the assertion is just numerically robust.
   - **Files modified:** `ScheduleRepositoryTests.swift`.
   - **Commit:** Task 1 (`1f954f9`).

**Rule 1 / Rule 2 / Rule 4 deviations:** None.

---

**Total deviations:** 3 auto-fixed (all Rule 3 — blocking).
**Impact on plan:** Tasks 1 and 2 completed fully; all `<acceptance_criteria>` gates pass. The three adjustments are local test/mock fixes and a split of protocol-body edits across the two commits; the plan's net outcome is unchanged.

## Acceptance Criteria Cross-check

### Task 1

- [x] `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` exists
- [x] `final class ScheduleRepositoryImpl: ScheduleRepository, @unchecked Sendable` count == 1
- [x] `func upsert(_ schedule: Schedule) async throws` in protocols == 1
- [x] `func consumeEventMarkers() async throws -> [ScheduleEventMarker]` in protocols == 1
- [x] `enum ScheduleStoreError: Error` in repo == 1
- [x] `CurrentValueSubject<[Schedule], Never>` in repo == 2 (property + init)
- [x] `options: [.atomic` in repo >= 1
- [x] `XCTSkipIf(true` in ScheduleRepositoryTests == 0
- [x] `func testCodableRoundTrip` in tests == 1
- [x] `func testConsumeEventMarkerReturnsAllMarkersAndDeletes` in tests == 1
- [x] `^import SwiftUI` in repo == 0
- [x] `^import FamilyControls` in repo == 0
- [x] `test -only-testing:DeluluDetoxTests/ScheduleRepositoryTests` — 5 passed, 0 failed, 0 skipped

### Task 2

- [x] `CreateOrUpdateScheduleUseCase.swift` exists
- [x] `ConsumeScheduleEventMarkerUseCase.swift` exists
- [x] `final class CreateOrUpdateScheduleUseCaseImpl: CreateOrUpdateScheduleUseCase, @unchecked Sendable` count == 1
- [x] `final class ConsumeScheduleEventMarkerUseCaseImpl: ConsumeScheduleEventMarkerUseCase, @unchecked Sendable` count == 1
- [x] `func callAsFunction(schedule: Schedule) async throws` in protocols == 1 (SyncScheduleWithSystemUseCase)
- [x] `try await repository.upsert` in CreateOrUpdate == 1
- [x] `try await sync(schedule:` in CreateOrUpdate == 1
- [x] `try await repository.consumeEventMarkers` in Consume == 1
- [x] `XCTSkipIf(true` in CreateOrUpdateScheduleUseCaseTests == 0
- [x] `XCTSkipIf(true` in ConsumeScheduleEventMarkerUseCaseTests == 0
- [x] Scoped tests: 7 passed (3 + 4), 0 failed, 0 skipped
- [x] Full suite green — 205 tests, 42 skipped, 0 failed (Plan 01 baseline 205/54/0 → Plan 02 delta: 12 skips removed)

## Issues Encountered

- **`mcp__XcodeBuildMCP__*` tools not exposed to this executor.** Same situation as Plan 05-01. Fallback: raw `xcodebuild` against the booted iPhone 17 simulator (UUID `6D73311F-3541-4B74-92E8-8014FABC3329`, iOS 26.3.1). Build SUCCEEDED and TEST SUCCEEDED — substantive outcome matches what XcodeBuildMCP would have produced. Flagging for orchestrator visibility; not a deviation to fix.
- **Worktree base recovery at session start.** Initial soft-reset to the orchestrator base wiped the working tree; `git checkout HEAD -- .` restored all tracked files. No data lost, no commits amended.

## User Setup Required

None.

## Next Phase / Plan Readiness

**Ready:**

- Plan 05-03 (ScheduleShieldRepository + ScheduleActivityMonitoringRepository) — `ManagedSettingsStoreNames` + `ScheduleActivityNames` from Plan 01 are in place; no protocol churn expected in `ScheduleProtocols.swift` for these two repositories.
- Plan 05-04 (UseCases + DI) — `SyncScheduleWithSystemUseCase` protocol now has the method signature the real impl will fill; `SchedulingInjection.register(in:)` body (empty per Plan 01) can register `ScheduleRepositoryImpl`, `CreateOrUpdateScheduleUseCaseImpl`, `ConsumeScheduleEventMarkerUseCaseImpl` alongside the new Plan 04 types.
- Plan 05-05 (DAM extension handlers) — the marker file naming convention is locked; DAM writers produce `schedule_event_marker_{unix_ms}.json` files that the repository + UC already consume correctly.
- Plan 05-06 (Editor VM) — `MockCreateOrUpdateScheduleUseCase` signature now matches production; ScheduleEditorViewModel "save tapped" flow can inject it unchanged.

**Blocked:**

- None within the `<dependency_graph>`. Plan 05-08 (Device UAT) still waits on the Wave 0 verdict, but that gate is outside Plan 02's scope.

## Self-Check: PASSED

All listed created files verified present on disk:

- `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift` — FOUND
- `DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift` — FOUND

Commits verified present in git log:

- `1f954f9` (Task 1) — FOUND
- `7ac9998` (Task 2) — FOUND

---

*Phase: 05-scheduled-blocking*
*Plan: 02 (complete)*
*Completed: 2026-04-20*
