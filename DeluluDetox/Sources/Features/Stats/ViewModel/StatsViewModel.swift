import Combine
import Foundation
import Observation

/// @Observable VM for the Stats screen (CONTEXT §D-11).
/// Monthly calendar state (displayedMonth + prev/next) lives here.
/// The View binds to `stats`, `displayedMonth`, `displayedMonthFormatted`,
/// `leadingEmptyCells`, `daysInMonth`, and queries `isMarked(day:)`.
@MainActor
@Observable
final class StatsViewModel: @unchecked Sendable {

    private(set) var stats: Stats = .empty
    private(set) var displayedMonth: Date

    @ObservationIgnored @LazyInjected private var observeStats: ObserveStatsUseCase

    @ObservationIgnored
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        // Monday-first (CONTEXT §Claude's Discretion — PL convention).
        cal.firstWeekday = 2
        cal.locale = Locale(identifier: "pl_PL")
        return cal
    }()

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private lazy var monthYearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pl_PL")
        df.dateFormat = "LLLL yyyy"
        return df
    }()

    init() {
        self.displayedMonth = calendar.startOfDay(for: Date())
        observeStats.execute()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStats in self?.stats = newStats }
            .store(in: &cancellables)
    }

    // MARK: - Intent

    func prevMonthTapped() { shiftMonth(by: -1) }
    func nextMonthTapped() { shiftMonth(by: +1) }

    private func shiftMonth(by months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: displayedMonth) {
            displayedMonth = calendar.startOfDay(for: next)
        }
    }

    // MARK: - View queries

    func isMarked(day: Date) -> Bool {
        stats.completedDaysSet.contains(calendar.startOfDay(for: day))
    }

    func isToday(day: Date) -> Bool {
        calendar.isDate(day, inSameDayAs: Date())
    }

    var displayedMonthFormatted: String {
        monthYearFormatter.string(from: displayedMonth).capitalized
    }

    /// Days in the displayed month (28..31).
    var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
    }

    /// Leading blank grid cells before day 1 in a Monday-first layout.
    /// Calendar.weekday is Sun-first (1..7). Monday-first mapping: (weekday + 5) % 7.
    var leadingEmptyCells: Int {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return 0
        }
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth) // 1=Sun..7=Sat
        return (weekdayOfFirst + 5) % 7                                       // 0=Mon..6=Sun
    }

    /// Produces `Date` for each day-of-month cell in the displayed grid.
    func date(forDayOfMonth day: Int) -> Date? {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return nil
        }
        return calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
    }

    // MARK: - Test seam

    /// Test-only seam so deterministic tests can pin `displayedMonth` to a
    /// known calendar month (e.g. April 2026) without polluting the public API.
    /// Production code MUST NOT call this — Prev/NextMonthTapped own the mutation surface.
    internal func setDisplayedMonthForTesting(_ date: Date) {
        displayedMonth = calendar.startOfDay(for: date)
    }
}
