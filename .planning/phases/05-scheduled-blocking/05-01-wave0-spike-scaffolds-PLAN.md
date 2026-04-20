---
phase: 05
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - project.yml
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift
  - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift
  - DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift
  - DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleShieldRepository.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleActivityMonitoringRepository.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockComputeScheduleWindowUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockObserveScheduleUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockSyncScheduleWithSystemUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockCreateOrUpdateScheduleUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockToggleScheduleUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockSelfHealSchedulesUseCase.swift
  - DeluluDetoxTests/Features/Scheduling/Mocks/MockConsumeScheduleEventMarkerUseCase.swift
autonomous: false
requirements: [SCH-01, SCH-02, SCH-03, SCH-04]
must_haves:
  truths:
    - "Spike verdict on iOS 26+ real device tells downstream plans whether repeats=true DAS is reliable or whether fallback (non-repeating + re-register per midnight) is required"
    - "Every downstream plan has concrete XCTest scaffolds (XCTSkipIf stubs) targeting Scheduling/* — no MISSING automated verify placeholders"
    - "Feature directory skeleton exists under DeluluDetox/Sources/Features/Scheduling/ so plans 2/3/4/5/6/7 can add files without structural churn"
    - "project.yml source-shares Scheduling App-Group files (Schedule/SchedulePaths/ScheduleActivityNames/ScheduleEventMarker) into DeviceActivityMonitorExtension — DAM can decode Schedule without pulling SwiftUI/Combine"
    - "SchedulingInjection skeleton is registered in DeluluDetoxApp.init() between SessionInjection and DenialInjection — placeholder body, production registrations added by Plan 4"
  artifacts:
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift"
      provides: "Schedule Codable struct per D-02 (id, name, daysOfWeek, startHour/Minute, endHour/Minute, enabled, blocklistId, appVersion)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift"
      provides: "enum ScheduleSegment { case main; case evening; case morning } — cross-midnight split helper (D-03/D-13)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift"
      provides: "Namespaced helpers: activityName(scheduleId:segment:) → DeviceActivityName; parseScheduleActivityName(_:) → (UUID, ScheduleSegment)?"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift"
      provides: "App Group URL helpers (schedule.json, schedule_events.json, schedule_event_marker_{ts}.json)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift"
      provides: "Append-only history row Codable struct (scheduleId, kind: started/ended, timestamp)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift"
      provides: "DAM-written marker file Codable struct (scheduleId, kind, timestamp)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift"
      provides: "enum ManagedSettingsStoreNames { static let session; static let schedule } — literal-string isolation (pitfall 6)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift"
      provides: "SchedulingInjection skeleton with empty register(in:) body — Plan 4 fills in repositories + UCs"
    - path: "DeluluDetoxTests/Features/Scheduling/Mocks/"
      provides: "10 mock files with @unchecked Sendable + call counters + error stubs — Plan 4/6/7 tests inject"
    - path: "DeluluDetoxTests/Features/Scheduling/"
      provides: "11 XCTest files (1 per repo, 1 per UC, 1 per VM) — each contains XCTSkipIf(true, ...) stubs referencing the exact assertion downstream plans must land"
  key_links:
    - from: "project.yml DeviceActivityMonitorExtension.sources"
      to: "DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/*.swift"
      via: "4 explicit path entries (Schedule.swift, SchedulePaths.swift, ScheduleActivityNames.swift, ScheduleEventMarker.swift)"
      pattern: "Features/Scheduling/Common/Repository/Models/Schedule"
    - from: "DeluluDetox/Sources/App/DeluluDetoxApp.swift"
      to: "SchedulingInjection.register(in: container)"
      via: "insert between SessionInjection.register and DenialInjection.register"
      pattern: "SchedulingInjection.register"
    - from: ".planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md"
      to: "Wave 0 spike verdict (Outcome A / B / C)"
      via: "appended by Task 1 human-checkpoint"
      pattern: "Wave 0 spike"
---

