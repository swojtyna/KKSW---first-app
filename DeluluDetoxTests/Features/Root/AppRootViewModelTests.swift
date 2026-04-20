// AppRootViewModelTests — Combine-driven destination flow.
//
// NOTE (W12 flakiness mitigation): every test that calls `mockObserve.subject.send(...)`
// followed by an assertion on `vm.destination` inserts `try await Task.yield()` immediately
// before the assertion. Combine .sink + Observation mutation propagation need at least one
// run-loop tick on MainActor before the new value is visible to assertions.
import XCTest
import Combine
import FamilyControls
@testable import DeluluDetox

@MainActor
final class AppRootViewModelTests: XCTestCase {
    // IUO safe in XCTest: setUp runs before every test (W16).
    var mockObserve: MockObserveScreenTimeAuthStatusUseCase!
    var mockRefresh: MockRefreshScreenTimeAuthStatusUseCase!
    var mockReconcile: MockReconcileBlocklistUseCase!
    var mockFinalizeFromMarker: MockFinalizeSessionFromMarkerUseCase!
    var mockSelfHeal: MockSelfHealExpiredSessionUseCase!
    var mockDetectRevocation: MockDetectRevocationUseCase!
    var mockConsumeScheduleMarker: MockConsumeScheduleEventMarkerUseCase!
    var mockSelfHealSchedules: MockSelfHealSchedulesUseCase!
    // Phase 06-04 additions — foreground reconcile.
    var mockObserveSchedule: MockObserveScheduleUseCase!
    var mockReconcileScheduleNotifications: MockReconcileScheduleNotificationsUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .notDetermined)
        mockRefresh = MockRefreshScreenTimeAuthStatusUseCase()
        mockReconcile = MockReconcileBlocklistUseCase()
        mockFinalizeFromMarker = MockFinalizeSessionFromMarkerUseCase()
        mockSelfHeal = MockSelfHealExpiredSessionUseCase()
        mockDetectRevocation = MockDetectRevocationUseCase()
        mockConsumeScheduleMarker = MockConsumeScheduleEventMarkerUseCase()
        mockSelfHealSchedules = MockSelfHealSchedulesUseCase()
        mockObserveSchedule = MockObserveScheduleUseCase()
        mockReconcileScheduleNotifications = MockReconcileScheduleNotificationsUseCase()
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        DIContainer.shared.register(RefreshScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockRefresh] _ in
            mockRefresh!
        }
        DIContainer.shared.register(ReconcileBlocklistUseCase.self, scope: .unique) { [mockReconcile] _ in
            mockReconcile!
        }
        DIContainer.shared.register(FinalizeSessionFromMarkerUseCase.self, scope: .unique) { [mockFinalizeFromMarker] _ in mockFinalizeFromMarker! }
        DIContainer.shared.register(SelfHealExpiredSessionUseCase.self, scope: .unique) { [mockSelfHeal] _ in mockSelfHeal! }
        DIContainer.shared.register(DetectRevocationUseCase.self, scope: .unique) { [mockDetectRevocation] _ in mockDetectRevocation! }
        DIContainer.shared.register(ConsumeScheduleEventMarkerUseCase.self, scope: .unique) { [mockConsumeScheduleMarker] _ in mockConsumeScheduleMarker! }
        DIContainer.shared.register(SelfHealSchedulesUseCase.self, scope: .unique) { [mockSelfHealSchedules] _ in mockSelfHealSchedules! }
        DIContainer.shared.register(ObserveScheduleUseCase.self, scope: .unique) { [mockObserveSchedule] _ in mockObserveSchedule! }
        DIContainer.shared.register(ReconcileScheduleNotificationsUseCase.self, scope: .unique) { [mockReconcileScheduleNotifications] _ in mockReconcileScheduleNotifications! }
    }

    override func tearDown() async throws {
        DIContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Existing tests (preserved)

    func testInitialDestinationForNotDetermined() async {
        let vm = AppRootViewModel()
        await Task.yield()
        // CurrentValueSubject initial .notDetermined → destination = .onboarding
        XCTAssertEqual(vm.destination, .onboarding)
    }

    func testInitialDestinationForApproved() async {
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }

        let vm = AppRootViewModel()
        await Task.yield()

        XCTAssertEqual(vm.destination, .home)
    }

    func testEmissionOfApprovedRoutesToHome() async {
        let vm = AppRootViewModel()
        await Task.yield()
        XCTAssertEqual(vm.destination, .onboarding)

        mockObserve.subject.send(.approved)
        await Task.yield()

        XCTAssertEqual(vm.destination, .home)
    }

    func testEmissionOfDeniedRoutesToDenial() async {
        let vm = AppRootViewModel()

        mockObserve.subject.send(.denied)
        await Task.yield()

        XCTAssertEqual(vm.destination, .denial)
    }

    func testRefreshStatusCallsUseCase() async {
        let vm = AppRootViewModel()
        XCTAssertEqual(mockRefresh.callCount, 0)

        vm.refreshStatus()
        await Task.yield()

        XCTAssertEqual(mockRefresh.callCount, 1)
    }

    func testMultipleEmissionsUpdateDestination() async {
        let vm = AppRootViewModel()

        mockObserve.subject.send(.approved)
        await Task.yield()
        XCTAssertEqual(vm.destination, .home)

        mockObserve.subject.send(.denied)
        await Task.yield()
        XCTAssertEqual(vm.destination, .denial)

        mockObserve.subject.send(.notDetermined)
        await Task.yield()
        XCTAssertEqual(vm.destination, .onboarding)
    }

    // MARK: - Phase 02 additions (SEL-05)

    func testRefreshStatusAlsoCallsReconcileBlocklist() async throws {
        let vm = AppRootViewModel()
        XCTAssertEqual(mockReconcile.callCount, 0)

        vm.refreshStatus()
        // Sleep yields the MainActor long enough for the fire-and-forget Task
        // to be scheduled and for the async `reconcileBlocklist()` body to run.
        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms

        XCTAssertEqual(mockReconcile.callCount, 1)
    }

    func testRefreshStatusReconcileFailureDoesNotCrashOrChangeDestination() async throws {
        enum TestError: Error { case boom }
        mockReconcile.stubbedError = TestError.boom

        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        let vm = AppRootViewModel()
        await Task.yield()
        XCTAssertEqual(vm.destination, .home)

        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms — see note above.

        // Reconcile threw, but destination is unchanged and refreshStatus still counted.
        XCTAssertEqual(mockReconcile.callCount, 1)
        XCTAssertEqual(mockRefresh.callCount, 1)
        XCTAssertEqual(vm.destination, .home)
    }

    // MARK: - Phase 03 additions

    func testRefreshStatusCallsAllSevenUseCases() async throws {
        let vm = AppRootViewModel()
        vm.refreshStatus()

        // Spawned Task runs async — sleep until all call counts settle.
        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms

        XCTAssertEqual(mockRefresh.callCount, 1)
        XCTAssertEqual(mockReconcile.callCount, 1)
        XCTAssertEqual(mockFinalizeFromMarker.callCount, 1)
        XCTAssertEqual(mockSelfHeal.callCount, 1)
        XCTAssertEqual(mockDetectRevocation.callCount, 1)
        XCTAssertEqual(mockConsumeScheduleMarker.callCount, 1)
        XCTAssertEqual(mockSelfHealSchedules.callCount, 1)
    }

    func testRefreshStatusLogsButDoesNotPropagateSelfHealError() async throws {
        mockSelfHeal.stubbedError = MockSelfHealError()
        let vm = AppRootViewModel()
        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms
        // Detect revocation still fired, confirming the UC chain did not abort.
        XCTAssertEqual(mockDetectRevocation.callCount, 1)
    }

    // MARK: - Phase 05 additions

    func testRefreshStatusCallsScheduleUCsAfterSessionUCs() async throws {
        // Shared ordering log — both schedule mocks append their tag in call order.
        // RESEARCH §Pitfall 8 requires consumeScheduleMarker BEFORE selfHealSchedules.
        let orderLog = NSMutableArray()
        mockConsumeScheduleMarker.callOrderLog = orderLog
        mockSelfHealSchedules.callOrderLog = orderLog

        let vm = AppRootViewModel()
        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms

        XCTAssertEqual(mockConsumeScheduleMarker.callCount, 1)
        XCTAssertEqual(mockSelfHealSchedules.callCount, 1)

        XCTAssertEqual(orderLog.count, 2, "Both schedule UCs must fire.")
        XCTAssertEqual(orderLog[0] as? String, "consumeScheduleMarker")
        XCTAssertEqual(orderLog[1] as? String, "selfHealSchedules")
    }

    func testScheduleDarwinNotificationTriggersRefresh() async throws {
        let vm = AppRootViewModel()
        // Wait for init/observer registration.
        try await Task.sleep(nanoseconds: 50_000_000)
        let baselineRefresh = mockRefresh.callCount
        let baselineSelfHeal = mockSelfHealSchedules.callCount

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let started = CFNotificationName("com.kksw.DeluluDetox.scheduleStarted" as CFString)
        CFNotificationCenterPostNotification(center, started, nil, nil, true)
        try await Task.sleep(nanoseconds: 100_000_000) // 100 ms for Darwin + refreshStatus

        XCTAssertGreaterThan(mockRefresh.callCount, baselineRefresh, "scheduleStarted should trigger refreshStatus")
        XCTAssertGreaterThan(mockSelfHealSchedules.callCount, baselineSelfHeal, "scheduleStarted should cascade into selfHealSchedules")

        let afterStartRefresh = mockRefresh.callCount
        let afterStartSelfHeal = mockSelfHealSchedules.callCount

        let ended = CFNotificationName("com.kksw.DeluluDetox.scheduleEnded" as CFString)
        CFNotificationCenterPostNotification(center, ended, nil, nil, true)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertGreaterThan(mockRefresh.callCount, afterStartRefresh, "scheduleEnded should trigger refreshStatus")
        XCTAssertGreaterThan(mockSelfHealSchedules.callCount, afterStartSelfHeal, "scheduleEnded should cascade into selfHealSchedules")
        _ = vm
    }
}

