import Foundation
@testable import DeluluDetox

final class MockSessionActivityMonitoringRepository: SessionActivityMonitoringRepository, @unchecked Sendable {
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
