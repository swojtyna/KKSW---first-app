import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-04. Records invocations of the sync entry point.
final class MockSyncScheduleWithSystemUseCase: SyncScheduleWithSystemUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastInputSchedule: Schedule?
    var syncError: Error?

    func sync(schedule: Schedule) async throws {
        callCount += 1
        lastInputSchedule = schedule
        if let syncError { throw syncError }
    }
}
