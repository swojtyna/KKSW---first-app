---
phase: 05
plan: 03
type: execute
wave: 1
depends_on: [05-01]
files_modified:
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleShieldRepository.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleActivityMonitoringRepository.swift
autonomous: true
requirements: [SCH-02, SCH-03, SCH-04]
must_haves:
  truths:
    - "ScheduleShieldRepository writes shields to the `deluludetox.schedule` named ManagedSettingsStore, isolated from Phase 3's `deluludetox.session` (D-05) — clearing one never affects the other"
    - "ScheduleShieldRepository applyShield also sets `requireAutomaticDateAndTime=true` so clock-skew bypass is defeated even when the schedule, not a session, is active (RESEARCH §Threat Patterns clock-skew)"
    - "ScheduleActivityMonitoringRepository.startMonitoring registers 1 DAS for single-day schedules and 2 DAS (evening+morning) for cross-midnight schedules (D-03, D-13)"
    - "ScheduleActivityMonitoringRepository.stopMonitoring(scheduleId:) removes BOTH .main AND .evening AND .morning segment activities so no stale DAS persists across schedule edits (pitfall from D-14 point 1)"
    - "Schedule.buildDeviceActivitySchedules() is an extension helper producing `[(name: DeviceActivityName, schedule: DeviceActivitySchedule)]` covering single-day + cross-midnight split per RESEARCH Example 1"
    - "Shield displayed during an active schedule window is visually identical to the Phase 4 quick-session shield (same branding, same fallback design, same icon) — user-observable parity per SCH-04."
  artifacts:
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift"
      provides: "ScheduleShieldRepository protocol + LiveScheduleShieldRepository wrapping a ManagedSettingsStoreWriter (reuse Phase 4 seam) constructed with ManagedSettingsStoreNames.schedule"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift"
      provides: "ScheduleActivityMonitoringRepository protocol + impl wrapping DeviceActivityCenterRunner (reuse Phase 4 seam) with per-schedule start/stop accepting 1 or 2 segments"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift"
      provides: "extension Schedule { func buildDeviceActivitySchedules() -> [(DeviceActivityName, DeviceActivitySchedule)] } per RESEARCH Example 1"
  key_links:
    - from: "LiveScheduleShieldRepository"
      to: "ManagedSettingsStore(named: ManagedSettingsStoreNames.schedule)"
      via: "LiveManagedSettingsStoreWriter(storeName: ManagedSettingsStoreNames.schedule) from Phase 4"
      pattern: "LiveManagedSettingsStoreWriter\\(storeName: ManagedSettingsStoreNames.schedule"
    - from: "LiveScheduleActivityMonitoringRepository"
      to: "DeviceActivityCenter via DeviceActivityCenterRunner seam from Phase 4"
      via: "init(runner: DeviceActivityCenterRunner)"
      pattern: "DeviceActivityCenterRunner"
    - from: "ScheduleActivityMonitoringRepository.startMonitoring(schedule:)"
      to: "Schedule.buildDeviceActivitySchedules()"
      via: "iterate segments → runner.startMonitoring(name, during: das) for each"
      pattern: "buildDeviceActivitySchedules"
---

<objective>
Ship the two systemic-side Repositories (shield writes + DAS scheduling) that mirror Phase 4's SessionShieldRepository + SessionActivityMonitoringRepository pattern. Phase 5 does NOT duplicate the `ManagedSettingsStoreWriter` or `DeviceActivityCenterRunner` protocol seams — it **reuses them as imports** from Phase 4, passing `ManagedSettingsStoreNames.schedule` to the writer so that clearing the session store does not touch schedule shields (D-05). SCH-04 shield parity is zero-code: same named store abstraction, same ShieldConfigurationExtension from Phase 4 renders the identical branded shield.

Purpose:
- SCH-03 (schedule executes via DAM extension — apps blocked during window): the DAM extension in Plan 05-05 will call the same ManagedSettingsStore(named: "deluludetox.schedule") that this plan writes to from main-app self-heal paths. The named-store contract is the cross-process handshake.
- SCH-02 (enable/disable schedule): `stopMonitoring(scheduleId:)` must remove BOTH segment variants so a single disable removes the full schedule, not a fragment.

