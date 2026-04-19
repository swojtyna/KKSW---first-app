import DeviceActivity
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
/// CONTEXT §D-01 canonical Apple/Opal/Foqos pattern.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox.DeviceActivityMonitorExtension",
        category: "Monitor"
    )

    /// Darwin notification name the main app listens for on foreground.
    /// Kept as a literal string (CoreFoundation API predates Sendable).
    private static let darwinSessionFinalizedName = "com.kksw.DeluluDetox.sessionFinalized"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart: \(activity.rawValue, privacy: .public)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("intervalDidEnd: \(activity.rawValue, privacy: .public)")

        // Filter: only react to the quick-session activity. Phase 5 schedules
        // will use a different name; this handler must ignore them.
        guard activity == SessionActivityNames.quickSession else {
            logger.info("ignoring non-session activity: \(activity.rawValue, privacy: .public)")
            return
        }

        // Step 1: clear the shared ManagedSettingsStore (main app and DAM share by name).
        clearSharedManagedSettingsStore()

        // Step 2: discover the active session id so the marker can carry it.
        let sessionId = loadActiveSessionId()

        // Step 3: write the finalize marker.
        writeFinalizeMarker(sessionId: sessionId)

        // Step 4: Darwin notification so a foregrounded main app can react fast.
        postDarwinNotification()

        logger.info("session finalize handoff complete id=\(sessionId.uuidString, privacy: .public)")
    }

    // MARK: - Helpers

    private func clearSharedManagedSettingsStore() {
        let store = ManagedSettingsStore(named: .init("deluludetox.session"))
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
}
