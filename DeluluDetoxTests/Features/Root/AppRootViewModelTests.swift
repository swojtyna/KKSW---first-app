// AppRootViewModelTests — Combine-driven destination flow.
//
// NOTE (W12 flakiness mitigation): every test that calls `mockObserve.subject.send(...)`
// followed by an assertion on `vm.destination` inserts `try await Task.yield()` immediately
// before the assertion. Combine .sink + Observation mutation propagation need at least one
// run-loop tick on MainActor before the new value is visible to assertions.
import XCTest
import Combine
import FamilyControls
@testable import DeluluDetox

@MainActor
final class AppRootViewModelTests: XCTestCase {
    // IUO safe in XCTest: setUp runs before every test (W16).
    var mockObserve: MockObserveScreenTimeAuthStatusUseCase!
    var mockRefresh: MockRefreshScreenTimeAuthStatusUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .notDetermined)
        mockRefresh = MockRefreshScreenTimeAuthStatusUseCase()
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        DIContainer.shared.register(RefreshScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockRefresh] _ in
            mockRefresh!
        }
    }

    func testInitialDestinationForNotDetermined() async {
        let vm = AppRootViewModel()
        await Task.yield()
        // CurrentValueSubject initial .notDetermined → destination = .onboarding
        XCTAssertEqual(vm.destination, .onboarding)
    }

    func testInitialDestinationForApproved() async {
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }

        let vm = AppRootViewModel()
        await Task.yield()

        XCTAssertEqual(vm.destination, .home)
    }

    func testEmissionOfApprovedRoutesToHome() async {
        let vm = AppRootViewModel()
        await Task.yield()
        XCTAssertEqual(vm.destination, .onboarding)

        mockObserve.subject.send(.approved)
        await Task.yield()

        XCTAssertEqual(vm.destination, .home)
    }

    func testEmissionOfDeniedRoutesToDenial() async {
        let vm = AppRootViewModel()

        mockObserve.subject.send(.denied)
        await Task.yield()

        XCTAssertEqual(vm.destination, .denial)
    }

    func testRefreshStatusCallsUseCase() {
        let vm = AppRootViewModel()
        XCTAssertEqual(mockRefresh.callCount, 0)

        vm.refreshStatus()

        XCTAssertEqual(mockRefresh.callCount, 1)
    }

    func testMultipleEmissionsUpdateDestination() async {
        let vm = AppRootViewModel()

        mockObserve.subject.send(.approved)
        await Task.yield()
        XCTAssertEqual(vm.destination, .home)

        mockObserve.subject.send(.denied)
        await Task.yield()
        XCTAssertEqual(vm.destination, .denial)

        mockObserve.subject.send(.notDetermined)
        await Task.yield()
        XCTAssertEqual(vm.destination, .onboarding)
    }
}
