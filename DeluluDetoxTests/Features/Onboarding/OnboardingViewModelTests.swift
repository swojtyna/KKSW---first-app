import Foundation
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class OnboardingViewModelTests {

    let mockUseCase: MockRequestScreenTimeAuthUseCase

    init() {
        DIContainer.shared.reset()
        mockUseCase = MockRequestScreenTimeAuthUseCase()
        DIContainer.shared.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { [mockUseCase] _ in
            mockUseCase
        }
    }

    @Test("grant access success calls use case and clears error and isRequesting")
    func grantAccessSuccess() async {
        let vm = OnboardingViewModel()
        await vm.grantAccessTapped()
        #expect(mockUseCase.callCount == 1)
        #expect(vm.error == nil)
        #expect(!vm.isRequesting)
    }

    @Test("grant access failure sets error message and clears isRequesting")
    func grantAccessFailure() async {
        mockUseCase.stubbedError = NSError(
            domain: "FamilyControls", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid account type"]
        )
        let vm = OnboardingViewModel()
        await vm.grantAccessTapped()
        #expect(mockUseCase.callCount == 1)
        #expect(vm.error != nil)
        #expect(vm.error == "Invalid account type")
        #expect(!vm.isRequesting)
    }

    @Test("isRequesting starts false")
    func isRequestingStartsFalse() async {
        let vm = OnboardingViewModel()
        #expect(!vm.isRequesting)
    }
}
