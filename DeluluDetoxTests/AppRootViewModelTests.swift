import XCTest
@testable import DeluluDetox

final class AppRootViewModelTests: XCTestCase {
    func testInitialRouteWhenNotDetermined() {
        let mockRepo = MockScreenTimeAuthRepository()
        mockRepo.stubbedStatus = .notDetermined
        let container = makeTestContainer(repo: mockRepo)
        let vm = AppRootViewModel(container: container)

        guard case .onboarding = vm.screen else {
            XCTFail("Expected .onboarding, got \(vm.screen)")
            return
        }
    }

    func testInitialRouteWhenApproved() {
        let mockRepo = MockScreenTimeAuthRepository()
        mockRepo.stubbedStatus = .approved
        let container = makeTestContainer(repo: mockRepo)
        let vm = AppRootViewModel(container: container)

        guard case .home = vm.screen else {
            XCTFail("Expected .home, got \(vm.screen)")
            return
        }
    }

    func testCheckAuthorizationRoutesDenied() {
        let mockRepo = MockScreenTimeAuthRepository()
        mockRepo.stubbedStatus = .notDetermined
        let container = makeTestContainer(repo: mockRepo)
        let vm = AppRootViewModel(container: container)

        mockRepo.stubbedStatus = .denied
        vm.checkAuthorization()

        guard case .denial = vm.screen else {
            XCTFail("Expected .denial, got \(vm.screen)")
            return
        }
    }

    func testCheckAuthorizationRoutesApproved() {
        let mockRepo = MockScreenTimeAuthRepository()
        mockRepo.stubbedStatus = .notDetermined
        let container = makeTestContainer(repo: mockRepo)
        let vm = AppRootViewModel(container: container)

        mockRepo.stubbedStatus = .approved
        vm.checkAuthorization()

        guard case .home = vm.screen else {
            XCTFail("Expected .home, got \(vm.screen)")
            return
        }
    }

    private func makeTestContainer(repo: ScreenTimeAuthRepository) -> DependencyContainer {
        DependencyContainer(screenTimeAuthRepository: repo)
    }
}
