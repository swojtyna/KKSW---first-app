protocol RemoveTokenRecordUseCase: Sendable {
    func callAsFunction(_ recordID: TokenRecord.ID) async throws
}

final class RemoveTokenRecordUseCaseImpl: RemoveTokenRecordUseCase {
    private let repository: BlocklistRepository

    init(repository: BlocklistRepository) {
        self.repository = repository
    }

    func callAsFunction(_ recordID: TokenRecord.ID) async throws {
        try await repository.remove(recordID: recordID)
    }
}
