import Foundation
import Combine
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class StatsViewModelTests {

    init() {
        DIContainer.shared.reset()
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in
            MockObserveStatsUseCase()
        }
    }

    // MARK: - Initial state

    @Test("initial state is empty")
    func initialState_isEmpty() {
        let vm = StatsViewModel()
        #expect(vm.stats.totalCount == 0)
        #expect(vm.stats.currentStreak == 0)
        #expect(vm.stats.longestStreak == 0)
    }

    // MARK: - Reactive pipeline

    @Test("receives stats from observe publisher")
    func receivesStats_fromObservePublisher() async {
        let mock = MockObserveStatsUseCase()
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in mock }
        let vm = StatsViewModel()

        let newStats = Stats(
            currentStreak: 7,
            longestStreak: 12,
            totalCount: 42,
            last7DaysFlags: Array(repeating: true, count: 7),
            todayWeekdayIndex: 2,
            completedDaysSet: []
        )
        mock.subject.send(newStats)
        await mainRunLoopBounce()

        #expect(vm.stats.currentStreak == 7)
        #expect(vm.stats.totalCount == 42)
        #expect(vm.stats.longestStreak == 12)
    }

    // MARK: - isMarked

    @Test("isMarked returns true for day in completedDaysSet")
    func isMarked_returnsTrue_forDayInCompletedDaysSet() async {
        let mock = MockObserveStatsUseCase()
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in mock }
        let vm = StatsViewModel()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let today = cal.startOfDay(for: Date())

        let stats = Stats(
            currentStreak: 1, longestStreak: 1, totalCount: 1,
            last7DaysFlags: Array(repeating: false, count: 7),
            todayWeekdayIndex: 0,
            completedDaysSet: [today]
        )
        mock.subject.send(stats)
        await mainRunLoopBounce()

        #expect(vm.isMarked(day: today))
    }

    @Test("isMarked returns false for day not in set")
    func isMarked_returnsFalse_forDayNotInSet() async {
        let mock = MockObserveStatsUseCase()
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in mock }
        let vm = StatsViewModel()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let stats = Stats(
            currentStreak: 1, longestStreak: 1, totalCount: 1,
            last7DaysFlags: Array(repeating: false, count: 7),
            todayWeekdayIndex: 0,
            completedDaysSet: [today]
        )
        mock.subject.send(stats)
        await mainRunLoopBounce()

        #expect(!vm.isMarked(day: yesterday))
    }

    // MARK: - Month navigation

    @Test("prevMonthTapped decrements displayed month")
    func prevMonthTapped_decrementsDisplayedMonth() {
        let vm = StatsViewModel()
        let initial = vm.displayedMonth

        vm.prevMonthTapped()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let expected = cal.date(byAdding: .month, value: -1, to: initial)!
        #expect(cal.component(.month, from: vm.displayedMonth) == cal.component(.month, from: expected))
        #expect(cal.component(.year, from: vm.displayedMonth) == cal.component(.year, from: expected))
    }

    @Test("nextMonthTapped increments displayed month")
    func nextMonthTapped_incrementsDisplayedMonth() {
        let vm = StatsViewModel()
        let initial = vm.displayedMonth

        vm.nextMonthTapped()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let expected = cal.date(byAdding: .month, value: 1, to: initial)!
        #expect(cal.component(.month, from: vm.displayedMonth) == cal.component(.month, from: expected))
        #expect(cal.component(.year, from: vm.displayedMonth) == cal.component(.year, from: expected))
    }

    // MARK: - Formatting / grid geometry

    @Test("displayedMonthFormatted is localized with 4-digit year")
    func displayedMonthFormatted_isLocalized() {
        let vm = StatsViewModel()
        let formatted = vm.displayedMonthFormatted
        #expect(!formatted.isEmpty)
        let yearPattern = try! NSRegularExpression(pattern: #"\d{4}"#)
        let range = NSRange(formatted.startIndex..., in: formatted)
        #expect(yearPattern.firstMatch(in: formatted, range: range) != nil, "expected 4-digit year in `\(formatted)`")
    }

    @Test("leadingEmptyCells is correct for Monday-first week (April 2026)")
    func leadingEmptyCells_correctForMondayFirstWeek() {
        let vm = StatsViewModel()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.firstWeekday = 2
        var comps = DateComponents(); comps.year = 2026; comps.month = 4; comps.day = 15
        let april2026 = cal.date(from: comps)!
        vm.setDisplayedMonthForTesting(april2026)

        #expect(vm.leadingEmptyCells == 2)
    }

    @Test("daysInMonth is correct for April 2026")
    func daysInMonth_correctForApril2026() {
        let vm = StatsViewModel()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        var comps = DateComponents(); comps.year = 2026; comps.month = 4; comps.day = 15
        let april2026 = cal.date(from: comps)!
        vm.setDisplayedMonthForTesting(april2026)

        #expect(vm.daysInMonth == 30)
    }
}

// MARK: - Private Helpers

private extension StatsViewModelTests {
    func mainRunLoopBounce() async {
        await withCheckedContinuation { cont in
            DispatchQueue.main.async { cont.resume() }
        }
    }
}
