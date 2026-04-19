import Foundation
@testable import DeluluDetox

final class MockFinalizeSessionFromMarkerUseCase: FinalizeSessionFromMarkerUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastNow: Date?
    var stubbedError: Error?
    var stubbedResult: Bool = false

    func callAsFunction(now: Date) async throws -> Bool {
        callCount += 1
        lastNow = now
        if let stubbedError { throw stubbedError }
        return stubbedResult
    }
}
