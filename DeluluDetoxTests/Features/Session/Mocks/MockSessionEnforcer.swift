import Foundation
@testable import DeluluDetox

final class MockSessionEnforcer: SessionEnforcer, @unchecked Sendable {
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

    // MARK: startActivityMonitoring
    private(set) var startActivityMonitoringCallCount = 0
    private(set) var startActivityMonitoringLastSession: SessionRecord?
    var startActivityMonitoringError: Error?

    func startActivityMonitoring(for session: SessionRecord) async throws {
        startActivityMonitoringCallCount += 1
        startActivityMonitoringLastSession = session
        if let startActivityMonitoringError { throw startActivityMonitoringError }
    }

    // MARK: stopActivityMonitoring
    private(set) var stopActivityMonitoringCallCount = 0
    func stopActivityMonitoring() async {
        stopActivityMonitoringCallCount += 1
    }
}
