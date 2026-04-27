import Combine

protocol ObserveBlocklistUseCase: Sendable {
    func execute() -> AnyPublisher<Blocklist, Never>
}

final class ObserveBlocklistUseCaseImpl: ObserveBlocklistUseCase {
    private let repository: BlocklistRepository

    init(repository: BlocklistRepository) {
        self.repository = repository
    }

    func execute() -> AnyPublisher<Blocklist, Never> {
        repository.blocklistPublisher
    }
}
