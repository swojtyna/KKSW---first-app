---
phase: 05
plan: 02
type: execute
wave: 1
depends_on: [05-01]
files_modified:
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift
  - DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift
autonomous: true
requirements: [SCH-01, SCH-02]
must_haves:
  truths:
    - "ScheduleRepository persists schedules in schedule.json with atomic writes; supports N records (schema) but MVP callers mutate the first/only entry"
    - "ScheduleRepository.schedulesPublisher emits the live list as CurrentValueSubject<[Schedule], Never>"
    - "CreateOrUpdateScheduleUseCase upserts + triggers sync — editor save path delivers SCH-01 acceptance (recurring schedule persists) and SCH-02 enabled toggle state"
    - "ConsumeScheduleEventMarkerUseCase lists timestamp-suffixed marker files, appends to schedule_events.json in chronological order, deletes marker files — solves RESEARCH Open Question #4 (cross-midnight marker loss)"
    - "Schedule events are append-only history readable by Phase 6 (NTF-02 consumer)"
  artifacts:
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift"
      provides: "ScheduleRepositoryImpl with two subjects (schedules + events are disk-backed; events is append-only), atomic writers, URL-provider test seams"
      min_lines: 120
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift"
      provides: "CreateOrUpdateScheduleUseCaseImpl depending on ScheduleRepository + SyncScheduleWithSystemUseCase (empty stub until Plan 05-04 fills in)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift"
      provides: "ConsumeScheduleEventMarkerUseCaseImpl — list + sort + append + delete markers"
    - path: "DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift"
      provides: "5 tests replacing Plan 01 stubs with real assertions"
    - path: "DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift"
      provides: "Real mock with call counters, schedulesSubject exposed, error stubs"
  key_links:
    - from: "ScheduleRepositoryImpl"
      to: "schedule.json on disk (via SchedulePaths.schedulesURL())"
      via: "writeAtomic(to:url) using [.atomic, .completeFileProtectionUntilFirstUserAuthentication]"
      pattern: "Data.write\\(to:.*options: \\[\\.atomic"
    - from: "ScheduleRepositoryImpl.consumeEventMarkers"
      to: "schedule_events.json (append-only)"
      via: "read events.json → append sorted markers → atomic write; delete each marker file after append"
      pattern: "FileManager.*removeItem"
    - from: "CreateOrUpdateScheduleUseCaseImpl"
      to: "ScheduleRepository.upsert + SyncScheduleWithSystemUseCase"
      via: "await repo.upsert THEN await sync"
      pattern: "try await repository.upsert"
---

<objective>
Deliver the Scheduling data layer: `ScheduleRepository` (atomic JSON persistence + Combine publisher over `[Schedule]`), the two persistence-facing UseCases (`CreateOrUpdateScheduleUseCase` + `ConsumeScheduleEventMarkerUseCase`), and turn their Plan 01 XCTSkipIf stubs into real assertions.

Purpose: SCH-01 (create recurring schedule) requires atomic persistence that survives app launches (REQUIREMENTS §Schedules). SCH-02 (enable/disable) requires the repository to observe and emit state changes. Open Question #4 resolution (timestamp-suffixed markers) is implemented here so DAM Plan 05-05 can write markers without clobbering cross-midnight events.

