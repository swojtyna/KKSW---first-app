import XCTest
@testable import DeluluDetox

/// Plan 05-03 lands these assertions.
final class ScheduleActivityMonitoringRepositoryTests: XCTestCase {

    func testStartMonitoringSingleDayUsesMainSegmentAndOneDAS() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: single-day schedule (endHour > startHour OR (endHour == startHour && endMinute > startMinute)) registers exactly 1 DeviceActivitySchedule with activityName suffix .main.")
    }

    func testStartMonitoringCrossMidnightSplitsIntoEveningAndMorningTwoDAS() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: cross-midnight (endMin <= startMin per Schedule.crossesMidnight) registers 2 DeviceActivitySchedules — .evening (intervalStart → 23:59:59) + .morning (00:00:00 → intervalEnd).")
    }

    func testStartMonitoringUsesRepeatsTruePerD13() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: DeviceActivitySchedule.repeats == true (per CONTEXT D-13). If Wave 0 spike outcome is C (repeats=true unreliable on iOS 26), this test will be REWRITTEN to assert repeats=false + .year/.month/.day DateComponents.")
    }

    func testStopMonitoringRemovesAllSegmentsForScheduleId() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: stopMonitoring(scheduleId:) calls DeviceActivityCenter.stopMonitoring with BOTH the .main variant AND the .evening + .morning variants so no stale segment persists after a schedule is deleted or disabled.")
    }

    func testStartMonitoringWrapsCenterErrorInRepositoryError() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: DeviceActivityCenter throws (e.g. authorization lapsed, 20-activity budget exceeded) → repository throws ScheduleActivityMonitoringError.startFailed(wrapped) with the underlying error preserved.")
    }

    func testSegmentHelperBuildDeviceActivitySchedulesRoundTrip() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: Schedule.buildDeviceActivitySchedules() returns an array whose ScheduleActivityNames.parse(_:) results reproduce the same (scheduleId, segment) tuples used by startMonitoring.")
    }
}
