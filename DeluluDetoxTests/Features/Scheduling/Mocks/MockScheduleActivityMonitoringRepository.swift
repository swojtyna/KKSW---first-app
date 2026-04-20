import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-03. Records the ordered sequence of start/stop calls so
/// Plan 05-04 SyncScheduleWithSystemUseCaseTests can assert call ordering.
final class MockScheduleActivityMonitoringRepository: ScheduleActivityMonitoringRepository, @unchecked Sendable {
    enum Call: Equatable {
        case start(scheduleId: UUID)
        case stop(scheduleId: UUID)
    }

    private(set) var callLog: [Call] = []

    // MARK: startMonitoring (Plan 05-03).
    private(set) var startMonitoringCallCount = 0
    private(set) var lastStartedSchedule: Schedule?
    var startMonitoringError: Error?

    func startMonitoring(schedule: Schedule) async throws {
        startMonitoringCallCount += 1
        lastStartedSchedule = schedule
        callLog.append(.start(scheduleId: schedule.id))
        if let startMonitoringError { throw startMonitoringError }
    }

    // MARK: stopMonitoring (Plan 05-03).
    private(set) var stopMonitoringCallCount = 0
    private(set) var lastStoppedScheduleId: UUID?
    var stopMonitoringError: Error?

    func stopMonitoring(scheduleId: UUID) async throws {
        stopMonitoringCallCount += 1
        lastStoppedScheduleId = scheduleId
        callLog.append(.stop(scheduleId: scheduleId))
        if let stopMonitoringError { throw stopMonitoringError }
    }
}
