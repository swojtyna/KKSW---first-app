import Foundation
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class DenialViewModelTests {

    let mockUseCase: MockRequestScreenTimeAuthUseCase

    init() {
        DIContainer.shared.reset()
        mockUseCase = MockRequestScreenTimeAuthUseCase()
        DIContainer.shared.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { [mockUseCase] _ in
            mockUseCase
        }
    }

    @Test("retry success calls use case and clears isRequesting")
    func retrySuccess() async {
        let vm = DenialViewModel()
        await vm.retryTapped()
        #expect(mockUseCase.callCount == 1)
        #expect(!vm.isRequesting)
    }

    @Test("retry failure calls use case and clears isRequesting")
    func retryFailure() async {
        mockUseCase.stubbedError = NSError(
            domain: "FamilyControls", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Prompt dismissed"]
        )
        let vm = DenialViewModel()
        await vm.retryTapped()
        #expect(mockUseCase.callCount == 1)
        #expect(!vm.isRequesting)
    }

    @Test("isRequesting starts false")
    func isRequestingStartsFalse() async {
        let vm = DenialViewModel()
        #expect(!vm.isRequesting)
    }
}
