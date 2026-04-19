import Combine
@preconcurrency import DeviceActivity
@preconcurrency import FamilyControls
import Foundation
@preconcurrency import ManagedSettings
import os

// MARK: - Errors

enum SessionEnforcerError: Error {
    case deviceActivityStartFailed(Error)
}

// MARK: - Protocol

protocol SessionEnforcer: Sendable {
    /// Write all three shield facets from `blocklist.lastSelection` PLUS the two
    /// CONTEXT §D-10 system-level friction flags (requireAutomaticDateAndTime +
    /// denyAppRemoval). Idempotent — re-applying overwrites prior values.
    func applyShield(for blocklist: Blocklist) async throws

    /// Revert all three shield facets to nil AND clear both system restrictions.
    /// Safe to call when no shield is active.
    func clearShield() async

    /// Schedule a non-repeating DeviceActivitySchedule terminating at
    /// `session.plannedEndAt`. The DAM extension receives `intervalDidEnd`.
    func startActivityMonitoring(for session: SessionRecord) async throws

    /// Stop monitoring the quick-session activity. No-op if not monitoring.
    func stopActivityMonitoring() async
}

// MARK: - Internal seams (testable)

/// Narrow facet of ManagedSettingsStore used by SessionEnforcer. Avoids
/// depending on the full ManagedSettingsStore concrete type in tests (it is
/// not Sendable and not mockable in the iOS 26.3 SDK without this seam).
protocol ManagedSettingsStoreWriter: AnyObject, Sendable {
    func setShieldApplications(_ tokens: Set<ApplicationToken>?)
    /// Pass nil to clear the applicationCategories shield facet.
    func setShieldApplicationCategories(_ setting: ShieldSettings.ActivityCategoryPolicy<Application>?)
    func setShieldWebDomains(_ tokens: Set<WebDomainToken>?)
    func setDateAndTimeRequireAutomatic(_ value: Bool)
    func setApplicationDenyAppRemoval(_ value: Bool)
}

/// Narrow facet of DeviceActivityCenter used by SessionEnforcer. Same rationale
/// as `ManagedSettingsStoreWriter` — keep the seam small and testable.
protocol DeviceActivityCenterRunner: AnyObject, Sendable {
    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

// MARK: - Production adapters

final class LiveManagedSettingsStoreWriter: ManagedSettingsStoreWriter, @unchecked Sendable {
    private let store: ManagedSettingsStore

    init(storeName: String = "deluludetox.session") {
        self.store = ManagedSettingsStore(named: .init(storeName))
    }

    func setShieldApplications(_ tokens: Set<ApplicationToken>?) {
        store.shield.applications = tokens
    }

    func setShieldApplicationCategories(_ setting: ShieldSettings.ActivityCategoryPolicy<Application>?) {
        store.shield.applicationCategories = setting
    }

    func setShieldWebDomains(_ tokens: Set<WebDomainToken>?) {
        store.shield.webDomains = tokens
    }

    func setDateAndTimeRequireAutomatic(_ value: Bool) {
        // API is Bool? — nil means unrestricted. true = require automatic date/time.
        store.dateAndTime.requireAutomaticDateAndTime = value ? true : nil
    }

    func setApplicationDenyAppRemoval(_ value: Bool) {
        // API is Bool? — nil means unrestricted. true = deny removal.
        store.application.denyAppRemoval = value ? true : nil
    }
}

final class LiveDeviceActivityCenterRunner: DeviceActivityCenterRunner, @unchecked Sendable {
    private let center = DeviceActivityCenter()

    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
        try center.startMonitoring(activity, during: schedule)
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        center.stopMonitoring(activities)
    }
}

// MARK: - Implementation

final class SessionEnforcerImpl: SessionEnforcer, @unchecked Sendable {
    private let store: ManagedSettingsStoreWriter
    private let center: DeviceActivityCenterRunner

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "SessionEnforcer"
    )

    /// Production convenience init uses real ManagedSettingsStore + DeviceActivityCenter.
    convenience init() {
        self.init(
            store: LiveManagedSettingsStoreWriter(),
            center: LiveDeviceActivityCenterRunner()
        )
    }

    /// Test seam — accepts protocol-wrapped doubles for both dependencies.
    init(store: ManagedSettingsStoreWriter, center: DeviceActivityCenterRunner) {
        self.store = store
        self.center = center
    }

    // MARK: applyShield

    func applyShield(for blocklist: Blocklist) async throws {
        let selection = blocklist.lastSelection

        // Apps: direct set of tokens. Empty selection → nil (no shield facet).
        let appTokens = selection.applicationTokens
        store.setShieldApplications(appTokens.isEmpty ? nil : appTokens)

        // Categories: .specific wrapper per iOS ManagedSettings ActivityCategoryPolicy.
        // SDK type: ShieldSettings.ActivityCategoryPolicy<Application>
        let categoryTokens = selection.categoryTokens
        let categoryPolicy: ShieldSettings.ActivityCategoryPolicy<Application>? =
            categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        store.setShieldApplicationCategories(categoryPolicy)

        // WebDomains: direct set of tokens. Empty selection → nil.
        let webTokens = selection.webDomainTokens
        store.setShieldWebDomains(webTokens.isEmpty ? nil : webTokens)

        // System-level friction (CONTEXT §D-10, QSN-05).
        // requireAutomaticDateAndTime defeats clock-skew bypass (research §A.8).
        // denyAppRemoval defeats delete-and-reinstall (research §A.4).
        store.setDateAndTimeRequireAutomatic(true)
        store.setApplicationDenyAppRemoval(true)

        Self.log.info(
            "shield applied apps=\(appTokens.count, privacy: .public) cats=\(categoryTokens.count, privacy: .public) web=\(webTokens.count, privacy: .public)"
        )
    }

    // MARK: clearShield

    func clearShield() async {
        // Unconditional clears — idempotent, never throws (CONTEXT §D-08, assumption 6).
        store.setShieldApplications(nil)
        store.setShieldApplicationCategories(nil)
        store.setShieldWebDomains(nil)
        store.setDateAndTimeRequireAutomatic(false)
        store.setApplicationDenyAppRemoval(false)
        Self.log.info("shield cleared")
    }

    // MARK: startActivityMonitoring

    func startActivityMonitoring(for session: SessionRecord) async throws {
        let startComponents = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: session.startedAt
        )
        let endComponents = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: session.plannedEndAt
        )
        // One-shot schedule: repeats=false fires intervalDidEnd exactly once (CONTEXT §D-01).
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        do {
            try center.startMonitoring(SessionActivityNames.quickSession, during: schedule)
            Self.log.info(
                "activity monitoring started id=\(session.id.uuidString, privacy: .public) end=\(session.plannedEndAt.timeIntervalSince1970, privacy: .public)"
            )
        } catch {
            Self.log.error("startMonitoring failed: \(String(describing: error), privacy: .public)")
            throw SessionEnforcerError.deviceActivityStartFailed(error)
        }
    }

    // MARK: stopActivityMonitoring

    func stopActivityMonitoring() async {
        center.stopMonitoring([SessionActivityNames.quickSession])
        Self.log.info("activity monitoring stopped")
    }
}
