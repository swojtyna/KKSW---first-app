import XCTest
@testable import DeluluDetox

final class HomeViewModelTests: XCTestCase {
    func testChooseAppsTappedIsNoOpInPhase1() {
        let vm = HomeViewModel()
        // No-op in Phase 1 per D-15 — simply ensure it doesn't crash.
        vm.chooseAppsTapped()
        // No observable state to assert on; HomeVM is empty per design.
    }
}
