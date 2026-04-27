@testable import DeluluDetox

final class MockRemoveTokenRecordUseCase: RemoveTokenRecordUseCase, @unchecked Sendable {
    var stubbedError: Error?
    private(set) var callCount = 0
    private(set) var capturedRecordID: TokenRecord.ID?

    func execute(_ recordID: TokenRecord.ID) async throws {
        callCount += 1
        capturedRecordID = recordID
        if let stubbedError { throw stubbedError }
    }
}
