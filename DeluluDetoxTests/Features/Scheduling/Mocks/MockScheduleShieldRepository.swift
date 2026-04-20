import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-03. `ScheduleShieldRepository` protocol body is empty
/// today; this mock records call counters that Plan 05-03 assertions will
/// inspect once the protocol methods are declared.
final class MockScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable {
    // MARK: applyShield (Plan 05-03 declares on protocol).
    private(set) var applyShieldCallCount = 0
    private(set) var lastAppliedBlocklistId: UUID?
    var applyShieldError: Error?

    func applyShield(blocklistId: UUID) async throws {
        applyShieldCallCount += 1
        lastAppliedBlocklistId = blocklistId
        if let applyShieldError { throw applyShieldError }
    }

    // MARK: clearShield (Plan 05-03).
    private(set) var clearShieldCallCount = 0
    func clearShield() async {
        clearShieldCallCount += 1
    }
}
