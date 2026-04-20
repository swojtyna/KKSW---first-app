import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-04. `ComputeScheduleWindowUseCase` protocol body is
/// empty today; this mock exposes a stubbable return value + call counter
/// that Plan 05-04 tests (SelfHeal / Sync) will drive.
final class MockComputeScheduleWindowUseCase: ComputeScheduleWindowUseCase, @unchecked Sendable {
    /// Plan 05-04 introduces the actual ScheduleWindowState enum — the mock
    /// stores the stubbed result as `Any?` until then so Plan 05-04 tests
    /// can cast / replace without recompiling this file for the existing
    /// skip-stub Plan 05-01 baseline.
    var stubbedResult: Any?
    private(set) var callCount = 0
    private(set) var lastInputSchedule: Schedule?
    private(set) var lastInputNow: Date?

    func compute(schedule: Schedule, now: Date) -> Any? {
        callCount += 1
        lastInputSchedule = schedule
        lastInputNow = now
        return stubbedResult
    }
}
