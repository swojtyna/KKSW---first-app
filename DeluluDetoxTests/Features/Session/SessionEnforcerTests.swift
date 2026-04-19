import XCTest
import DeviceActivity
@preconcurrency import FamilyControls
import ManagedSettings
@testable import DeluluDetox

@MainActor
final class SessionEnforcerTests: XCTestCase {

    // MARK: - Fakes

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

    final class FakeCenter: DeviceActivityCenterRunner, @unchecked Sendable {
        var startedActivities: [DeviceActivityName] = []
        var startedSchedules: [DeviceActivitySchedule] = []
        var stoppedActivities: [DeviceActivityName] = []
        var startError: Error?

        func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
            if let startError { throw startError }
            startedActivities.append(activity)
            startedSchedules.append(schedule)
        }
        func stopMonitoring(_ activities: [DeviceActivityName]) {
            stoppedActivities.append(contentsOf: activities)
        }
    }

    struct TestError: Error, Equatable {}

    // MARK: - Helpers

    private func makeBlocklist() -> Blocklist {
        Blocklist.empty()   // Simulator cannot produce real tokens.
    }

    private func makeSession(startingAt: Date = Date(), durationSeconds: Int = 1800) -> SessionRecord {
        SessionRecord(
            blocklistId: UUID(),
            startedAt: startingAt,
            plannedEndAt: startingAt.addingTimeInterval(TimeInterval(durationSeconds)),
            plannedDurationSeconds: durationSeconds,
            appVersion: "test"
        )
    }

    // MARK: - applyShield

    func testApplyShieldWritesAllThreeFacetsFromBlocklistLastSelection() async throws {
        let fakeStore = FakeStore()
        let fakeCenter = FakeCenter()
        let enforcer = SessionEnforcerImpl(store: fakeStore, center: fakeCenter)

        try await enforcer.applyShield(for: makeBlocklist())

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
        let enforcer = SessionEnforcerImpl(store: fakeStore, center: FakeCenter())
        try await enforcer.applyShield(for: makeBlocklist())
        XCTAssertTrue(fakeStore.dateAndTimeRequireAutomatic)
        XCTAssertTrue(fakeStore.applicationDenyAppRemoval)
    }

    // MARK: - clearShield

    func testClearShieldRevertsAllFacetsAndBothRestrictions() async throws {
        let fakeStore = FakeStore()
        let enforcer = SessionEnforcerImpl(store: fakeStore, center: FakeCenter())
        try await enforcer.applyShield(for: makeBlocklist())
        await enforcer.clearShield()

        XCTAssertNil(fakeStore.shieldApplications)
        XCTAssertNil(fakeStore.shieldApplicationCategories)
        XCTAssertNil(fakeStore.shieldWebDomains)
        XCTAssertFalse(fakeStore.dateAndTimeRequireAutomatic)
        XCTAssertFalse(fakeStore.applicationDenyAppRemoval)
    }

    func testClearShieldIsSafeToCallWhenNothingWasApplied() async {
        let fakeStore = FakeStore()
        let enforcer = SessionEnforcerImpl(store: fakeStore, center: FakeCenter())
        await enforcer.clearShield()
        XCTAssertNil(fakeStore.shieldApplications)
        XCTAssertFalse(fakeStore.dateAndTimeRequireAutomatic)
        XCTAssertFalse(fakeStore.applicationDenyAppRemoval)
    }

    // MARK: - startActivityMonitoring

    func testStartActivityMonitoringInvokesCenterWithQuickSessionNameAndNonRepeatingSchedule() async throws {
        let fakeCenter = FakeCenter()
        let enforcer = SessionEnforcerImpl(store: FakeStore(), center: fakeCenter)
        let session = makeSession(durationSeconds: 30 * 60)

        try await enforcer.startActivityMonitoring(for: session)

        XCTAssertEqual(fakeCenter.startedActivities, [SessionActivityNames.quickSession])
        XCTAssertEqual(fakeCenter.startedSchedules.count, 1)
        XCTAssertEqual(fakeCenter.startedSchedules.first?.repeats, false)
    }

    func testStartActivityMonitoringThrowsWrappedErrorWhenCenterThrows() async {
        let fakeCenter = FakeCenter()
        fakeCenter.startError = TestError()
        let enforcer = SessionEnforcerImpl(store: FakeStore(), center: fakeCenter)

        do {
            try await enforcer.startActivityMonitoring(for: makeSession())
            XCTFail("expected throw")
        } catch SessionEnforcerError.deviceActivityStartFailed(let inner) {
            XCTAssertTrue((inner as? TestError) != nil)
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    // MARK: - stopActivityMonitoring

    func testStopActivityMonitoringStopsTheQuickSessionActivity() async {
        let fakeCenter = FakeCenter()
        let enforcer = SessionEnforcerImpl(store: FakeStore(), center: fakeCenter)
        await enforcer.stopActivityMonitoring()
        XCTAssertEqual(fakeCenter.stoppedActivities, [SessionActivityNames.quickSession])
    }

    // MARK: - SessionActivityNames constant

    func testSessionActivityNameRawValueMatchesSharedConstant() {
        XCTAssertEqual(SessionActivityNames.quickSession.rawValue, "deluludetox.quickSession")
    }
}
