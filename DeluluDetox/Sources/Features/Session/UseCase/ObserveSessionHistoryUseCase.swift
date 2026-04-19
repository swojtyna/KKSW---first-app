import Combine

protocol ObserveSessionHistoryUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<[SessionRecord], Never>
}

final class ObserveSessionHistoryUseCaseImpl: ObserveSessionHistoryUseCase {
    private let repository: SessionRepository

    init(repository: SessionRepository) {
        self.repository = repository
    }

    func callAsFunction() -> AnyPublisher<[SessionRecord], Never> {
        repository.historyPublisher
    }
}
