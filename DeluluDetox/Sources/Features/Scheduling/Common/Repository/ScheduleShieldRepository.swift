@preconcurrency import FamilyControls
import Foundation
@preconcurrency import ManagedSettings
import os

// MARK: - Implementation

/// Plan 05-03 — systemic shield writer for scheduled-blocking windows.
///
/// Mirrors `LiveSessionShieldRepository` exactly, with two scheduled-mode
/// differences (both per CONTEXT §D-05 / §D-11):
///  1. The `ManagedSettingsStoreWriter` is constructed with
///     `ManagedSettingsStoreNames.schedule` — a named store isolated from
///     the session store so clearing one never affects the other.
///  2. `applyShield` does NOT set `denyAppRemoval`. Schedules are user-
///     reconfigurable; making app removal impossible during a recurring
///     window contradicts D-11 (disable-from-next-window model).
///
/// The `ManagedSettingsStoreWriter` / `LiveManagedSettingsStoreWriter` types
/// are REUSED from Phase 4 (see `Features/Session/Repository/SessionShieldRepository.swift`).
/// This file deliberately does NOT redefine them.
final class LiveScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable {
    private let store: ManagedSettingsStoreWriter

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ScheduleShieldRepository"
    )

    /// Production convenience init — pins the writer to the schedule-named store.
    /// D-05: session and schedule stores are independent; iOS unions the shields.
    convenience init() {
        self.init(store: LiveManagedSettingsStoreWriter(
            storeName: ManagedSettingsStoreNames.schedule
        ))
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
        let categoryTokens = selection.categoryTokens
        let categoryPolicy: ShieldSettings.ActivityCategoryPolicy<Application>? =
            categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        store.setShieldApplicationCategories(categoryPolicy)

        // WebDomains: direct set of tokens. Empty selection → nil.
        let webTokens = selection.webDomainTokens
        store.setShieldWebDomains(webTokens.isEmpty ? nil : webTokens)

        // Clock-skew bypass defense (RESEARCH §Threat Patterns, anti-bypass §A.8).
        // denyAppRemoval NOT set: schedules are user-reconfigurable (D-11).
        store.setDateAndTimeRequireAutomatic(true)

        Self.log.info(
            "schedule shield applied apps=\(appTokens.count, privacy: .public) cats=\(categoryTokens.count, privacy: .public) web=\(webTokens.count, privacy: .public)"
        )
    }

    func clearShield() async {
        // Unconditional clears — idempotent, never throws.
        store.setShieldApplications(nil)
        store.setShieldApplicationCategories(nil)
        store.setShieldWebDomains(nil)
        store.setDateAndTimeRequireAutomatic(false)
        // Do NOT touch denyAppRemoval — it was never set by this repository.
        Self.log.info("schedule shield cleared")
    }
}
