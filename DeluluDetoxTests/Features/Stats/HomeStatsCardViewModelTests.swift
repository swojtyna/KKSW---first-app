import Foundation
import Combine
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class HomeStatsCardViewModelTests {

    init() {
        DIContainer.shared.reset()
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in
            MockObserveStatsUseCase()
        }
        DIContainer.shared.register(GetBrokenStreakCopyUseCase.self, scope: .unique) { _ in
            MockGetBrokenStreakCopyUseCase()
        }
    }

    // MARK: - Initial state

    @Test("initial state is empty")
    func initialState_isEmpty() {
        let vm = HomeStatsCardViewModel()
        #expect(vm.stats.totalCount == 0)
        #expect(vm.stats.currentStreak == 0)
        #expect(vm.brokenStreakCopy == nil)
    }

    // MARK: - Stats projection

    @Test("receives stats and updates current and total")
    func receivesStats_updatesCurrentAndTotal() async {
        let mockObserve = MockObserveStatsUseCase()
        registerMocks(observe: mockObserve)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 5, longest: 12, total: 20))
        await mainRunLoopBounce()

        #expect(vm.stats.currentStreak == 5)
        #expect(vm.stats.totalCount == 20)
    }

    // MARK: - Broken streak branch (D-10)

    @Test("brokenStreakCopy is non-nil when current zero and longest at least three")
    func brokenStreakCopy_nonNil_whenCurrentZeroAndLongestAtLeastThree() async {
        let mockObserve = MockObserveStatsUseCase()
        let mockCopy = MockGetBrokenStreakCopyUseCase()
        mockCopy.stub = { "Straciłeś \($0)-dniową serię." }
        registerMocks(observe: mockObserve, copy: mockCopy)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 0, longest: 12, total: 100))
        await mainRunLoopBounce()

        #expect(vm.brokenStreakCopy != nil)
        #expect(vm.brokenStreakCopy!.contains("12"))
    }

    @Test("brokenStreakCopy is nil when current zero and longest below three")
    func brokenStreakCopy_nil_whenCurrentZeroAndLongestBelowThree() async {
        let mockObserve = MockObserveStatsUseCase()
        registerMocks(observe: mockObserve)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 0, longest: 2))
        await mainRunLoopBounce()

        #expect(vm.brokenStreakCopy == nil)
    }

    @Test("brokenStreakCopy is nil when current non-zero")
    func brokenStreakCopy_nil_whenCurrentNonZero() async {
        let mockObserve = MockObserveStatsUseCase()
        registerMocks(observe: mockObserve)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 5, longest: 12))
        await mainRunLoopBounce()

        #expect(vm.brokenStreakCopy == nil)
    }

    @Test("brokenStreakCopy uses GetBrokenStreakCopyUseCase")
    func brokenStreakCopy_usesGetBrokenStreakCopyUseCase() async {
        let mockObserve = MockObserveStatsUseCase()
        let mockCopy = MockGetBrokenStreakCopyUseCase()
        mockCopy.stub = { "shame-\($0)" }
        registerMocks(observe: mockObserve, copy: mockCopy)
        let vm = HomeStatsCardViewModel()

        mockObserve.subject.send(stats(current: 0, longest: 7))
        await mainRunLoopBounce()

        #expect(vm.brokenStreakCopy == "shame-7")
    }

    // MARK: - Pass-through

    @Test("last7DaysFlags and todayWeekdayIndex are exposed")
    func last7DaysFlags_exposed() async {
        let mockObserve = MockObserveStatsUseCase()
        registerMocks(observe: mockObserve)
        let vm = HomeStatsCardViewModel()

        let flags: [Bool] = [true, true, true, false, false, false, false]
        mockObserve.subject.send(stats(current: 3, longest: 3, total: 3, flags: flags, todayIndex: 3))
        await mainRunLoopBounce()

        #expect(vm.stats.last7DaysFlags == flags)
        #expect(vm.stats.todayWeekdayIndex == 3)
    }
}

// MARK: - Private Helpers

private extension HomeStatsCardViewModelTests {
    func mainRunLoopBounce() async {
        await withCheckedContinuation { cont in
            DispatchQueue.main.async { cont.resume() }
        }
    }

    func registerMocks(
        observe: MockObserveStatsUseCase,
        copy: MockGetBrokenStreakCopyUseCase = MockGetBrokenStreakCopyUseCase()
    ) {
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in observe }
        DIContainer.shared.register(GetBrokenStreakCopyUseCase.self, scope: .unique) { _ in copy }
    }

    func stats(
        current: Int,
        longest: Int,
        total: Int = 0,
        flags: [Bool] = Array(repeating: false, count: 7),
        todayIndex: Int = 0
    ) -> Stats {
        Stats(
            currentStreak: current,
            longestStreak: longest,
            totalCount: total,
            last7DaysFlags: flags,
            todayWeekdayIndex: todayIndex,
            completedDaysSet: []
        )
    }
}
