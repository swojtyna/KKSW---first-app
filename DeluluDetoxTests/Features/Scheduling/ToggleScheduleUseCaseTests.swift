import XCTest
@testable import DeluluDetox

/// Plan 05-04 lands these assertions.
final class ToggleScheduleUseCaseTests: XCTestCase {

    func testToggleEnableCallsUpsertThenSync() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: toggle(scheduleId:, enabled: true) → repo.upsert(schedule with enabled=true) THEN sync(schedule:) — order verified via call log.")
    }

    func testToggleDisableCallsUpsertThenSyncWhichStopsMonitoring() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: toggle(scheduleId:, enabled: false) → repo.upsert THEN sync; sync then calls stopMonitoring only (no startMonitoring).")
    }

    func testToggleMissingScheduleThrowsNotFound() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: scheduleId not present in ScheduleRepository → UC throws ScheduleNotFound without calling sync.")
    }
}
