import XCTest
import Combine
import FamilyControls
@testable import DeluluDetox

@MainActor
final class HomeViewModelTests: XCTestCase {
    var mockObserve: MockObserveBlocklistUseCase!
    var mockUpdate: MockUpdateBlocklistUseCase!
    var mockObserveActive: MockObserveActiveSessionUseCase!
    var mockObserveHistory: MockObserveSessionHistoryUseCase!
    var mockMarkSuccessShown: MockMarkSuccessShownUseCase!
    var mockCheckSuccessShown: MockCheckSuccessShownUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockObserve = MockObserveBlocklistUseCase(initial: .empty())
        mockUpdate = MockUpdateBlocklistUseCase()
        mockObserveActive = MockObserveActiveSessionUseCase()
        mockObserveHistory = MockObserveSessionHistoryUseCase()
        mockMarkSuccessShown = MockMarkSuccessShownUseCase()
        mockCheckSuccessShown = MockCheckSuccessShownUseCase()
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        DIContainer.shared.register(UpdateBlocklistUseCase.self, scope: .unique) { [mockUpdate] _ in
            mockUpdate!
        }
        DIContainer.shared.register(ObserveActiveSessionUseCase.self, scope: .application) { [mockObserveActive] _ in mockObserveActive! }
        DIContainer.shared.register(ObserveSessionHistoryUseCase.self, scope: .application) { [mockObserveHistory] _ in mockObserveHistory! }
        DIContainer.shared.register(MarkSuccessShownUseCase.self, scope: .application) { [mockMarkSuccessShown] _ in mockMarkSuccessShown! }
        DIContainer.shared.register(CheckSuccessShownUseCase.self, scope: .application) { [mockCheckSuccessShown] _ in mockCheckSuccessShown! }
    }

    // MARK: - Helpers

    private func yield() async {
        await Task.yield()
        await Task.yield()
    }

    private func makeSession(
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

    // MARK: - Existing tests (preserved unchanged)

    func testInitSubscribesToBlocklistPublisher() async {
        let vm = HomeViewModel()
        await Task.yield()
        XCTAssertEqual(mockObserve.callCount, 1)
        XCTAssertTrue(vm.snapshot.records.isEmpty)
    }

    func testEmissionUpdatesSnapshot() async {
        let vm = HomeViewModel()
        await Task.yield()

        var seeded = Blocklist.empty()
        seeded.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data(), lastSeenAt: Date())
        ]
        mockObserve.subject.send(seeded)
        await Task.yield()

        XCTAssertEqual(vm.snapshot.records.count, 1)
    }

    func testChooseAppsTappedSetsPickerDestination() async {
        let vm = HomeViewModel()
        await Task.yield()

        vm.chooseAppsTapped()

        XCTAssertNotNil(vm.destination)
        guard case .picker = vm.destination else {
            XCTFail("Expected .picker destination, got \(String(describing: vm.destination))")
            return
        }
    }

    func testChooseAppsTappedSeedsPickerWithCurrentLastSelection() async {
        let vm = HomeViewModel()
        await Task.yield()

        vm.chooseAppsTapped()

        if case .picker(let session) = vm.destination {
            // Simulator cannot synthesize real tokens; assert the seeded selection
            // equals the current snapshot.lastSelection (empty <-> empty).
            XCTAssertEqual(session.selection, vm.snapshot.lastSelection)
        } else {
            XCTFail("Expected .picker destination with PickerSession")
        }
    }

    func testPickerDismissedInvokesUpdateUseCase() async {
        let vm = HomeViewModel()
        let selection = FamilyActivitySelection()

        await vm.pickerDismissed(committed: selection)

        XCTAssertEqual(mockUpdate.callCount, 1)
        XCTAssertEqual(mockUpdate.capturedSelection, selection)
    }

    func testPickerDismissedSuccessClearsDestination() async {
        let vm = HomeViewModel()
        vm.chooseAppsTapped()
        XCTAssertNotNil(vm.destination)

        await vm.pickerDismissed(committed: FamilyActivitySelection())

        XCTAssertNil(vm.destination)
    }

    func testPickerDismissedFailureSetsErrorAlertDestination() async {
        enum TestError: Error { case boom }
        mockUpdate.stubbedError = TestError.boom

        let vm = HomeViewModel()
        await vm.pickerDismissed(committed: FamilyActivitySelection())

        guard case .errorAlert(let message) = vm.destination else {
            XCTFail("Expected .errorAlert destination, got \(String(describing: vm.destination))")
            return
        }
        XCTAssertEqual(message, "Nie udało się zapisać wyboru. Spróbuj ponownie.")
    }

    // MARK: - New tests (Task 2 additions)

    func testStartSessionTappedRoutesToSessionStartDestination() {
        let vm = HomeViewModel()
        vm.startSessionTapped()
        if case .sessionStart = vm.destination {
            // pass
        } else {
            XCTFail("expected .sessionStart destination, got \(String(describing: vm.destination))")
        }
    }

    func testGotoCountdownBridgeSetsCountdownDestinationWithProvidedRecord() {
        let vm = HomeViewModel()
        let record = makeSession()
        vm.gotoCountdown(record)
        if case .countdown(let cvm) = vm.destination {
            XCTAssertEqual(cvm.session.id, record.id)
        } else {
            XCTFail("expected .countdown destination after gotoCountdown")
        }
    }

    func testActiveSessionEmissionRoutesToCountdown() async {
        let vm = HomeViewModel()
        let session = makeSession()
        mockObserveActive.subject.send(session)
        await yield()

        if case .countdown(let cvm) = vm.destination {
            XCTAssertEqual(cvm.session.id, session.id)
        } else {
            XCTFail("expected .countdown destination")
        }
    }

    func testActiveSessionBecomingNilClearsCountdownDestination() async {
        let vm = HomeViewModel()
        let session = makeSession()
        mockObserveActive.subject.send(session)
        await yield()
        mockObserveActive.subject.send(nil)
        await yield()

        XCTAssertNil(vm.destination)
    }

    func testCompletedSessionInHistoryShowsSuccessDestinationOnceWhenNoActive() async {
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
        // mockCheckSuccessShown.stubbedShownIds empty (default) — record NOT yet shown.
        mockObserveActive.subject.send(nil)
        mockObserveHistory.subject.send([record])
        await yield()

        if case .sessionSuccess(let svm) = vm.destination {
            XCTAssertEqual(svm.sessionId, record.id)
        } else {
            XCTFail("expected .sessionSuccess destination, got \(String(describing: vm.destination))")
        }
        XCTAssertEqual(mockMarkSuccessShown.callCount, 1)
        XCTAssertEqual(mockMarkSuccessShown.lastSessionId, record.id)
        XCTAssertTrue(mockMarkSuccessShown.allMarked.contains(record.id))
    }

    func testCompletedSessionAlreadyMarkedShownDoesNotReshow() async {
        let recordId = UUID()
        // Pre-mark via mock: CheckSuccessShownUseCase returns true for this id.
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

        XCTAssertNil(vm.destination)
        XCTAssertEqual(mockMarkSuccessShown.callCount, 0)
    }

    func testCancelledByUserOrBrokenByRevokeDoesNotShowSuccess() async {
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

        XCTAssertNil(vm.destination)
    }

    // MARK: - SHL-04 deep link routing (Plan 04 implements; Plan 01 scaffolds)

    func testHandleDeepLink_sessionActiveURL_routesToCountdown() async throws {
        try XCTSkipIf(true, "Plan 04 will add HomeViewModel.handleDeepLink(_:). Expected: handleDeepLink(URL(string: \"deluludetox://session/active\")!) with active session present sets destination to .countdown.")
    }

    func testHandleDeepLink_sessionActiveURL_noActiveSession_clearsDestination() async throws {
        try XCTSkipIf(true, "Plan 04 will add HomeViewModel.handleDeepLink(_:). Expected: handleDeepLink with no active session sets destination to nil (silent route per D-10).")
    }

    func testHandleDeepLink_rootURL_clearsDestination() async throws {
        try XCTSkipIf(true, "Plan 04 will add HomeViewModel.handleDeepLink(_:). Expected: handleDeepLink(URL(string: \"deluludetox://\")!) sets destination to nil.")
    }

    func testHandleDeepLink_unknownScheme_isIgnored() async throws {
        try XCTSkipIf(true, "Plan 04 will add HomeViewModel.handleDeepLink(_:). Expected: handleDeepLink(URL(string: \"https://example.com\")!) leaves destination unchanged (early-return on scheme guard).")
    }
}
