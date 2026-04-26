import Foundation
import Combine
import FamilyControls
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class HomeViewModelTests {

    let mockObserve: MockObserveBlocklistUseCase
    let mockUpdate: MockUpdateBlocklistUseCase
    let mockObserveActive: MockObserveActiveSessionUseCase
    let mockObserveHistory: MockObserveSessionHistoryUseCase
    let mockMarkSuccessShown: MockMarkSuccessShownUseCase
    let mockCheckSuccessShown: MockCheckSuccessShownUseCase

    init() {
        DIContainer.shared.reset()
        mockObserve = MockObserveBlocklistUseCase(initial: .empty())
        mockUpdate = MockUpdateBlocklistUseCase()
        mockObserveActive = MockObserveActiveSessionUseCase()
        mockObserveHistory = MockObserveSessionHistoryUseCase()
        mockMarkSuccessShown = MockMarkSuccessShownUseCase()
        mockCheckSuccessShown = MockCheckSuccessShownUseCase()
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve
        }
        DIContainer.shared.register(UpdateBlocklistUseCase.self, scope: .unique) { [mockUpdate] _ in
            mockUpdate
        }
        DIContainer.shared.register(ObserveActiveSessionUseCase.self, scope: .application) { [mockObserveActive] _ in mockObserveActive }
        DIContainer.shared.register(ObserveSessionHistoryUseCase.self, scope: .application) { [mockObserveHistory] _ in mockObserveHistory }
        DIContainer.shared.register(MarkSuccessShownUseCase.self, scope: .application) { [mockMarkSuccessShown] _ in mockMarkSuccessShown }
        DIContainer.shared.register(CheckSuccessShownUseCase.self, scope: .application) { [mockCheckSuccessShown] _ in mockCheckSuccessShown }
        DIContainer.shared.register(ObserveScheduleUseCase.self, scope: .unique) { _ in MockObserveScheduleUseCase() }
        DIContainer.shared.register(ToggleScheduleUseCase.self, scope: .unique) { _ in MockToggleScheduleUseCase() }
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .unique) { _ in MockObserveStatsUseCase() }
        DIContainer.shared.register(GetBrokenStreakCopyUseCase.self, scope: .unique) { _ in MockGetBrokenStreakCopyUseCase() }
    }

    @Test("init subscribes to blocklist publisher")
    func initSubscribesToBlocklistPublisher() async {
        let vm = HomeViewModel()
        await Task.yield()
        #expect(mockObserve.callCount == 1)
        #expect(vm.snapshot.records.isEmpty)
    }

    @Test("emission updates snapshot")
    func emissionUpdatesSnapshot() async {
        let vm = HomeViewModel()
        await Task.yield()

        var seeded = Blocklist.empty()
        seeded.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data(), lastSeenAt: Date())
        ]
        mockObserve.subject.send(seeded)
        await Task.yield()

        #expect(vm.snapshot.records.count == 1)
    }

    @Test("chooseAppsTapped sets picker destination")
    func chooseAppsTappedSetsPickerDestination() async {
        let vm = HomeViewModel()
        await Task.yield()

        vm.chooseAppsTapped()

        #expect(vm.destination != nil)
        guard case .picker = vm.destination else {
            Issue.record("Expected .picker destination, got \(String(describing: vm.destination))")
            return
        }
    }

    @Test("chooseAppsTapped seeds picker with current lastSelection")
    func chooseAppsTappedSeedsPickerWithCurrentLastSelection() async {
        let vm = HomeViewModel()
        await Task.yield()

        vm.chooseAppsTapped()

        if case .picker(let session) = vm.destination {
            #expect(session.selection == vm.snapshot.lastSelection)
        } else {
            Issue.record("Expected .picker destination with PickerSession")
        }
    }

    @Test("pickerDismissed invokes update use case")
    func pickerDismissedInvokesUpdateUseCase() async {
        let vm = HomeViewModel()
        let selection = FamilyActivitySelection()

        await vm.pickerDismissed(committed: selection)

        #expect(mockUpdate.callCount == 1)
        #expect(mockUpdate.capturedSelection == selection)
    }

    @Test("pickerDismissed success clears destination")
    func pickerDismissedSuccessClearsDestination() async {
        let vm = HomeViewModel()
        vm.chooseAppsTapped()
        #expect(vm.destination != nil)

        await vm.pickerDismissed(committed: FamilyActivitySelection())

        #expect(vm.destination == nil)
    }

    @Test("pickerDismissed failure sets errorAlert destination")
    func pickerDismissedFailureSetsErrorAlertDestination() async {
        enum TestError: Error { case boom }
        mockUpdate.stubbedError = TestError.boom

        let vm = HomeViewModel()
        await vm.pickerDismissed(committed: FamilyActivitySelection())

        guard case .errorAlert(let message) = vm.destination else {
            Issue.record("Expected .errorAlert destination, got \(String(describing: vm.destination))")
            return
        }
        #expect(message == "Nie udało się zapisać wyboru. Spróbuj ponownie.")
    }

    @Test("startSessionTapped routes to sessionStart destination")
    func startSessionTappedRoutesToSessionStartDestination() {
        let vm = HomeViewModel()
        vm.startSessionTapped()
        var matched = false
        if case .sessionStart = vm.destination { matched = true }
        #expect(matched, "expected .sessionStart, got \(String(describing: vm.destination))")
    }

    @Test("gotoCountdown sets countdown destination with provided record")
    func gotoCountdownBridgeSetsCountdownDestinationWithProvidedRecord() {
        let vm = HomeViewModel()
        let record = makeSession()
        vm.gotoCountdown(record)
        if case .countdown(let cvm) = vm.destination {
            #expect(cvm.session.id == record.id)
        } else {
            Issue.record("expected .countdown destination after gotoCountdown")
        }
    }

    @Test("active session emission routes to countdown")
    func activeSessionEmissionRoutesToCountdown() async {
        let vm = HomeViewModel()
        let session = makeSession()
        mockObserveActive.subject.send(session)
        await yield()

        if case .countdown(let cvm) = vm.destination {
            #expect(cvm.session.id == session.id)
        } else {
            Issue.record("expected .countdown destination")
        }
    }

    @Test("active session becoming nil clears countdown destination")
    func activeSessionBecomingNilClearsCountdownDestination() async {
        let vm = HomeViewModel()
        let session = makeSession()
        mockObserveActive.subject.send(session)
        await yield()
        mockObserveActive.subject.send(nil)
        await yield()

        #expect(vm.destination == nil)
    }

    @Test("completed session in history shows success destination once when no active")
    func completedSessionInHistoryShowsSuccessDestinationOnceWhenNoActive() async {
        let vm = HomeViewModel()
        let now = Date()
        let record = SessionRecord(
            blocklistId: UUID(),
            startedAt: now.addingTimeInterval(-1800),
            plannedEndAt: now,
            plannedDurationSeconds: 1800,
            actualEndAt: now,
            outcome: .completed,
            appVersion: "test"
        )
        mockObserveActive.subject.send(nil)
        mockObserveHistory.subject.send([record])
        await yield()

        if case .sessionSuccess(let svm) = vm.destination {
            #expect(svm.sessionId == record.id)
        } else {
            Issue.record("expected .sessionSuccess destination, got \(String(describing: vm.destination))")
        }
        #expect(mockMarkSuccessShown.callCount == 1)
        #expect(mockMarkSuccessShown.lastSessionId == record.id)
        #expect(mockMarkSuccessShown.allMarked.contains(record.id))
    }

    @Test("completed session already marked shown does not re-show")
    func completedSessionAlreadyMarkedShownDoesNotReshow() async {
        let recordId = UUID()
        mockCheckSuccessShown.stubbedShownIds = [recordId]

        let vm = HomeViewModel()
        let record = SessionRecord(
            id: recordId,
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date(),
            plannedDurationSeconds: 1800,
            actualEndAt: Date(),
            outcome: .completed,
            appVersion: "test"
        )
        mockObserveActive.subject.send(nil)
        mockObserveHistory.subject.send([record])
        await yield()

        #expect(vm.destination == nil)
        #expect(mockMarkSuccessShown.callCount == 0)
    }

    @Test("cancelled or broken-by-revoke session does not show success")
    func cancelledByUserOrBrokenByRevokeDoesNotShowSuccess() async {
        let vm = HomeViewModel()
        let r1 = SessionRecord(
            blocklistId: UUID(), startedAt: Date(),
            plannedEndAt: Date(), plannedDurationSeconds: 1800,
            actualEndAt: Date(), outcome: .cancelledByUser, appVersion: "test"
        )
        let r2 = SessionRecord(
            blocklistId: UUID(), startedAt: Date(),
            plannedEndAt: Date(), plannedDurationSeconds: 1800,
            actualEndAt: Date(), outcome: .brokenByRevoke, appVersion: "test"
        )
        mockObserveActive.subject.send(nil)
        mockObserveHistory.subject.send([r1, r2])
        await yield()

        #expect(vm.destination == nil)
    }

    // MARK: - SHL-04 deep link routing

    @Test("handleDeepLink session/active URL routes to countdown")
    func handleDeepLink_sessionActiveURL_routesToCountdown() async throws {
        let vm = HomeViewModel()
        await yield()

        let session = makeSession()
        mockObserveActive.subject.send(session)
        await yield()

        await vm.handleDeepLink(URL(string: "deluludetox://session/active")!)
        await yield()

        guard case .countdown(let cvm) = vm.destination else {
            Issue.record("Expected .countdown, got \(String(describing: vm.destination))")
            return
        }
        #expect(cvm.session.id == session.id)
    }

    @Test("handleDeepLink session/active URL with no active session clears destination")
    func handleDeepLink_sessionActiveURL_noActiveSession_clearsDestination() async throws {
        let vm = HomeViewModel()
        await yield()
        mockObserveActive.subject.send(nil)
        await yield()

        vm.destination = .errorAlert("preexisting")

        await vm.handleDeepLink(URL(string: "deluludetox://session/active")!)
        await yield()

        #expect(vm.destination == nil, "handleDeepLink with no active session must clear destination")
    }

    @Test("handleDeepLink root URL clears destination")
    func handleDeepLink_rootURL_clearsDestination() async throws {
        let vm = HomeViewModel()
        await yield()

        vm.destination = .errorAlert("preexisting")

        await vm.handleDeepLink(URL(string: "deluludetox://")!)
        await yield()

        #expect(vm.destination == nil)
    }

    @Test("handleDeepLink unknown scheme is ignored")
    func handleDeepLink_unknownScheme_isIgnored() async throws {
        let vm = HomeViewModel()
        await yield()

        vm.destination = .errorAlert("preserve")

        await vm.handleDeepLink(URL(string: "https://example.com")!)
        await yield()

        guard case .errorAlert(let msg) = vm.destination else {
            Issue.record("Expected destination to remain .errorAlert, got \(String(describing: vm.destination))")
            return
        }
        #expect(msg == "preserve")
    }

    @Test("ShieldNotification userInfoURLKey contract is stable")
    func shieldNotificationConstants_userInfoURLKeyContract() {
        #expect(
            ShieldNotificationConstants.userInfoURLKey == "url",
            "Delegate reads userInfo[\"url\"] — repository must write to the same key."
        )
        #expect(
            ShieldNotificationConstants.identifierPrefix == "com.kksw.DeluluDetox.shield-deeplink.",
            "Delegate filters identifier by this prefix — repository must produce identifiers with this exact prefix."
        )
    }

    @Test("scheduleListTapped routes to scheduleList destination")
    func scheduleListTappedRoutesToScheduleListDestination() async {
        let vm = HomeViewModel()
        await yield()

        vm.scheduleListTapped()

        var matchedScheduleList = false
        if case .scheduleList = vm.destination { matchedScheduleList = true }
        #expect(matchedScheduleList, "expected .scheduleList, got \(String(describing: vm.destination))")
    }

    @Test("statsCardTapped sets stats destination")
    func statsCardTapped_setsStatsDestination() async {
        let vm = HomeViewModel()
        await yield()

        vm.statsCardTapped()

        var matchedStats = false
        if case .stats = vm.destination { matchedStats = true }
        #expect(matchedStats, "expected .stats, got \(String(describing: vm.destination))")
    }

    @Test("stats destination is identity equatable")
    func statsCardDestination_isIdentityEquatable() {
        let a = StatsViewModel()
        let b = StatsViewModel()
        #expect(HomeViewModel.Destination.stats(a) != HomeViewModel.Destination.stats(b))
        #expect(HomeViewModel.Destination.stats(a) == HomeViewModel.Destination.stats(a))
    }
}

// MARK: - Private Helpers

private extension HomeViewModelTests {
    func yield() async {
        await Task.yield()
        await Task.yield()
    }

    func makeSession(
        id: UUID = UUID(),
        outcome: SessionOutcome? = nil,
        actualEndAt: Date? = nil
    ) -> SessionRecord {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        return SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            actualEndAt: actualEndAt,
            outcome: outcome,
            appVersion: "test"
        )
    }
}
