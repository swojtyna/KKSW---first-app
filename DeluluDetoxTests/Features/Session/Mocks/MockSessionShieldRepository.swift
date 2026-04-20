import Foundation
@testable import DeluluDetox

final class MockSessionShieldRepository: SessionShieldRepository, @unchecked Sendable {
    // MARK: applyShield
    private(set) var applyShieldCallCount = 0
    private(set) var applyShieldLastBlocklistId: UUID?
    var applyShieldError: Error?

    func applyShield(for blocklist: Blocklist) async throws {
        applyShieldCallCount += 1
        applyShieldLastBlocklistId = blocklist.id
        if let applyShieldError { throw applyShieldError }
    }

    // MARK: clearShield
    private(set) var clearShieldCallCount = 0
    func clearShield() async {
        clearShieldCallCount += 1
    }
}
