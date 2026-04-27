import Combine

protocol ObserveSessionHistoryUseCase: Sendable {
    func execute() -> AnyPublisher<[SessionRecord], Never>
}

final class ObserveSessionHistoryUseCaseImpl: ObserveSessionHistoryUseCase {
    private let repository: SessionRepository

    init(repository: SessionRepository) {
        self.repository = repository
    }

    func execute() -> AnyPublisher<[SessionRecord], Never> {
        repository.historyPublisher
    }
}
