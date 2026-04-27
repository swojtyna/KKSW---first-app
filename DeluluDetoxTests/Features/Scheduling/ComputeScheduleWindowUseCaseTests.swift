import Foundation
import Testing
@testable import DeluluDetox

@Suite("ComputeScheduleWindowUseCase")
struct ComputeScheduleWindowUseCaseTests {

    // MARK: - Helpers

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = 0
        return calendar.date(from: comps)!
    }

    private func monFriSchedule(startHour: Int = 9, endHour: Int = 17, enabled: Bool = true) -> Schedule {
        Schedule(
            id: UUID(), name: nil,
            daysOfWeek: [2, 3, 4, 5, 6],
            startHour: startHour, startMinute: 0,
            endHour: endHour, endMinute: 0,
            enabled: enabled, blocklistId: UUID(), appVersion: "test"
        )
    }

    private func dailySchedule(startHour: Int, endHour: Int) -> Schedule {
        Schedule(
            id: UUID(), name: nil,
            daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
            startHour: startHour, startMinute: 0,
            endHour: endHour, endMinute: 0,
            enabled: true, blocklistId: UUID(), appVersion: "test"
        )
    }

    // MARK: - Single-day schedule

    @Test("active mid-window (Wed 12:00 in Mon-Fri 9–17)")
    func singleDayActiveMidWindow() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let now = date(2026, 4, 22, 12, 0) // Wednesday
        let window = uc.execute(schedule: monFriSchedule(), now: now, calendar: calendar)
        #expect(window.state == .active(endsAt: date(2026, 4, 22, 17, 0)))
        #expect(window.currentWeekday == 4) // Calendar.weekday: Sun=1 → Wed=4
    }

    @Test("upcoming today before window start (Wed 7:00 in Mon-Fri 9–17)")
    func singleDayUpcomingToday() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let now = date(2026, 4, 22, 7, 0) // Wednesday before 9:00
        let window = uc.execute(schedule: monFriSchedule(), now: now, calendar: calendar)
        #expect(window.state == .upcomingToday(startsAt: date(2026, 4, 22, 9, 0)))
        #expect(window.currentWeekday == 4)
    }

    // MARK: - Cross-midnight schedule (parameterized)

    struct CrossMidnightCase: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let nowDay: Int, nowHour: Int, nowMinute: Int
        let expectedEndDay: Int
    }

    @Test("cross-midnight window is active", arguments: [
        CrossMidnightCase(
            testDescription: "before midnight — Wed 23:30 (segment started same day)",
            nowDay: 22, nowHour: 23, nowMinute: 30, expectedEndDay: 23
        ),
        CrossMidnightCase(
            testDescription: "after midnight — Thu 03:00 (segment started previous day)",
            nowDay: 23, nowHour: 3, nowMinute: 0, expectedEndDay: 23
        ),
    ])
    func crossMidnightActive(_ tc: CrossMidnightCase) {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let now = date(2026, 4, tc.nowDay, tc.nowHour, tc.nowMinute)
        let window = uc.execute(schedule: dailySchedule(startHour: 22, endHour: 6), now: now, calendar: calendar)
        #expect(window.state == .active(endsAt: date(2026, 4, tc.expectedEndDay, 6, 0)))
    }

    // MARK: - Weekday exclusion

    @Test("not today when weekday excluded (Sat in Mon-Fri schedule, next run = Mon)")
    func weekdayExclusionReturnsNotToday() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let now = date(2026, 4, 25, 10, 0) // Saturday (weekday=7)
        let window = uc.execute(schedule: monFriSchedule(), now: now, calendar: calendar)
        guard case let .notToday(nextDate) = window.state else {
            Issue.record("Expected .notToday, got \(window.state)")
            return
        }
        #expect(nextDate == date(2026, 4, 27, 9, 0)) // Monday 09:00
    }

    // MARK: - Disabled schedule

    @Test("disabled schedule returns inactive regardless of time")
    func disabledScheduleReturnsInactive() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let now = date(2026, 4, 22, 12, 0)
        let window = uc.execute(schedule: monFriSchedule(enabled: false), now: now, calendar: calendar)
        #expect(window.state == .inactive)
        #expect(window.currentWeekday == 0)
    }
}
