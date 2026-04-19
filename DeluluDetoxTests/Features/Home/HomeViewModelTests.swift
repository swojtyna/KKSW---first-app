import XCTest
import Combine
import FamilyControls
@testable import DeluluDetox

@MainActor
final class HomeViewModelTests: XCTestCase {
    var mockObserve: MockObserveBlocklistUseCase!
    var mockUpdate: MockUpdateBlocklistUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockObserve = MockObserveBlocklistUseCase(initial: .empty())
        mockUpdate = MockUpdateBlocklistUseCase()
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        DIContainer.shared.register(UpdateBlocklistUseCase.self, scope: .unique) { [mockUpdate] _ in
            mockUpdate!
        }
    }

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
}
