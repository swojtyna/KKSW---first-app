import Foundation
@testable import DeluluDetox

/// Plan 05-04 — production-aligned mock. `ComputeScheduleWindowUseCase` is a
/// pure function; the mock exposes a stubbable `ScheduleWindow` plus call
/// counters so `SelfHealSchedulesUseCaseTests` can drive the
/// "shouldBeActive" branch without constructing real time math.
final class MockComputeScheduleWindowUseCase: ComputeScheduleWindowUseCase, @unchecked Sendable {
    var stubbedResult: ScheduleWindow = ScheduleWindow(state: .inactive, currentWeekday: 0)
    /// Per-scheduleId override so tests can configure different outcomes
    /// across multiple schedules in a single invocation.
    var stubbedResultsByScheduleId: [UUID: ScheduleWindow] = [:]

    private(set) var callCount = 0
    private(set) var lastInputSchedule: Schedule?
    private(set) var lastInputNow: Date?

    func callAsFunction(schedule: Schedule, now: Date, calendar: Calendar) -> ScheduleWindow {
        callCount += 1
        lastInputSchedule = schedule
        lastInputNow = now
        if let specific = stubbedResultsByScheduleId[schedule.id] {
            return specific
        }
        return stubbedResult
    }
}