// MARK: - Plan 06-04 NTF-02 foreground reconcile

extension AppRootViewModelTests {
    func testForegroundHook_reconcilesAllSchedules() async throws {
        // Seed publisher with one enabled + one disabled schedule. BOTH pass
        // through — the reconcile UC itself handles enabled=false (removes
        // stale pending). AppRootViewModel must not gate on `.enabled`.
        let enabled = Schedule(
            id: UUID(), name: nil, daysOfWeek: [2, 3],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0,
            enabled: true, blocklistId: UUID(), appVersion: "test"
        )
        let disabled = Schedule(
            id: UUID(), name: nil, daysOfWeek: [4],
            startHour: 18, startMinute: 0, endHour: 20, endMinute: 0,
            enabled: false, blocklistId: UUID(), appVersion: "test"
        )
        mockObserveSchedule.subject.send([enabled, disabled])

        let vm = AppRootViewModel()
        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 100_000_000) // 100 ms — foreground chain is long

        // Both schedules reconciled — enabled + disabled.
        let receivedIds = mockReconcileScheduleNotifications.receivedSchedules.map(\.id)
        XCTAssertTrue(receivedIds.contains(enabled.id), "enabled schedule must be reconciled")
        XCTAssertTrue(receivedIds.contains(disabled.id), "disabled schedule must also be passed through — UC handles the `enabled=false` case")
        XCTAssertEqual(mockReconcileScheduleNotifications.receivedSchedules.count, 2)
        _ = vm
    }
}

private struct MockSelfHealError: Error {}
