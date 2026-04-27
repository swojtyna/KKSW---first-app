import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-02 / Plan 05-06. ScheduleEditorViewModelTests inject
/// this to assert that saveTapped() wires through to the UC.
final class MockCreateOrUpdateScheduleUseCase: CreateOrUpdateScheduleUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastInputSchedule: Schedule?
    var createOrUpdateError: Error?

    func execute(_ schedule: Schedule) async throws {
        callCount += 1
        lastInputSchedule = schedule
        if let createOrUpdateError { throw createOrUpdateError }
    }
}
