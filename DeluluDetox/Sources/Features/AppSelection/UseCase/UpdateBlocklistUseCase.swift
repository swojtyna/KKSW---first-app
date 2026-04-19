@preconcurrency import FamilyControls

protocol UpdateBlocklistUseCase: Sendable {
    func callAsFunction(_ selection: FamilyActivitySelection) async throws
}

final class UpdateBlocklistUseCaseImpl: UpdateBlocklistUseCase {
    private let repository: BlocklistRepository

    init(repository: BlocklistRepository) {
        self.repository = repository
    }

    func callAsFunction(_ selection: FamilyActivitySelection) async throws {
        try await repository.update(with: selection)
    }
}