Output:
- `ScheduleShieldRepository` protocol body in `ScheduleProtocols.swift` (replaces empty one from Plan 01) + `LiveScheduleShieldRepository` impl.
- `ScheduleActivityMonitoringRepository` protocol body + `LiveScheduleActivityMonitoringRepository` impl.
- `Schedule+DeviceActivity.swift` extension providing `buildDeviceActivitySchedules()`.
- 10 tests turned green (4 shield + 6 monitoring).
- MockScheduleShieldRepository + MockScheduleActivityMonitoringRepository complete.
</objective>

<execution_context>
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/workflows/execute-plan.md
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/05-scheduled-blocking/05-CONTEXT.md
@.planning/phases/05-scheduled-blocking/05-RESEARCH.md
@.planning/phases/05-scheduled-blocking/05-01-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md
@DeluluDetox/Sources/Features/Session/Repository/SessionShieldRepository.swift
@DeluluDetox/Sources/Features/Session/Repository/SessionActivityMonitoringRepository.swift
@DeluluDetox/Sources/Features/AppSelection/Repository/Models/Blocklist.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift

<interfaces>
Final `ScheduleShieldRepository` protocol body (Plan 03 replaces empty):
```swift
protocol ScheduleShieldRepository: Sendable {
    /// Apply shield from blocklist selection to the schedule-named store.
    /// Also sets requireAutomaticDateAndTime=true (clock-skew bypass defense,
    /// RESEARCH §Threat Patterns). denyAppRemoval is NOT set here — schedules
    /// are user-reconfigurable by design (D-11 disable-from-next-window),
    /// so removing the app during an active schedule is an acceptable eject.
    func applyShield(for blocklist: Blocklist) async throws
    /// Clear the schedule-named store only. Session store is untouched.
    func clearShield() async
}
```

Final `ScheduleActivityMonitoringRepository` protocol body:
```swift
protocol ScheduleActivityMonitoringRepository: Sendable {
    func startMonitoring(schedule: Schedule) async throws
    func stopMonitoring(scheduleId: UUID) async
}

enum ScheduleActivityMonitoringError: Error {
    case startFailed(Error)
}
```

Phase 4 reusable seams (DO NOT duplicate — import as-is):
```swift
// From DeluluDetox/Sources/Features/Session/Repository/SessionShieldRepository.swift:
protocol ManagedSettingsStoreWriter: AnyObject, Sendable {
    func setShieldApplications(_ tokens: Set<ApplicationToken>?)
    func setShieldApplicationCategories(_ setting: ShieldSettings.ActivityCategoryPolicy<Application>?)
    func setShieldWebDomains(_ tokens: Set<WebDomainToken>?)
    func setDateAndTimeRequireAutomatic(_ value: Bool)
    func setApplicationDenyAppRemoval(_ value: Bool)
}
final class LiveManagedSettingsStoreWriter: ManagedSettingsStoreWriter, @unchecked Sendable {
    init(storeName: String = "deluludetox.session") { ... }
}

// From DeluluDetox/Sources/Features/Session/Repository/SessionActivityMonitoringRepository.swift:
protocol DeviceActivityCenterRunner: AnyObject, Sendable {
    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}
final class LiveDeviceActivityCenterRunner: DeviceActivityCenterRunner, @unchecked Sendable { ... }
```

Phase 2's Blocklist model (consumed by ScheduleShieldRepository.applyShield):
```swift
struct Blocklist: Codable, Equatable, Sendable {
    let id: UUID
    var lastSelection: FamilyActivitySelection  // .applicationTokens / .categoryTokens / .webDomainTokens
    ...
}
```
</interfaces>

<wave0_contingency>
If Plan 05-01 Task 1 recorded Wave 0 Outcome C (DAS with `repeats=true` does NOT fire on iOS 26), this plan MUST override the RESEARCH §Example 1 implementation. Replace the "single DAS with repeats=true + weekday filter in DAM" approach with:

- `startMonitoring(schedule:)` registers DAS with `repeats: false` + explicit `.year/.month/.day` DateComponents for the NEXT occurrence (same-day if before start, else next scheduled day). `SelfHealSchedulesUseCase` (Plan 04) will re-register after each `intervalDidEnd` fires — midnight re-register pattern.
- DAM handler (Plan 05-05) still uses the weekday filter (defense-in-depth).
- Tests adapt: `testStartMonitoringUsesRepeatsTruePerD13` renamed to `testStartMonitoringUsesRepeatsFalseWithNextOccurrenceComponents`; assertion becomes `das.repeats == false` and endComponents carries `.year/.month/.day`.

