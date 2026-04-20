import XCTest
@testable import DeluluDetox

/// Plan 05-03 lands these assertions.
final class ScheduleShieldRepositoryTests: XCTestCase {

    func testApplyShieldWritesTokensToScheduleNamedStoreOnly() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: applyShield(for:) calls writer.setShieldApplications/WebDomains/Categories on a LiveManagedSettingsStoreWriter constructed with storeName = ManagedSettingsStoreNames.schedule. Session store (deluludetox.session) is NEVER touched.")
    }

    func testApplyShieldWritesRequireAutomaticDateAndTime() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: applyShield also calls setDateAndTimeRequireAutomatic(true) on the schedule store to defeat clock-skew bypass (anti-tamper mitigation — user cannot roll the device clock to escape the window).")
    }

    func testClearShieldResetsAllFacetsAndRestrictions() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: clearShield sets applications, webDomains, categories, shieldDateAndTime, and any other relevant ManagedSettingsStore fields to nil/false unconditionally on the schedule-named store.")
    }

    func testStoreNameIsolationFromSessionStore() throws {
        try XCTSkipIf(true, "Stub — Plan 05-03 replaces with real assertion. Expected: LiveScheduleShieldRepository constructs LiveManagedSettingsStoreWriter(storeName: ManagedSettingsStoreNames.schedule), NOT .session — verified via mock writer call inspection.")
    }
}
