import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-02 / 05-07 (AppRoot scenePhase.active marker drain).
final class MockConsumeScheduleEventMarkerUseCase: ConsumeScheduleEventMarkerUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    /// Number of events the UC reports as appended (Plan 05-02 defines return).
    var stubbedAppendedCount: Int = 0
    var consumeError: Error?

    /// Shared call-order log (optional — AppRootViewModelTests passes a single
    /// array through two mocks to verify "consume marker BEFORE self-heal"
    /// ordering per RESEARCH §Pitfall 8).
    var callOrderLog: NSMutableArray?
    var callOrderTag: String = "consumeScheduleMarker"

    func execute() async throws -> Int {
        callCount += 1
        callOrderLog?.add(callOrderTag)
        if let consumeError { throw consumeError }
        return stubbedAppendedCount
    }
}
