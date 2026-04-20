import XCTest
@testable import DeluluDetox

final class ComputeStatsUseCaseTests: XCTestCase {

    private var calendar: Calendar!
    private var sut: ComputeStatsUseCaseImpl!

    override func setUp() {
        super.setUp()
        calendar = SessionRecordFixtures.polishCalendar()
        sut = ComputeStatsUseCaseImpl(calendar: calendar)
    }

    override func tearDown() {
        calendar = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        SessionRecordFixtures.date(y, m, d, calendar: calendar)
    }

    // MARK: - Test 1: totalCount counts only .completed outcomes

    func testTotalCount_countsOnlyCompletedOutcomes() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 19), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 18), calendar: calendar),
            SessionRecordFixtures.cancelled(on: day(2026, 4, 17), calendar: calendar),
            SessionRecordFixtures.cancelled(on: day(2026, 4, 16), calendar: calendar),
            SessionRecordFixtures.brokenByRevoke(on: day(2026, 4, 15), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.totalCount, 3)
    }

    // MARK: - Test 2: totalCount empty history → 0

    func testTotalCount_emptyHistory_returnsZero() {
        let now = day(2026, 4, 20)
        let stats = sut(history: [], now: now)
        XCTAssertEqual(stats.totalCount, 0)
    }

    // MARK: - Test 3: current streak today + past days

    func testCurrentStreak_todayAndPastDaysCompleted_returnsConsecutive() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 19), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 18), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.currentStreak, 3)
    }

    // MARK: - Test 4: current streak today only

    func testCurrentStreak_todayOnlyCompleted_returnsOne() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.currentStreak, 1)
    }

    // MARK: - Test 5: trailing edge (today empty, yesterday .completed → streak still alive)

    func testCurrentStreak_todayEmptyYesterdayCompleted_returnsYesterdayStreak() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 4, 19), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 18), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 17), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.currentStreak, 3) // D-03 trailing edge
    }

    // MARK: - Test 6: two-day gap → zero

    func testCurrentStreak_twoDayGap_returnsZero() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 4, 18), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 17), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.currentStreak, 0)
    }

    // MARK: - Test 7: empty history

    func testCurrentStreak_emptyHistory_returnsZero() {
        let now = day(2026, 4, 20)
        let stats = sut(history: [], now: now)
        XCTAssertEqual(stats.currentStreak, 0)
    }

    // MARK: - Test 8: cancelled only

    func testCurrentStreak_cancelledOutcomes_ignored() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.cancelled(on: day(2026, 4, 20), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.currentStreak, 0)
    }

    // MARK: - Test 9: broken only

    func testCurrentStreak_brokenByRevokeOutcomes_ignored() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.brokenByRevoke(on: day(2026, 4, 20), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.currentStreak, 0)
    }

    // MARK: - Test 10: longest streak scans full history

    func testLongestStreak_scansFullHistory_returnsMaxRun() {
        let now = day(2026, 4, 20)
        // Older run of 3 days, newer run of 6 days (today inclusive)
        let history: [SessionRecord] = [
            // older run: 2026-04-10, 11, 12 (3 days)
            SessionRecordFixtures.completed(on: day(2026, 4, 10), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 11), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 12), calendar: calendar),
            // current run: 2026-04-15..20 (6 days)
            SessionRecordFixtures.completed(on: day(2026, 4, 15), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 16), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 17), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 18), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 19), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.longestStreak, 6)
        XCTAssertEqual(stats.currentStreak, 6)
    }

    // MARK: - Test 11: single day longest

    func testLongestStreak_singleDay_returnsOne() {
        let now = day(2026, 4, 20)
        let history = [
            SessionRecordFixtures.completed(on: day(2026, 4, 10), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.longestStreak, 1)
    }

    // MARK: - Test 12: empty longest

    func testLongestStreak_emptyHistory_returnsZero() {
        let now = day(2026, 4, 20)
        let stats = sut(history: [], now: now)
        XCTAssertEqual(stats.longestStreak, 0)
    }

    // MARK: - Test 13: last7DaysFlags Monday-first

    func testLast7DaysFlags_orderMondayFirst() {
        // 2026-04-22 is a Wednesday. Monday of that week = 2026-04-20.
        let now = day(2026, 4, 22)
        let history = [
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar) // Monday
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.last7DaysFlags.count, 7)
        XCTAssertTrue(stats.last7DaysFlags[0], "Monday flag should be true")
        for i in 1..<7 {
            XCTAssertFalse(stats.last7DaysFlags[i], "Weekday index \(i) should be false")
        }
    }

    // MARK: - Test 14: todayWeekdayIndex identifies today (Wednesday → 2)

    func testLast7DaysFlags_todayWeekdayIndex_identifiesToday() {
        // 2026-04-22 is a Wednesday.
        let now = day(2026, 4, 22)
        let stats = sut(history: [], now: now)
        XCTAssertEqual(stats.todayWeekdayIndex, 2) // 0=Mon, 1=Tue, 2=Wed
    }

    // MARK: - Test 15: all 7 true

    func testLast7DaysFlags_allSeven_completedAcrossWeek() {
        // Week of 2026-04-20 Monday..2026-04-26 Sunday
        let now = day(2026, 4, 22) // Wednesday mid-week
        let history: [SessionRecord] = (0..<7).map { offset in
            let d = calendar.date(byAdding: .day, value: offset, to: day(2026, 4, 20))!
            return SessionRecordFixtures.completed(on: d, calendar: calendar)
        }

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.last7DaysFlags, Array(repeating: true, count: 7))
    }

    // MARK: - Test 16: DST spring-forward boundary (2026-03-29 CET→CEST)

    func testStreak_acrossDSTBoundary_springForward_contiguous() {
        // Poland CET→CEST transition: 2026-03-29 (clocks go from 02:00 → 03:00).
        let now = day(2026, 3, 29)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 3, 29), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 3, 28), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 3, 27), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.currentStreak, 3)
        XCTAssertEqual(stats.longestStreak, 3)
    }

    // MARK: - Test 17: DST fall-back boundary (2026-10-25 CEST→CET)

    func testStreak_acrossDSTBoundary_fallBack_contiguous() {
        // Poland CEST→CET transition: 2026-10-25 (clocks go from 03:00 → 02:00).
        let now = day(2026, 10, 26)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 10, 26), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 10, 25), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 10, 24), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.currentStreak, 3)
        XCTAssertEqual(stats.longestStreak, 3)
    }

    // MARK: - Test 18: completedDaysSet buckets by startOfDay

    func testCompletedDaysSet_bucketsByStartOfDay() {
        let now = day(2026, 4, 20)
        // Two sessions same day at different hours
        let noon = SessionRecordFixtures.date(2026, 4, 20, hour: 12, calendar: calendar)
        let evening = SessionRecordFixtures.date(2026, 4, 20, hour: 20, calendar: calendar)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: noon, calendar: calendar),
            SessionRecordFixtures.completed(on: evening, calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.completedDaysSet.count, 1, "Two sessions same day should bucket to one day")
    }

    // MARK: - Test 19: active records (actualEndAt == nil, outcome == nil) ignored

    func testRecordWithNilActualEndAt_ignored() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.active(startedAt: day(2026, 4, 20)),
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.totalCount, 1, "Active record must NOT contribute to totalCount")
        XCTAssertEqual(stats.currentStreak, 1)
    }

    // MARK: - Test 20: multiple completed same day — totalCount counts each, streak counts 1 day

    func testMultipleCompletedSameDay_countsAsOneDay_totalCountsEach() {
        let now = day(2026, 4, 20)
        let morning = SessionRecordFixtures.date(2026, 4, 20, hour: 8, calendar: calendar)
        let afternoon = SessionRecordFixtures.date(2026, 4, 20, hour: 14, calendar: calendar)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: morning, calendar: calendar),
            SessionRecordFixtures.completed(on: afternoon, calendar: calendar)
        ]

        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.totalCount, 2)
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.longestStreak, 1)
    }

    // MARK: - Test 21: calendar injection is honored

    func testCalendarInjection_customCalendarHonored() {
        // Construct an independent Polish calendar — same semantics, deterministic.
        let deterministicCalendar = SessionRecordFixtures.polishCalendar()
        let alternateSut = ComputeStatsUseCaseImpl(calendar: deterministicCalendar)
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar),
            SessionRecordFixtures.completed(on: day(2026, 4, 19), calendar: calendar)
        ]

        let a = sut(history: history, now: now)
        let b = alternateSut(history: history, now: now)

        XCTAssertEqual(a, b, "Identical deterministic calendars should produce identical Stats")
    }

    // MARK: - Test 22: malformed record (outcome == .completed but actualEndAt == nil) ignored gracefully

    func testActualEndAtNil_butOutcomeCompleted_ignoredGracefully() {
        let now = day(2026, 4, 20)
        let history: [SessionRecord] = [
            SessionRecordFixtures.malformedCompletedWithoutEndDate(),
            SessionRecordFixtures.completed(on: day(2026, 4, 20), calendar: calendar)
        ]

        // Should not crash; malformed record contributes nothing.
        let stats = sut(history: history, now: now)

        XCTAssertEqual(stats.totalCount, 1)
        XCTAssertEqual(stats.currentStreak, 1)
    }
}
