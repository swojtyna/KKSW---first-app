import XCTest
@testable import DeluluDetox

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    var mockRepo: MockScreenTimeAuthRepository!

    override func setUp() {
        super.setUp()
        DIContainer.shared.reset()
        mockRepo = MockScreenTimeAuthRepository()
        DIContainer.shared.register(ScreenTimeAuthRepository.self, scope: .application) { [mockRepo] _ in
            mockRepo!
        }
        DIContainer.shared.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { c in
            RequestScreenTimeAuthUseCaseImpl(repository: c.resolve())
        }
    }

    func testGrantAccessSuccess() async {
        var authorizedCalled = false
        let vm = OnboardingViewModel()
        vm.onAuthorized = { authorizedCalled = true }

        await vm.grantAccessTapped()

        XCTAssertTrue(authorizedCalled)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isRequesting)
    }

    func testGrantAccessFailure() async {
        mockRepo.requestAuthorizationError = NSError(
            domain: "FamilyControls", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid account type"]
        )
        var authorizedCalled = false
        let vm = OnboardingViewModel()
        vm.onAuthorized = { authorizedCalled = true }

        await vm.grantAccessTapped()

        XCTAssertFalse(authorizedCalled)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isRequesting)
    }

    func testIsRequestingDuringRequest() async {
        let vm = OnboardingViewModel()

        // isRequesting starts false
        XCTAssertFalse(vm.isRequesting)
    }
}
