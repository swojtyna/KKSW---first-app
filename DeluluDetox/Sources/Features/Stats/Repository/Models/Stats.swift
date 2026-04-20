import Foundation

/// Aggregated stats for GAM-01 + GAM-02. Computed on demand from the full
/// `[SessionRecord]` history (CONTEXT §D-06 / §D-07 — no cache, no stats.json).
/// Produced exclusively by `ComputeStatsUseCase`.
struct Stats: Equatable, Sendable {
    /// GAM-02 current streak (D-03): longest trailing run of days, from today
    /// back, with ≥1 `.completed` session. Trailing-edge rule — if today has
    /// none but yesterday has .completed, streak still "alive" counting from yesterday.
    let currentStreak: Int

    /// GAM-02 longest streak across full history (D-05).
    let longestStreak: Int

    /// GAM-01 total count of `.completed` outcomes across full history (D-06).
    /// `.cancelledByUser` and `.brokenByRevoke` NOT counted (D-02).
    let totalCount: Int

    /// Home-card mini row: 7 flags ordered Monday..Sunday (PL locale).
    /// `flags[0]` = this week's Monday, `flags[6]` = this week's Sunday.
    /// "This week" = the week containing the reference date.
    let last7DaysFlags: [Bool]

    /// Index into `last7DaysFlags` identifying today. 0=Monday..6=Sunday.
    let todayWeekdayIndex: Int

    /// Full set of days (Calendar.startOfDay) on which ≥1 `.completed` was
    /// recorded. Used by Stats screen calendar grid (`StatsViewModel.isMarked(day:)`).
    let completedDaysSet: Set<Date>

    static let empty = Stats(
        currentStreak: 0,
        longestStreak: 0,
        totalCount: 0,
        last7DaysFlags: Array(repeating: false, count: 7),
        todayWeekdayIndex: 0,
        completedDaysSet: []
    )
}
