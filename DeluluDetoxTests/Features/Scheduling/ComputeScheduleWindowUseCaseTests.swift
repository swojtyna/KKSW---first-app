import XCTest
@testable import DeluluDetox

/// Plan 05-04 Task 1 — pure-logic assertions for `ComputeScheduleWindowUseCaseImpl`.
/// All tests pin the calendar to `Europe/Warsaw` for determinism and feed fixed
/// `now` Dates via ISO8601 parsing. No mocks — the UC is pure.
final class ComputeScheduleWindowUseCaseTests: XCTestCase {

    // MARK: - Helpers

    private func warsawCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return cal
    }

    /// Build a Date in Europe/Warsaw from year/month/day/hour/minute.
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        let cal = warsawCalendar()
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = 0
        return cal.date(from: comps)!
    }

    /// Produce a Schedule with the given time window + weekday mask.
    private func schedule(
        startHour: Int, startMinute: Int = 0,
        endHour: Int, endMinute: Int = 0,
        daysOfWeek: [Int],
        enabled: Bool = true
    ) -> Schedule {
        Schedule(
            id: UUID(),
            name: nil,
            daysOfWeek: daysOfWeek,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            enabled: enabled,
            blocklistId: UUID(),
            appVersion: "test"
        )
    }

    // MARK: - Tests

    func testSingleDayActiveMidWindow() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let cal = warsawCalendar()
        // 2026-04-22 (Wednesday). Calendar.weekday: Sun=1 → Wed=4.
        let now = date(2026, 4, 22, 12, 0)
        let s = schedule(startHour: 9, endHour: 17, daysOfWeek: [2, 3, 4, 5, 6])
        let expectedEnd = date(2026, 4, 22, 17, 0)

        let window = uc(schedule: s, now: now, calendar: cal)

        XCTAssertEqual(window.state, .active(endsAt: expectedEnd))
        XCTAssertEqual(window.currentWeekday, 4)
    }

    func testSingleDayUpcomingToday() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let cal = warsawCalendar()
        let now = date(2026, 4, 22, 7, 0) // Wed 07:00
        let s = schedule(startHour: 9, endHour: 17, daysOfWeek: [2, 3, 4, 5, 6])
        let expectedStart = date(2026, 4, 22, 9, 0)

        let window = uc(schedule: s, now: now, calendar: cal)

        XCTAssertEqual(window.state, .upcomingToday(startsAt: expectedStart))
        XCTAssertEqual(window.currentWeekday, 4)
    }

    func testCrossMidnightBeforeMidnightActive() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let cal = warsawCalendar()
        // Wed 23:30 with daily sleep-block 22:00 → 06:00. Today's evening is running;
        // ends tomorrow 06:00.
        let now = date(2026, 4, 22, 23, 30)
        let s = schedule(startHour: 22, endHour: 6, daysOfWeek: [1, 2, 3, 4, 5, 6, 7])
        let expectedEnd = date(2026, 4, 23, 6, 0)

        let window = uc(schedule: s, now: now, calendar: cal)

        XCTAssertEqual(window.state, .active(endsAt: expectedEnd))
    }

    func testCrossMidnightAfterMidnightActive() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let cal = warsawCalendar()
        // Thursday 03:00. Yesterday (Wed) evening segment is still running — ends today at 06:00.
        let now = date(2026, 4, 23, 3, 0)
        let s = schedule(startHour: 22, endHour: 6, daysOfWeek: [1, 2, 3, 4, 5, 6, 7])
        let expectedEnd = date(2026, 4, 23, 6, 0)

        let window = uc(schedule: s, now: now, calendar: cal)

        XCTAssertEqual(window.state, .active(endsAt: expectedEnd))
    }

    func testWeekdayExclusionReturnsNotToday() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let cal = warsawCalendar()
        // 2026-04-25 is a Saturday (weekday=7). Schedule is Mon-Fri [2..6] only.
        let now = date(2026, 4, 25, 10, 0)
        let s = schedule(startHour: 9, endHour: 17, daysOfWeek: [2, 3, 4, 5, 6])
        let expectedNext = date(2026, 4, 27, 9, 0) // Monday 09:00

        let window = uc(schedule: s, now: now, calendar: cal)

        guard case let .notToday(nextDate) = window.state else {
            return XCTFail("Expected .notToday, got \(window.state)")
        }
        XCTAssertNotNil(nextDate)
        XCTAssertEqual(nextDate, expectedNext)
    }

    func testDisabledScheduleReturnsInactive() {
        let uc = ComputeScheduleWindowUseCaseImpl()
        let cal = warsawCalendar()
        let now = date(2026, 4, 22, 12, 0)
        let s = schedule(startHour: 9, endHour: 17, daysOfWeek: [2, 3, 4, 5, 6], enabled: false)

        let window = uc(schedule: s, now: now, calendar: cal)

        XCTAssertEqual(window.state, .inactive)
        XCTAssertEqual(window.currentWeekday, 0)
    }
}
