import Combine

protocol ObserveBlocklistUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<Blocklist, Never>
}

final class ObserveBlocklistUseCaseImpl: ObserveBlocklistUseCase {
    private let repository: BlocklistRepository

    init(repository: BlocklistRepository) {
        self.repository = repository
    }

    func callAsFunction() -> AnyPublisher<Blocklist, Never> {
        repository.blocklistPublisher
    }
}
