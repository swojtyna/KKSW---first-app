import Foundation
@testable import DeluluDetox

final class MockStartSessionUseCase: StartSessionUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastBlocklistId: UUID?
    private(set) var lastDuration: SessionDuration?
    private(set) var lastNow: Date?
    var stubbedError: Error?
    var stubbedResult: SessionRecord?

    /// Optional async hook — if set, awaited BEFORE returning the stubbed result.
    /// Lets callers gate the call to exercise re-entry guards (P05).
    var beforeReturn: (@Sendable () async -> Void)?

    func execute(blocklistId: UUID, duration: SessionDuration, now: Date) async throws -> SessionRecord {
        callCount += 1
        lastBlocklistId = blocklistId
        lastDuration = duration
        lastNow = now
        if let stubbedError { throw stubbedError }
        guard let stubbedResult else {
            fatalError("MockStartSessionUseCase.stubbedResult not set")
        }
        if let beforeReturn { await beforeReturn() }
        return stubbedResult
    }
}
