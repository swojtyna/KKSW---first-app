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
        let vm = OnboardingViewModel()
        await vm.grantAccessTapped()

        XCTAssertEqual(mockRepo.requestAuthorizationCallCount, 1)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isRequesting)
        // Event authorized — pełny test przez statusPublisher w Wave 5 (01.1-05).
    }

    func testGrantAccessFailure() async {
        mockRepo.requestAuthorizationError = NSError(
            domain: "FamilyControls", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid account type"]
        )
        let vm = OnboardingViewModel()
        await vm.grantAccessTapped()

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isRequesting)
    }

    func testIsRequestingStartsFalse() async {
        let vm = OnboardingViewModel()
        XCTAssertFalse(vm.isRequesting)
    }
}
