import Foundation
@testable import DeluluDetox

/// Plan 05-03 — production-aligned mock. Records the ordered sequence of
/// start/stop calls so Plan 05-04 SyncScheduleWithSystemUseCaseTests can
/// assert the stop-before-start ordering.
///
/// `stopMonitoring(scheduleId:)` is non-throwing on the production protocol
/// (Plan 03 interface); Plan 04's test stub that implies otherwise will be
/// rewritten when Plan 04 lands.
final class MockScheduleActivityMonitoringRepository: ScheduleActivityMonitoringRepository, @unchecked Sendable {
    enum Call: Equatable {
        case start(scheduleId: UUID)
        case stop(scheduleId: UUID)
    }

    private(set) var callLog: [Call] = []

    // MARK: startMonitoring
    private(set) var startMonitoringCallCount = 0
    private(set) var lastStartedSchedule: Schedule?
    var startMonitoringError: Error?

    func startMonitoring(schedule: Schedule) async throws {
        startMonitoringCallCount += 1
        lastStartedSchedule = schedule
        callLog.append(.start(scheduleId: schedule.id))
        if let startMonitoringError { throw startMonitoringError }
    }

    // MARK: stopMonitoring
    private(set) var stopMonitoringCallCount = 0
    private(set) var lastStoppedScheduleId: UUID?
    private(set) var stoppedScheduleIds: [UUID] = []

    func stopMonitoring(scheduleId: UUID) async {
        stopMonitoringCallCount += 1
        lastStoppedScheduleId = scheduleId
        stoppedScheduleIds.append(scheduleId)
        callLog.append(.stop(scheduleId: scheduleId))
    }
}
