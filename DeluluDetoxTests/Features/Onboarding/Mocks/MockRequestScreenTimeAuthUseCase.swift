@testable import DeluluDetox

final class MockRequestScreenTimeAuthUseCase: RequestScreenTimeAuthUseCase, @unchecked Sendable {
    var stubbedError: Error?
    var callCount = 0

    func callAsFunction() async throws {
        callCount += 1
        if let error = stubbedError {
            throw error
        }
    }
}
