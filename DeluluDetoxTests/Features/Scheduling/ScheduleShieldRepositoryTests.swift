import Foundation
@preconcurrency import FamilyControls
import ManagedSettings
import Testing
@testable import DeluluDetox

/// Plan 05-03 Task 1 — ScheduleShieldRepository targets the `deluludetox.schedule`
/// named store exclusively; clearing session store never touches schedule shield (D-05).
@Suite("LiveScheduleShieldRepository")
@MainActor
struct ScheduleShieldRepositoryTests {

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

    // MARK: - applyShield

    @Test("applyShield writes tokens to schedule named store only")
    func applyShieldWritesTokensToScheduleNamedStoreOnly() async throws {
        let fakeStore = FakeStore()
        let repo = LiveScheduleShieldRepository(store: fakeStore)

        try await repo.applyShield(for: makeBlocklist())

        #expect(fakeStore.shieldAppsSetCount == 1)
        #expect(fakeStore.shieldCategoriesSetCount == 1)
        #expect(fakeStore.shieldWebSetCount == 1)
        #expect(fakeStore.shieldApplications == nil)
        #expect(fakeStore.shieldApplicationCategories == nil)
        #expect(fakeStore.shieldWebDomains == nil)
    }

    @Test("applyShield writes requireAutomaticDateAndTime but NOT denyAppRemoval")
    func applyShieldWritesRequireAutomaticDateAndTime() async throws {
        let fakeStore = FakeStore()
        let repo = LiveScheduleShieldRepository(store: fakeStore)
        try await repo.applyShield(for: makeBlocklist())
        #expect(fakeStore.dateAndTimeRequireAutomatic,
                "Clock-skew bypass defense (RESEARCH §Threat Patterns) must be armed on schedule apply.")
        #expect(fakeStore.denyAppRemovalSetCount == 0,
                "Schedules are user-reconfigurable by design, differs from SessionShieldRepository (D-11).")
    }

    // MARK: - clearShield

    @Test("clearShield resets all facets and restrictions")
    func clearShieldResetsAllFacetsAndRestrictions() async throws {
        let fakeStore = FakeStore()
        let repo = LiveScheduleShieldRepository(store: fakeStore)
        try await repo.applyShield(for: makeBlocklist())
        await repo.clearShield()

        #expect(fakeStore.shieldApplications == nil)
        #expect(fakeStore.shieldApplicationCategories == nil)
        #expect(fakeStore.shieldWebDomains == nil)
        #expect(!fakeStore.dateAndTimeRequireAutomatic)
        #expect(fakeStore.denyAppRemovalSetCount == 0)
    }

    // MARK: - Store name isolation

    @Test("schedule and session store names are distinct and match contract")
    func storeNameIsolationFromSessionStore() {
        #expect(ManagedSettingsStoreNames.schedule == "deluludetox.schedule")
        #expect(ManagedSettingsStoreNames.session == "deluludetox.session")
        #expect(ManagedSettingsStoreNames.schedule != ManagedSettingsStoreNames.session)
    }
}

// MARK: - Private Helpers

private extension ScheduleShieldRepositoryTests {
    func makeBlocklist() -> Blocklist {
        Blocklist.empty()
    }
}
