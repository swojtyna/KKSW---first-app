import XCTest
import Combine
@testable import DeluluDetox

/// VM-level tests for `HomeStatsCardViewModel`. Asserts Stats projection +
/// D-10 broken-streak branch semantics (nil when currentStreak > 0 OR
/// longestStreak < 3; non-nil only when currentStreak == 0 AND longestStreak >= 3).
@MainActor
final class HomeStatsCardViewModelTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in
            MockObserveStatsUseCase()
        }
        DIContainer.shared.register(GetBrokenStreakCopyUseCase.self, scope: .unique) { _ in
            MockGetBrokenStreakCopyUseCase()
        }
    }

    private func mainRunLoopBounce() {
        let exp = expectation(description: "sink")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
    }

    private func registerMocks(
        observe: MockObserveStatsUseCase,
        copy: MockGetBrokenStreakCopyUseCase = MockGetBrokenStreakCopyUseCase()
    ) {
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in observe }
        DIContainer.shared.register(GetBrokenStreakCopyUseCase.self, scope: .unique) { _ in copy }
    }

    private func stats(current: Int, longest: Int, total: Int = 0,
                       flags: [Bool] = Array(repeating: false, count: 7),
                       todayIndex: Int = 0) -> Stats {
        Stats(
            currentStreak: current,
            longestStreak: longest,
            totalCount: total,
            last7DaysFlags: flags,
            todayWeekdayIndex: todayIndex,
            completedDaysSet: []
        )
    }

    // MARK: - Initial state

    func testInitialState_isEmpty() {
        let vm = HomeStatsCardViewModel()
        XCTAssertEqual(vm.stats.totalCount, 0)
        XCTAssertEqual(vm.stats.currentStreak, 0)
        XCTAssertNil(vm.brokenStreakCopy)
    }

    // MARK: - Stats projection

    func testReceivesStats_updatesCurrentAndTotal() {
        let mockObserve = MockObserveStatsUseCase()
        registerMocks(observe: mockObserve)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 5, longest: 12, total: 20))
        mainRunLoopBounce()

        XCTAssertEqual(vm.stats.currentStreak, 5)
        XCTAssertEqual(vm.stats.totalCount, 20)
    }

    // MARK: - Broken streak branch (D-10)

    func testBrokenStreakCopy_nonNil_whenCurrentZeroAndLongestAtLeastThree() {
        let mockObserve = MockObserveStatsUseCase()
        let mockCopy = MockGetBrokenStreakCopyUseCase()
        mockCopy.stub = { "Straciłeś \($0)-dniową serię." }
        registerMocks(observe: mockObserve, copy: mockCopy)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 0, longest: 12, total: 100))
        mainRunLoopBounce()

        XCTAssertNotNil(vm.brokenStreakCopy)
        XCTAssertTrue(vm.brokenStreakCopy!.contains("12"))
    }

    func testBrokenStreakCopy_nil_whenCurrentZeroAndLongestBelowThree() {
        let mockObserve = MockObserveStatsUseCase()
        registerMocks(observe: mockObserve)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 0, longest: 2))
        mainRunLoopBounce()

        XCTAssertNil(vm.brokenStreakCopy)
    }

    func testBrokenStreakCopy_nil_whenCurrentNonZero() {
        let mockObserve = MockObserveStatsUseCase()
        registerMocks(observe: mockObserve)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 5, longest: 12))
        mainRunLoopBounce()

        XCTAssertNil(vm.brokenStreakCopy)
    }

    func testBrokenStreakCopy_usesGetBrokenStreakCopyUseCase() {
        let mockObserve = MockObserveStatsUseCase()
        let mockCopy = MockGetBrokenStreakCopyUseCase()
        mockCopy.stub = { "shame-\($0)" }
        registerMocks(observe: mockObserve, copy: mockCopy)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 0, longest: 7))
        mainRunLoopBounce()

        XCTAssertEqual(vm.brokenStreakCopy, "shame-7")
    }

    // MARK: - Pass-through

    func testLast7DaysFlags_exposed() {
        let mockObserve = MockObserveStatsUseCase()
        registerMocks(observe: mockObserve)
        let vm = HomeStatsCardViewModel()

        let flags: [Bool] = [true, true, true, false, false, false, false]
        mockObserve.subject.send(stats(current: 3, longest: 3, total: 3, flags: flags, todayIndex: 3))
        mainRunLoopBounce()

        XCTAssertEqual(vm.stats.last7DaysFlags, flags)
        XCTAssertEqual(vm.stats.todayWeekdayIndex, 3)
    }
}
