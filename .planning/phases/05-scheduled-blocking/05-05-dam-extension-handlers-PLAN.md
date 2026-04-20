---
phase: 05
plan: 05
type: execute
wave: 2
depends_on: [05-01, 05-02, 05-03]
files_modified:
  - Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
autonomous: true
requirements: [SCH-03, SCH-04]
must_haves:
  truths:
    - "DAM extension dispatches by activity-name prefix: `SessionActivityNames.quickSession` hits the Phase 3 session path (unchanged); `deluludetox.schedule.*` activities hit the NEW Phase 5 schedule path"
    - "DAM `intervalDidStart(for:)` on a schedule activity: parses scheduleId + segment, reads schedule.json, checks schedule.enabled, checks Calendar.weekday is in schedule.daysOfWeek (D-15 step 3), reads blocklists.json tokens, writes to ManagedSettingsStore(named: \"deluludetox.schedule\"), writes timestamp-suffixed marker file + Darwin notification"
    - "DAM `intervalDidEnd(for:)` on a schedule activity: clears the schedule-named store (only), writes .ended marker + Darwin notification. Session-path `intervalDidEnd` (Phase 3) is untouched"
    - "Weekday filter uses Calendar.current.component(.weekday, from: Date()) — 1=Sunday..7=Saturday; the FIRED segment's weekday drives the filter (evening segment fires on its own day; morning segment fires on the NEXT day — spec says weekday filter applies to the evening-start day, which means morning segment filter uses `yesterday's weekday`)"
    - "DAM target stays under 6 MB RAM — no new imports beyond Phase 3's Foundation/DeviceActivity/ManagedSettings/os; local Decodable envelopes decode only required fields from schedule.json and blocklists.json"
    - "Marker files use timestamp-suffixed naming (schedule_event_marker_{unix_ms}.json) so cross-midnight evening+morning events coexist without overwrite (resolves RESEARCH Open Question #4)"
  artifacts:
    - path: "Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift"
      provides: "Extended DAM handler with prefix-based dispatch, schedule intervalDidStart + intervalDidEnd paths, token-envelope Decodable for blocklists.json reads, ScheduleEventMarker writes (timestamp-suffixed), Darwin post for scheduleStarted/scheduleEnded"
  key_links:
    - from: "DAM intervalDidStart(for: activity)"
      to: "ManagedSettingsStore(named: ManagedSettingsStoreNames.schedule)"
      via: "parse activity → load schedule → weekday filter → load tokens → write store + marker + Darwin"
      pattern: "ManagedSettingsStore\\(named: \\.init\\(ManagedSettingsStoreNames.schedule"
    - from: "DAM"
      to: "schedule_event_marker_{ts}.json + schedule_events.json reconcile"
      via: "SchedulePaths.markerURL(timestamp: Date()) + atomic write; main app consumes next foreground via ConsumeScheduleEventMarkerUseCase"
      pattern: "SchedulePaths.markerURL"
    - from: "DAM"
      to: "Darwin com.kksw.DeluluDetox.scheduleStarted / scheduleEnded"
      via: "CFNotificationCenterPostNotification"
      pattern: "com.kksw.DeluluDetox.scheduleStarted|com.kksw.DeluluDetox.scheduleEnded"
---

