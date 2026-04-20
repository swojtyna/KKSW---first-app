import Foundation
@testable import DeluluDetox

/// Plan 05-03 — production-aligned mock. `applyShield(for blocklist:)` matches
/// the repository protocol landed by this plan; Plan 05-04 SyncScheduleUseCase
/// tests will inspect `lastAppliedBlocklist` / call counters.
final class MockScheduleShieldRepository: ScheduleShieldRepository, @unchecked Sendable {
    // MARK: applyShield
    private(set) var applyShieldCallCount = 0
    private(set) var lastAppliedBlocklist: Blocklist?
    var applyShieldError: Error?

    func applyShield(for blocklist: Blocklist) async throws {
        applyShieldCallCount += 1
        lastAppliedBlocklist = blocklist
        if let applyShieldError { throw applyShieldError }
    }

    // MARK: clearShield
    private(set) var clearShieldCallCount = 0
    func clearShield() async {
        clearShieldCallCount += 1
    }
}
