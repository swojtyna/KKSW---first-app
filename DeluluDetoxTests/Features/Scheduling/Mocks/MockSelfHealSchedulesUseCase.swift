import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-04 / 05-07 (AppRoot scenePhase.active reconciliation).
final class MockSelfHealSchedulesUseCase: SelfHealSchedulesUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastInputNow: Date?
    var selfHealError: Error?

    func callAsFunction(now: Date) async throws {
        callCount += 1
        lastInputNow = now
        if let selfHealError { throw selfHealError }
    }
}
