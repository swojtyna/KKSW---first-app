import XCTest
@testable import DeluluDetox

/// Plan 05-06 lands these assertions.
final class ScheduleEditorViewModelTests: XCTestCase {

    func testInitialStateHasNoDaysAndDefault09To17Enabled() throws {
        try XCTSkipIf(true, "Stub — Plan 05-06 replaces with real assertion. Expected: VM init with no existing Schedule → daysOfWeek=[], startHour=9, startMinute=0, endHour=17, endMinute=0, enabled=true.")
    }

    func testInitFromExistingSeedsAllFields() throws {
        try XCTSkipIf(true, "Stub — Plan 05-06 replaces with real assertion. Expected: VM(existing: Schedule(...)) seeds daysOfWeek, startHour/Minute, endHour/Minute, enabled, name from the passed schedule.")
    }

    func testPresetDniRoboczeSetsMonToFriWeekdays() throws {
        try XCTSkipIf(true, "Stub — Plan 05-06 replaces with real assertion. Expected: tapping 'Dni robocze' preset sets daysOfWeek = [2,3,4,5,6] (Mon=2..Fri=6 per Calendar.weekday).")
    }

    func testPresetWeekendSetsSatAndSun() throws {
        try XCTSkipIf(true, "Stub — Plan 05-06 replaces with real assertion. Expected: tapping 'Weekend' sets daysOfWeek = [7, 1] (Sat=7, Sun=1 per Calendar.weekday). Order may be sorted [1,7] — assertion MUST use Set equality.")
    }

    func testPresetCodziennieSetsAllSeven() throws {
        try XCTSkipIf(true, "Stub — Plan 05-06 replaces with real assertion. Expected: tapping 'Codziennie' sets daysOfWeek = [1,2,3,4,5,6,7].")
    }

    func testCrossMidnightDetectionWhenEndLessThanStart() throws {
        try XCTSkipIf(true, "Stub — Plan 05-06 replaces with real assertion. Expected: startHour=22, endHour=6 → vm.isCrossMidnight == true; UI shows the subtle 'Cross-midnight' marker (CONTEXT §D-10).")
    }

    func testSaveTappedCallsCreateOrUpdateUseCase() throws {
        try XCTSkipIf(true, "Stub — Plan 05-06 replaces with real assertion. Expected: saveTapped() → createOrUpdate(schedule:) called with assembled Schedule; on success, destination becomes nil (editor dismisses).")
    }

    func testSaveTappedFailureSetsErrorAlertDestination() throws {
        try XCTSkipIf(true, "Stub — Plan 05-06 replaces with real assertion. Expected: createOrUpdate throws → destination = .errorAlert with sarcastic Polish message (iOS się zbuntował, spróbuj jeszcze raz — per CONTEXT §D-14).")
    }
}
