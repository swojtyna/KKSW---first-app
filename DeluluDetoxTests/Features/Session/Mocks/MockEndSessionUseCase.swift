import Foundation
@testable import DeluluDetox

final class MockEndSessionUseCase: EndSessionUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastOutcome: SessionOutcome?
    private(set) var lastActualEndAt: Date?
    var stubbedError: Error?

    func callAsFunction(outcome: SessionOutcome, actualEndAt: Date) async throws {
        callCount += 1
        lastOutcome = outcome
        lastActualEndAt = actualEndAt
        if let stubbedError { throw stubbedError }
    }
}
