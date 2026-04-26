import Foundation
import Combine
import FamilyControls
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class BlockedViewModelTests {

    let mockObserve: MockObserveBlocklistUseCase
    let mockRemove: MockRemoveTokenRecordUseCase

    init() {
        DIContainer.shared.reset()
        mockObserve = MockObserveBlocklistUseCase(initial: .empty())
        mockRemove = MockRemoveTokenRecordUseCase()
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve
        }
        DIContainer.shared.register(RemoveTokenRecordUseCase.self, scope: .unique) { [mockRemove] _ in
            mockRemove
        }
    }

    @Test("init filters initial emission into three arrays")
    func initFiltersInitialEmissionIntoThreeArrays() async {
        let seeded = seedBlocklist(apps: 1, categories: 2, web: 1)
        let seededMock = MockObserveBlocklistUseCase(initial: seeded)
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { _ in seededMock }

        let vm = BlockedViewModel()
        await Task.yield()

        #expect(vm.appRecords.count == 1)
        #expect(vm.categoryRecords.count == 2)
        #expect(vm.webRecords.count == 1)
    }

    @Test("publisher emission updates all three arrays")
    func publisherEmissionUpdatesAllThreeArrays() async {
        let vm = BlockedViewModel()
        await Task.yield()
        #expect(vm.appRecords.count == 0)

        mockObserve.subject.send(seedBlocklist(apps: 2, categories: 0, web: 3))
        await Task.yield()

        #expect(vm.appRecords.count == 2)
        #expect(vm.categoryRecords.count == 0)
        #expect(vm.webRecords.count == 3)
    }

    @Test("deleteTapped invokes remove use case with record ID")
    func deleteTappedInvokesRemoveUseCaseWithRecordID() async {
        let vm = BlockedViewModel()
        let id = UUID()
        await vm.deleteTapped(recordID: id)
        #expect(mockRemove.callCount == 1)
        #expect(mockRemove.capturedRecordID == id)
        #expect(vm.errorMessage == nil)
    }

    @Test("delete failure sets error message")
    func deleteFailureSetsErrorMessage() async {
        enum TestError: Error { case boom }
        mockRemove.stubbedError = TestError.boom

        let vm = BlockedViewModel()
        await vm.deleteTapped(recordID: UUID())

        #expect(mockRemove.callCount == 1)
        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage == "Nie udało się usunąć.")
    }

    @Test("changeSelectionTapped invokes callback")
    func changeSelectionTappedInvokesCallback() {
        let vm = BlockedViewModel()
        var fired = false
        vm.onChangeSelection = { fired = true }
        vm.changeSelectionTapped()
        #expect(fired)
    }

    @Test("changeSelectionTapped when callback nil is no-op")
    func changeSelectionTappedWhenCallbackNilIsNoOp() {
        let vm = BlockedViewModel()
        vm.onChangeSelection = nil
        vm.changeSelectionTapped()
    }
}

// MARK: - Private Helpers

private extension BlockedViewModelTests {
    func seedBlocklist(apps: Int, categories: Int, web: Int) -> Blocklist {
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
}
