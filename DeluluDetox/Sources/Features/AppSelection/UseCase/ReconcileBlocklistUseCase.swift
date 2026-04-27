protocol ReconcileBlocklistUseCase: Sendable {
    func execute() async throws
}

final class ReconcileBlocklistUseCaseImpl: ReconcileBlocklistUseCase {
    private let repository: BlocklistRepository

    init(repository: BlocklistRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.reconcile()
    }
}
