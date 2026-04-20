import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-02 / 05-07 (AppRoot scenePhase.active marker drain).
final class MockConsumeScheduleEventMarkerUseCase: ConsumeScheduleEventMarkerUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    /// Number of events the UC reports as appended (Plan 05-02 defines return).
    var stubbedAppendedCount: Int = 0
    var consumeError: Error?

    func callAsFunction() async throws -> Int {
        callCount += 1
        if let consumeError { throw consumeError }
        return stubbedAppendedCount
    }
}
