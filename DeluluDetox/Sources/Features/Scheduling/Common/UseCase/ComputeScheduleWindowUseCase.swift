import Foundation

/// Pure window-computation UseCase. Given a `Schedule`, a `now` Date, and a
/// calendar (timezone-aware), returns whether the schedule is supposed to be
/// actively blocking right now and — if so — when the current segment ends.
///
/// No mocks, no clock, no persistence: the implementation is deterministic.
/// `SelfHealSchedulesUseCase` (same plan) consumes the emitted `ScheduleWindow`
/// to decide whether to apply / clear the shield on app foreground
/// (CONTEXT §D-18).
///
/// Cross-midnight semantics (CONTEXT §D-03 / §D-13):
///  - The START weekday is authoritative. A schedule with `daysOfWeek = [2]`
///    (Monday) and 22:00 → 06:00 means "Monday 22:00 → Tuesday 06:00".
///  - Case A (post-midnight): if we're in `today` *before* the cross-end
///    time AND yesterday's weekday was in the schedule, we're still in
///    yesterday's evening segment.
///  - Case B (pre-midnight): if we're in today *after* start and today's
///    weekday is in the schedule, today's evening is running → ends
///    tomorrow at the configured end-of-window.
final class ComputeScheduleWindowUseCaseImpl: ComputeScheduleWindowUseCase, @unchecked Sendable {

    /// UserDefaults key for the "last-applied" flag consulted by
    /// `SelfHealSchedulesUseCase`. Colocated here because this UC owns the
    /// compute contract; the self-heal UC just reads what compute stamped.
    static func lastAppliedKey(scheduleId: UUID) -> String {
        "schedule_applied_\(scheduleId.uuidString)"
    }

    /// Dedicated UserDefaults suite for schedule reconciliation state.
    static let scheduleStateSuiteName = "com.kksw.DeluluDetox.scheduleState"

    init() {}

    func callAsFunction(schedule: Schedule, now: Date, calendar: Calendar) -> ScheduleWindow {
        guard schedule.enabled else {
            return ScheduleWindow(state: .inactive, currentWeekday: 0)
        }

        let weekday = calendar.component(.weekday, from: now)
        let startOfToday = calendar.startOfDay(for: now)

        let todayStart = startOfToday.addingTimeInterval(
            TimeInterval(schedule.startHour * 3600 + schedule.startMinute * 60)
        )
        let todayEnd = startOfToday.addingTimeInterval(
            TimeInterval(schedule.endHour * 3600 + schedule.endMinute * 60)
        )

        if schedule.crossesMidnight {
            // Case A: yesterday's evening still running in today before end-of-window.
            let yesterdayWeekday = ((weekday - 2 + 7) % 7) + 1 // roll back 1 weekday (1..7)
            if now < todayEnd, schedule.daysOfWeek.contains(yesterdayWeekday) {
                return ScheduleWindow(state: .active(endsAt: todayEnd), currentWeekday: weekday)
            }
            // Case B: today's evening starts / has started.
            if schedule.daysOfWeek.contains(weekday) {
                if now >= todayStart {
                    let tomorrowEnd = todayEnd.addingTimeInterval(24 * 3600)
                    return ScheduleWindow(state: .active(endsAt: tomorrowEnd), currentWeekday: weekday)
                } else {
                    return ScheduleWindow(state: .upcomingToday(startsAt: todayStart), currentWeekday: weekday)
                }
            }
            // Case C: neither today nor yesterday — next occurrence.
            let next = findNextOccurrence(
                after: now,
                daysOfWeek: schedule.daysOfWeek,
                hour: schedule.startHour,
                minute: schedule.startMinute,
                calendar: calendar
            )
            return ScheduleWindow(state: .notToday(nextDate: next), currentWeekday: weekday)
        }

        // Single-day schedule.
        if !schedule.daysOfWeek.contains(weekday) {
            let next = findNextOccurrence(
                after: now,
                daysOfWeek: schedule.daysOfWeek,
                hour: schedule.startHour,
                minute: schedule.startMinute,
                calendar: calendar
            )
            return ScheduleWindow(state: .notToday(nextDate: next), currentWeekday: weekday)
        }
        if now < todayStart {
            return ScheduleWindow(state: .upcomingToday(startsAt: todayStart), currentWeekday: weekday)
        }
        if now < todayEnd {
            return ScheduleWindow(state: .active(endsAt: todayEnd), currentWeekday: weekday)
        }
        let next = findNextOccurrence(
            after: now,
            daysOfWeek: schedule.daysOfWeek,
            hour: schedule.startHour,
            minute: schedule.startMinute,
            calendar: calendar
        )
        return ScheduleWindow(state: .notToday(nextDate: next), currentWeekday: weekday)
    }

    // MARK: - Next-occurrence search

    private func findNextOccurrence(
        after date: Date,
        daysOfWeek: [Int],
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date? {
        guard !daysOfWeek.isEmpty else { return nil }
        for dayOffset in 1...7 {
            guard let candidate = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let candidateWeekday = calendar.component(.weekday, from: candidate)
            if daysOfWeek.contains(candidateWeekday) {
                return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: candidate)
            }
        }
        return nil
    }
}