Output:
- Production `ScheduleRepositoryImpl` mirroring `SessionRepositoryImpl` shape — CurrentValueSubject, atomic writes, URL-provider test seam, destructive-consume semantics for markers.
- `CreateOrUpdateScheduleUseCaseImpl` — upserts via repo, calls sync UC (injected from Plan 04 via container; for Plan 02 we accept a protocol param that can be satisfied by Plan 01's empty `SyncScheduleWithSystemUseCase` protocol until Plan 04 adds real methods).
- `ConsumeScheduleEventMarkerUseCaseImpl` — lists `schedule_event_marker_*.json`, sorts by unix-millis suffix, appends each to `schedule_events.json`, deletes each marker file.
- 5 ScheduleRepositoryTests + 3 CreateOrUpdateUseCase tests + 4 ConsumeEventMarkerUseCase tests landed (green).
- `MockScheduleRepository` fleshed out with real protocol implementation.
</objective>

<execution_context>
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/workflows/execute-plan.md
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/05-scheduled-blocking/05-CONTEXT.md
@.planning/phases/05-scheduled-blocking/05-RESEARCH.md
@.planning/phases/05-scheduled-blocking/05-01-SUMMARY.md
@.planning/phases/03-quick-sessions/03-01-SUMMARY.md
@DeluluDetox/Sources/Features/Session/Repository/SessionRepository.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift

<interfaces>
<!-- Plan 01 created empty protocols in ScheduleProtocols.swift. Plan 02 REPLACES the relevant ones with method declarations. -->

Final `ScheduleRepository` protocol body (Plan 02 replaces the empty `protocol ScheduleRepository: Sendable {}`):
```swift
protocol ScheduleRepository: Sendable {
    var schedulesPublisher: AnyPublisher<[Schedule], Never> { get }
    func upsert(_ schedule: Schedule) async throws
    func remove(id: UUID) async throws
    func loadFromDisk() async throws -> [Schedule]
    func appendEvent(_ event: ScheduleEvent) async throws
    func consumeEventMarkers() async throws -> [ScheduleEventMarker]   // RESEARCH OQ#4 multi-marker consume
}

enum ScheduleStoreError: Error {
    case scheduleNotFound
    case pathsUnavailable
}
```

Final `CreateOrUpdateScheduleUseCase` protocol body:
```swift
protocol CreateOrUpdateScheduleUseCase: Sendable {
    func callAsFunction(_ schedule: Schedule) async throws
}
```

Final `ConsumeScheduleEventMarkerUseCase` protocol body:
```swift
protocol ConsumeScheduleEventMarkerUseCase: Sendable {
    /// Returns count of markers consumed (appended to events.json and deleted).
    @discardableResult
    func callAsFunction() async throws -> Int
}
```

`SyncScheduleWithSystemUseCase` stays empty (Plan 04 fills it). `CreateOrUpdateScheduleUseCaseImpl` init depends on it but Plan 02's test mock is a no-op `MockSyncScheduleWithSystemUseCase` — mock already exists from Plan 01.

From SessionRepository.swift (analogue, verified lines):
```swift
final class SessionRepositoryImpl: SessionRepository, @unchecked Sendable {
    private let activeSubject: CurrentValueSubject<SessionRecord?, Never>
    private let historySubject: CurrentValueSubject<[SessionRecord], Never>
    private let activeURLProvider: () throws -> URL
    ...
    init(activeURLProvider: @escaping () throws -> URL = { try SessionPaths.activeSessionURL() }, ...)
}
```
ScheduleRepositoryImpl follows the same shape with `schedulesURL`, `eventsURL`, `markerDirectoryURL` providers.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: ScheduleRepository — protocol body + ScheduleRepositoryImpl + 5 tests + mock impl</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/Repository/SessionRepository.swift (analogue — copy init/atomic-write/publisher shape; swap `activeSubject` for `schedulesSubject`, no history distinction — we have `schedules` + `events`)
    - DeluluDetoxTests/Features/Session/SessionRepositoryTests.swift (analogue — URL-provider test seam, typed publisher helpers to avoid `T??` ambiguity)
    - DeluluDetoxTests/Features/Session/Mocks/MockSessionRepository.swift (analogue — CurrentValueSubject + error stubs + call counters)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift (new in Plan 01 — uses `markerURL(timestamp:)` + `markerDirectoryURL()` + `isMarkerFile(_:)`)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift (new in Plan 01 — D-02 schema)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift (new in Plan 01)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift (new in Plan 01 — empty protocol body to replace)
  </read_first>
  <behavior>
    RED → GREEN → REFACTOR (TDD):

    1. RED — Turn 5 XCTSkipIf stubs in `ScheduleRepositoryTests.swift` into real assertions. Each test constructs `ScheduleRepositoryImpl` with temp-directory URL providers and exercises:
       - `testCodableRoundTrip`: encode a Schedule with all D-02 fields, decode, XCTAssertEqual.
       - `testAtomicWriteAndReadBackViaURLProviderSeam`: construct ScheduleRepositoryImpl(schedulesURLProvider: {tmp}, ...), upsert schedule, read raw bytes from tmp URL, decode, XCTAssertEqual.
       - `testUpsertAddsNewScheduleToPublisher`: subscribe to schedulesPublisher, upsert Schedule, assert publisher emitted `[schedule]`.
       - `testAppendEventAppendsToSchedulesEventsJSON`: appendEvent twice, read events.json, decode `[ScheduleEvent]`, assert count == 2 and order preserved.
       - `testConsumeEventMarkerReturnsAllMarkersAndDeletes`: write 3 marker files with distinct unix-millis suffixes (100, 200, 50), call consumeEventMarkers, assert returned array is sorted [50, 100, 200] by timestamp AND all 3 marker files removed from disk.

       Tests compile but FAIL because protocol body is empty / impl doesn't exist.

    2. GREEN — Replace empty `protocol ScheduleRepository: Sendable {}` in `ScheduleProtocols.swift` with the methods shown in `<interfaces>`. Create `ScheduleRepository.swift` containing:
       - `enum ScheduleStoreError: Error { case scheduleNotFound; case pathsUnavailable }`
       - `final class ScheduleRepositoryImpl: ScheduleRepository, @unchecked Sendable` with:
         - `private let schedulesSubject: CurrentValueSubject<[Schedule], Never>` seeded from disk in init
         - URL-provider closures: `schedulesURLProvider`, `eventsURLProvider`, `markerDirectoryURLProvider`
         - `appVersion: String` for audit
         - Production init: reads `SchedulePaths.schedulesURL()` at startup; falls back to empty array on read failure
         - Test-seam init accepting all 4 closures
         - `schedulesPublisher` = `schedulesSubject.eraseToAnyPublisher()`
         - `upsert(_:)` — async throws: replace or append by id, write atomic, send on subject
         - `remove(id:)` — async throws: remove by id, write atomic, send on subject, throw `.scheduleNotFound` if missing
         - `loadFromDisk()` — async throws: read+decode, ignore missing file (empty array)
         - `appendEvent(_:)` — async throws: read events.json if exists (empty []) + append + atomic write. Send on an internal `eventsSubject` if added (optional — not in protocol).
         - `consumeEventMarkers()` — async throws: `FileManager.contentsOfDirectory(at: markerDir)` → filter `SchedulePaths.isMarkerFile(_:)` → parse unix-millis suffix from filename → sort ascending → for each: decode ScheduleEventMarker, APPEND to events.json via `appendEvent(ScheduleEvent(...))`, then `FileManager.removeItem(at:)`. Return the decoded markers in sorted order.

       Atomic writes: `try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])`.

       os.Logger: `Logger(subsystem: "com.kksw.DeluluDetox", category: "ScheduleRepository")`. Log schedule counts + marker counts scalar-only `.public`.

    3. Update `MockScheduleRepository.swift` — remove `#if false` if present, implement full protocol per `<interfaces>`:
       ```swift
       final class MockScheduleRepository: ScheduleRepository, @unchecked Sendable {
           let schedulesSubject = CurrentValueSubject<[Schedule], Never>([])
           var schedulesPublisher: AnyPublisher<[Schedule], Never> { schedulesSubject.eraseToAnyPublisher() }

           private(set) var upsertCallCount = 0
           private(set) var lastUpserted: Schedule?
           var upsertError: Error?
           func upsert(_ schedule: Schedule) async throws {
               upsertCallCount += 1
               lastUpserted = schedule
               if let upsertError { throw upsertError }
               var arr = schedulesSubject.value
               if let idx = arr.firstIndex(where: { $0.id == schedule.id }) { arr[idx] = schedule } else { arr.append(schedule) }
               schedulesSubject.send(arr)
           }

           private(set) var removeCallCount = 0
           var removeError: Error?
           func remove(id: UUID) async throws { removeCallCount += 1; if let removeError { throw removeError } }

           var loadFromDiskResult: [Schedule] = []
           var loadFromDiskError: Error?
           func loadFromDisk() async throws -> [Schedule] { if let loadFromDiskError { throw loadFromDiskError }; return loadFromDiskResult }

           private(set) var appendedEvents: [ScheduleEvent] = []
           var appendEventError: Error?
           func appendEvent(_ event: ScheduleEvent) async throws { if let appendEventError { throw appendEventError }; appendedEvents.append(event) }

           var consumeMarkersResult: [ScheduleEventMarker] = []
           var consumeMarkersError: Error?
           private(set) var consumeMarkersCallCount = 0
           func consumeEventMarkers() async throws -> [ScheduleEventMarker] {
               consumeMarkersCallCount += 1
               if let consumeMarkersError { throw consumeMarkersError }
               return consumeMarkersResult
           }
       }
       ```

    4. REFACTOR (if needed) — extract marker-filename-parsing into private helper if the consumeEventMarkers body is > 20 lines.

    5. Run `mcp__XcodeBuildMCP__test_sim` scoped to `DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests` — all 5 tests PASS, 0 failures, 0 skips (previously 5 skipped).

    Commit: `feat(05-02): ship ScheduleRepository + atomic JSON persistence + multi-marker consume`.
  </behavior>
  <action>
    See `<behavior>` — implement protocol body + impl class + 5 tests + complete MockScheduleRepository. Use exact identifiers:

    - Type: `final class ScheduleRepositoryImpl: ScheduleRepository, @unchecked Sendable`
    - Store name: not applicable (JSON only)
    - Logger subsystem: `"com.kksw.DeluluDetox"` category `"ScheduleRepository"`
    - App Group ID: `"group.com.kksw.DeluluDetox"` (via `SchedulePaths.appGroupIdentifier`)
    - File write options: `[.atomic, .completeFileProtectionUntilFirstUserAuthentication]`
    - Test seam: 4-closure init `(schedulesURLProvider:eventsURLProvider:markerDirectoryURLProvider:appVersion:)` all `@escaping () throws -> URL` except appVersion which is `String`
    - Test method names verbatim from Plan 01 scaffold: `testCodableRoundTrip`, `testAtomicWriteAndReadBackViaURLProviderSeam`, `testUpsertAddsNewScheduleToPublisher`, `testAppendEventAppendsToSchedulesEventsJSON`, `testConsumeEventMarkerReturnsAllMarkersAndDeletes`.
    - Parse the unix-millis suffix from filename by stripping `SchedulePaths.markerFilePrefix` and `SchedulePaths.markerFileSuffix` then `Int64(...)`. Skip filenames where parse fails (log warning, do not throw).

    Build + test via XcodeBuildMCP. Commit atomically.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests — expect 5 passed, 0 failed, 0 skipped</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` exits 0
    - `grep -c "final class ScheduleRepositoryImpl: ScheduleRepository, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` == 1
    - `grep -c "func upsert(_ schedule: Schedule) async throws" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "func consumeEventMarkers() async throws -> \[ScheduleEventMarker\]" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "enum ScheduleStoreError: Error" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` == 1
    - `grep -c "CurrentValueSubject<\[Schedule\], Never>" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` >= 1
    - `grep -c "options: \[.atomic" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` >= 1
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift` == 0 (all stubs replaced)
    - `grep -c "func testCodableRoundTrip" DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift` == 1
    - `grep -c "func testConsumeEventMarkerReturnsAllMarkersAndDeletes" DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift` == 1
    - `grep -c "^import SwiftUI" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` == 0
    - `grep -c "^import FamilyControls" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped to ScheduleRepositoryTests: 5 passed, 0 failed, 0 skipped
  </acceptance_criteria>
  <done>
    ScheduleRepository protocol has full method set. ScheduleRepositoryImpl implements all 6 methods including multi-marker consume. 5 tests pass. MockScheduleRepository complete. Committed.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: CreateOrUpdateScheduleUseCase + ConsumeScheduleEventMarkerUseCase + 7 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockCreateOrUpdateScheduleUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockConsumeScheduleEventMarkerUseCase.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/UseCase/EndSessionUseCase.swift (analogue — thin UC composing Repository ops with idempotent swallowing of a specific error type)
    - DeluluDetox/Sources/Features/Session/UseCase/FinalizeSessionFromMarkerUseCase.swift (analogue — marker-consume UC; checks marker id validity, destructive consumption)
    - DeluluDetoxTests/Features/Session/EndSessionUseCaseTests.swift (analogue — UC test pattern with MockSessionRepository + per-method call assertions)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleRepository.swift (just created — protocol methods this task's UCs call)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift (replace empty `CreateOrUpdateScheduleUseCase` + `ConsumeScheduleEventMarkerUseCase` protocol bodies)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-14 (Sync UC error handling — rollback schedule.json on sync throw; the sync UC itself is Plan 04's responsibility, Plan 02's CreateOrUpdate delegates to it)
  </read_first>
  <behavior>
    1. RED — Turn Plan 01 stubs into real assertions:

       **CreateOrUpdateScheduleUseCaseTests (3 tests):**
       - `testCreateAssignsNewUUIDAndPersists` — existing test with no `id` pre-set doesn't apply since Schedule.id is `let id: UUID` (must be provided). Reframe: construct Schedule(id: UUID(), enabled: true, ...), call UC, assert `repo.upsertCallCount == 1 && repo.lastUpserted?.id == schedule.id`.
       - `testUpdatePreservesExistingId` — construct Schedule with fixed id, upsert via UC, then call UC AGAIN with same id but different `endHour`, assert repo.lastUpserted?.id matches original.
       - `testTriggersSyncAfterUpsert` — inject MockSyncScheduleWithSystemUseCase, invoke UC, assert `sync.callCount == 1 && sync.lastCalledSchedule?.id == input.id`.

       **ConsumeScheduleEventMarkerUseCaseTests (4 tests):**
       - `testConsumeAppendsAllMarkersToEventsJSON` — MockScheduleRepository pre-populated `consumeMarkersResult = [marker1, marker2, marker3]`; call UC; assert repo.appendedEvents.count == 3, all have matching scheduleId/kind/timestamp.
       - `testConsumeDeletesMarkerFilesAfterAppending` — rely on repository's `consumeEventMarkers()` handling deletion (since repo contract says "returns markers AND deletes"); UC test asserts UC returned Int count == 3 matching mock result.
       - `testConsumeReturnsZeroWhenNoMarkers` — mock returns empty array; UC returns 0; repo.appendedEvents stays empty.
       - `testConsumeSortsMarkersByTimestampBeforeAppend` — repo returns pre-sorted array (its contract); UC preserves order and asserts `repo.appendedEvents` order matches input order.

       Tests compile but fail (UC impls don't exist).

    2. GREEN:

       Replace empty protocol bodies in `ScheduleProtocols.swift`:
       ```swift
       protocol CreateOrUpdateScheduleUseCase: Sendable {
           func callAsFunction(_ schedule: Schedule) async throws
       }
       protocol ConsumeScheduleEventMarkerUseCase: Sendable {
           @discardableResult
           func callAsFunction() async throws -> Int
       }
       ```

       Create `CreateOrUpdateScheduleUseCase.swift`:
       ```swift
       import Foundation
       import os

       final class CreateOrUpdateScheduleUseCaseImpl: CreateOrUpdateScheduleUseCase, @unchecked Sendable {
           private let repository: ScheduleRepository
           private let sync: SyncScheduleWithSystemUseCase
           private static let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "CreateOrUpdateScheduleUseCase")

           init(repository: ScheduleRepository, sync: SyncScheduleWithSystemUseCase) {
               self.repository = repository
               self.sync = sync
           }

           func callAsFunction(_ schedule: Schedule) async throws {
               try await repository.upsert(schedule)
               Self.log.info("schedule upserted id=\(schedule.id.uuidString, privacy: .public) enabled=\(schedule.enabled, privacy: .public)")
               // Sync DAS — Plan 04's SyncScheduleWithSystemUseCase handles error + rollback
               // semantics (D-14). Plan 02 just delegates.
               try await sync(schedule: schedule)
           }
       }
       ```

       Note: `SyncScheduleWithSystemUseCase` protocol is still empty from Plan 01. For Plan 02 to compile, ADD the method signature to it here (Plan 04 keeps it + fills impl):
       ```swift
       protocol SyncScheduleWithSystemUseCase: Sendable {
           func callAsFunction(schedule: Schedule) async throws
       }
       ```

       Create `ConsumeScheduleEventMarkerUseCase.swift`:
       ```swift
       import Foundation
       import os

       final class ConsumeScheduleEventMarkerUseCaseImpl: ConsumeScheduleEventMarkerUseCase, @unchecked Sendable {
           private let repository: ScheduleRepository
           private static let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "ConsumeScheduleEventMarkerUseCase")

           init(repository: ScheduleRepository) {
               self.repository = repository
           }

           @discardableResult
           func callAsFunction() async throws -> Int {
               let markers = try await repository.consumeEventMarkers()
               // Repository already deleted marker files and returned sorted list.
               // UC appends each to events.json via repository.
               for marker in markers {
                   let event = ScheduleEvent(
                       scheduleId: marker.scheduleId,
                       kind: marker.kind == .started ? .started : .ended,
                       timestamp: marker.timestamp
                   )
                   try await repository.appendEvent(event)
               }
               Self.log.info("markers consumed count=\(markers.count, privacy: .public)")
               return markers.count
           }
       }
       ```

       Update `MockCreateOrUpdateScheduleUseCase.swift` + `MockConsumeScheduleEventMarkerUseCase.swift` (remove any `#if false` wrapper, implement protocol).

       Note also: `MockSyncScheduleWithSystemUseCase.swift` must now include the method. Update it minimally:
       ```swift
       final class MockSyncScheduleWithSystemUseCase: SyncScheduleWithSystemUseCase, @unchecked Sendable {
           private(set) var callCount = 0
           private(set) var lastCalledSchedule: Schedule?
           var stubbedError: Error?
           func callAsFunction(schedule: Schedule) async throws {
               callCount += 1
               lastCalledSchedule = schedule
               if let stubbedError { throw stubbedError }
           }
       }
       ```

    3. REFACTOR — none expected, UCs are thin.

    4. Run scoped test: `mcp__XcodeBuildMCP__test_sim` filter `-only-testing:DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests -only-testing:DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests`. All 7 tests PASS.

    Commit: `feat(05-02): ship CreateOrUpdate + ConsumeEventMarker UseCases`.
  </behavior>
  <action>
    See `<behavior>`. Exact identifiers:
    - `final class CreateOrUpdateScheduleUseCaseImpl: CreateOrUpdateScheduleUseCase, @unchecked Sendable`
    - `final class ConsumeScheduleEventMarkerUseCaseImpl: ConsumeScheduleEventMarkerUseCase, @unchecked Sendable`
    - `SyncScheduleWithSystemUseCase` method: `func callAsFunction(schedule: Schedule) async throws` (keyword param for readability at call site)
    - MockSyncScheduleWithSystemUseCase gets `stubbedError: Error?` for error-injection tests (not exercised in Plan 02 tests but needed by Plan 04)
    - Logger categories: `"CreateOrUpdateScheduleUseCase"` and `"ConsumeScheduleEventMarkerUseCase"`

    Run full test suite after commit to ensure no regressions.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests -only-testing:DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests — expect 7 passed total, 0 failed</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift` exits 0
    - `grep -c "final class CreateOrUpdateScheduleUseCaseImpl: CreateOrUpdateScheduleUseCase, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift` == 1
    - `grep -c "final class ConsumeScheduleEventMarkerUseCaseImpl: ConsumeScheduleEventMarkerUseCase, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift` == 1
    - `grep -c "func callAsFunction(schedule: Schedule) async throws" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1 (SyncScheduleWithSystemUseCase signature)
    - `grep -c "try await repository.upsert" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift` == 1
    - `grep -c "try await sync(schedule:" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift` == 1
    - `grep -c "try await repository.consumeEventMarkers" DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ConsumeScheduleEventMarkerUseCase.swift` == 1
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift` == 0
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped to both test files: 7 passed, 0 failed, 0 skipped
    - Full suite still green (no regressions in Phase 1..4 tests)
  </acceptance_criteria>
  <done>
    Two UCs + their mocks + 7 tests green. Repository integration proven. Plan 04 can now wire these into DI without gaps.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| main-app / App Group disk | `schedule.json`, `schedule_events.json`, `schedule_event_marker_*.json` — sole writer is main app (D-04); DAM writes only marker files (Plan 05-05) |
| concurrent readers/writers | CurrentValueSubject is in-process; multiple Tasks may call upsert concurrently |
| untrusted marker filename | Malicious/corrupted marker filenames could cause parse failures |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-05-02-01 | Tampering | Partial write mid-crash corrupts schedule.json | mitigate | `options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]` on all writes |
| T-05-02-02 | Denial of Service | Concurrent upsert race corrupts subject state | mitigate | `ScheduleRepositoryImpl` is `@unchecked Sendable` — call sites await serialized Task contexts; CurrentValueSubject.send is thread-safe (Combine contract) |
| T-05-02-03 | Information Disclosure | os.Logger leaks schedule content (token UUIDs ok; no FamilyControls tokens in Schedule) | mitigate | Schedule contains only UUIDs + Ints + Bool; logger uses `.public` only on scalar fields |
| T-05-02-04 | Spoofing | Malformed marker filename crashes consumeEventMarkers | mitigate | Parse with `Int64(...)` — returns nil on invalid — log warning and skip, do not throw |
| T-05-02-05 | Tampering | Marker deleted between list + decode | accept | Race window microseconds; `FileManager.removeItem` in UC chain; if decode fails, log + continue (next run picks up remaining) |
| T-05-02-06 | Denial of Service | events.json grows unbounded over time | accept | Phase 6 NTF-02 consumer can compact; MVP accepts unbounded growth — 1 event ≈ 80 bytes, ~1 MB after ~12k events |
| T-05-02-07 | Repudiation | No audit of upsert failures | mitigate | `Logger.error` on each throw path in repo + UC |
</threat_model>

<verification>
1. `mcp__XcodeBuildMCP__test_sim` full suite — 0 failures, test count grew by ≥12 (5 Repo + 3 CreateOrUpdate + 4 ConsumeEventMarker), skip count dropped by ≥12.
2. `git log --oneline -2` shows exactly 2 commits from this plan.
3. `grep -rc "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift DeluludetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift` == 0 across these 3 files.
4. `grep -c "func callAsFunction(schedule: Schedule) async throws" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1.
</verification>

<success_criteria>
- ScheduleRepository fully implemented with atomic JSON persistence + multi-marker consume.
- CreateOrUpdateScheduleUseCase composes repo.upsert → sync UC in correct order.
- ConsumeScheduleEventMarkerUseCase appends + deletes in chronological order.
- 12 new tests green (5 + 3 + 4).
- MockScheduleRepository, MockSyncScheduleWithSystemUseCase, MockCreateOrUpdateScheduleUseCase, MockConsumeScheduleEventMarkerUseCase complete.
- SyncScheduleWithSystemUseCase protocol has its method signature (Plan 04 adds impl).
</success_criteria>

<output>
After completion, create `.planning/phases/05-scheduled-blocking/05-02-SUMMARY.md` listing file counts, test delta, and any deviations from Plan.
</output>
