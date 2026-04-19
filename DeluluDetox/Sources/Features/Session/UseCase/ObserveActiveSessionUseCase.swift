import Combine

protocol ObserveActiveSessionUseCase: Sendable {
    func callAsFunction() -> AnyPublisher<SessionRecord?, Never>
}

final class ObserveActiveSessionUseCaseImpl: ObserveActiveSessionUseCase {
    private let repository: SessionRepository

    init(repository: SessionRepository) {
        self.repository = repository
    }

    func callAsFunction() -> AnyPublisher<SessionRecord?, Never> {
        repository.activeSessionPublisher
    }
}
