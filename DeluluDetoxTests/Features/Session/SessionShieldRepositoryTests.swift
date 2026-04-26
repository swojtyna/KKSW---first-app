import Foundation
@preconcurrency import FamilyControls
import ManagedSettings
import Testing
@testable import DeluluDetox

@Suite("LiveSessionShieldRepository")
@MainActor
struct SessionShieldRepositoryTests {

    final class FakeStore: ManagedSettingsStoreWriter, @unchecked Sendable {
        var shieldApplications: Set<ApplicationToken>?
        var shieldApplicationCategories: ShieldSettings.ActivityCategoryPolicy<Application>?
        var shieldWebDomains: Set<WebDomainToken>?
        var dateAndTimeRequireAutomatic: Bool = false
        var applicationDenyAppRemoval: Bool = false

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

    // MARK: - applyShield

    @Test("applyShield writes all three facets from blocklist lastSelection")
    func applyShieldWritesAllThreeFacetsFromBlocklistLastSelection() async throws {
        let fakeStore = FakeStore()
        let repo = LiveSessionShieldRepository(store: fakeStore)

        try await repo.applyShield(for: makeBlocklist())

        #expect(fakeStore.shieldAppsSetCount == 1)
        #expect(fakeStore.shieldCategoriesSetCount == 1)
        #expect(fakeStore.shieldWebSetCount == 1)
        #expect(fakeStore.shieldApplications == nil)
        #expect(fakeStore.shieldApplicationCategories == nil)
        #expect(fakeStore.shieldWebDomains == nil)
    }

    @Test("applyShield writes both system restriction flags to true")
    func applyShieldWritesBothSystemRestrictionFlagsTrue() async throws {
        let fakeStore = FakeStore()
        let repo = LiveSessionShieldRepository(store: fakeStore)
        try await repo.applyShield(for: makeBlocklist())
        #expect(fakeStore.dateAndTimeRequireAutomatic)
        #expect(fakeStore.applicationDenyAppRemoval)
    }

    // MARK: - clearShield

    @Test("clearShield reverts all facets and both restrictions")
    func clearShieldRevertsAllFacetsAndBothRestrictions() async throws {
        let fakeStore = FakeStore()
        let repo = LiveSessionShieldRepository(store: fakeStore)
        try await repo.applyShield(for: makeBlocklist())
        await repo.clearShield()

        #expect(fakeStore.shieldApplications == nil)
        #expect(fakeStore.shieldApplicationCategories == nil)
        #expect(fakeStore.shieldWebDomains == nil)
        #expect(!fakeStore.dateAndTimeRequireAutomatic)
        #expect(!fakeStore.applicationDenyAppRemoval)
    }

    @Test("clearShield is safe to call when nothing was applied")
    func clearShieldIsSafeToCallWhenNothingWasApplied() async {
        let fakeStore = FakeStore()
        let repo = LiveSessionShieldRepository(store: fakeStore)
        await repo.clearShield()
        #expect(fakeStore.shieldApplications == nil)
        #expect(!fakeStore.dateAndTimeRequireAutomatic)
        #expect(!fakeStore.applicationDenyAppRemoval)
    }
}

// MARK: - Private Helpers

private extension SessionShieldRepositoryTests {
    func makeBlocklist() -> Blocklist {
        Blocklist.empty()
    }
}
