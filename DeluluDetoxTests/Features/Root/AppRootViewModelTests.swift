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
    var mockReconcile: MockReconcileBlocklistUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .notDetermined)
        mockRefresh = MockRefreshScreenTimeAuthStatusUseCase()
        mockReconcile = MockReconcileBlocklistUseCase()
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        DIContainer.shared.register(RefreshScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockRefresh] _ in
            mockRefresh!
        }
        DIContainer.shared.register(ReconcileBlocklistUseCase.self, scope: .unique) { [mockReconcile] _ in
            mockReconcile!
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

    func testRefreshStatusCallsUseCase() async {
        let vm = AppRootViewModel()
        XCTAssertEqual(mockRefresh.callCount, 0)

        vm.refreshStatus()
        await Task.yield()

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

    // MARK: - Phase 02 additions (SEL-05)

    func testRefreshStatusAlsoCallsReconcileBlocklist() async throws {
        let vm = AppRootViewModel()
        XCTAssertEqual(mockReconcile.callCount, 0)

        vm.refreshStatus()
        // Sleep yields the MainActor long enough for the fire-and-forget Task
        // to be scheduled and for the async `reconcileBlocklist()` body to run.
        // Plain `Task.yield()` is insufficient here because the detached Task
        // is MainActor-bound and won't run until the caller suspends with a
        // non-trivial wait.
        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms

        XCTAssertEqual(mockReconcile.callCount, 1)
    }

    func testRefreshStatusReconcileFailureDoesNotCrashOrChangeDestination() async throws {
        enum TestError: Error { case boom }
        mockReconcile.stubbedError = TestError.boom

        mockObserve = MockObserveScreenTimeAuthStatusUseCase(initialStatus: .approved)
        DIContainer.shared.register(ObserveScreenTimeAuthStatusUseCase.self, scope: .unique) { [mockObserve] _ in
            mockObserve!
        }
        let vm = AppRootViewModel()
        await Task.yield()
        XCTAssertEqual(vm.destination, .home)

        vm.refreshStatus()
        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms — see note above.

        // Reconcile threw, but destination is unchanged and refreshStatus still counted.
        XCTAssertEqual(mockReconcile.callCount, 1)
        XCTAssertEqual(mockRefresh.callCount, 1)
        XCTAssertEqual(vm.destination, .home)
    }
}
