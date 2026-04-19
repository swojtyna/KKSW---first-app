import XCTest
import Combine
import FamilyControls
@testable import DeluluDetox

@MainActor
final class BlockedViewModelTests: XCTestCase {
    // IUO pattern is safe in XCTest: setUp runs before every test and assigns the
    // value; mocks stay non-nil through each invocation (Phase 01.1 W16 idiom).
    var mockObserve: MockObserveBlocklistUseCase!
    var mockRemove: MockRemoveTokenRecordUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockObserve = MockObserveBlocklistUseCase(initial: .empty())
        mockRemove = MockRemoveTokenRecordUseCase()
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        DIContainer.shared.register(RemoveTokenRecordUseCase.self, scope: .unique) { [mockRemove] _ in
            mockRemove!
        }
    }

    // MARK: - Helpers

    private func seedBlocklist(apps: Int, categories: Int, web: Int) -> Blocklist {
        var list = Blocklist.empty()
        let appRecs = (0..<apps).map { _ in
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data(), lastSeenAt: Date())
        }
        let catRecs = (0..<categories).map { _ in
            TokenRecord(id: UUID(), kind: .category, encodedToken: Data(), lastSeenAt: Date())
        }
        let webRecs = (0..<web).map { _ in
            TokenRecord(id: UUID(), kind: .webDomain, encodedToken: Data(), lastSeenAt: Date())
        }
        list.records = appRecs + catRecs + webRecs
        return list
    }

    // MARK: - Tests

    func testInitFiltersInitialEmissionIntoThreeArrays() async {
        mockObserve = MockObserveBlocklistUseCase(initial: seedBlocklist(apps: 1, categories: 2, web: 1))
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }

        let vm = BlockedViewModel()
        await Task.yield()

        XCTAssertEqual(vm.appRecords.count, 1)
        XCTAssertEqual(vm.categoryRecords.count, 2)
        XCTAssertEqual(vm.webRecords.count, 1)
    }

    func testPublisherEmissionUpdatesAllThreeArrays() async {
        let vm = BlockedViewModel()
        await Task.yield()
        XCTAssertEqual(vm.appRecords.count, 0)

        mockObserve.subject.send(seedBlocklist(apps: 2, categories: 0, web: 3))
        await Task.yield()

        XCTAssertEqual(vm.appRecords.count, 2)
        XCTAssertEqual(vm.categoryRecords.count, 0)
        XCTAssertEqual(vm.webRecords.count, 3)
    }

    func testDeleteTappedInvokesRemoveUseCaseWithRecordID() async {
        let vm = BlockedViewModel()
        let id = UUID()
        await vm.deleteTapped(recordID: id)
        XCTAssertEqual(mockRemove.callCount, 1)
        XCTAssertEqual(mockRemove.capturedRecordID, id)
        XCTAssertNil(vm.errorMessage)
    }

    func testDeleteFailureSetsErrorMessage() async {
        enum TestError: Error { case boom }
        mockRemove.stubbedError = TestError.boom

        let vm = BlockedViewModel()
        await vm.deleteTapped(recordID: UUID())

        XCTAssertEqual(mockRemove.callCount, 1)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.errorMessage, "Nie udało się usunąć.")
    }

    func testChangeSelectionTappedInvokesCallback() {
        let vm = BlockedViewModel()
        var fired = false
        vm.onChangeSelection = { fired = true }
        vm.changeSelectionTapped()
        XCTAssertTrue(fired)
    }

    func testChangeSelectionTappedWhenCallbackNilIsNoOp() {
        let vm = BlockedViewModel()
        vm.onChangeSelection = nil
        vm.changeSelectionTapped() // should not crash
    }
}
