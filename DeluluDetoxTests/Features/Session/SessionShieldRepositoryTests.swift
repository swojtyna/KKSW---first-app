import XCTest
@preconcurrency import FamilyControls
import ManagedSettings
@testable import DeluluDetox

@MainActor
final class SessionShieldRepositoryTests: XCTestCase {

    // MARK: - Fake

    final class FakeStore: ManagedSettingsStoreWriter, @unchecked Sendable {
        var shieldApplications: Set<ApplicationToken>?
        var shieldApplicationCategories: ShieldSettings.ActivityCategoryPolicy<Application>?
        var shieldWebDomains: Set<WebDomainToken>?
        var dateAndTimeRequireAutomatic: Bool = false
        var applicationDenyAppRemoval: Bool = false

        // Call counters for applyShield invariants.
        private(set) var shieldAppsSetCount = 0
        private(set) var shieldCategoriesSetCount = 0
        private(set) var shieldWebSetCount = 0

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
        }
        func setApplicationDenyAppRemoval(_ value: Bool) {
            applicationDenyAppRemoval = value
        }
    }

    // MARK: - Helpers

    private func makeBlocklist() -> Blocklist {
        Blocklist.empty()   // Simulator cannot produce real tokens.
    }

    // MARK: - applyShield

    func testApplyShieldWritesAllThreeFacetsFromBlocklistLastSelection() async throws {
        let fakeStore = FakeStore()
        let repo = LiveSessionShieldRepository(store: fakeStore)

        try await repo.applyShield(for: makeBlocklist())

        XCTAssertEqual(fakeStore.shieldAppsSetCount, 1)
        XCTAssertEqual(fakeStore.shieldCategoriesSetCount, 1)
        XCTAssertEqual(fakeStore.shieldWebSetCount, 1)
        // Empty selection → all facets nil (zero-token shortcut path).
        XCTAssertNil(fakeStore.shieldApplications)
        XCTAssertNil(fakeStore.shieldApplicationCategories)
        XCTAssertNil(fakeStore.shieldWebDomains)
    }

    func testApplyShieldWritesBothSystemRestrictionFlagsTrue() async throws {
        let fakeStore = FakeStore()
        let repo = LiveSessionShieldRepository(store: fakeStore)
        try await repo.applyShield(for: makeBlocklist())
        XCTAssertTrue(fakeStore.dateAndTimeRequireAutomatic)
        XCTAssertTrue(fakeStore.applicationDenyAppRemoval)
    }

    // MARK: - clearShield

    func testClearShieldRevertsAllFacetsAndBothRestrictions() async throws {
        let fakeStore = FakeStore()
        let repo = LiveSessionShieldRepository(store: fakeStore)
        try await repo.applyShield(for: makeBlocklist())
        await repo.clearShield()

        XCTAssertNil(fakeStore.shieldApplications)
        XCTAssertNil(fakeStore.shieldApplicationCategories)
        XCTAssertNil(fakeStore.shieldWebDomains)
        XCTAssertFalse(fakeStore.dateAndTimeRequireAutomatic)
        XCTAssertFalse(fakeStore.applicationDenyAppRemoval)
    }

    func testClearShieldIsSafeToCallWhenNothingWasApplied() async {
        let fakeStore = FakeStore()
        let repo = LiveSessionShieldRepository(store: fakeStore)
        await repo.clearShield()
        XCTAssertNil(fakeStore.shieldApplications)
        XCTAssertFalse(fakeStore.dateAndTimeRequireAutomatic)
        XCTAssertFalse(fakeStore.applicationDenyAppRemoval)
    }
}