Check `.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` → "Wave 0 Spike Verdict" section. Proceed with happy path (`repeats=true`) ONLY if Outcome A is recorded. If B or C, pivot as described above and note the pivot in this plan's SUMMARY.
</wave0_contingency>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: ScheduleShieldRepository + protocol body + 4 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleShieldRepository.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/Repository/SessionShieldRepository.swift (analogue — MIRROR structure exactly; the only differences are: storeName = ManagedSettingsStoreNames.schedule; applyShield does NOT set denyAppRemoval=true)
    - DeluluDetoxTests/Features/Session/SessionEnforcerTests.swift (analogue — test pattern for `ManagedSettingsStoreWriter` mock; Phase 3 Plan 02 SUMMARY documents the 8-method fake writer pattern)
    - DeluluDetox/Sources/Features/AppSelection/Repository/Models/Blocklist.swift (consumed — verify `lastSelection.applicationTokens`, `.categoryTokens`, `.webDomainTokens` accessors)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift (new in Plan 01 — use `ManagedSettingsStoreNames.schedule`)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-05, §D-11 (why schedule store is separate from session; why no denyAppRemoval for schedules)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Threat Patterns (clock-skew bypass → requireAutomaticDateAndTime=true on schedule apply)
  </read_first>
  <behavior>
    1. RED — Replace XCTSkipIf stubs in ScheduleShieldRepositoryTests with real assertions:

       - `testApplyShieldWritesTokensToScheduleNamedStoreOnly` — inject a FakeManagedSettingsStoreWriter (local test class), construct LiveScheduleShieldRepository(store: fake), call `applyShield(for: Blocklist(with 2 app tokens + 1 category token + 3 web tokens))`, assert fake.applicationTokensSet == 2-item Set AND fake.applicationCategoriesPolicy is .specific with 1 token AND fake.webDomainTokensSet.count == 3.
       - `testApplyShieldWritesRequireAutomaticDateAndTime` — after applyShield, assert fake.dateAndTimeRequireAutomatic == true.
       - `testClearShieldResetsAllFacetsAndRestrictions` — call clearShield(), assert fake.applicationTokensSet == nil, fake.applicationCategoriesPolicy == nil, fake.webDomainTokensSet == nil, fake.dateAndTimeRequireAutomatic == false. NOTE: denyAppRemoval is NOT touched by schedule repo (different from session).
       - `testStoreNameIsolationFromSessionStore` — verify `LiveManagedSettingsStoreWriter(storeName: ManagedSettingsStoreNames.schedule)` is used in the production convenience init. Assertion: inspect Swift source via grep test (in-test `XCTAssertEqual(ManagedSettingsStoreNames.schedule, "deluludetox.schedule")` AND `XCTAssertNotEqual(ManagedSettingsStoreNames.schedule, ManagedSettingsStoreNames.session)`).

    2. GREEN — Replace empty protocol body in ScheduleProtocols.swift:
       ```swift
       protocol ScheduleShieldRepository: Sendable {
           func applyShield(for blocklist: Blocklist) async throws
           func clearShield() async
       }
       ```

       Create `ScheduleShieldRepository.swift` mirroring SessionShieldRepository.swift:
       ```swift
       @preconcurrency import FamilyControls
       import Foundation
       @preconcurrency import ManagedSettings
       import os

       final class LiveScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable {
           private let store: ManagedSettingsStoreWriter   // REUSE Phase 4 seam
           private static let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "ScheduleShieldRepository")

           convenience init() {
               // CRITICAL: pass schedule store name so clearing session store does NOT touch schedule shield (D-05).
               self.init(store: LiveManagedSettingsStoreWriter(storeName: ManagedSettingsStoreNames.schedule))
           }

           init(store: ManagedSettingsStoreWriter) {
               self.store = store
           }

           func applyShield(for blocklist: Blocklist) async throws {
               let selection = blocklist.lastSelection
               let appTokens = selection.applicationTokens
               store.setShieldApplications(appTokens.isEmpty ? nil : appTokens)

               let categoryTokens = selection.categoryTokens
               let categoryPolicy: ShieldSettings.ActivityCategoryPolicy<Application>? =
                   categoryTokens.isEmpty ? nil : .specific(categoryTokens)
               store.setShieldApplicationCategories(categoryPolicy)

               let webTokens = selection.webDomainTokens
               store.setShieldWebDomains(webTokens.isEmpty ? nil : webTokens)

               // Clock-skew bypass defense (RESEARCH §Threat Patterns).
               // denyAppRemoval NOT set: schedules are user-reconfigurable (D-11).
               store.setDateAndTimeRequireAutomatic(true)

               Self.log.info(
                   "schedule shield applied apps=\(appTokens.count, privacy: .public) cats=\(categoryTokens.count, privacy: .public) web=\(webTokens.count, privacy: .public)"
               )
           }

           func clearShield() async {
               store.setShieldApplications(nil)
               store.setShieldApplicationCategories(nil)
               store.setShieldWebDomains(nil)
               store.setDateAndTimeRequireAutomatic(false)
               // Do NOT touch denyAppRemoval — it was never set.
               Self.log.info("schedule shield cleared")
           }
       }
       ```

       Update MockScheduleShieldRepository:
       ```swift
       final class MockScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable {
           private(set) var applyCallCount = 0
           private(set) var lastAppliedBlocklist: Blocklist?
           var applyShieldError: Error?
           func applyShield(for blocklist: Blocklist) async throws {
               applyCallCount += 1
               lastAppliedBlocklist = blocklist
               if let applyShieldError { throw applyShieldError }
           }

           private(set) var clearCallCount = 0
           func clearShield() async { clearCallCount += 1 }
       }
       ```

    3. REFACTOR — none expected.

    4. `mcp__XcodeBuildMCP__test_sim` scoped to `ScheduleShieldRepositoryTests` — 4 tests PASS.

    Commit: `feat(05-03): ship ScheduleShieldRepository on deluludetox.schedule named store`.
  </behavior>
  <action>
    Implement per `<behavior>`. Exact identifiers:
    - `final class LiveScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable`
    - Convenience init: `self.init(store: LiveManagedSettingsStoreWriter(storeName: ManagedSettingsStoreNames.schedule))`
    - Logger category: `"ScheduleShieldRepository"`
    - `applyShield` sets `requireAutomaticDateAndTime=true`; does NOT touch `denyAppRemoval`
    - `clearShield` resets 3 shield facets + `requireAutomaticDateAndTime=false`; does NOT touch `denyAppRemoval`

    FakeManagedSettingsStoreWriter for tests: define it inline in `ScheduleShieldRepositoryTests.swift` or reuse one from Phase 3 tests (inspect `DeluluDetoxTests/Features/Session/SessionEnforcerTests.swift` for exact shape).
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests — expect 4 passed, 0 failed</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` exits 0
    - `grep -c "final class LiveScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` == 1
    - `grep -c "LiveManagedSettingsStoreWriter(storeName: ManagedSettingsStoreNames.schedule)" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` == 1
    - `grep -c "setDateAndTimeRequireAutomatic(true)" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` == 1
    - `grep -c "setApplicationDenyAppRemoval" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` == 0 (NOT touched in Plan 03)
    - `grep -c "protocol ScheduleShieldRepository: Sendable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "func applyShield(for blocklist: Blocklist) async throws" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped to ScheduleShieldRepositoryTests: 4 passed, 0 failed, 0 skipped
  </acceptance_criteria>
  <done>
    LiveScheduleShieldRepository implemented on separate named store. 4 tests green. Mock complete. Committed.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: ScheduleActivityMonitoringRepository + Schedule+DeviceActivity extension + 6 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleActivityMonitoringRepository.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/Repository/SessionActivityMonitoringRepository.swift (analogue — copy structure, protocol seam reuse; note the inline cross-midnight comment lines 68-77)
    - DeluluDetoxTests/Features/Session/SessionEnforcerTests.swift §testStartActivityMonitoring* (analogue — FakeDeviceActivityCenterRunner pattern)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift (consumes — uses `schedule.crossesMidnight`, startHour/Minute, endHour/Minute)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift (uses `activityName(scheduleId:segment:)`)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift (enum cases: .main, .evening, .morning)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Example 1 (canonical buildDeviceActivitySchedules impl)
    - .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md §Wave 0 Spike Verdict (decides repeats=true vs the Outcome-C fallback path)
  </read_first>
  <behavior>
    1. RED — Replace XCTSkipIf stubs in ScheduleActivityMonitoringRepositoryTests with real assertions. Use a `FakeDeviceActivityCenterRunner` (local test class) that captures `startMonitoring` invocations as `(name, schedule)` pairs and `stopMonitoring` as array of names. Tests:

       - `testStartMonitoringSingleDayUsesMainSegmentAndOneDAS` — schedule startHour=9, startMinute=0, endHour=17, endMinute=0 (single-day). After startMonitoring: fake.startedActivities.count == 1, fake.startedActivities[0].0.rawValue.hasSuffix(".main"), fake.startedActivities[0].1.repeats == true, startComponents hour==9 minute==0, endComponents hour==17 minute==0.
       - `testStartMonitoringCrossMidnightSplitsIntoEveningAndMorningTwoDAS` — schedule startHour=22, endHour=6 (cross-midnight, since endMin 360 <= startMin 1320). After startMonitoring: fake.startedActivities.count == 2. Find `.evening` entry: startH=22 startM=0 endH=23 endM=59 (second=59). Find `.morning` entry: startH=0 startM=0 endH=6 endM=0.
       - `testStartMonitoringUsesRepeatsTruePerD13` — assertion depends on Wave 0 Outcome. If Outcome A (most likely): `XCTAssertTrue(das.repeats)`. If Outcome B/C: test renamed to `testStartMonitoringUsesRepeatsFalseWithNextOccurrenceComponents` and assertion becomes `XCTAssertFalse(das.repeats) && das.intervalEnd.year != nil`.
       - `testStopMonitoringRemovesAllSegmentsForScheduleId` — call startMonitoring(cross-midnight schedule) then stopMonitoring(scheduleId: schedule.id). Assert fake.stoppedActivities contains exactly 3 names: `"deluludetox.schedule.{uuid}.main"` AND `"...evening"` AND `"...morning"` (all three variants are passed defensively, iOS ignores names not registered).
       - `testStartMonitoringWrapsCenterErrorInRepositoryError` — fake.startMonitoringError = NSError(domain:"test", code:42). Call startMonitoring; XCTAssertThrowsError with check that thrown error is `ScheduleActivityMonitoringError.startFailed(let underlying)` where underlying is the injected NSError.
       - `testSegmentHelperBuildDeviceActivitySchedulesRoundTrip` — pure helper test: `schedule.buildDeviceActivitySchedules()` returns pairs whose `.0` (DeviceActivityName) round-trips through `ScheduleActivityNames.parse(_:)` to yield the same `(scheduleId, segment)`.

    2. GREEN:

       Replace empty protocol bodies in ScheduleProtocols.swift:
       ```swift
       protocol ScheduleActivityMonitoringRepository: Sendable {
           func startMonitoring(schedule: Schedule) async throws
           func stopMonitoring(scheduleId: UUID) async
       }

       enum ScheduleActivityMonitoringError: Error {
           case startFailed(Error)
       }
       ```

       Create `Schedule+DeviceActivity.swift`:
       ```swift
       @preconcurrency import DeviceActivity
       import Foundation

       extension Schedule {
           /// Returns 1 (single-day) or 2 (cross-midnight) pairs for DAS registration.
           /// CONTEXT §D-03, §D-13 + RESEARCH Example 1.
           func buildDeviceActivitySchedules() -> [(name: DeviceActivityName, schedule: DeviceActivitySchedule)] {
               if !crossesMidnight {
                   let name = ScheduleActivityNames.activityName(scheduleId: id, segment: .main)
                   let das = DeviceActivitySchedule(
                       intervalStart: DateComponents(hour: startHour, minute: startMinute),
                       intervalEnd: DateComponents(hour: endHour, minute: endMinute, second: 0),
                       repeats: true    // Wave 0 Outcome A path; B/C pivot replaces this block
                   )
                   return [(name, das)]
               }

               // Cross-midnight split (D-03).
               let evening = (
                   ScheduleActivityNames.activityName(scheduleId: id, segment: .evening),
                   DeviceActivitySchedule(
                       intervalStart: DateComponents(hour: startHour, minute: startMinute),
                       intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
                       repeats: true
                   )
               )
               let morning = (
                   ScheduleActivityNames.activityName(scheduleId: id, segment: .morning),
                   DeviceActivitySchedule(
                       intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
                       intervalEnd: DateComponents(hour: endHour, minute: endMinute, second: 0),
                       repeats: true
                   )
               )
               return [evening, morning]
           }
       }
       ```

       Create `ScheduleActivityMonitoringRepository.swift`:
       ```swift
       @preconcurrency import DeviceActivity
       import Foundation
       import os

       final class LiveScheduleActivityMonitoringRepository: ScheduleActivityMonitoringRepository, @unchecked Sendable {
           private let runner: DeviceActivityCenterRunner   // REUSE Phase 4 seam
           private static let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "ScheduleActivityMonitoring")

           convenience init() {
               self.init(runner: LiveDeviceActivityCenterRunner())
           }

           init(runner: DeviceActivityCenterRunner) {
               self.runner = runner
           }

           func startMonitoring(schedule: Schedule) async throws {
               let pairs = schedule.buildDeviceActivitySchedules()
               for (name, das) in pairs {
                   do {
                       try runner.startMonitoring(name, during: das)
                       Self.log.info("schedule monitoring started name=\(name.rawValue, privacy: .public)")
                   } catch {
                       Self.log.error("startMonitoring failed name=\(name.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
                       throw ScheduleActivityMonitoringError.startFailed(error)
                   }
               }
           }

           func stopMonitoring(scheduleId: UUID) async {
               // Pass all three segment variants — iOS stopMonitoring ignores unknowns.
               // This ensures no stale segment remains after schedule edits.
               let names = [ScheduleSegment.main, .evening, .morning].map {
                   ScheduleActivityNames.activityName(scheduleId: scheduleId, segment: $0)
               }
               runner.stopMonitoring(names)
               Self.log.info("schedule monitoring stopped id=\(scheduleId.uuidString, privacy: .public)")
           }
       }
       ```

       Update MockScheduleActivityMonitoringRepository to implement full protocol:
       ```swift
       final class MockScheduleActivityMonitoringRepository: ScheduleActivityMonitoringRepository, @unchecked Sendable {
           private(set) var startMonitoringCallCount = 0
           private(set) var lastStartedSchedule: Schedule?
           var startMonitoringError: Error?
           func startMonitoring(schedule: Schedule) async throws {
               startMonitoringCallCount += 1
               lastStartedSchedule = schedule
               if let startMonitoringError { throw startMonitoringError }
           }

           private(set) var stopMonitoringCallCount = 0
           private(set) var stoppedScheduleIds: [UUID] = []
           func stopMonitoring(scheduleId: UUID) async {
               stopMonitoringCallCount += 1
               stoppedScheduleIds.append(scheduleId)
           }
       }
       ```

    3. REFACTOR — extract `DeviceActivitySchedule` construction if duplicated (it is — evening+morning share pattern). Could add a private `makeDAS(startH:startM:endH:endM:second:)` helper. Optional.

    4. `mcp__XcodeBuildMCP__test_sim` scoped to ScheduleActivityMonitoringRepositoryTests — 6 tests PASS.

    Commit: `feat(05-03): ship ScheduleActivityMonitoringRepository + cross-midnight DAS split helper`.
  </behavior>
  <action>
    Implement per `<behavior>`. Exact identifiers:
    - `final class LiveScheduleActivityMonitoringRepository: ScheduleActivityMonitoringRepository, @unchecked Sendable`
    - `init(runner: DeviceActivityCenterRunner)` + `convenience init()` using `LiveDeviceActivityCenterRunner()` (Phase 4 reuse)
    - Logger category: `"ScheduleActivityMonitoring"`
    - Error case: `ScheduleActivityMonitoringError.startFailed(Error)` — matches RESEARCH §Pattern 1 naming
    - `buildDeviceActivitySchedules()` extension method signature verbatim from RESEARCH Example 1
    - `stopMonitoring(scheduleId:)` passes ALL THREE segment variants as a defensive clear

    **Wave 0 Outcome gate:** BEFORE implementing, `grep` the DISCUSSION-LOG for "Outcome A" / "Outcome B" / "Outcome C". If A → proceed with `repeats: true` as shown. If B/C → add comment `// PIVOT from Wave 0 Outcome {B,C}: see DISCUSSION-LOG YYYY-MM-DD` and switch to `repeats: false` + full `.year/.month/.day` DateComponents; update test `testStartMonitoringUsesRepeatsTruePerD13` to new name/assertion.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests — expect 6 passed, 0 failed</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift` exits 0
    - `grep -c "final class LiveScheduleActivityMonitoringRepository: ScheduleActivityMonitoringRepository, @unchecked Sendable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift` == 1
    - `grep -c "enum ScheduleActivityMonitoringError" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "case startFailed(Error)" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "func buildDeviceActivitySchedules" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift` == 1
    - `grep -c "ScheduleActivityNames.activityName(scheduleId:" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift` >= 3 (main + evening + morning calls)
    - `grep -c "ScheduleSegment.main, .evening, .morning" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleActivityMonitoringRepository.swift` == 1
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped to ScheduleActivityMonitoringRepositoryTests: 6 passed, 0 failed, 0 skipped
    - Full suite still green (no regression)
  </acceptance_criteria>
  <done>
    LiveScheduleActivityMonitoringRepository + buildDeviceActivitySchedules extension + 6 tests green. Mock complete. Wave 0 Outcome honored. Committed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| main-app / iOS ManagedSettings system service | Writes to named store cross-process-visible to iOS; schedule store literal is the contract |
