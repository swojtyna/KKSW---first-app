protocol ReconcileBlocklistUseCase: Sendable {
    func callAsFunction() async throws
}

final class ReconcileBlocklistUseCaseImpl: ReconcileBlocklistUseCase {
    private let repository: BlocklistRepository

    init(repository: BlocklistRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws {
        try await repository.reconcile()
    }
}
