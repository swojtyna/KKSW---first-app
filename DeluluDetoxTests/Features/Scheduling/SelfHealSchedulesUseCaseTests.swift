import XCTest
@testable import DeluluDetox

/// Plan 05-04 lands these assertions.
final class SelfHealSchedulesUseCaseTests: XCTestCase {

    func testAppliesShieldWhenShouldBeActiveButStoreClear() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: ComputeScheduleWindow returns .active but last-apply marker absent (reboot mid-window) → UC calls shieldRepo.applyShield(for: blocklist) on the schedule-named store (CONTEXT §D-18).")
    }

    func testClearsShieldWhenStoreDirtyButShouldNotBeActive() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: ComputeScheduleWindow returns .inactive/.upcomingToday but schedule store was previously applied → UC calls shieldRepo.clearShield() (covers missed DAM intervalDidEnd callback).")
    }

    func testNoOpWhenStateMatches() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: ComputeScheduleWindow says .active AND schedule store was last-applied matching → UC makes ZERO calls to shieldRepo.applyShield/clearShield.")
    }

    func testIteratesOverAllEnabledSchedules() throws {
        try XCTSkipIf(true, "Stub — Plan 05-04 replaces with real assertion. Expected: multiple schedules in repository (even if MVP UI exposes one) — UC does filter(\\.enabled).forEach(heal) so schema-supports-N (CONTEXT §D-01) stays honest.")
    }
}
