import XCTest
@testable import DeluluDetox

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    // IUO pattern is safe in XCTest: setUp runs before every test and assigns the value; tearDown nils it.
    // Standard idiom — see `.claude/guides` for rationale (W16).
    var mockUseCase: MockRequestScreenTimeAuthUseCase!

    override func setUp() {
        super.setUp()
        DIContainer.shared.reset()
        mockUseCase = MockRequestScreenTimeAuthUseCase()
        DIContainer.shared.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { [mockUseCase] _ in
            mockUseCase!
        }
    }

    func testGrantAccessSuccess() async {
        let vm = OnboardingViewModel()

        await vm.grantAccessTapped()

        XCTAssertEqual(mockUseCase.callCount, 1)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isRequesting)
    }

    func testGrantAccessFailure() async {
        mockUseCase.stubbedError = NSError(
            domain: "FamilyControls", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid account type"]
        )
        let vm = OnboardingViewModel()

        await vm.grantAccessTapped()

        XCTAssertEqual(mockUseCase.callCount, 1)
        XCTAssertNotNil(vm.error)
        XCTAssertEqual(vm.error, "Invalid account type")
        XCTAssertFalse(vm.isRequesting)
    }

    func testIsRequestingStartsFalse() async {
        let vm = OnboardingViewModel()
        XCTAssertFalse(vm.isRequesting)
    }
}
