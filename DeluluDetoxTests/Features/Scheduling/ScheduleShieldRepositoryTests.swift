import XCTest
@preconcurrency import FamilyControls
import ManagedSettings
@testable import DeluluDetox

/// Plan 05-03 Task 1 — ScheduleShieldRepository targets the `deluludetox.schedule`
/// named store exclusively; clearing session store never touches schedule shield (D-05).
@MainActor
final class ScheduleShieldRepositoryTests: XCTestCase {

    // MARK: - Fake writer

    /// Mirrors `SessionShieldRepositoryTests.FakeStore`. Captures facet writes +
    /// the two system-level flags so Plan 05-03 can assert denyAppRemoval is
    /// NEVER touched (D-11 — schedules are user-reconfigurable).
    final class FakeStore: ManagedSettingsStoreWriter, @unchecked Sendable {
        var shieldApplications: Set<ApplicationToken>?
        var shieldApplicationCategories: ShieldSettings.ActivityCategoryPolicy<Application>?
        var shieldWebDomains: Set<WebDomainToken>?
        var dateAndTimeRequireAutomatic: Bool = false
        var applicationDenyAppRemoval: Bool = false

        private(set) var shieldAppsSetCount = 0
        private(set) var shieldCategoriesSetCount = 0
        private(set) var shieldWebSetCount = 0
        private(set) var dateAndTimeSetCount = 0
        private(set) var denyAppRemovalSetCount = 0

        func setShieldApplications(_ tokens: Set<ApplicationToken>?) {
            shieldApplications = tokens
            shieldAppsSetCount += 1
        }
        func setShieldApplicationCategories(_ setting: ShieldSettings.ActivityCategoryPolicy<Application>?) {
            shieldApplicationCategories = setting
            shieldCategoriesSetCount += 1
        }
        func setShieldWebDomains(_ tokens: Set<WebDomainToken>?) {
            shieldWebDomains = tokens
            shieldWebSetCount += 1
        }
        func setDateAndTimeRequireAutomatic(_ value: Bool) {
            dateAndTimeRequireAutomatic = value
            dateAndTimeSetCount += 1
        }
        func setApplicationDenyAppRemoval(_ value: Bool) {
            applicationDenyAppRemoval = value
            denyAppRemovalSetCount += 1
        }
    }

    // MARK: - Helpers

    private func makeBlocklist() -> Blocklist {
        // Simulator cannot mint real FamilyControls tokens; empty selection still
        // exercises all three facet-set paths (which receive nil). For token-count
        // assertions we rely on the shieldAppsSetCount / shieldCategoriesSetCount /
        // shieldWebSetCount counters, not on decoded token-set sizes.
        Blocklist.empty()
    }

    // MARK: - applyShield

    func testApplyShieldWritesTokensToScheduleNamedStoreOnly() async throws {
        let fakeStore = FakeStore()
        let repo = LiveScheduleShieldRepository(store: fakeStore)

        try await repo.applyShield(for: makeBlocklist())

        // All three facet-writers hit exactly once (even on empty selection —
        // the repo always calls the setters and maps empty → nil internally).
        XCTAssertEqual(fakeStore.shieldAppsSetCount, 1)
        XCTAssertEqual(fakeStore.shieldCategoriesSetCount, 1)
        XCTAssertEqual(fakeStore.shieldWebSetCount, 1)
        // Empty selection → all facets nil (zero-token shortcut path).
        XCTAssertNil(fakeStore.shieldApplications)
        XCTAssertNil(fakeStore.shieldApplicationCategories)
        XCTAssertNil(fakeStore.shieldWebDomains)
    }

    func testApplyShieldWritesRequireAutomaticDateAndTime() async throws {
        let fakeStore = FakeStore()
        let repo = LiveScheduleShieldRepository(store: fakeStore)
        try await repo.applyShield(for: makeBlocklist())
        XCTAssertTrue(fakeStore.dateAndTimeRequireAutomatic,
                      "Clock-skew bypass defense (RESEARCH §Threat Patterns) must be armed on schedule apply.")
        // denyAppRemoval is NOT set by ScheduleShieldRepository (D-11 — schedules
        // are user-reconfigurable by design, differs from SessionShieldRepository).
        XCTAssertEqual(fakeStore.denyAppRemovalSetCount, 0)
    }

    // MARK: - clearShield

    func testClearShieldResetsAllFacetsAndRestrictions() async throws {
        let fakeStore = FakeStore()
        let repo = LiveScheduleShieldRepository(store: fakeStore)
        try await repo.applyShield(for: makeBlocklist())
        await repo.clearShield()

        XCTAssertNil(fakeStore.shieldApplications)
        XCTAssertNil(fakeStore.shieldApplicationCategories)
        XCTAssertNil(fakeStore.shieldWebDomains)
        XCTAssertFalse(fakeStore.dateAndTimeRequireAutomatic)
        // denyAppRemoval MUST stay untouched across the full apply/clear cycle.
        XCTAssertEqual(fakeStore.denyAppRemovalSetCount, 0)
    }

    // MARK: - Store name isolation

    func testStoreNameIsolationFromSessionStore() {
        // The literal `deluludetox.schedule` is the cross-process contract between
        // main app (this repository) and the DAM extension (Plan 05-05 writer).
        // Drift would silently break SCH-03. We assert via the canonical constant.
        XCTAssertEqual(ManagedSettingsStoreNames.schedule, "deluludetox.schedule")
        XCTAssertEqual(ManagedSettingsStoreNames.session, "deluludetox.session")
        XCTAssertNotEqual(ManagedSettingsStoreNames.schedule, ManagedSettingsStoreNames.session)
    }
}
