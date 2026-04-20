import Foundation

/// Pure function: `[SessionRecord] + referenceDate` → `Stats`.
/// No I/O, no DI beyond `Calendar`. GAM-01 + GAM-02 correctness lives here.
/// Semantics: CONTEXT §D-01..§D-08.
protocol ComputeStatsUseCase: Sendable {
    func callAsFunction(history: [SessionRecord], now: Date) -> Stats
}

final class ComputeStatsUseCaseImpl: ComputeStatsUseCase {
    private let calendar: Calendar

    init(calendar: Calendar = ComputeStatsUseCaseImpl.defaultCalendar()) {
        self.calendar = calendar
    }

    func callAsFunction(history: [SessionRecord], now: Date) -> Stats {
        // 1. Extract .completed completion dates. Records where outcome != .completed
        //    OR actualEndAt == nil (active / malformed) are ignored.
        let completedDates: [Date] = history.compactMap { record in
            guard record.outcome == .completed, let endedAt = record.actualEndAt else { return nil }
            return endedAt
        }
        let totalCount = completedDates.count

        // 2. Bucket by Calendar day (DST-safe; arithmetic via Calendar only, no raw TimeInterval).
        let completedDaysSet: Set<Date> = Set(completedDates.map { calendar.startOfDay(for: $0) })

        // 3. Current streak (D-03 trailing edge).
        let today = calendar.startOfDay(for: now)
        var currentStreak = 0
        let startOfCurrentRun: Date? = {
            if completedDaysSet.contains(today) { return today }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               completedDaysSet.contains(yesterday) {
                return yesterday
            }
            return nil
        }()
        if let start = startOfCurrentRun {
            var cursor = start
            while completedDaysSet.contains(cursor) {
                currentStreak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            }
        }

        // 4. Longest streak — scan sorted unique days, track max run.
        var longestStreak = 0
        var run = 0
        var prev: Date?
        for day in completedDaysSet.sorted() {
            if let p = prev, let next = calendar.date(byAdding: .day, value: 1, to: p),
               calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longestStreak = max(longestStreak, run)
            prev = day
        }

        // 5. Monday-first week flags + todayWeekdayIndex.
        //    Week of `now`: find Monday of this week, then flag each day Mon..Sun.
        let (last7DaysFlags, todayWeekdayIndex) = computeLast7Days(
            today: today,
            now: now,
            completedDaysSet: completedDaysSet
        )

        return Stats(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalCount: totalCount,
            last7DaysFlags: last7DaysFlags,
            todayWeekdayIndex: todayWeekdayIndex,
            completedDaysSet: completedDaysSet
        )
    }

    // MARK: - Private

    /// Monday-first weekdays: 0=Monday, 1=Tuesday, ..., 6=Sunday.
    /// Calendar.weekday: 1=Sunday, 2=Monday, ..., 7=Saturday.
    /// Mapping: mondayFirstIndex = (weekday + 5) % 7
    private func computeLast7Days(
        today: Date,
        now: Date,
        completedDaysSet: Set<Date>
    ) -> (flags: [Bool], todayIndex: Int) {
        let weekdayOfToday = calendar.component(.weekday, from: now) // 1=Sun..7=Sat
        let todayMondayFirst = (weekdayOfToday + 5) % 7              // 0=Mon..6=Sun
        // Monday of current week = today minus todayMondayFirst days.
        guard let monday = calendar.date(byAdding: .day, value: -todayMondayFirst, to: today) else {
            return (Array(repeating: false, count: 7), todayMondayFirst)
        }
        let flags: [Bool] = (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return false }
            return completedDaysSet.contains(calendar.startOfDay(for: day))
        }
        return (flags, todayMondayFirst)
    }

    private static func defaultCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        cal.firstWeekday = 2 // Monday (PL convention — Claude's Discretion per CONTEXT)
        return cal
    }
}
