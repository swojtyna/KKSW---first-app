import DeviceActivity
@preconcurrency import FamilyControls
import Foundation
import ManagedSettings
import os

/// DeviceActivityMonitor extension — runs out-of-process with a 6 MB RAM
/// ceiling. Handles `intervalDidEnd` for `SessionActivityNames.quickSession`
/// to:
///   1. Clear the shared `ManagedSettingsStore(named: "deluludetox.session")`
///      (the same named store the main app's `SessionEnforcer` writes to).
///   2. Write a `SessionFinalizeMarker` into the App Group container at
///      `SessionPaths.finalizeMarkerURL()`.
///   3. Post a Darwin notification so the main app wakes up (if foregrounded)
///      and reconciles `sessions.json`.
///
/// Phase 5 — schedule dispatch path added (CONTEXT §D-05, §D-15, §D-16).
/// Activity names prefixed with `deluludetox.schedule.` route to the schedule
/// handlers which apply/clear `ManagedSettingsStore(named: "deluludetox.schedule")`,
/// write timestamp-suffixed marker files, and post Darwin notifications
/// (`scheduleStarted` / `scheduleEnded`). Phase 3 session path is untouched.
///
/// CONTEXT §D-01 canonical Apple/Opal/Foqos pattern.
///
/// RAM posture: FamilyControls added (Phase 5 Plan 05-05 Option A) so the
/// extension can decode `FamilyActivitySelection` tokens from `blocklists.json`
/// and write them into the schedule-named store. Phase 3 empirical baseline
/// (~500 KB) leaves ample 6 MB headroom for the added framework import.
/// No SwiftUI / Combine / networking imports.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox.DeviceActivityMonitorExtension",
        category: "Monitor"
    )

    /// Darwin notification names the main app listens for on foreground.
    /// Kept as literal strings (CoreFoundation API predates Sendable).
    private static let darwinSessionFinalizedName = "com.kksw.DeluluDetox.sessionFinalized"
    private static let darwinScheduleStartedName = "com.kksw.DeluluDetox.scheduleStarted"
    private static let darwinScheduleEndedName = "com.kksw.DeluluDetox.scheduleEnded"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart: \(activity.rawValue, privacy: .public)")

        // Phase 5 path — schedule activity.
        if let parsed = ScheduleActivityNames.parse(activity) {
            handleScheduleStart(scheduleId: parsed.scheduleId, segment: parsed.segment)
            return
        }

        // Phase 3 path — quickSession has no intervalDidStart handler; log only.
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("intervalDidEnd: \(activity.rawValue, privacy: .public)")

        // Phase 3 path — quick-session finalize (UNCHANGED from original).
        if activity == SessionActivityNames.quickSession {
            // Step 1: clear the shared ManagedSettingsStore (main app and DAM share by name).
            clearSharedManagedSettingsStore()

            // Step 2: discover the active session id so the marker can carry it.
            let sessionId = loadActiveSessionId()

            // Step 3: write the finalize marker.
            writeFinalizeMarker(sessionId: sessionId)

            // Step 4: Darwin notification so a foregrounded main app can react fast.
            postDarwinNotification()

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

    // MARK: - Phase 3 session helpers (UNCHANGED)

    private func clearSharedManagedSettingsStore() {
        let store = ManagedSettingsStore(named: .init(ManagedSettingsStoreNames.session))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.dateAndTime.requireAutomaticDateAndTime = false
        store.application.denyAppRemoval = false
        logger.info("store cleared")
    }

    private func loadActiveSessionId() -> UUID {
        let sentinel = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

        do {
            let url = try SessionPaths.activeSessionURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                logger.info("active_session.json missing; using sentinel id")
                return sentinel
            }
            let data = try Data(contentsOf: url)

            // We cannot import SessionRecord here without bringing FamilyControls-adjacent
            // symbols into the lean extension target. Decode only the `id` field via a
            // tiny local struct. Extension-side schema coupling is acceptable because
            // SessionRecord.id is the first-class identifier and unlikely to rename.
            struct SessionIdEnvelope: Decodable { let id: UUID }
            let envelope = try JSONDecoder().decode(SessionIdEnvelope.self, from: data)
            return envelope.id
        } catch {
            logger.error("failed to load active session id: \(String(describing: error), privacy: .public)")
            return sentinel
        }
    }

    private func writeFinalizeMarker(sessionId: UUID) {
        do {
            let url = try SessionPaths.finalizeMarkerURL()
            let marker = SessionFinalizeMarker(
                sessionId: sessionId,
                finalizedAt: Date(),
                source: .damIntervalDidEnd
            )
            let data = try JSONEncoder().encode(marker)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            logger.info("marker written bytes=\(data.count, privacy: .public)")
        } catch {
            logger.error("marker write failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func postDarwinNotification() {
        let name = CFNotificationName(Self.darwinSessionFinalizedName as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            name,
            nil,
            nil,
            true
        )
        logger.info("darwin post: \(Self.darwinSessionFinalizedName, privacy: .public)")
    }

    // MARK: - Phase 5 schedule handlers

    /// `intervalDidStart(for:)` on a schedule activity.
    /// Steps: load schedule → weekday-filter → load blocklist tokens →
    /// write schedule-named store → write timestamp-suffixed marker → post Darwin.
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

        // Step 2: Weekday filter (D-15 step 3). The relevant weekday depends on segment:
        //   .main / .evening → today's weekday (the schedule's start day).
        //   .morning → yesterday's weekday (morning fires on the NEXT calendar day,
        //     but the weekday filter applies to the evening-start day per spec).
        let today = Calendar.current.component(.weekday, from: Date())
        let relevantWeekday: Int = {
            switch segment {
            case .main, .evening: return today
            case .morning:
                // Roll back 1 day: 1=Sun..7=Sat. Map today → previous weekday; wraps 1 → 7.
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

        // Step 4: Apply shield to the SCHEDULE-named store (D-05, D-15 step 5).
        // Never touches the session store — clearing semantics are independent (D-05).
        let store = ManagedSettingsStore(named: .init(ManagedSettingsStoreNames.schedule))
        store.shield.applications = tokens.applicationTokens.isEmpty ? nil : tokens.applicationTokens
        store.shield.webDomains = tokens.webDomainTokens.isEmpty ? nil : tokens.webDomainTokens
        if !tokens.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(tokens.categoryTokens)
        } else {
            store.shield.applicationCategories = nil
        }
        // Clock-skew defense (Plan 03 parity): protect immediately even before
        // the main-app self-heal runs.
        store.dateAndTime.requireAutomaticDateAndTime = true

        // Step 5: Write timestamp-suffixed marker + Darwin.
        writeScheduleEventMarker(scheduleId: scheduleId, kind: .started)
        postScheduleDarwin(name: Self.darwinScheduleStartedName)

        logger.info("schedule applied id=\(scheduleId.uuidString, privacy: .public) seg=\(segment.rawValue, privacy: .public) apps=\(tokens.applicationTokens.count, privacy: .public) cats=\(tokens.categoryTokens.count, privacy: .public) web=\(tokens.webDomainTokens.count, privacy: .public)")
    }

    /// `intervalDidEnd(for:)` on a schedule activity.
    /// Clears ONLY the schedule-named store (D-05, D-16), then marker + Darwin.
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

    /// Load a single `Schedule` by id from the shared `schedule.json` array.
    /// Returns nil on missing file / decode failure / id not found.
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

    /// Decode `FamilyActivitySelection` tokens from `blocklists.json` by id.
    /// Uses the `FamilyControls` import (top-level) since
    /// `Set<ApplicationToken>` / `Set<WebDomainToken>` / `Set<ActivityCategoryToken>`
    /// require the framework. Lean `BlocklistEnvelope` avoids pulling the full
    /// Phase 2 `Blocklist` struct into the DAM target.
    private func loadBlocklistTokens(blocklistId: UUID) -> FamilyActivitySelection? {
        do {
            let url = try blocklistsURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)

            // Minimal envelope matching the subset of Phase 2 `Blocklist` we need.
            // `blocklists.json` persists a single Blocklist object (not an array —
            // see BlocklistRepositoryImpl.writeAndEmit).
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

    /// App Group URL for `blocklists.json`.
    /// Reproduced locally so the DAM target doesn't need to import `BlocklistRepository`
    /// (and its Combine dependency). Path must match Phase 2's
    /// `BlocklistRepositoryImpl.appGroupIdentifier` + `fileName`.
    private func blocklistsURL() throws -> URL {
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.kksw.DeluluDetox"
        ) else {
            throw NSError(
                domain: "DAM.Blocklist",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "App Group container unavailable"]
            )
        }
        return base.appendingPathComponent("blocklists.json", isDirectory: false)
    }

    /// Write a timestamp-suffixed marker file. Multi-marker naming solves
    /// RESEARCH OQ#4 (cross-midnight `.evening` + `.morning` events would
    /// overwrite a single marker file between foregrounds). The main app
    /// consumes via `ScheduleRepository.consumeEventMarkers()`.
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
}
