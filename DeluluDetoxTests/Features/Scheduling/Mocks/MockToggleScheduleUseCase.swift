import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-07. ScheduleListViewModelTests inject this for
/// row-level enable/disable toggle verification.
final class MockToggleScheduleUseCase: ToggleScheduleUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastInputScheduleId: UUID?
    private(set) var lastInputEnabled: Bool?
    var toggleError: Error?

    func callAsFunction(scheduleId: UUID, enabled: Bool) async throws {
        callCount += 1
        lastInputScheduleId = scheduleId
        lastInputEnabled = enabled
        if let toggleError { throw toggleError }
    }
}
