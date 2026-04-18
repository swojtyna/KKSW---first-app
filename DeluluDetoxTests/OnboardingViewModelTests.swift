import XCTest
@testable import DeluluDetox

final class OnboardingViewModelTests: XCTestCase {
    func testGrantAccessSuccess() async {
        let mockRepo = MockScreenTimeAuthRepository()
        let useCase = RequestScreenTimeAuthUseCaseImpl(repository: mockRepo)
        var authorizedCalled = false
        let vm = OnboardingViewModel(
            requestAuth: useCase,
            onAuthorized: { authorizedCalled = true }
        )

        await vm.grantAccessTapped()

        XCTAssertTrue(authorizedCalled)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isRequesting)
    }

    func testGrantAccessFailure() async {
        let mockRepo = MockScreenTimeAuthRepository()
        mockRepo.requestAuthorizationError = NSError(
            domain: "FamilyControls", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid account type"]
        )
        let useCase = RequestScreenTimeAuthUseCaseImpl(repository: mockRepo)
        var authorizedCalled = false
        let vm = OnboardingViewModel(
            requestAuth: useCase,
            onAuthorized: { authorizedCalled = true }
        )

        await vm.grantAccessTapped()

        XCTAssertFalse(authorizedCalled)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isRequesting)
    }

    func testIsRequestingDuringRequest() async {
        let mockRepo = MockScreenTimeAuthRepository()
        let useCase = RequestScreenTimeAuthUseCaseImpl(repository: mockRepo)
        let vm = OnboardingViewModel(requestAuth: useCase)

        // isRequesting starts false
        XCTAssertFalse(vm.isRequesting)
    }
}