<objective>
Wave 0 gating plan: (1) verify on a physical iOS 26+ device that `DeviceActivitySchedule(repeats: true)` with `DateComponents(hour:minute:)` fires `intervalDidStart` reliably at the scheduled time (RESEARCH Open Question #1, assumption A1); (2) lay down the complete Scheduling feature scaffold (models, paths, DI skeleton, test files, mocks) so Plans 02..07 add code instead of inventing structure; (3) confirm spike verdict in `05-DISCUSSION-LOG.md` so Plan 02+ knows whether to implement `repeats=true` (happy path) or fall back to daily re-register.

Purpose: the entire Phase 5 architecture (single repeating DAS + weekday filter in DAM) is predicated on A1. A silent-fail on real device would waste Plans 02..07 execution. The scaffold half is pure mechanical prep so downstream plans have concrete `<automated>` commands and a canonical feature-tree layout (mirror of Features/Session/).

Output:
- Signed-off spike verdict (Outcome A = fires reliably → proceed; Outcome B = fires but wrong time → Plan 03 switches DAM filter strategy; Outcome C = does not fire → Plan 02+ pivots to non-repeating DAS + daily re-register via midnight self-heal) in `05-DISCUSSION-LOG.md`.
- 7 new source files (Scheduling/Common/Repository/Models + Injection skeleton) committed.
- 11 new XCTest files + 10 mocks under `DeluluDetoxTests/Features/Scheduling/` committed (all XCTSkipIf(true, ...) stubs — test suite stays green).
- `project.yml` source-shares 4 App-Group files into DAM extension.
- `DeluluDetoxApp.init()` calls `SchedulingInjection.register(in: container)` (body is empty for now).
</objective>

<execution_context>
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/workflows/execute-plan.md
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/STATE.md
@.planning/phases/05-scheduled-blocking/05-CONTEXT.md
@.planning/phases/05-scheduled-blocking/05-RESEARCH.md
@.planning/phases/05-scheduled-blocking/05-VALIDATION.md
@.planning/phases/03-quick-sessions/03-01-SUMMARY.md
@.planning/phases/03-quick-sessions/03-04-SUMMARY.md
@.planning/phases/04-shield-customization/04-01-SUMMARY.md
@DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
@DeluluDetox/Sources/Features/Session/Repository/Models/SessionActivityNames.swift
@DeluluDetox/Sources/Features/Session/Repository/Models/SessionFinalizeMarker.swift
@DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift
@DeluluDetox/Sources/App/DeluluDetoxApp.swift
@project.yml

<interfaces>
<!-- Types downstream plans will consume. Extracted from Phase 3 + CONTEXT/RESEARCH. -->

From DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift (analogue for SchedulePaths):
```swift
enum SessionPaths {
    static let appGroupIdentifier = "group.com.kksw.DeluluDetox"
    enum PathError: Error { case containerUnavailable }
    private static func containerURL() throws -> URL { ... }
    static func activeSessionURL() throws -> URL { ... }
    static func finalizeMarkerURL() throws -> URL { ... }
}
```

From CONTEXT.md D-02 (Schedule schema — exact fields):
```swift
struct Schedule: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String?         // nil in MVP (D-02)
    var daysOfWeek: [Int]     // Calendar.weekday values: 1=Sun..7=Sat (pitfall 7)
    var startHour: Int        // 0..23
    var startMinute: Int      // 0..59
    var endHour: Int          // 0..23
    var endMinute: Int        // 0..59
    var enabled: Bool
    var blocklistId: UUID     // FK → Phase 2 Blocklist.id
    var appVersion: String
}
```

From RESEARCH Open Question #4 resolution (orchestrator additional_constraints #1 — marker overwrite fix):
- `schedule_event_marker.json` (single-file overwrite) is INSUFFICIENT for cross-midnight where two segments fire without a foreground between them (evening @22:00 → morning @00:00, no scenePhase.active in between → second write overwrites first → first event lost).
- Use timestamp-suffixed marker files: `schedule_event_marker_{unix_millis}.json`. `SchedulePaths.markerDirectoryURL()` returns the App Group container directory; main-app lists all files matching `schedule_event_marker_*.json`, sorts by the unix-millis suffix, consumes (deletes) after appending each to `schedule_events.json`.

From DAS naming convention (D-13 / RESEARCH Example 1):
- Single-day: `"deluludetox.schedule.{uuidString}.main"`
- Cross-midnight: `"deluludetox.schedule.{uuidString}.evening"` + `"deluludetox.schedule.{uuidString}.morning"`
- Prefix: `"deluludetox.schedule."` (used by DAM `hasPrefix` gate)

From Phase 4 split precedent (three-repo pattern):
- `Features/Session/Repository/` contains: `SessionRepository.swift` (JSON), `SessionShieldRepository.swift` (ManagedSettings), `SessionActivityMonitoringRepository.swift` (DeviceActivityCenter).
- Phase 5 mirrors: `Features/Scheduling/Common/Repository/` with: `ScheduleRepository.swift`, `ScheduleShieldRepository.swift`, `ScheduleActivityMonitoringRepository.swift`.
- Reuse existing test seams `ManagedSettingsStoreWriter` (defined in `SessionShieldRepository.swift`) and `DeviceActivityCenterRunner` (defined in `SessionActivityMonitoringRepository.swift`) — Plan 03 constructs `LiveManagedSettingsStoreWriter(storeName: ManagedSettingsStoreNames.schedule)`.
</interfaces>

<spike_instrumentation>
<!-- Task 1 physical-device spike instrumentation — temporary code, reverted after spike. -->

Spike contract (appended verbatim to `05-DISCUSSION-LOG.md` with Outcome):

1. Pick a time 10 minutes in the future (e.g. if device clock shows 14:35, pick 14:45).
2. Register a single test DAS: name `"deluludetox.spike.wave0"`, schedule `DeviceActivitySchedule(intervalStart: DateComponents(hour: 14, minute: 45), intervalEnd: DateComponents(hour: 14, minute: 46), repeats: true)`.
3. In DAM extension `intervalDidStart(for:)`, log a distinctive string `"[WAVE0-SPIKE] fired at \(Date()) for \(activity.rawValue)"` via `os.Logger` with `.public` privacy.
4. Attach device to Mac, open Console.app filtered to subsystem `com.kksw.DeluluDetox.DeviceActivityMonitorExtension`.
5. At 14:45 + 5min buffer, record:
   - **Outcome A:** `[WAVE0-SPIKE] fired at 14:45:0X` observed → iOS 26 honors `repeats=true` with only hour/minute. Proceed with CONTEXT plan as-is.
   - **Outcome B:** Fired but at wrong time (e.g. 00:00 next day) → iOS 26 interprets DateComponents differently. Plan 03 must include `.year/.month/.day` in `DeviceActivitySchedule` components + accept that the DAS is effectively non-repeating (Plan 04 `SyncScheduleWithSystemUseCase` must re-register on midnight via `SelfHealSchedulesUseCase`).
   - **Outcome C:** No log line within 5 minutes → DAS does not fire on repeats=true on iOS 26. Plan 02+ pivots to non-repeating DAS + daily re-register via midnight self-heal (reuses Phase 3 pattern).

After the spike: revert all spike-only edits (the DAS registration code + the Console log line + the project.yml entry if any). DO NOT commit spike code. Only the DISCUSSION-LOG append is committed.
</spike_instrumentation>
</context>

<tasks>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 1: Wave 0 spike — verify iOS 26 DeviceActivitySchedule(repeats:true) on physical device</name>
  <what-built>
    This is a pre-build verification step. No production code is committed from this task. The human installs a temporary spike (5-line edit to `DeviceActivityMonitorExtension.swift` adding a `.public` log line + a throwaway call to `DeviceActivityCenter.startMonitoring(...)` with a test DAS), runs it on a physical iOS 26+ device with Family Controls authorized, observes Console.app, and records the outcome.
  </what-built>
  <how-to-verify>
    Execute the `<spike_instrumentation>` block in `<context>` verbatim. You MUST:
    1. On a physical iOS 26.0+ device with Family Controls entitlement approved and Phase 1 onboarding completed, install the app with the spike code temporarily added to `intervalDidStart(for:)` in `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`.
    2. Register a one-off test DAS from the main app (any debug screen or `DeluluDetoxApp.init()` temporary call) with `DeviceActivityCenter().startMonitoring(DeviceActivityName("deluludetox.spike.wave0"), during: DeviceActivitySchedule(intervalStart: DateComponents(hour: <pick hour>, minute: <pick minute 10 min from now>), intervalEnd: DateComponents(hour: <pick hour>, minute: <pick minute + 1>), repeats: true))`.
    3. Wait until the scheduled time + 5-minute buffer, open Console.app filtered by subsystem `com.kksw.DeluluDetox.DeviceActivityMonitorExtension`.
    4. Record Outcome A / B / C per `<spike_instrumentation>`.
    5. Append a markdown section to `.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` titled `## Wave 0 Spike Verdict (YYYY-MM-DD)` with: device model, iOS version, start time registered, observed fire time, log line screenshot/paste, Outcome letter, and implications for Plan 02+.
    6. Revert all spike-only changes (DAM extension log line, main-app test DAS registration). Confirm `git status` shows only the `05-DISCUSSION-LOG.md` edit before proceeding.
  </how-to-verify>
  <files>.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md</files>
  <action>
    This is a human-action checkpoint — the human performs the spike per the `<how-to-verify>` block on a physical iOS 26+ device and records the outcome in `05-DISCUSSION-LOG.md`. The executor agent MUST NOT attempt to automate the spike (simulator cannot reliably reproduce DAS callback behavior). If no physical device is available, MARK this task as BLOCKED in `.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` with rationale "physical device unavailable this session" and STOP — the phase cannot proceed until the spike outcome is recorded.
  </action>
  <verify>
    <automated>grep -c "## Wave 0 Spike Verdict" .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md</automated>
  </verify>
  <read_first>
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Open Questions #1 and §Assumptions Log A1 (the risk this spike retires)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-13 (the architectural decision this spike validates)
    - .planning/phases/04-shield-customization/04-01-SUMMARY.md §Task 1 Physical-device spike (BLOCKED — awaiting device) — same human-action checkpoint pattern, same revert discipline
    - Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift (the file receiving the temporary spike instrumentation)
  </read_first>
  <acceptance_criteria>
    - `grep -c "## Wave 0 Spike Verdict" .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` >= 1
    - The verdict section contains exactly one of the tokens "Outcome A" / "Outcome B" / "Outcome C"
    - `git diff --name-only` shows only `.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` at the end of the task (no leftover spike code in `Extensions/` or `DeluluDetox/Sources/`)
    - The verdict section lists device model + iOS version (non-empty lines beginning "Device:" and "iOS:")
    - If Outcome is B or C, the verdict section contains an "Implication for Plan 02+:" paragraph describing the required plan pivot (non-repeating DAS + midnight re-register, or .year/.month/.day components)
  </acceptance_criteria>
  <resume-signal>
    Type "Outcome A" / "Outcome B" / "Outcome C" + one-line note (e.g. "Outcome A — fired at 14:45:02 on iPhone 14 Pro iOS 26.2"). The planner-next step (Plan 02 authoring) uses this to lock `repeats=true` or switch to the re-register fallback.
  </resume-signal>
  <done>
    Verdict recorded in `05-DISCUSSION-LOG.md`. Spike code fully reverted from working tree. Human has selected one of A/B/C. If Outcome C, an orchestrator note is added (by the user or the planner) that Plan 03's `ScheduleActivityMonitoringRepository.startMonitoring` will use `repeats: false` + `.year/.month/.day` + daily midnight re-register instead of `repeats: true`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Scheduling feature scaffold — models, paths, DI skeleton, project.yml source-shares</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift,
    DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift,
    DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift,
    DeluluDetox/Sources/App/DeluluDetoxApp.swift,
    project.yml
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift (analogue — mirror structure, swap `active_session.json` for `schedule.json`, `finalize_marker` for `event_marker`)
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionActivityNames.swift (analogue — single-activity `DeviceActivityName` constant; Scheduling extends with prefix + parser helpers)
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionFinalizeMarker.swift (analogue — DAM-written marker Codable struct)
    - DeluluDetox/Sources/Features/Session/Injection/SessionInjection.swift (analogue — `enum SchedulingInjection { static func register(in:) }` stub)
    - DeluluDetox/Sources/App/DeluluDetoxApp.swift (modify — insert `SchedulingInjection.register(in: container)` after `SessionInjection.register`)
    - project.yml (lines 92-116 = DeviceActivityMonitorExtension target source-shares — mirror 4 new entries)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-02 (Schedule schema — exact field list)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Example 1 (ScheduleActivityNames parser) and §Pitfall 6 (ManagedSettingsStoreNames)
  </read_first>
  <action>
    Create 7 source files + modify `DeluluDetoxApp.swift` + modify `project.yml`. Exact bodies:

    **1. `Schedule.swift`** (Features/Scheduling/Common/Repository/Models/):
    ```swift
    import Foundation

    /// Persisted schedule record (CONTEXT §D-01, D-02). Stored in `schedule.json`
    /// as an array of `Schedule` (schema supports N; MVP surfaces first).
    /// `daysOfWeek` uses Calendar.weekday values (1=Sunday..7=Saturday) —
    /// UI layer maps display order (Pn..Nd) to these values, never vice versa.
    struct Schedule: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        var name: String?
        var daysOfWeek: [Int]          // Calendar.weekday (1=Sun..7=Sat)
        var startHour: Int             // 0..23
        var startMinute: Int           // 0..59
        var endHour: Int               // 0..23
        var endMinute: Int             // 0..59
        var enabled: Bool
        var blocklistId: UUID
        var appVersion: String

        /// True iff `(endHour, endMinute) <= (startHour, startMinute)` — schedule wraps past midnight (D-03).
        var crossesMidnight: Bool {
            let startMin = startHour * 60 + startMinute
            let endMin = endHour * 60 + endMinute
            return endMin <= startMin
        }
    }
    ```

    **2. `ScheduleSegment.swift`**:
    ```swift
    import Foundation

    /// Cross-midnight split marker (CONTEXT §D-03, D-13). Single-day schedules
    /// use `.main`; cross-midnight schedules register TWO DAS — `.evening`
    /// (intervalStart → 23:59:59) and `.morning` (00:00:00 → intervalEnd).
    enum ScheduleSegment: String, Codable, Equatable, Sendable {
        case main
        case evening
        case morning
    }
    ```

    **3. `ScheduleActivityNames.swift`** (extension-safe — imports DeviceActivity only):
    ```swift
    @preconcurrency import DeviceActivity
    import Foundation

    /// DeviceActivity name namespace for Phase 5 schedules.
    /// Format: `"deluludetox.schedule.{uuidString}.{segment.rawValue}"`.
    enum ScheduleActivityNames {
        static let prefix = "deluludetox.schedule."

        static func activityName(scheduleId: UUID, segment: ScheduleSegment) -> DeviceActivityName {
            DeviceActivityName("\(prefix)\(scheduleId.uuidString).\(segment.rawValue)")
        }

        /// Returns nil if the activity name is not a Scheduling activity.
        static func parse(_ name: DeviceActivityName) -> (scheduleId: UUID, segment: ScheduleSegment)? {
            let raw = name.rawValue
            guard raw.hasPrefix(prefix) else { return nil }
            let parts = raw.split(separator: ".")
            // Expected: ["deluludetox", "schedule", "{uuid}", "{segment}"]
            guard parts.count == 4 else { return nil }
            guard let scheduleId = UUID(uuidString: String(parts[2])) else { return nil }
            guard let segment = ScheduleSegment(rawValue: String(parts[3])) else { return nil }
            return (scheduleId, segment)
        }
    }
    ```

    **4. `SchedulePaths.swift`** (mirror SessionPaths with marker-directory pattern for timestamp-suffixed markers — RESEARCH Open Question #4 resolution):
    ```swift
    import Foundation

    /// App Group file URL helpers shared with DeviceActivityMonitor extension
    /// (CONTEXT §D-04, §D-17 — marker overwrite fix from RESEARCH OQ#4).
    enum SchedulePaths {
        static let appGroupIdentifier = "group.com.kksw.DeluluDetox"
        static let schedulesFileName = "schedule.json"
        static let eventsFileName = "schedule_events.json"
        static let markerFilePrefix = "schedule_event_marker_"
        static let markerFileSuffix = ".json"

        enum PathError: Error { case containerUnavailable }

        private static func containerURL() throws -> URL {
            guard let base = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            ) else {
                throw PathError.containerUnavailable
            }
            return base
        }

        static func schedulesURL() throws -> URL {
            try containerURL().appendingPathComponent(schedulesFileName, isDirectory: false)
        }

        static func eventsURL() throws -> URL {
            try containerURL().appendingPathComponent(eventsFileName, isDirectory: false)
        }

        /// Timestamp-suffixed marker file (unix milliseconds).
        /// Multiple markers can coexist; main app lists, sorts by suffix, consumes.
        static func markerURL(timestamp: Date) throws -> URL {
            let ms = Int64(timestamp.timeIntervalSince1970 * 1000)
            return try containerURL().appendingPathComponent(
                "\(markerFilePrefix)\(ms)\(markerFileSuffix)",
                isDirectory: false
            )
        }

        /// Directory (App Group root) to scan for marker files.
        static func markerDirectoryURL() throws -> URL { try containerURL() }

        /// True iff `url.lastPathComponent` matches the marker naming convention.
        static func isMarkerFile(_ url: URL) -> Bool {
            let name = url.lastPathComponent
            return name.hasPrefix(markerFilePrefix) && name.hasSuffix(markerFileSuffix)
        }
    }
    ```

    **5. `ScheduleEvent.swift`**:
    ```swift
    import Foundation

    /// Append-only history row (CONTEXT §D-17). Main app appends to
    /// `schedule_events.json`; Phase 6 consumes for NTF-02 notifications.
    struct ScheduleEvent: Codable, Equatable, Sendable {
        enum Kind: String, Codable, Sendable { case started, ended }
        let scheduleId: UUID
        let kind: Kind
        let timestamp: Date
    }
    ```

    **6. `ScheduleEventMarker.swift`** (extension-safe — no FamilyControls/SwiftUI imports):
    ```swift
    import Foundation

    /// DAM → main-app handoff payload written from `intervalDidStart` /
    /// `intervalDidEnd` (CONTEXT §D-17). One marker file per event, named
    /// `schedule_event_marker_{unix_millis}.json` — multiple markers coexist
    /// (RESEARCH Open Question #4: cross-midnight would overwrite a single
    /// marker; timestamp suffix preserves both evening-start and morning-end).
    struct ScheduleEventMarker: Codable, Equatable, Sendable {
        enum Kind: String, Codable, Sendable { case started, ended }
        let scheduleId: UUID
        let kind: Kind
        let timestamp: Date
    }
    ```

    **7. `ManagedSettingsStoreNames.swift`** (literal-string isolation — pitfall 6):
    ```swift
    import Foundation

    /// Canonical store names so Phase 3 / Phase 5 literals never drift.
    /// Clearing one store MUST NOT affect the other (D-05 schedule × session).
    enum ManagedSettingsStoreNames {
        static let session = "deluludetox.session"
        static let schedule = "deluludetox.schedule"
    }
    ```

    **8. `SchedulingInjection.swift`** (skeleton — Plan 04 fills body):
    ```swift
    // Features/Scheduling/Injection/SchedulingInjection.swift
    //
    // Distributed DI registration for the Scheduling feature. Feature-owner of
    // `ScheduleRepository` + `ScheduleShieldRepository` +
    // `ScheduleActivityMonitoringRepository` + 7 Scheduling UseCases.
    // Called from `DeluluDetoxApp.init()` BETWEEN `SessionInjection` and
    // `DenialInjection`. Scheduling depends on AppSelection (Blocklist) and
    // Session (no direct dep, but bootstraps after so BlocklistRepository
    // is registered before SelfHealSchedulesUseCase resolves it).
    //
    // Plan 05-01: skeleton only (empty body). Plan 05-04 adds 3 repo +
    // 7 UC registrations.

    enum SchedulingInjection {
        static func register(in container: DIContainer) {
            // Intentionally empty until Plan 05-04.
            // Downstream plans add repository + UC registrations here.
        }
    }
    ```

    **9. Modify `DeluluDetox/Sources/App/DeluluDetoxApp.swift`**: insert one line between existing `SessionInjection.register(in: container)` and `DenialInjection.register(in: container)`. The resulting order:
    ```swift
    OnboardingInjection.register(in: container)
    AppSelectionInjection.register(in: container)
    SessionInjection.register(in: container)
    SchedulingInjection.register(in: container)    // ← NEW (Plan 05-01)
    DenialInjection.register(in: container)
    HomeInjection.register(in: container)
    RootInjection.register(in: container)
    ```

    **10. Modify `project.yml` DeviceActivityMonitorExtension.sources** (lines ~95-99): APPEND 4 entries (preserving existing 4 lines — do not remove Session sources):
    ```yaml
      DeviceActivityMonitorExtension:
        type: app-extension
        platform: iOS
        sources:
          - path: Extensions/DeviceActivityMonitorExtension
          - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
          - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionFinalizeMarker.swift
          - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionActivityNames.swift
          - path: DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift
          - path: DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift
          - path: DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift
          - path: DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift
          - path: DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift
          - path: DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift
    ```

    After edits run `xcodegen generate` (MUST succeed zero-error) then `mcp__XcodeBuildMCP__build_sim` on scheme `DeluluDetox` destination iPhone 17 (preferred) or `mcp__XcodeBuildMCP__test_sim` to confirm green build. Commit with message `feat(05-01): add Scheduling feature scaffold — models + paths + DI skeleton + project.yml source-shares`.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox destination={iPhone 17 simulator from session_show_defaults} — expect full suite still green, same test count as Phase 4 baseline (153 tests, 3 skipped, 0 failures — NO new tests yet since Task 3 creates the scaffolds)</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEvent.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` exits 0
    - `grep -c "struct Schedule: Codable, Equatable, Identifiable, Sendable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift` == 1
    - `grep -c "enum ScheduleSegment: String, Codable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift` == 1
    - `grep -c "static let schedule = \"deluludetox.schedule\"" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift` == 1
    - `grep -c "static let session = \"deluludetox.session\"" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift` == 1
    - `grep -c "static let prefix = \"deluludetox.schedule.\"" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift` == 1
    - `grep -c "enum SchedulingInjection" DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` == 1
    - `grep -c "SchedulingInjection.register(in: container)" DeluluDetox/Sources/App/DeluluDetoxApp.swift` == 1
    - `grep -n "SchedulingInjection.register" DeluluDetox/Sources/App/DeluluDetoxApp.swift` shows line between `SessionInjection.register` and `DenialInjection.register` (Session line < Scheduling line < Denial line)
    - `grep -c "Features/Scheduling/Common/Repository/Models/Schedule.swift" project.yml` >= 1
    - `grep -c "Features/Scheduling/Common/Repository/Models/SchedulePaths.swift" project.yml` >= 1
    - `grep -c "Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift" project.yml` >= 1
    - `grep -c "Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift" project.yml` >= 1
    - `grep -c "^import SwiftUI" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/*.swift` == 0 (extension-safe)
    - `grep -c "^import Combine" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/*.swift` == 0
    - `grep -c "^import FamilyControls" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/*.swift` == 0
    - `xcodegen generate` exits 0 with no diff on second run
    - `mcp__XcodeBuildMCP__test_sim` scheme=DeluluDetox reports 0 failures (full suite green)
  </acceptance_criteria>
  <done>
    7 scaffold source files exist on disk. `SchedulingInjection.register` wired into `DeluluDetoxApp.init()` in correct bootstrap position. `project.yml` source-shares 4 App Group files into DAM extension. Full test suite green. Committed.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: XCTest scaffolds + mocks for Plans 02..07 (XCTSkipIf stubs only)</name>
  <files>
    DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleShieldRepositoryTests.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleActivityMonitoringRepositoryTests.swift,
    DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/SyncScheduleWithSystemUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/ToggleScheduleUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/SelfHealSchedulesUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/CreateOrUpdateScheduleUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/ConsumeScheduleEventMarkerUseCaseTests.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleShieldRepository.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleActivityMonitoringRepository.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockComputeScheduleWindowUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockObserveScheduleUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockSyncScheduleWithSystemUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockCreateOrUpdateScheduleUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockToggleScheduleUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockSelfHealSchedulesUseCase.swift,
    DeluluDetoxTests/Features/Scheduling/Mocks/MockConsumeScheduleEventMarkerUseCase.swift
  </files>
  <read_first>
    - DeluluDetoxTests/Features/Session/SessionRepositoryTests.swift (analogue — XCTest structure + URL-provider test seam pattern)
    - DeluluDetoxTests/Features/Session/Mocks/MockSessionRepository.swift (analogue — @unchecked Sendable pattern for mocks, call counters, error stubs)
    - DeluluDetoxTests/Features/Shield/ShieldConfigurationBuilderTests.swift (analogue — XCTSkipIf stub pattern from Phase 4 Wave 0)
    - .planning/phases/04-shield-customization/04-01-SUMMARY.md §Task 2 (XCTSkipIf scaffolding technique — lets tests compile and document intent without failing suite)
    - .planning/phases/05-scheduled-blocking/05-VALIDATION.md §Wave 0 Requirements (the exact 11 test files + 7 mocks expected; this task delivers 11 + 10 because ObserveScheduleUseCase + ConsumeScheduleEventMarkerUseCase mocks split out)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Per Phase Requirements → Test Map (the exact method names + assertions each test stub must document)
  </read_first>
  <action>
    Create 11 XCTest files + 10 mock files. Every test method body is `XCTSkipIf(true, "Stub — Plan 05-{NN} replaces with real assertion. Expected: {exact behavior}")`. Every mock is a `final class Mock{X}: {Protocol}, @unchecked Sendable` with call counters + error stubs. Do NOT reference production symbols that don't exist yet (Plan 02+ creates them) — instead, the XCTSkipIf body documents the assertion in English, not Swift.

    **Naming / wave map for skip messages:**
    - Plan 05-02 → ScheduleRepositoryTests, CreateOrUpdateScheduleUseCaseTests, ConsumeScheduleEventMarkerUseCaseTests
    - Plan 05-03 → ScheduleShieldRepositoryTests, ScheduleActivityMonitoringRepositoryTests
    - Plan 05-04 → ComputeScheduleWindowUseCaseTests, SyncScheduleWithSystemUseCaseTests, ToggleScheduleUseCaseTests, SelfHealSchedulesUseCaseTests
    - Plan 05-06 → ScheduleEditorViewModelTests
    - Plan 05-07 → ScheduleListViewModelTests

    **Test file contents** (exact method names per VALIDATION.md + RESEARCH §Test Map):

    **`ScheduleRepositoryTests.swift`** — 5 stubs:
    - `testCodableRoundTrip` — "Plan 05-02: encode Schedule with full D-02 schema, decode, assert equal"
    - `testAtomicWriteAndReadBackViaURLProviderSeam` — "Plan 05-02: write via repository, read file bytes, decode, assert match"
    - `testUpsertAddsNewScheduleToPublisher` — "Plan 05-02: repository.upsert emits new array via schedulesPublisher"
    - `testAppendEventAppendsToSchedulesEventsJSON` — "Plan 05-02: appendEvent reads events.json, appends, writes atomically"
    - `testConsumeEventMarkerReturnsAllMarkersAndDeletes` — "Plan 05-02: list marker files, decode each, delete each, return sorted by timestamp"

    **`ScheduleShieldRepositoryTests.swift`** — 4 stubs:
    - `testApplyShieldWritesTokensToScheduleNamedStoreOnly` — "Plan 05-03: applyShield(for:) calls writer.setShieldApplications/WebDomains/Categories on a writer constructed with storeName=ManagedSettingsStoreNames.schedule"
    - `testApplyShieldWritesRequireAutomaticDateAndTime` — "Plan 05-03: applyShield also calls setDateAndTimeRequireAutomatic(true) for anti-clock-skew (pitfall threat T-05-03-XX)"
    - `testClearShieldResetsAllFacetsAndRestrictions` — "Plan 05-03: clearShield sets all 5 store fields to nil/false unconditionally"
    - `testStoreNameIsolationFromSessionStore` — "Plan 05-03: grep-level assertion that LiveScheduleShieldRepository constructs LiveManagedSettingsStoreWriter(storeName: .schedule), NOT .session"

    **`ScheduleActivityMonitoringRepositoryTests.swift`** — 6 stubs:
    - `testStartMonitoringSingleDayUsesMainSegmentAndOneDAS` — "Plan 05-03: single-day schedule (endHour > startHour) registers exactly 1 DAS with activityName suffix .main"
    - `testStartMonitoringCrossMidnightSplitsIntoEveningAndMorningTwoDAS` — "Plan 05-03: cross-midnight (endMin <= startMin) registers 2 DAS: .evening (start → 23:59:59) + .morning (00:00:00 → end)"
    - `testStartMonitoringUsesRepeatsTruePerD13` — "Plan 05-03: DeviceActivitySchedule.repeats == true (unless Wave 0 Outcome C — in which case test must be rewritten to assert repeats=false)"
    - `testStopMonitoringRemovesAllSegmentsForScheduleId` — "Plan 05-03: stopMonitoring(scheduleId:) calls center.stopMonitoring with BOTH .main AND .evening AND .morning variants so no stale segment persists"
    - `testStartMonitoringWrapsCenterErrorInRepositoryError` — "Plan 05-03: center throws → repository throws ScheduleActivityMonitoringError.startFailed(wrapped)"
    - `testSegmentHelperBuildDeviceActivitySchedulesRoundTrip` — "Plan 05-03: Schedule.buildDeviceActivitySchedules() returns array whose names parse back to the same (scheduleId, segment) tuples"

    **`ComputeScheduleWindowUseCaseTests.swift`** — 6 stubs (pure logic — no mocks):
    - `testSingleDayActiveMidWindow` — "Plan 05-04: schedule 09:00-17:00 Mon-Fri, now=Wed 12:00 → .active(endsAt: Wed 17:00)"
    - `testSingleDayUpcomingToday` — "Plan 05-04: schedule 09:00-17:00 Mon-Fri, now=Wed 07:00 → .upcomingToday(startsAt: Wed 09:00)"
    - `testCrossMidnightBeforeMidnightActive` — "Plan 05-04: schedule 22:00-06:00 daily, now=23:30 → .active(endsAt: tomorrow 06:00)"
    - `testCrossMidnightAfterMidnightActive` — "Plan 05-04: schedule 22:00-06:00 daily, now=03:00 → .active(endsAt: today 06:00) — yesterday's evening segment is the trigger"
    - `testWeekdayExclusionReturnsNotToday` — "Plan 05-04: schedule Mon-Fri only, now=Saturday → .notToday(nextDate: next Monday 09:00)"
    - `testDisabledScheduleReturnsInactive` — "Plan 05-04: schedule.enabled=false → .inactive regardless of now"

    **`SyncScheduleWithSystemUseCaseTests.swift`** — 4 stubs:
    - `testSyncStopsOldThenStartsNewWhenEnabled` — "Plan 05-04: UC calls monitoring.stopMonitoring(scheduleId:) THEN monitoring.startMonitoring(schedule:) in that order"
    - `testSyncOnlyStopsWhenScheduleDisabled` — "Plan 05-04: schedule.enabled=false → UC calls stopMonitoring, does NOT call startMonitoring"
    - `testSyncRollsBackScheduleJSONWhenStartMonitoringThrows` — "Plan 05-04: start throws → UC calls repository.rollback / revert to prior snapshot + rethrows"
    - `testSyncLogsErrorWhenStopMonitoringThrows` — "Plan 05-04: stopMonitoring throws → logged, UC continues with startMonitoring (pitfall #5 disable mid-window leaves dirty store anyway)"

    **`ToggleScheduleUseCaseTests.swift`** — 3 stubs:
    - `testToggleEnableCallsUpsertThenSync` — "Plan 05-04: toggle(scheduleId:enabled:true) calls repo.upsert(enabled=true) THEN sync(schedule:)"
    - `testToggleDisableCallsUpsertThenSyncWhichStopsMonitoring` — "Plan 05-04: toggle(scheduleId:enabled:false) calls repo.upsert THEN sync; sync calls stopMonitoring only"
    - `testToggleMissingScheduleThrowsNotFound` — "Plan 05-04: scheduleId not in repository → UC throws ScheduleNotFound"

    **`SelfHealSchedulesUseCaseTests.swift`** — 4 stubs:
    - `testAppliesShieldWhenShouldBeActiveButStoreClear` — "Plan 05-04: compute returns .active but last-apply marker absent → UC calls shieldRepo.applyShield(for: blocklist)"
    - `testClearsShieldWhenStoreDirtyButShouldNotBeActive` — "Plan 05-04: compute returns .inactive/.upcomingToday but schedule store previously applied → UC calls shieldRepo.clearShield()"
    - `testNoOpWhenStateMatches` — "Plan 05-04: compute says .active AND schedule was last applied → UC makes zero calls"
    - `testIteratesOverAllEnabledSchedules` — "Plan 05-04: multi-schedule (even if MVP UI is single) — UC iterates .filter(\\.enabled).forEach(heal)"

    **`CreateOrUpdateScheduleUseCaseTests.swift`** — 3 stubs:
    - `testCreateAssignsNewUUIDAndPersists` — "Plan 05-02: UC(schedule: draft-without-id) → repo.upsert with newly-generated UUID; returns Schedule with non-nil id"
    - `testUpdatePreservesExistingId` — "Plan 05-02: UC(schedule: existing id=X) → repo.upsert keeps id=X"
    - `testTriggersSyncAfterUpsert` — "Plan 05-02: UC calls sync(schedule:) after repo.upsert succeeds — editor save → DAS registration in one flow"

    **`ConsumeScheduleEventMarkerUseCaseTests.swift`** — 4 stubs:
    - `testConsumeAppendsAllMarkersToEventsJSON` — "Plan 05-02: 3 markers in directory → UC appends 3 ScheduleEvent rows to schedule_events.json"
    - `testConsumeDeletesMarkerFilesAfterAppending` — "Plan 05-02: marker files are removed from disk after successful append"
    - `testConsumeReturnsZeroWhenNoMarkers` — "Plan 05-02: empty directory → UC returns 0, no throws, no writes"
    - `testConsumeSortsMarkersByTimestampBeforeAppend` — "Plan 05-02: out-of-order filenames (different unix-millis suffixes) → events appended in chronological order"

    **`ScheduleEditorViewModelTests.swift`** — 8 stubs (will grow when Plan 06 implements):
    - `testInitialStateHasNoDaysAndDefault09To17Enabled` — "Plan 05-06: VM init with no existing → daysOfWeek=[], startHour=9, endHour=17, enabled=true"
    - `testInitFromExistingSeedsAllFields` — "Plan 05-06: VM(existing: Schedule) seeds daysOfWeek/start/end/enabled from the passed schedule"
    - `testPresetDniRoboczeSetsMonToFriWeekdays` — "Plan 05-06: tapping 'Dni robocze' preset sets daysOfWeek = [2,3,4,5,6] (Mon-Fri Calendar.weekday)"
    - `testPresetWeekendSetsSatAndSun` — "Plan 05-06: tapping 'Weekend' sets [7, 1] (Sat=7, Sun=1)"
    - `testPresetCodziennieSetsAllSeven` — "Plan 05-06: tapping 'Codziennie' sets [1,2,3,4,5,6,7]"
    - `testCrossMidnightDetectionWhenEndLessThanStart` — "Plan 05-06: start=22:00 end=06:00 → model.isCrossMidnight == true"
    - `testSaveTappedCallsCreateOrUpdateUseCase` — "Plan 05-06: saveTapped() → createOrUpdate(schedule:) called with assembled Schedule; destination becomes nil (dismiss editor)"
    - `testSaveTappedFailureSetsErrorAlertDestination` — "Plan 05-06: createOrUpdate throws → destination = .errorAlert(sarcastic Polish message)"

    **`ScheduleListViewModelTests.swift`** — 4 stubs:
    - `testListObservesScheduleRepositoryPublisher` — "Plan 05-07: observeSchedule emits [Schedule] → vm.schedules reflects it"
    - `testTapEditExistingSetsEditorDestinationWithSchedule` — "Plan 05-07: list.editTapped(existing) → destination = .scheduleEditor(ScheduleEditorViewModel(existing:))"
    - `testTapCreateNewSetsEditorDestinationWithNil` — "Plan 05-07: list.createTapped() → destination = .scheduleEditor(ScheduleEditorViewModel(existing: nil))"
    - `testToggleRowCallsToggleScheduleUseCase` — "Plan 05-07: row-level toggle flip calls toggleSchedule(scheduleId:enabled:) UC"

    **Mock file contents** — canonical pattern (mirror `MockSessionRepository`):
    ```swift
    import Combine
    import Foundation
    @testable import DeluluDetox

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
            var current = schedulesSubject.value
            if let idx = current.firstIndex(where: { $0.id == schedule.id }) {
                current[idx] = schedule
            } else {
                current.append(schedule)
            }
            schedulesSubject.send(current)
        }
        // ... appendEvent / consumeMarkers / remove — same shape
    }
    ```
    Produce a mock file of this shape for EACH protocol Plans 02-07 will define. Mocks can reference protocol names (`ScheduleRepository`, etc.) BEFORE Plan 02+ creates them — IF the mock file is conditionally compiled out. To avoid compilation breakage at Plan 01 time:

    **Critical:** wrap EVERY mock file body in `#if false ... #endif` until Plans 02-04 create the referenced protocols. The XCTest stubs themselves compile because they only contain `XCTSkipIf(true, "...")` and no protocol references. Plan 02 / 03 / 04 flip the `#if false` to real code when they create the corresponding protocol.

    **Alternative (preferred if protocols would compile):** Since protocols are pure Swift declarations with no external deps, an even cleaner option is to include empty protocol declarations for each Scheduling protocol directly in `SchedulingInjection.swift` as `// MARK: - Protocols (filled in Plan 05-02..04)` with `protocol ScheduleRepository: Sendable {}` (etc.), and let Plans 02/03/04 ADD the method declarations. This way mocks compile immediately without `#if false`.

    **Use the second option** (empty protocols in `SchedulingInjection.swift` or a new file `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift`). Add:
    ```swift
    // Features/Scheduling/Common/Repository/ScheduleProtocols.swift
    import Combine
    import Foundation

    /// Empty protocols declared up-front so Plan 01 mocks compile. Plan 02/03/04
    /// ADD method declarations in-place (in the same file when that plan lands).
    protocol ScheduleRepository: Sendable {
        var schedulesPublisher: AnyPublisher<[Schedule], Never> { get }
    }
    protocol ScheduleShieldRepository: Sendable {}
    protocol ScheduleActivityMonitoringRepository: Sendable {}
    protocol ObserveScheduleUseCase: Sendable {}
    protocol CreateOrUpdateScheduleUseCase: Sendable {}
    protocol ToggleScheduleUseCase: Sendable {}
    protocol SyncScheduleWithSystemUseCase: Sendable {}
    protocol SelfHealSchedulesUseCase: Sendable {}
    protocol ComputeScheduleWindowUseCase: Sendable {}
    protocol ConsumeScheduleEventMarkerUseCase: Sendable {}
    ```
    Add this file to the `files_modified` mental model (add to project under `DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift`). Plans 02-04 REPLACE the empty protocol bodies with the real method declarations (not create — replace).

    Run `xcodegen generate` if `project.yml` has changed (the new file is under `DeluluDetox/Sources/` glob so no project.yml edit needed). Run `mcp__XcodeBuildMCP__test_sim` and verify: all previous tests still pass, new XCTSkipIf tests appear as skipped (test count grows by ~51, skip count grows by ~51). Commit `test(05-01): add Scheduling XCTest scaffolds + 10 mocks (XCTSkipIf stubs)`.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox destination={iPhone 17 simulator} — expect ≥204 tests (prior 153 + ~51 new Scheduling stubs), ≥54 skipped (prior 3 + ~51 new), 0 failures</automated>
  </verify>
  <acceptance_criteria>
    - `ls DeluluDetoxTests/Features/Scheduling/*.swift | wc -l` >= 11
    - `ls DeluluDetoxTests/Features/Scheduling/Mocks/*.swift | wc -l` >= 10
    - `grep -c "final class ScheduleRepositoryTests" DeluluDetoxTests/Features/Scheduling/ScheduleRepositoryTests.swift` == 1
    - `grep -c "final class ComputeScheduleWindowUseCaseTests" DeluluDetoxTests/Features/Scheduling/ComputeScheduleWindowUseCaseTests.swift` == 1
    - `grep -c "final class ScheduleEditorViewModelTests" DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift` == 1
    - `grep -rn "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ | wc -l` >= 45 (each test body is XCTSkipIf(true, "..."))
    - `grep -c "final class MockScheduleRepository" DeluluDetoxTests/Features/Scheduling/Mocks/MockScheduleRepository.swift` == 1
    - `grep -c "@unchecked Sendable" DeluluDetoxTests/Features/Scheduling/Mocks/*.swift` >= 10 (every mock has it)
    - `test -f DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` exits 0
    - `grep -c "protocol ScheduleRepository: Sendable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `grep -c "protocol ComputeScheduleWindowUseCase: Sendable" DeluluDetox/Sources/Features/Scheduling/Common/Repository/ScheduleProtocols.swift` == 1
    - `mcp__XcodeBuildMCP__test_sim` reports 0 failures with test count ≥ 204 and skip count ≥ 54
  </acceptance_criteria>
  <done>
    11 XCTest scaffold files + 10 mock files + `ScheduleProtocols.swift` (empty protocols) exist on disk. Full suite green with new skips. All tests have XCTSkipIf stubs documenting the exact assertion downstream plans will land. Committed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| physical-device / iOS system | Spike runs real DAS on device; iOS callback timing is the untrusted input |
| dev-workstation / git | Spike code must NOT be committed; rely on `git status` discipline |
| main-app / App Group container | Models + Paths are the schema contract read by DAM — schema drift here causes cross-process corruption |
| main-app / DAM extension (via source-share) | project.yml source-shares files across processes — ABI stability is required |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-05-01-01 | Tampering | Spike code committed by mistake | mitigate | Task 1 acceptance criterion: `git diff --name-only` shows only `05-DISCUSSION-LOG.md`; revert spike before ending task |
| T-05-01-02 | Information Disclosure | Spike log line leaks PII | accept | Spike log string hard-coded in task body — scalar-only `Date()` + `activity.rawValue` (no user data), matches Phase 4 01 precedent |
| T-05-01-03 | Tampering | Schedule.swift schema field reordered after DAM ships | mitigate | Codable with named keys (Swift default uses property names); downstream tests assert round-trip; any DAM-visible field change requires DAM rebuild |
| T-05-01-04 | Denial of Service | DAM target size bloat | mitigate | project.yml only source-shares 6 files (all < 100 LOC combined), all Foundation-only (no SwiftUI/Combine/FamilyControls); `grep -c "^import SwiftUI" DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/*.swift` == 0 |
| T-05-01-05 | Spoofing | Marker filename suffix guessed by attacker app | accept | App Group is sandboxed to our 4 targets only; markerDirectoryURL() scoped to our own App Group; no external write surface |
| T-05-01-06 | Elevation of Privilege | Empty `SchedulingInjection.register(in:)` body accidentally shadows Plan 04 registrations | mitigate | `grep -c "container.register" DeluluDetox/Sources/Features/Scheduling/Injection/SchedulingInjection.swift` == 0 at end of Plan 01 — Plan 04 adds registrations (executor enforces task order) |
| T-05-01-07 | Repudiation | No audit trail for spike verdict | mitigate | Acceptance criterion mandates "Device:", "iOS:", "Outcome A/B/C" tokens in DISCUSSION-LOG verdict section |
</threat_model>

<verification>
**Plan-level gate (run after all 3 tasks):**
1. `mcp__XcodeBuildMCP__test_sim` scheme=DeluluDetox — full suite green, test count ≥ 204 (prior 153 + ~51 skip stubs), 0 failures.
2. `git log --oneline -3` shows exactly 2 commits from this plan (scaffold + tests); no spike code in any commit.
3. `grep -c "SchedulingInjection.register" DeluluDetox/Sources/App/DeluluDetoxApp.swift` == 1 (bootstrap wired).
4. `grep -c "## Wave 0 Spike Verdict" .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md` == 1 (Task 1 verdict recorded).
5. `xcodegen generate` produces zero diff on second run (idempotent).
</verification>

<success_criteria>
- Wave 0 spike verdict recorded in `05-DISCUSSION-LOG.md` with Outcome A/B/C. If Outcome B or C, Plan 03 author (human or next-planner invocation) knows to pivot.
- 7 scaffold source files exist; `ScheduleProtocols.swift` has 10 empty protocols.
- 11 XCTest files with ~51 XCTSkipIf stubs + 10 mocks exist, all compile against empty protocols.
- Bootstrap order in `DeluluDetoxApp.init()`: Onboarding → AppSelection → Session → **Scheduling** → Denial → Home → Root.
- `project.yml` source-shares 6 Scheduling Models files into DAM extension; no SwiftUI/Combine/FamilyControls imports in those files.
- Full test suite green.
- Plans 02-07 have concrete `<automated>` verify commands (`mcp__XcodeBuildMCP__test_sim` with filter `-only-testing:DeluluDetoxTests/Features/Scheduling/...`).
</success_criteria>

<output>
After completion, create `.planning/phases/05-scheduled-blocking/05-01-SUMMARY.md` summarizing: spike verdict Outcome letter, file counts (created vs. modified), test skip delta, bootstrap position, and any Plan 02+ pivot implications.
</output>
