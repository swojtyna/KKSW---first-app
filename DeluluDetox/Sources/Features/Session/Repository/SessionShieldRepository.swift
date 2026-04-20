@preconcurrency import FamilyControls
import Foundation
@preconcurrency import ManagedSettings
import os

// MARK: - Protocol

/// Data-layer facade over `ManagedSettingsStore` for session shield writes.
/// Split from the legacy `SessionEnforcer` to honor the "1 aggregate = 1 repository"
/// rule — shield application/clearing is a separate aggregate from DeviceActivity
/// monitoring.
protocol SessionShieldRepository: Sendable {
    /// Write all three shield facets from `blocklist.lastSelection` PLUS the two
    /// CONTEXT §D-10 system-level friction flags (requireAutomaticDateAndTime +
    /// denyAppRemoval). Idempotent — re-applying overwrites prior values.
    func applyShield(for blocklist: Blocklist) async throws

    /// Revert all three shield facets to nil AND clear both system restrictions.
    /// Safe to call when no shield is active.
    func clearShield() async
}

// MARK: - Internal seam (testable)

/// Narrow facet of ManagedSettingsStore used by the shield repository. Avoids
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

// MARK: - Production adapter

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

// MARK: - Implementation

final class LiveSessionShieldRepository: SessionShieldRepository, @unchecked Sendable {
    private let store: ManagedSettingsStoreWriter

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "SessionShieldRepository"
    )

    /// Production convenience init uses real ManagedSettingsStore via the Live writer.
    convenience init() {
        self.init(store: LiveManagedSettingsStoreWriter())
    }

    /// Test seam — accepts a protocol-wrapped writer double.
    init(store: ManagedSettingsStoreWriter) {
        self.store = store
    }

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

    func clearShield() async {
        // Unconditional clears — idempotent, never throws (CONTEXT §D-08, assumption 6).
        store.setShieldApplications(nil)
        store.setShieldApplicationCategories(nil)
        store.setShieldWebDomains(nil)
        store.setDateAndTimeRequireAutomatic(false)
        store.setApplicationDenyAppRemoval(false)
        Self.log.info("shield cleared")
    }
}
