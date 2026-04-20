import XCTest
@testable import DeluluDetox

/// Plan 05-07 lands these assertions.
final class ScheduleListViewModelTests: XCTestCase {

    func testListObservesScheduleRepositoryPublisher() throws {
        try XCTSkipIf(true, "Stub — Plan 05-07 replaces with real assertion. Expected: observeSchedule emits [Schedule] via ScheduleRepository.schedulesPublisher → vm.schedules reflects the emitted array.")
    }

    func testTapEditExistingSetsEditorDestinationWithSchedule() throws {
        try XCTSkipIf(true, "Stub — Plan 05-07 replaces with real assertion. Expected: list.editTapped(existing) → destination = .scheduleEditor(ScheduleEditorViewModel(existing:)) carrying the tapped schedule.")
    }

    func testTapCreateNewSetsEditorDestinationWithNil() throws {
        try XCTSkipIf(true, "Stub — Plan 05-07 replaces with real assertion. Expected: list.createTapped() → destination = .scheduleEditor(ScheduleEditorViewModel(existing: nil)) — empty editor flow.")
    }

    func testToggleRowCallsToggleScheduleUseCase() throws {
        try XCTSkipIf(true, "Stub — Plan 05-07 replaces with real assertion. Expected: row-level enable/disable toggle flip calls ToggleScheduleUseCase(scheduleId:, enabled:) — NOT a direct repo.upsert.")
    }
}
