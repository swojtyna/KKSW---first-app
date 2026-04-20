import XCTest
import Combine
@testable import DeluluDetox

/// VM-level tests for `StatsViewModel`. DIContainer is reset per test and
/// seeded with `MockObserveStatsUseCase`. Main-run-loop bounces are awaited
/// via `expectation` → `DispatchQueue.main.async { fulfill }`.
@MainActor
final class StatsViewModelTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        DIContainer.shared.register(ObserveStatsUseCase.self, scope: .application) { _ in
            MockObserveStatsUseCase()
        }
    }

    private func mainRunLoopBounce() {
        let exp = expectation(description: "sink")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - Initial state

    func testInitialState_isEmpty() {
        let vm = StatsViewModel()
        XCTAssertEqual(vm.stats.totalCount, 0)
        XCTAssertEqual(vm.stats.currentStreak, 0)
        XCTAssertEqual(vm.stats.longestStreak, 0)
    }

    // MARK: - Reactive pipeline

    func testReceivesStats_fromObservePublisher() {
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
        mainRunLoopBounce()

        XCTAssertEqual(vm.stats.currentStreak, 7)
        XCTAssertEqual(vm.stats.totalCount, 42)
        XCTAssertEqual(vm.stats.longestStreak, 12)
    }

    // MARK: - isMarked

    func testIsMarked_returnsTrue_forDayInCompletedDaysSet() {
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
        mainRunLoopBounce()

        XCTAssertTrue(vm.isMarked(day: today))
    }

    func testIsMarked_returnsFalse_forDayNotInSet() {
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
        mainRunLoopBounce()

        XCTAssertFalse(vm.isMarked(day: yesterday))
    }

    // MARK: - Month navigation

    func testPrevMonthTapped_decrementsDisplayedMonth() {
        let vm = StatsViewModel()
        let initial = vm.displayedMonth

        vm.prevMonthTapped()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let expected = cal.date(byAdding: .month, value: -1, to: initial)!
        XCTAssertEqual(cal.component(.month, from: vm.displayedMonth), cal.component(.month, from: expected))
        XCTAssertEqual(cal.component(.year, from: vm.displayedMonth), cal.component(.year, from: expected))
    }

    func testNextMonthTapped_incrementsDisplayedMonth() {
        let vm = StatsViewModel()
        let initial = vm.displayedMonth

        vm.nextMonthTapped()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let expected = cal.date(byAdding: .month, value: 1, to: initial)!
        XCTAssertEqual(cal.component(.month, from: vm.displayedMonth), cal.component(.month, from: expected))
        XCTAssertEqual(cal.component(.year, from: vm.displayedMonth), cal.component(.year, from: expected))
    }

    // MARK: - Formatting / grid geometry

    func testDisplayedMonthFormatted_isLocalized() {
        let vm = StatsViewModel()
        let formatted = vm.displayedMonthFormatted
        XCTAssertFalse(formatted.isEmpty)
        // PL format "LLLL yyyy" — must contain a 4-digit year substring.
        let yearPattern = try! NSRegularExpression(pattern: #"\d{4}"#)
        let range = NSRange(formatted.startIndex..., in: formatted)
        XCTAssertNotNil(yearPattern.firstMatch(in: formatted, range: range), "expected 4-digit year in `\(formatted)`")
    }

    /// April 2026: April 1 is a Wednesday. Monday-first ⇒ leadingEmptyCells = 2 (Mon, Tue).
    func testLeadingEmptyCells_correctForMondayFirstWeek() {
        let vm = StatsViewModel()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.firstWeekday = 2
        var comps = DateComponents(); comps.year = 2026; comps.month = 4; comps.day = 15
        let april2026 = cal.date(from: comps)!
        vm.setDisplayedMonthForTesting(april2026)

        XCTAssertEqual(vm.leadingEmptyCells, 2)
    }

    func testDaysInMonth_correctForApril2026() {
        let vm = StatsViewModel()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        var comps = DateComponents(); comps.year = 2026; comps.month = 4; comps.day = 15
        let april2026 = cal.date(from: comps)!
        vm.setDisplayedMonthForTesting(april2026)

        XCTAssertEqual(vm.daysInMonth, 30)
    }
}
