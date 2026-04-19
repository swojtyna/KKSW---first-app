@testable import DeluluDetox

final class MockReconcileBlocklistUseCase: ReconcileBlocklistUseCase, @unchecked Sendable {
    var stubbedError: Error?
    private(set) var callCount = 0

    func callAsFunction() async throws {
        callCount += 1
        if let stubbedError { throw stubbedError }
    }
}
