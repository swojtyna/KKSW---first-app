import XCTest
@preconcurrency import DeviceActivity
@testable import DeluluDetox

/// Plan 05-03 Task 2 — scheduled-blocking DAS registration lives on the
/// repository; the Phase 4 DeviceActivityCenterRunner seam is reused.
///
/// Wave 0 Outcome A assumed (see 05-DISCUSSION-LOG.md) — happy path uses
/// `repeats: true` for every segment; NO daily re-register fallback code.
@MainActor
final class ScheduleActivityMonitoringRepositoryTests: XCTestCase {

    // MARK: - Fake runner

    final class FakeCenter: DeviceActivityCenterRunner, @unchecked Sendable {
        /// Captures `(name, schedule)` pairs in registration order.
        var startedActivities: [(name: DeviceActivityName, schedule: DeviceActivitySchedule)] = []
        var stoppedActivities: [DeviceActivityName] = []
        var startError: Error?

        func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
            if let startError { throw startError }
            startedActivities.append((activity, schedule))
        }
        func stopMonitoring(_ activities: [DeviceActivityName]) {
            stoppedActivities.append(contentsOf: activities)
        }
    }

    struct TestError: Error, Equatable {}

    // MARK: - Helpers

    private func makeSchedule(
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int,
        id: UUID = UUID()
    ) -> Schedule {
        Schedule(
            id: id,
            name: nil,
            daysOfWeek: [2, 3, 4, 5, 6],       // Mon..Fri
            startHour: startHour, startMinute: startMinute,
            endHour: endHour, endMinute: endMinute,
            enabled: true,
            blocklistId: UUID(),
            appVersion: "test"
        )
    }

    // MARK: - startMonitoring (single-day)

    func testStartMonitoringSingleDayUsesMainSegmentAndOneDAS() async throws {
        let fake = FakeCenter()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        let schedule = makeSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        try await repo.startMonitoring(schedule: schedule)

        XCTAssertEqual(fake.startedActivities.count, 1)
        let (name, das) = try XCTUnwrap(fake.startedActivities.first)
        XCTAssertTrue(name.rawValue.hasSuffix(".\(ScheduleSegment.main.rawValue)"),
                      "Single-day schedule MUST register the .main segment name — got \(name.rawValue)")
        XCTAssertTrue(das.repeats, "D-13 happy-path — DAS.repeats == true (Wave 0 Outcome A).")
        XCTAssertEqual(das.intervalStart.hour, 9)
        XCTAssertEqual(das.intervalStart.minute, 0)
        XCTAssertEqual(das.intervalEnd.hour, 17)
        XCTAssertEqual(das.intervalEnd.minute, 0)
    }

    // MARK: - startMonitoring (cross-midnight split)

    func testStartMonitoringCrossMidnightSplitsIntoEveningAndMorningTwoDAS() async throws {
        let fake = FakeCenter()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        // 22:00 → 06:00 sleep-block: endMin(360) <= startMin(1320) ⇒ crossesMidnight.
        let schedule = makeSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

        try await repo.startMonitoring(schedule: schedule)

        XCTAssertEqual(fake.startedActivities.count, 2)

        let eveningEntry = fake.startedActivities.first(where: {
            $0.name.rawValue.hasSuffix(".\(ScheduleSegment.evening.rawValue)")
        })
        let morningEntry = fake.startedActivities.first(where: {
            $0.name.rawValue.hasSuffix(".\(ScheduleSegment.morning.rawValue)")
        })
        let evening = try XCTUnwrap(eveningEntry, "Missing .evening DAS for cross-midnight schedule.")
        let morning = try XCTUnwrap(morningEntry, "Missing .morning DAS for cross-midnight schedule.")

        // .evening: 22:00 → 23:59:59
        XCTAssertEqual(evening.schedule.intervalStart.hour, 22)
        XCTAssertEqual(evening.schedule.intervalStart.minute, 0)
        XCTAssertEqual(evening.schedule.intervalEnd.hour, 23)
        XCTAssertEqual(evening.schedule.intervalEnd.minute, 59)
        XCTAssertEqual(evening.schedule.intervalEnd.second, 59)

        // .morning: 00:00:00 → 06:00
        XCTAssertEqual(morning.schedule.intervalStart.hour, 0)
        XCTAssertEqual(morning.schedule.intervalStart.minute, 0)
        XCTAssertEqual(morning.schedule.intervalEnd.hour, 6)
        XCTAssertEqual(morning.schedule.intervalEnd.minute, 0)
    }

    // MARK: - repeats=true (Wave 0 Outcome A)

    func testStartMonitoringUsesRepeatsTruePerD13() async throws {
        let fake = FakeCenter()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        // Exercise both single-day and cross-midnight to cover all branches.
        let singleDay = makeSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let crossMidnight = makeSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

        try await repo.startMonitoring(schedule: singleDay)
        try await repo.startMonitoring(schedule: crossMidnight)

        XCTAssertEqual(fake.startedActivities.count, 3)
        for entry in fake.startedActivities {
            XCTAssertTrue(entry.schedule.repeats,
                          "Wave 0 Outcome A — every DAS registered by ScheduleActivityMonitoringRepository MUST use repeats=true (D-13). Got repeats=false on \(entry.name.rawValue).")
        }
    }

    // MARK: - stopMonitoring (defensive clear of all 3 variants)

    func testStopMonitoringRemovesAllSegmentsForScheduleId() async throws {
        let fake = FakeCenter()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        let id = UUID()

        await repo.stopMonitoring(scheduleId: id)

        // Defensive: ALL 3 segment variants must be passed to stopMonitoring so
        // a prior single-day→cross-midnight (or vice versa) edit leaves no
        // stale segment consuming the 20-activity budget (pitfall D-14 #1).
        let stoppedRaw = Set(fake.stoppedActivities.map { $0.rawValue })
        XCTAssertEqual(stoppedRaw.count, 3)
        XCTAssertTrue(stoppedRaw.contains("deluludetox.schedule.\(id.uuidString).main"))
        XCTAssertTrue(stoppedRaw.contains("deluludetox.schedule.\(id.uuidString).evening"))
        XCTAssertTrue(stoppedRaw.contains("deluludetox.schedule.\(id.uuidString).morning"))
    }

    // MARK: - Error wrapping

    func testStartMonitoringWrapsCenterErrorInRepositoryError() async {
        let fake = FakeCenter()
        fake.startError = TestError()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        let schedule = makeSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        do {
            try await repo.startMonitoring(schedule: schedule)
            XCTFail("expected throw")
        } catch ScheduleActivityMonitoringError.startFailed(let inner) {
            XCTAssertTrue(inner is TestError, "Underlying error must be preserved for Plan 04 rollback logging.")
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    // MARK: - buildDeviceActivitySchedules round-trip

    func testSegmentHelperBuildDeviceActivitySchedulesRoundTrip() {
        let singleDay = makeSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let crossMidnight = makeSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

        // Single-day: expect exactly one (name, das) pair with segment=.main,
        // and ScheduleActivityNames.parse must reproduce (id, .main).
        let singlePairs = singleDay.buildDeviceActivitySchedules()
        XCTAssertEqual(singlePairs.count, 1)
        let parsedSingle = ScheduleActivityNames.parse(singlePairs[0].name)
        XCTAssertEqual(parsedSingle?.scheduleId, singleDay.id)
        XCTAssertEqual(parsedSingle?.segment, .main)

        // Cross-midnight: two pairs, both round-tripping to (id, .evening/.morning).
        let crossPairs = crossMidnight.buildDeviceActivitySchedules()
        XCTAssertEqual(crossPairs.count, 2)
        let parsed = crossPairs.compactMap { ScheduleActivityNames.parse($0.name) }
        XCTAssertEqual(parsed.count, 2)
        for p in parsed {
            XCTAssertEqual(p.scheduleId, crossMidnight.id)
        }
        let segments = Set(parsed.map { $0.segment })
        XCTAssertEqual(segments, [.evening, .morning])
    }
}
