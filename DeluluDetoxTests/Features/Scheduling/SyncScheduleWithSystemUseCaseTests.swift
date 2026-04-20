import XCTest
@testable import DeluluDetox

/// Plan 05-04 lands these assertions.
final class SyncScheduleWithSystemUseCaseTests: XCTestCase {

    func testSyncStopsOldThenStartsNewWhenEnabled() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: UC calls monitoring.stopMonitoring(scheduleId:) FIRST, then monitoring.startMonitoring(schedule:) — verify call order via MockScheduleActivityMonitoringRepository ordered-call log.")
    }

    func testSyncOnlyStopsWhenScheduleDisabled() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: schedule.enabled == false → UC calls stopMonitoring, does NOT call startMonitoring.")
    }

    func testSyncRollsBackScheduleJSONWhenStartMonitoringThrows() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: startMonitoring throws → UC calls repository.rollback / revert to prior snapshot AND rethrows so editor can surface the sarcastic error toast (CONTEXT §D-14).")
    }

    func testSyncLogsErrorWhenStopMonitoringThrows() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: stopMonitoring throws (stale segment, etc.) → UC logs the failure and CONTINUES with startMonitoring rather than aborting (pitfall #5: disable mid-window otherwise leaves dirty store + no recovery).")
    }
}