<objective>
Extend the existing `DeviceActivityMonitorExtension.swift` (Phase 3's quickSession-only handler) with the schedule dispatch path: parse schedule activity names by prefix, apply/clear the schedule-named ManagedSettingsStore during scheduled windows, write timestamp-suffixed event markers for the main-app consumer, post Darwin notifications. This is the sole DAM-side code Phase 5 ships — the cross-process contract (named store, marker format, Darwin names) is the interface every other Phase 5 plan targets.

**Wave placement note (planning iteration 1, 2026-04-20):** This plan runs in Wave 2 alongside Plan 05-04, not Wave 1. Rationale: the `<verify>` automated command runs the full test suite which requires Plans 05-02 and 05-03's artifacts (ScheduleRepository, ScheduleActivityMonitoringRepository, ScheduleShieldRepository) to compile. Wave 1 parallel execution would cause compilation races. Plan 05-05 therefore depends on `[05-01, 05-02, 05-03]` and executes after Wave 1 completes.

Purpose:
- SCH-03 acceptance: "Schedule executes via DeviceActivityMonitor extension — apps blocked during scheduled window." This plan implements that, end-to-end, in the extension process.
- SCH-04 acceptance: "Shield overlay during scheduled blocks behaves identically to quick session shields." This is delivered by zero code here — `ShieldConfigurationExtension` from Phase 4 renders the same branded shield regardless of which named store (`deluludetox.session` or `deluludetox.schedule`) posted tokens. No DAM-side work needed for SCH-04 beyond writing the correct store.
- RAM posture: DAM stays Foundation-only + DeviceActivity + ManagedSettings + os (the 4 imports Phase 3 established). No `FamilyControls`/`SwiftUI`/`Combine`.

Output:
- Single-file modification to `DeviceActivityMonitorExtension.swift`:
  - `intervalDidStart(for:)` (currently a logger line only) gains schedule branch.
  - `intervalDidEnd(for:)` (currently only handles SessionActivityNames.quickSession) gains a schedule branch.
  - Helper methods for schedule-path: `loadScheduleById`, `loadBlocklistTokensById`, `writeScheduleEventMarker(kind:scheduleId:)`, `postScheduleDarwin(kind:)`.
- No new source files. Extension target RAM posture preserved.
- `project.yml` already source-shares Schedule.swift + SchedulePaths.swift + ScheduleActivityNames.swift + ScheduleEventMarker.swift + ScheduleSegment.swift + ManagedSettingsStoreNames.swift into the DAM target (set up in Plan 05-01).

**Verification note:** DAM behavior CANNOT be unit-tested — the extension runs out-of-process under iOS control. This plan ships with NO new XCTest files. Verification is via `mcp__XcodeBuildMCP__build_sim` ensuring the extension compiles with the 4-import constraint, and `mcp__XcodeBuildMCP__test_sim` ensuring no regression of the existing 150+ test suite (session tests + all Plan 02-04 unit tests still green). Real-device UAT is the only way to validate runtime DAS firing — that is Plan 05-08's responsibility.
</objective>

<execution_context>
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/workflows/execute-plan.md
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/05-scheduled-blocking/05-CONTEXT.md
@.planning/phases/05-scheduled-blocking/05-RESEARCH.md
@.planning/phases/05-scheduled-blocking/05-01-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md
@.planning/phases/03-quick-sessions/03-04-SUMMARY.md
@Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleSegment.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleEventMarker.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ManagedSettingsStoreNames.swift
@DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
@DeluluDetox/Sources/Features/AppSelection/Repository/Models/Blocklist.swift

<interfaces>
Existing DAM handler (Phase 3 — unchanged session path):
```swift
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart: \(activity.rawValue, privacy: .public)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("intervalDidEnd: \(activity.rawValue, privacy: .public)")
        guard activity == SessionActivityNames.quickSession else { return }
        // ... session finalize (Phase 3) ...
    }
}
```

Source-shared Plan 01 files the DAM now has access to (from project.yml):
- `ScheduleActivityNames.parse(_:)` → `(scheduleId: UUID, segment: ScheduleSegment)?`
- `ScheduleActivityNames.prefix` = `"deluludetox.schedule."`
- `SchedulePaths.schedulesURL()` / `markerURL(timestamp:)`
- `ManagedSettingsStoreNames.schedule` = `"deluludetox.schedule"`
- `Schedule` full Codable struct (but decode via local envelope to stay lean)
- `ScheduleSegment` enum (`.main`, `.evening`, `.morning`)
- `ScheduleEventMarker` full Codable struct

Blocklists.json schema (Phase 2 — read via lean envelope):
```swift
// From Phase 2 Blocklist.swift — DAM decodes ONLY the fields it needs:
struct Blocklist: Codable, ... {
    let id: UUID
    var lastSelection: FamilyActivitySelection   // contains applicationTokens, categoryTokens, webDomainTokens
    ...
}
// DAM approach: FamilyActivitySelection IS Codable (Apple framework). Decoding it via Decodable envelope would normally force FamilyControls import.
// Pattern: the DAM target ALREADY links FamilyControls transitively because ManagedSettings depends on FamilyControls types? NO — Phase 3 avoided FamilyControls. The extension MUST continue avoiding.
// Solution: the DAM writes `store.shield.applications = tokens` using `Set<ApplicationToken>` from ManagedSettings. It must read these tokens from blocklists.json.
// BUT `ApplicationToken` lives in FamilyControls. To stay lean, the DAM decodes an intermediate JSON envelope that mirrors FamilyActivitySelection's on-disk format:
//   { "lastSelection": { "applicationTokens": [<base64-encoded-token>...], "categoryTokens": [...], "webDomainTokens": [...] } }
// HOWEVER: Set<ApplicationToken> encodes to an opaque format we cannot re-create without FamilyControls.
```

**CRITICAL REALIZATION**: Phase 3 DAM does NOT read tokens from blocklists.json — it just CLEARS the session store. The existing DAM has no precedent for loading FamilyControls tokens. For Phase 5, the DAM's `intervalDidStart` MUST write tokens into the schedule store, so it MUST decode them.

Two possible approaches (choose per executor inspection of iOS 26 SDK):

**Option A — Import FamilyControls in DAM (conditional)**. Add `@preconcurrency import FamilyControls` only if runtime memory profiling (simulator + Console.app) shows staying under 6 MB. This is the simple path but violates Phase 3's lean posture.

**Option B — Move token application to main-app self-heal ONLY**. The DAM `intervalDidStart` writes the marker + posts Darwin, but does NOT apply the shield. The main-app `SelfHealSchedulesUseCase` (Plan 04) observes the Darwin notification, forgrounds (or was already foregrounded), applies shield from main-app context. Drawback: if the main app is BACKGROUNDED at schedule start, the shield doesn't apply until the user opens the app. This means background schedule starts don't enforce blocking until foreground — **fails SCH-03 acceptance**.

**Decision: Option A** — import FamilyControls in DAM. This unlocks token application at schedule start without requiring main-app foreground. Runtime memory budget accepted because Phase 3 empirically ships a minimal DAM and FamilyControls adds ~1-2 MB (not full SwiftUI bloat). Budget is 6 MB; Phase 3 ships ~500 KB; we have ~5 MB headroom. Add a one-line comment explaining this choice.

Project.yml note: `project.yml` already has `com.apple.developer.family-controls: true` entitlement on the DeviceActivityMonitorExtension target (verify in pre-flight). No project.yml change needed.
</interfaces>

<wave0_contingency>
If Plan 01 DISCUSSION-LOG recorded Wave 0 Outcome B or C, DAM extension logic is MOSTLY unchanged (same parse/weekday-filter/store-write logic). The difference is on the MAIN APP side (Plan 03 + Plan 04 register non-repeating DAS + daily re-register). DAM doesn't care whether DAS repeats or not — it reacts to the fire. No adjustment needed here.

ONE edge case: if Outcome C + Plan 04 implements "daily midnight re-register", the DAM on Outcome C cross-midnight schedule fires `.evening` at 22:00 then `.morning` at 00:00 each as SEPARATE one-shot DAS. The timestamp-suffixed marker naming (Plan 01) handles this fine.
</wave0_contingency>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extend DAM extension — schedule intervalDidStart + intervalDidEnd + helpers</name>
  <files>Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift</files>
  <read_first>
    - Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift (entire file — existing session-path handler; preserve all of it verbatim)
    - .planning/phases/03-quick-sessions/03-04-SUMMARY.md §Task 2 (pattern: activity-name filter gate + clearSharedManagedSettingsStore + writeFinalizeMarker + postDarwinNotification — the canonical DAM structure to mirror)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Example 2 (canonical intervalDidStart body — copy the parse/filter/read/write/post sequence, swap overwrite-marker for timestamp-suffixed marker)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-15, §D-16 (exact step list for intervalDidStart and intervalDidEnd)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/SchedulePaths.swift (uses markerURL(timestamp:) — timestamp-suffixed naming)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/ScheduleActivityNames.swift (parse method)
    - DeluluDetox/Sources/Features/AppSelection/Repository/Models/Blocklist.swift (to understand FamilyActivitySelection shape — we decode the full struct)
  </read_first>
  <action>
    Modify `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` in place. Preserve the entire session path (Phase 3 code). Add imports + schedule branches.

    **Edit plan:**

    1. ADD import line at top (after existing imports):
    ```swift
    @preconcurrency import FamilyControls
    ```
    Existing imports preserved: `DeviceActivity`, `Foundation`, `ManagedSettings`, `os`. New 5th import: `FamilyControls` (Option A per `<interfaces>`).

    2. ADD two static Darwin notification names alongside the existing one:
    ```swift
    private static let darwinSessionFinalizedName = "com.kksw.DeluluDetox.sessionFinalized"   // existing
    private static let darwinScheduleStartedName = "com.kksw.DeluluDetox.scheduleStarted"     // NEW
    private static let darwinScheduleEndedName   = "com.kksw.DeluluDetox.scheduleEnded"       // NEW
    ```

    3. REPLACE `intervalDidStart(for:)` — add dispatch:
    ```swift
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart: \(activity.rawValue, privacy: .public)")

        // Phase 5 path — schedule activity.
        if let parsed = ScheduleActivityNames.parse(activity) {
            handleScheduleStart(scheduleId: parsed.scheduleId, segment: parsed.segment)
            return
        }

        // Phase 3 path — quickSession has no intervalDidStart handler; we just log.
        // (No action required; Phase 3 only uses intervalDidEnd.)
    }
    ```

    4. REPLACE `intervalDidEnd(for:)` — add dispatch (preserving session path verbatim):
    ```swift
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("intervalDidEnd: \(activity.rawValue, privacy: .public)")

        // Phase 3 path — quick-session finalize (existing code UNCHANGED below).
        if activity == SessionActivityNames.quickSession {
            clearSharedManagedSettingsStore()
            let sessionId = loadActiveSessionId()
            writeFinalizeMarker(sessionId: sessionId)
            postDarwinNotification()  // existing session darwin
            logger.info("session finalize handoff complete id=\(sessionId.uuidString, privacy: .public)")
            return
        }

        // Phase 5 path — schedule end.
        if let parsed = ScheduleActivityNames.parse(activity) {
            handleScheduleEnd(scheduleId: parsed.scheduleId, segment: parsed.segment)
            return
        }

        logger.info("ignoring unrecognized activity: \(activity.rawValue, privacy: .public)")
    }
    ```

    5. ADD new private methods at the bottom of the class (below existing Phase 3 helpers):

    ```swift
    // MARK: - Phase 5 schedule handlers

    private func handleScheduleStart(scheduleId: UUID, segment: ScheduleSegment) {
        // Step 1: Load schedule by id. If missing or disabled, skip.
        guard let schedule = loadScheduleById(scheduleId) else {
            logger.info("schedule not found id=\(scheduleId.uuidString, privacy: .public); skip apply")
            return
        }
        guard schedule.enabled else {
            logger.info("schedule disabled id=\(scheduleId.uuidString, privacy: .public); skip apply")
            return
        }

        // Step 2: Weekday filter. The relevant weekday depends on segment:
        //   .main / .evening → today's weekday
        //   .morning → yesterday's weekday (the START day of the schedule window)
        let today = Calendar.current.component(.weekday, from: Date())
        let relevantWeekday: Int = {
            switch segment {
            case .main, .evening: return today
            case .morning:
                // roll back 1 day: 1=Sun..7=Sat. today-1 wraps 1 → 7.
                return ((today - 2 + 7) % 7) + 1
            }
        }()
        guard schedule.daysOfWeek.contains(relevantWeekday) else {
            logger.info("schedule id=\(scheduleId.uuidString, privacy: .public) segment=\(segment.rawValue, privacy: .public) weekday=\(relevantWeekday, privacy: .public) NOT in days=\(schedule.daysOfWeek, privacy: .public); skip apply")
            return
        }

        // Step 3: Load blocklist tokens (by schedule.blocklistId).
        guard let tokens = loadBlocklistTokens(blocklistId: schedule.blocklistId) else {
            logger.error("blocklist missing id=\(schedule.blocklistId.uuidString, privacy: .public); skip apply")
            return
        }

        // Step 4: Apply shield to the schedule-named store (D-05, D-15 step 5).
        let store = ManagedSettingsStore(named: .init(ManagedSettingsStoreNames.schedule))
        store.shield.applications = tokens.applicationTokens.isEmpty ? nil : tokens.applicationTokens
        store.shield.webDomains = tokens.webDomainTokens.isEmpty ? nil : tokens.webDomainTokens
        if !tokens.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(tokens.categoryTokens)
        } else {
            store.shield.applicationCategories = nil
        }
        // Clock-skew defense (Plan 03 parity): applyShield also set requireAutomaticDateAndTime=true
        // on main-app path. DAM sets it here too so the protection is in place immediately,
        // even before the main-app self-heal runs.
        store.dateAndTime.requireAutomaticDateAndTime = true

        // Step 5: Write timestamp-suffixed marker + Darwin.
        writeScheduleEventMarker(scheduleId: scheduleId, kind: .started)
        postScheduleDarwin(name: Self.darwinScheduleStartedName)

        logger.info("schedule applied id=\(scheduleId.uuidString, privacy: .public) seg=\(segment.rawValue, privacy: .public) apps=\(tokens.applicationTokens.count, privacy: .public) cats=\(tokens.categoryTokens.count, privacy: .public) web=\(tokens.webDomainTokens.count, privacy: .public)")
    }

    private func handleScheduleEnd(scheduleId: UUID, segment: ScheduleSegment) {
        // Step 1: Clear schedule-named store ONLY (D-05, D-16).
        let store = ManagedSettingsStore(named: .init(ManagedSettingsStoreNames.schedule))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.dateAndTime.requireAutomaticDateAndTime = nil

        // Step 2: Write marker + Darwin.
        writeScheduleEventMarker(scheduleId: scheduleId, kind: .ended)
        postScheduleDarwin(name: Self.darwinScheduleEndedName)

        logger.info("schedule cleared id=\(scheduleId.uuidString, privacy: .public) seg=\(segment.rawValue, privacy: .public)")
    }

    /// Decode only the fields we need from schedule.json.
    private func loadScheduleById(_ id: UUID) -> Schedule? {
        do {
            let url = try SchedulePaths.schedulesURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            let all = try JSONDecoder().decode([Schedule].self, from: data)
            return all.first(where: { $0.id == id })
        } catch {
            logger.error("loadScheduleById failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Decode FamilyActivitySelection tokens from blocklists.json by id.
    /// Uses FamilyControls (imported above) since Set<ApplicationToken> requires the framework.
    private func loadBlocklistTokens(blocklistId: UUID) -> FamilyActivitySelection? {
        do {
            // blocklists.json shape: { "blocklists": [Blocklist...] } or just [Blocklist...]?
            // Inspect Phase 2 BlocklistRepository to confirm on-disk format.
            // Phase 2 uses single-blocklist persistence — file contains `{ ...Blocklist fields... }` not an array.
            let url = try blocklistsURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)

            // Decode minimal envelope matching Phase 2 Blocklist schema:
            struct BlocklistEnvelope: Decodable {
                let id: UUID
                let lastSelection: FamilyActivitySelection
            }
            let blocklist = try JSONDecoder().decode(BlocklistEnvelope.self, from: data)
            guard blocklist.id == blocklistId else {
                logger.info("blocklist id mismatch file=\(blocklist.id.uuidString, privacy: .public) requested=\(blocklistId.uuidString, privacy: .public)")
                return nil
            }
            return blocklist.lastSelection
        } catch {
            logger.error("loadBlocklistTokens failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// App Group URL for blocklists.json.
    /// (Phase 2's BlocklistRepository owns the canonical path; DAM reproduces it locally to avoid importing BlocklistRepository.)
    private func blocklistsURL() throws -> URL {
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.kksw.DeluluDetox"
        ) else {
            throw NSError(domain: "DAM.Blocklist", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group container unavailable"])
        }
        return base.appendingPathComponent("blocklists.json", isDirectory: false)
    }

    /// Write a timestamp-suffixed marker file. Multi-marker naming solves RESEARCH OQ#4
    /// (cross-midnight would overwrite a single marker file between foregrounds).
    private func writeScheduleEventMarker(scheduleId: UUID, kind: ScheduleEventMarker.Kind) {
        let now = Date()
        do {
            let url = try SchedulePaths.markerURL(timestamp: now)
            let marker = ScheduleEventMarker(scheduleId: scheduleId, kind: kind, timestamp: now)
            let data = try JSONEncoder().encode(marker)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            logger.info("schedule marker written kind=\(kind.rawValue, privacy: .public) bytes=\(data.count, privacy: .public)")
        } catch {
            logger.error("schedule marker write failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func postScheduleDarwin(name: String) {
        let cfName = CFNotificationName(name as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            cfName,
            nil,
            nil,
            true
        )
        logger.info("darwin post: \(name, privacy: .public)")
    }
    ```

    6. Verify: `mcp__XcodeBuildMCP__build_sim` scheme=DeluluDetox — extension compiles with all 5 imports + new methods. `mcp__XcodeBuildMCP__test_sim` full suite — 0 failures, 0 regressions in Phase 2/3/4 tests.

    7. Commit: `feat(05-05): extend DAM extension with schedule intervalDidStart + intervalDidEnd handlers`.

    **Blocklist file path verification:** before committing, confirm `blocklists.json` is the actual filename Phase 2 uses. Inspect `DeluluDetox/Sources/Features/AppSelection/Repository/BlocklistRepository.swift` for its path constant. If it differs from `"blocklists.json"`, update the DAM's `blocklistsURL()` helper accordingly.

    **Pre-flight check:** run `grep -c "com.apple.developer.family-controls" project.yml` under the `DeviceActivityMonitorExtension` block to confirm the entitlement exists. It was added in Phase 1 scaffolding. If missing, ADD it and run `xcodegen generate` before compiling.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox — expect 0 failures, full suite green (Plan 04 test count preserved; no new tests this plan since DAM behavior is manual-only per VALIDATION.md)</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "@preconcurrency import FamilyControls" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "^import DeviceActivity$" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "^import ManagedSettings$" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "^import SwiftUI$" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 0 (strict — DAM RAM posture)
    - `grep -c "^import Combine$" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 0
    - `grep -c "ScheduleActivityNames.parse(activity)" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` >= 2 (once in intervalDidStart, once in intervalDidEnd)
    - `grep -c "func handleScheduleStart" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "func handleScheduleEnd" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "func loadScheduleById" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "func loadBlocklistTokens" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "func writeScheduleEventMarker" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "func postScheduleDarwin" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "ManagedSettingsStore(named: .init(ManagedSettingsStoreNames.schedule))" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` >= 2 (apply + clear)
    - `grep -c "com.kksw.DeluluDetox.scheduleStarted" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "com.kksw.DeluluDetox.scheduleEnded" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1
    - `grep -c "SessionActivityNames.quickSession" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` >= 1 (Phase 3 path preserved)
    - `grep -c "SchedulePaths.markerURL(timestamp:" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` == 1 (timestamp-suffixed marker)
    - `mcp__XcodeBuildMCP__build_sim` scheme=DeluluDetox builds green (extension compiles)
    - `mcp__XcodeBuildMCP__test_sim` full suite: 0 failures
  </acceptance_criteria>
  <done>
    DAM extension extended with schedule path. Phase 3 session path untouched. Extension compiles with 5 approved imports. Full test suite green (no regressions). Committed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| DAM process / App Group disk | DAM reads schedule.json + blocklists.json (read-only); writes timestamp-suffixed marker files + modifies ManagedSettingsStore("deluludetox.schedule") |
| DAM process / 6 MB RAM ceiling | Adding FamilyControls import must not blow the budget (Phase 3 empirical posture: ~500 KB used, 5.5 MB headroom) |
| DAM / other DAM activities | Future features may register other DeviceActivityNames; dispatch-by-prefix gates ours from theirs |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-05-05-01 | Denial of Service | DAM exceeds 6 MB with FamilyControls import | mitigate | Test on simulator, observe Console.app RAM usage; if > 5 MB in ordinary operation, revisit (drop FamilyControls import and pivot to Option B — main-app apply) |
| T-05-05-02 | Tampering | Corrupted schedule.json causes handler throw | mitigate | All JSON reads wrapped in do/catch; on fail → log + early return (shield not applied, log trail recorded) |
| T-05-05-03 | Tampering | Corrupted blocklists.json (same) | mitigate | Same do/catch pattern; decoded via lean `BlocklistEnvelope` struct so malformed fields propagate as decode errors |
| T-05-05-04 | Spoofing | Attacker writes bogus schedule activity name | accept | DAM only responds to activities iOS actually registered via DeviceActivityCenter; App Group sandbox prevents external write |
| T-05-05-05 | Information Disclosure | DAM logs token content | mitigate | Logger `.public` on scalar counts only (apps count, cats count, web count); token values NEVER in log messages |
| T-05-05-06 | Elevation of Privilege | DAM clears session store accidentally | mitigate | `handleScheduleEnd` uses `ManagedSettingsStoreNames.schedule` literal; dispatch gate (`ScheduleActivityNames.parse(_:)` returns nil for session) prevents crossover |
| T-05-05-07 | Repudiation | No audit trail for schedule fires | mitigate | Every `handleScheduleStart`/`handleScheduleEnd` writes a marker + posts Darwin + logs; Phase 6 reads events.json for history |
| T-05-05-08 | Denial of Service | Weekday filter wrong for morning segment → shield never applies | mitigate | Weekday resolution handles morning case explicitly (`((today - 2 + 7) % 7) + 1`); ComputeScheduleWindowUseCase (Plan 04) tests provide cross-ref via `testCrossMidnightAfterMidnightActive` |
| T-05-05-09 | Tampering | Marker write succeeds but process crashes before Darwin post | accept | On next foreground, `ConsumeScheduleEventMarkerUseCase` still finds the marker and appends — marker survives crash |
</threat_model>

<verification>
1. Compile check: DAM extension has exactly 5 imports (DeviceActivity + Foundation + ManagedSettings + os + FamilyControls). Zero SwiftUI/Combine.
2. Build succeeds via XcodeBuildMCP (extension links + embeds).
3. Full test suite green — Phase 2/3/4 tests untouched.
4. `ScheduleActivityNames.parse(_:)` is called BEFORE applying any schedule-store logic (dispatch gate integrity).
5. Session path (`activity == SessionActivityNames.quickSession`) is reached ONLY via the existing Phase 3 branch — no accidental interception.
</verification>

<success_criteria>
- DAM extension's single .swift file extended with schedule paths.
- No new files in Extensions/ directory.
- Extension RAM posture preserved (only FamilyControls added).
- Zero regressions in full test suite.
- `ScheduleActivityNames.parse` used for dispatch — no bare string-prefix matching.
- Marker files use `SchedulePaths.markerURL(timestamp:)` — multi-marker safe.
- Both Darwin notifications (`scheduleStarted`, `scheduleEnded`) posted on correct code paths.
- SCH-04 delivered by zero code (ShieldConfigurationExtension renders same shield automatically).
</success_criteria>

<output>
After completion, create `.planning/phases/05-scheduled-blocking/05-05-SUMMARY.md`. Note observed RAM posture (via simulator if feasible) or mark as "real-device UAT deferred to Plan 05-08". Confirm Option A (FamilyControls import) was used or document pivot to Option B.
</output>
