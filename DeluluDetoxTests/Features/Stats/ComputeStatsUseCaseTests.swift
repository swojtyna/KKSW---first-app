import Foundation
import Testing
@testable import DeluluDetox

@Suite("ComputeStatsUseCase")
struct ComputeStatsUseCaseTests {

    private let calendar = SessionRecordFixtures.polishCalendar()

    private func makeSut() -> ComputeStatsUseCaseImpl {
        ComputeStatsUseCaseImpl(calendar: calendar)
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        SessionRecordFixtures.date(y, m, d, calendar: calendar)
    }

    // MARK: - totalCount

    @Test("totalCount counts only .completed outcomes")
    func totalCountOnlyCountsCompleted() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 19), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 18), calendar: calendar),
            SessionRecordFixtures.cancelled(on: day(2026, 4, 17), calendar: calendar),
            SessionRecordFixtures.cancelled(on: day(2026, 4, 16), calendar: calendar),
            SessionRecordFixtures.brokenByRevoke(on: day(2026, 4, 15), calendar: calendar),
        ]
        #expect(makeSut().execute(history: history, now: now).totalCount == 3)
    }

    @Test("totalCount is zero for empty history")
    func totalCountEmptyHistory() {
        #expect(makeSut().execute(history: [], now: day(2026, 4, 20)).totalCount == 0)
    }

    // MARK: - currentStreak (parameterized)

    struct StreakCase: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let completedAprilDays: [Int]
        let nowAprilDay: Int
        let expected: Int
    }

    @Test("currentStreak", arguments: [
        StreakCase(
            testDescription: "today + 2 consecutive past days → 3",
            completedAprilDays: [18, 19, 20], nowAprilDay: 20, expected: 3
        ),
        StreakCase(
            testDescription: "today only → 1",
            completedAprilDays: [20], nowAprilDay: 20, expected: 1
        ),
        StreakCase(
            testDescription: "today empty, 3 consecutive past days → 3 (trailing edge)",
            completedAprilDays: [17, 18, 19], nowAprilDay: 20, expected: 3
        ),
        StreakCase(
            testDescription: "two-day gap from today → 0",
            completedAprilDays: [17, 18], nowAprilDay: 20, expected: 0
        ),
        StreakCase(
            testDescription: "empty history → 0",
            completedAprilDays: [], nowAprilDay: 20, expected: 0
        ),
    ])
    func currentStreak(_ tc: StreakCase) {
        let history = tc.completedAprilDays.map {
            SessionRecordFixtures.completed(on: day(2026, 4, $0), calendar: calendar)
        }
        let stats = makeSut().execute(history: history, now: day(2026, 4, tc.nowAprilDay))
        #expect(stats.currentStreak == tc.expected)
    }

    @Test("currentStreak ignores .cancelledByUser outcome")
    func currentStreakIgnoresCancelled() {
        let now = day(2026, 4, 20)
        let history = [SessionRecordFixtures.cancelled(on: now, calendar: calendar)]
        #expect(makeSut().execute(history: history, now: now).currentStreak == 0)
    }

    @Test("currentStreak ignores .brokenByRevoke outcome")
    func currentStreakIgnoresBrokenByRevoke() {
        let now = day(2026, 4, 20)
        let history = [SessionRecordFixtures.brokenByRevoke(on: now, calendar: calendar)]
        #expect(makeSut().execute(history: history, now: now).currentStreak == 0)
    }

    // MARK: - longestStreak

    @Test("longestStreak scans full history and returns the longest run")
    func longestStreakScansFullHistory() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            // older run: 3 days
            SessionRecordFixtures.completed(on: day(2026, 4, 10), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 11), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 12), calendar: calendar),
            // current run: 6 days
            SessionRecordFixtures.completed(on: day(2026, 4, 15), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 16), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 17), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 18), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 19), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar),
        ]
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.longestStreak == 6)
        #expect(stats.currentStreak == 6)
    }

    @Test("longestStreak is 1 for single day")
    func longestStreakSingleDay() {
        let stats = makeSut().execute(history: [SessionRecordFixtures.completed(on: day(2026, 4, 10), calendar: calendar)], now: day(2026, 4, 20))
        #expect(stats.longestStreak == 1)
    }

    @Test("longestStreak is 0 for empty history")
    func longestStreakEmptyHistory() {
        #expect(makeSut().execute(history: [], now: day(2026, 4, 20)).longestStreak == 0)
    }

    // MARK: - last7DaysFlags

    @Test("last7DaysFlags array is Monday-first and marks only completed days")
    func last7DaysFlagsOrderMondayFirst() {
        // 2026-04-22 is Wednesday; Monday of that week = 2026-04-20
        let now = day(2026, 4, 22)
        let history = [SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar)] // Monday
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.last7DaysFlags.count == 7)
        #expect(stats.last7DaysFlags[0]) // Monday = true
        for i in 1..<7 {
            #expect(!stats.last7DaysFlags[i], "weekday index \(i) should be false")
        }
    }

    @Test("todayWeekdayIndex identifies Wednesday (index 2 in 0=Mon scheme)")
    func todayWeekdayIndexForWednesday() {
        let stats = makeSut().execute(history: [], now: day(2026, 4, 22))
        #expect(stats.todayWeekdayIndex == 2) // 0=Mon, 1=Tue, 2=Wed
    }

    @Test("last7DaysFlags all true when full week completed")
    func last7DaysFlagsAllTrue() {
        let now = day(2026, 4, 22) // Wednesday mid-week
        let history: [SessionRecord] = (0..<7).map { offset in
            let d = calendar.date(byAdding: .day, value: offset, to: day(2026, 4, 20))!
            return SessionRecordFixtures.completed(on: d, calendar: calendar)
        }
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.last7DaysFlags == Array(repeating: true, count: 7))
    }

    // MARK: - DST boundary

    @Test("streak is contiguous across DST spring-forward (2026-03-29 CET→CEST)")
    func streakAcrossDSTSpringForward() {
        let now = day(2026, 3, 29)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 3, 29), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 3, 28), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 3, 27), calendar: calendar),
        ]
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.currentStreak == 3)
        #expect(stats.longestStreak == 3)
    }

    @Test("streak is contiguous across DST fall-back (2026-10-25 CEST→CET)")
    func streakAcrossDSTFallBack() {
        let now = day(2026, 10, 26)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 10, 26), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 10, 25), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 10, 24), calendar: calendar),
        ]
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.currentStreak == 3)
        #expect(stats.longestStreak == 3)
    }

    // MARK: - Edge cases

    @Test("two sessions on same day bucket to one completed day")
    func sameDay_bucketedToOneDay() {
        let now = day(2026, 4, 20)
        let noon = SessionRecordFixtures.date(2026, 4, 20, hour: 12, calendar: calendar)
        let evening = SessionRecordFixtures.date(2026, 4, 20, hour: 20, calendar: calendar)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: noon, calendar: calendar),
            SessionRecordFixtures.completed(on: evening, calendar: calendar),
        ]
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.completedDaysSet.count == 1)
    }

    @Test("active record (actualEndAt nil) is ignored by all stats")
    func activeRecordIsIgnored() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.active(startedAt: day(2026, 4, 20)),
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar),
        ]
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.totalCount == 1)
        #expect(stats.currentStreak == 1)
    }

    @Test("two completed same day: totalCount counts each, streak counts 1 day")
    func multipleCompletedSameDay() {
        let now = day(2026, 4, 20)
        let morning = SessionRecordFixtures.date(2026, 4, 20, hour: 8, calendar: calendar)
        let afternoon = SessionRecordFixtures.date(2026, 4, 20, hour: 14, calendar: calendar)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: morning, calendar: calendar),
            SessionRecordFixtures.completed(on: afternoon, calendar: calendar),
        ]
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.totalCount == 2)
        #expect(stats.currentStreak == 1)
        #expect(stats.longestStreak == 1)
    }

    @Test("malformed record (outcome completed but actualEndAt nil) is ignored gracefully")
    func malformedRecordIgnored() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.malformedCompletedWithoutEndDate(),
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar),
        ]
        let stats = makeSut().execute(history: history, now: now)
        #expect(stats.totalCount == 1)
        #expect(stats.currentStreak == 1)
    }

    @Test("identical deterministic calendars produce identical Stats")
    func calendarInjectionIsHonored() {
        let alternate = ComputeStatsUseCaseImpl(calendar: SessionRecordFixtures.polishCalendar())
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 19), calendar: calendar),
        ]
        let a = makeSut().execute(history: history, now: now)
        let b = alternate.execute(history: history, now: now)
        #expect(a == b)
    }
}