| main-app / iOS DeviceActivityCenter | 20-activity budget; wrong DAS name sticking around leaks budget |
| main-app / Phase 4 shared seams | `ManagedSettingsStoreWriter` / `DeviceActivityCenterRunner` are shared Swift types — refactor in Phase 4 could break Phase 5 |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-05-03-01 | Tampering | Schedule store literal drifts from session store literal | mitigate | `ManagedSettingsStoreNames.schedule` constant defined in Plan 01 file; `grep` acceptance check ensures no bare `"deluludetox.schedule"` literal elsewhere |
| T-05-03-02 | Tampering | Clock-skew bypass defeats schedule | mitigate | `applyShield` sets `requireAutomaticDateAndTime = true` (see acceptance); user must have automatic date/time on |
| T-05-03-03 | Denial of Service | Orphan DAS consumes 20-activity budget | mitigate | `stopMonitoring(scheduleId:)` passes all three segment names; `SyncScheduleWithSystemUseCase` (Plan 04) is responsible for stop-before-start ordering on schedule edits |
| T-05-03-04 | Information Disclosure | Logging reveals FamilyActivitySelection tokens | mitigate | Logger logs only `.count` of token sets, never the tokens themselves — same pattern as Phase 3 SessionEnforcer |
| T-05-03-05 | Elevation of Privilege | denyAppRemoval during schedule prevents user from quitting | accept (not applied) | `applyShield` deliberately does NOT set denyAppRemoval (D-11 schedules are user-reconfigurable; the friction would contradict the design intent) |
| T-05-03-06 | Spoofing | Segment name collision between two schedules with equal UUIDs | accept | UUIDs are cryptographically unique; collision probability nil |
| T-05-03-07 | Denial of Service | startMonitoring partially succeeds then throws mid-segment (evening registered, morning throws) | mitigate | On catch, Plan 04's `SyncScheduleWithSystemUseCase` calls `stopMonitoring(scheduleId:)` as rollback (which clears ALL segment variants defensively) |
</threat_model>

