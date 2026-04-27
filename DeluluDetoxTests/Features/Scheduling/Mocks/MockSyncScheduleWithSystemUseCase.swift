import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-02 / Plan 05-04. Records invocations of the sync entry point.
/// Plan 05-02 uses it for CreateOrUpdateScheduleUseCase tests; Plan 05-04
/// replaces the production conformer with the real `SyncScheduleWithSystemUseCaseImpl`.
final class MockSyncScheduleWithSystemUseCase: SyncScheduleWithSystemUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastInputSchedule: Schedule?
    var syncError: Error?

    func execute(schedule: Schedule) async throws {
        callCount += 1
        lastInputSchedule = schedule
        if let syncError { throw syncError }
    }
}
