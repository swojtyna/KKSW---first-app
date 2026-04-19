@preconcurrency import FamilyControls
@testable import DeluluDetox

final class MockUpdateBlocklistUseCase: UpdateBlocklistUseCase, @unchecked Sendable {
    var stubbedError: Error?
    private(set) var callCount = 0
    private(set) var capturedSelection: FamilyActivitySelection?

    func callAsFunction(_ selection: FamilyActivitySelection) async throws {
        callCount += 1
        capturedSelection = selection
        if let stubbedError { throw stubbedError }
    }
}
