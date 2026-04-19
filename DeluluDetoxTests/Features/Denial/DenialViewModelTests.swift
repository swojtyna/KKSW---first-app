import XCTest
@testable import DeluluDetox

@MainActor
final class DenialViewModelTests: XCTestCase {
    // IUO safe in XCTest: setUp runs before every test (W16).
    var mockUseCase: MockRequestScreenTimeAuthUseCase!

    override func setUp() {
        super.setUp()
        DIContainer.shared.reset()
        mockUseCase = MockRequestScreenTimeAuthUseCase()
        // Denial consumes UC registered by OnboardingInjection (D-17).
        // In tests we register directly — same protocol ID, same mock instance.
        DIContainer.shared.register(RequestScreenTimeAuthUseCase.self, scope: .unique) { [mockUseCase] _ in
            mockUseCase!
        }
    }

    func testRetrySuccess() async {
        let vm = DenialViewModel()

        await vm.retryTapped()

        XCTAssertEqual(mockUseCase.callCount, 1)
        XCTAssertFalse(vm.isRequesting)
    }

    func testRetryFailure() async {
        mockUseCase.stubbedError = NSError(
            domain: "FamilyControls", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Prompt dismissed"]
        )
        let vm = DenialViewModel()

        await vm.retryTapped()

        XCTAssertEqual(mockUseCase.callCount, 1)
        XCTAssertFalse(vm.isRequesting)
    }

    func testIsRequestingStartsFalse() async {
        let vm = DenialViewModel()
        XCTAssertFalse(vm.isRequesting)
    }
}
