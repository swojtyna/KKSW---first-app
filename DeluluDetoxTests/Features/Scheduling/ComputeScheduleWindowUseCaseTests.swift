import XCTest
@testable import DeluluDetox

/// Plan 05-04 lands these assertions. Pure logic — no mocks needed.
final class ComputeScheduleWindowUseCaseTests: XCTestCase {

    func testSingleDayActiveMidWindow() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: schedule 09:00-17:00 Mon-Fri, now=Wed 12:00 → result = .active(endsAt: Wed 17:00).")
    }

    func testSingleDayUpcomingToday() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: schedule 09:00-17:00 Mon-Fri, now=Wed 07:00 → result = .upcomingToday(startsAt: Wed 09:00).")
    }

    func testCrossMidnightBeforeMidnightActive() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: schedule 22:00-06:00 daily, now=23:30 → result = .active(endsAt: tomorrow 06:00). Evening segment is the trigger.")
    }

    func testCrossMidnightAfterMidnightActive() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: schedule 22:00-06:00 daily, now=03:00 → result = .active(endsAt: today 06:00). Yesterday's evening segment is the trigger — weekday-filter check must consult YESTERDAY's weekday.")
    }

    func testWeekdayExclusionReturnsNotToday() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: schedule Mon-Fri only (daysOfWeek=[2..6]), now=Saturday 10:00 → result = .notToday(nextDate: next Monday 09:00).")
    }

    func testDisabledScheduleReturnsInactive() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: schedule.enabled = false → result = .inactive regardless of now / daysOfWeek / window.")
    }
}