<verification>
1. `mcp__XcodeBuildMCP__test_sim` full suite — 0 failures, test count grew by 10 (4 shield + 6 monitoring).
2. `git log --oneline -2` shows 2 commits from this plan.
3. `grep -c "ManagedSettingsStoreNames.schedule" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` == 1.
4. `grep -c "repeats: true" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule+DeviceActivity.swift` == 3 (main + evening + morning) IF Wave 0 Outcome A; else 0 with `repeats: false` matching count.
5. `grep -c "denyAppRemoval" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleShieldRepository.swift` == 0 (intentionally absent).
</verification>

<success_criteria>
- ScheduleShieldRepository writes to `deluludetox.schedule` named store, isolated from session store.
- ScheduleActivityMonitoringRepository registers 1 or 2 DAS per schedule; stops all 3 defensive segment names on disable.
- Schedule+DeviceActivity extension's `buildDeviceActivitySchedules` round-trips through `ScheduleActivityNames.parse`.
- 10 tests green.
- MockScheduleShieldRepository + MockScheduleActivityMonitoringRepository implement full protocols.
- Wave 0 Outcome A/B/C pivot applied if B/C.
- SCH-04 delivered by zero code (Phase 4 ShieldConfigurationExtension automatically renders same shield for this new named store).
</success_criteria>

<output>
After completion, create `.planning/phases/05-scheduled-blocking/05-03-SUMMARY.md` — list Wave 0 Outcome honored, whether `repeats=true` path was taken or pivot applied, any segment-ordering corner cases discovered.
</output>
