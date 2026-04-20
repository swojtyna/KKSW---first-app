import Foundation
@testable import DeluluDetox

/// Mock for Plan 05-04 / 05-07 (AppRoot scenePhase.active reconciliation).
/// Plan 04 finalised the protocol as `@discardableResult -> Int`; the mock
/// exposes a stubbable return value + optional thrown error.
final class MockSelfHealSchedulesUseCase: SelfHealSchedulesUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastInputNow: Date?
    var stubbedResult: Int = 0
    var selfHealError: Error?

    /// Shared call-order log (optional — AppRootViewModelTests passes a
    /// single array through two mocks to verify "consume marker BEFORE
    /// self-heal" ordering per RESEARCH §Pitfall 8).
    var callOrderLog: NSMutableArray?
    /// Identifier appended to `callOrderLog` on each call.
    var callOrderTag: String = "selfHealSchedules"

    @discardableResult
    func callAsFunction(now: Date) async throws -> Int {
        callCount += 1
        lastInputNow = now
        callOrderLog?.add(callOrderTag)
        if let selfHealError { throw selfHealError }
        return stubbedResult
    }
}
