import Foundation
import Combine
import FamilyControls
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class AppRootViewModelTests {

    var mockObserve: MockObserveScreenTimeAuthStatusUseCase
    let mockRefresh: MockRefreshScreenTimeAuthStatusUseCase
    let mockReconcile: MockReconcileBlocklistUseCase
    let mockFinalizeFromMarker: MockFinalizeSessionFromMarkerUseCase
    let mockSelfHeal: MockSelfHealExpiredSessionUseCase
    let mockDetectRevocation: MockDetectRevocationUseCase
    let mockConsumeScheduleMarker: MockConsumeScheduleEventMarkerUseCase
    let mockSelfHealSchedules: MockSelfHealSchedulesUseCase
    let mockObserveSchedule: MockObserveScheduleUseCase
    let mockReconcileScheduleNotifications: MockReconcileScheduleNotificationsUseCase
    let mockGetNotificationAuthStatus: MockGetNotificationAuthStatusUseCase
    let mockObserveNotificationsOnboardingCompletion: MockObserveNotificationsOnboardingCompletionUseCase

    init() {
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
        mockGetNotificationAuthStatus = MockGetNotificationAuthStatusUseCase()
        mockObserveNotificationsOnboardingCompletion = MockObserveNotificationsOnboardingCompletionUseCase()
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve
        }
        DIContainer.shared.register(RefreshScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockRefresh] _ in
            mockRefresh
        }
        DIContainer.shared.register(ReconcileBlocklistUseCase.self, scope: .unique) { [mockReconcile] _ in
            mockReconcile
        }
        DIContainer.shared.register(FinalizeSessionFromMarkerUseCase.self, scope: .unique) { [mockFinalizeFromMarker] _ in mockFinalizeFromMarker }
        DIContainer.shared.register(SelfHealExpiredSessionUseCase.self, scope: .unique) { [mockSelfHeal] _ in mockSelfHeal }
        DIContainer.shared.register(DetectRevocationUseCase.self, scope: .unique) { [mockDetectRevocation] _ in mockDetectRevocation }
        DIContainer.shared.register(ConsumeScheduleEventMarkerUseCase.self, scope: .unique) { [mockConsumeScheduleMarker] _ in mockConsumeScheduleMarker }
        DIContainer.shared.register(SelfHealSchedulesUseCase.self, scope: .unique) { [mockSelfHealSchedules] _ in mockSelfHealSchedules }
        DIContainer.shared.register(ObserveScheduleUseCase.self, scope: .unique) { [mockObserveSchedule] _ in mockObserveSchedule }
        DIContainer.shared.register(ReconcileScheduleNotificationsUseCase.self, scope: .unique) { [mockReconcileScheduleNotifications] _ in mockReconcileScheduleNotifications }
        DIContainer.shared.register(GetNotificationAuthStatusUseCase.self, scope: .unique) { [mockGetNotificationAuthStatus] _ in
            mockGetNotificationAuthStatus
        }
        DIContainer.shared.register(ObserveNotificationsOnboardingCompletionUseCase.self, scope: .unique) { [mockObserveNotificationsOnboardingCompletion] _ in
            mockObserveNotificationsOnboardingCompletion
        }
    }

    // MARK: - Destination routing

    @Test("initial destination for notDetermined is onboarding")
    func initialDestinationForNotDetermined() async {
        let vm = AppRootViewModel()
        await Task.yield()
        #expect(vm.destination == .onboarding)
    }

    @Test("initial destination for approved is home")
    func initialDestinationForApproved() async throws {
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve
        }

        let vm = AppRootViewModel()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(vm.destination == .home)
    }

    @Test("emission of approved routes to home")
    func emissionOfApprovedRoutesToHome() async throws {
        let vm = AppRootViewModel()
        await Task.yield()
        #expect(vm.destination == .onboarding)

        mockObserve.subject.send(.approved)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(vm.destination == .home)
    }

    @Test("emission of denied routes to denial")
    func emissionOfDeniedRoutesToDenial() async {
        let vm = AppRootViewModel()

        mockObserve.subject.send(.denied)
        await Task.yield()

        #expect(vm.destination == .denial)
    }

    @Test("refreshStatus calls use case")
    func refreshStatusCallsUseCase() async {
        let vm = AppRootViewModel()
        #expect(mockRefresh.callCount == 0)

        vm.refreshStatus()
        await Task.yield()

        #expect(mockRefresh.callCount == 1)
    }

    @Test("multiple emissions update destination correctly")
    func multipleEmissionsUpdateDestination() async throws {
        let vm = AppRootViewModel()

        mockObserve.subject.send(.approved)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.destination == .home)

        mockObserve.subject.send(.denied)
        await Task.yield()
        #expect(vm.destination == .denial)

        mockObserve.subject.send(.notDetermined)
        await Task.yield()
        #expect(vm.destination == .onboarding)
    }

    // MARK: - Phase 02 additions (SEL-05)

    @Test("refreshStatus also calls reconcileBlocklist")
    func refreshStatusAlsoCallsReconcileBlocklist() async throws {
        let vm = AppRootViewModel()
        #expect(mockReconcile.callCount == 0)

        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(mockReconcile.callCount == 1)
    }

    @Test("refreshStatus reconcile failure does not crash or change destination")
    func refreshStatusReconcileFailureDoesNotCrashOrChangeDestination() async throws {
        enum TestError: Error { case boom }
        mockReconcile.stubbedError = TestError.boom

        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve
        }
        let vm = AppRootViewModel()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.destination == .home)

        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(mockReconcile.callCount == 1)
        #expect(mockRefresh.callCount == 1)
        #expect(vm.destination == .home)
    }

    // MARK: - Phase 03 additions

    @Test("refreshStatus calls all seven use cases")
    func refreshStatusCallsAllSevenUseCases() async throws {
        let vm = AppRootViewModel()
        vm.refreshStatus()

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(mockRefresh.callCount == 1)
        #expect(mockReconcile.callCount == 1)
        #expect(mockFinalizeFromMarker.callCount == 1)
        #expect(mockSelfHeal.callCount == 1)
        #expect(mockDetectRevocation.callCount == 1)
        #expect(mockConsumeScheduleMarker.callCount == 1)
        #expect(mockSelfHealSchedules.callCount == 1)
    }

    @Test("refreshStatus logs but does not propagate selfHeal error")
    func refreshStatusLogsButDoesNotPropagateSelfHealError() async throws {
        mockSelfHeal.stubbedError = MockSelfHealError()
        let vm = AppRootViewModel()
        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(mockDetectRevocation.callCount == 1)
    }

    // MARK: - Phase 05 additions

    @Test("refreshStatus calls schedule UCs in order: consumeScheduleMarker then selfHealSchedules")
    func refreshStatusCallsScheduleUCsAfterSessionUCs() async throws {
        let orderLog = NSMutableArray()
        mockConsumeScheduleMarker.callOrderLog = orderLog
        mockSelfHealSchedules.callOrderLog = orderLog

        let vm = AppRootViewModel()
        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(mockConsumeScheduleMarker.callCount == 1)
        #expect(mockSelfHealSchedules.callCount == 1)

        #expect(orderLog.count == 2, "Both schedule UCs must fire.")
        #expect(orderLog[0] as? String == "consumeScheduleMarker")
        #expect(orderLog[1] as? String == "selfHealSchedules")
    }

    @Test("Darwin schedule notification triggers refresh")
    func scheduleDarwinNotificationTriggersRefresh() async throws {
        let vm = AppRootViewModel()
        try await Task.sleep(nanoseconds: 50_000_000)
        let baselineRefresh = mockRefresh.callCount
        let baselineSelfHeal = mockSelfHealSchedules.callCount

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let started = CFNotificationName("com.kksw.DeluluDetox.scheduleStarted" as CFString)
        CFNotificationCenterPostNotification(center, started, nil, nil, true)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(mockRefresh.callCount > baselineRefresh, "scheduleStarted should trigger refreshStatus")
        #expect(mockSelfHealSchedules.callCount > baselineSelfHeal, "scheduleStarted should cascade into selfHealSchedules")

        let afterStartRefresh = mockRefresh.callCount
        let afterStartSelfHeal = mockSelfHealSchedules.callCount

        let ended = CFNotificationName("com.kksw.DeluluDetox.scheduleEnded" as CFString)
        CFNotificationCenterPostNotification(center, ended, nil, nil, true)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(mockRefresh.callCount > afterStartRefresh, "scheduleEnded should trigger refreshStatus")
        #expect(mockSelfHealSchedules.callCount > afterStartSelfHeal, "scheduleEnded should cascade into selfHealSchedules")
        _ = vm
    }

    // MARK: - TASK-007 Notifications onboarding

    @Test("approved + notifications not determined routes to notificationsOnboarding")
    func approvedWithNotificationsNotDetermined_routesToNotificationsOnboarding() async throws {
        mockGetNotificationAuthStatus.stubStatus = .notDetermined
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve
        }

        let vm = AppRootViewModel()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(vm.destination == .notificationsOnboarding)
    }

    @Test("approved + notifications authorized routes to home")
    func approvedWithNotificationsAuthorized_routesToHome() async throws {
        mockGetNotificationAuthStatus.stubStatus = .authorized
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve
        }

        let vm = AppRootViewModel()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(vm.destination == .home)
    }

    @Test("notifications onboarding completion publisher transitions to home")
    func notificationsOnboardingCompletionPublisher_routesToHome() async throws {
        mockGetNotificationAuthStatus.stubStatus = .notDetermined
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve
        }

        let vm = AppRootViewModel()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.destination == .notificationsOnboarding)

        mockObserveNotificationsOnboardingCompletion.subject.send()
        await Task.yield()

        #expect(vm.destination == .home)
    }
}

// MARK: - Plan 06-04 NTF-02 foreground reconcile

extension AppRootViewModelTests {
    @Test("foreground hook reconciles all schedules (enabled and disabled)")
    func testForegroundHook_reconcilesAllSchedules() async throws {
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
        try await Task.sleep(nanoseconds: 100_000_000)

        let receivedIds = mockReconcileScheduleNotifications.receivedSchedules.map(\.id)
        #expect(receivedIds.contains(enabled.id), "enabled schedule must be reconciled")
        #expect(receivedIds.contains(disabled.id), "disabled schedule must also be passed through — UC handles the enabled=false case")
        #expect(mockReconcileScheduleNotifications.receivedSchedules.count == 2)
        _ = vm
    }
}

private struct MockSelfHealError: Error {}
